# geMMaFloW — Piano di lavoro

> Handoff document. Leggere questo file per intero all'inizio di ogni nuova chat
> per ripartire senza perdere contesto.

---

## 1. Contesto e obiettivo

**geMMaFloW** è un fork personale di [FreeFlow](https://github.com/zachlatta/freeflow),
un'app macOS nativa in Swift che replica Wispr Flow: tieni premuto `Fn`,
detti, e il testo pulito viene incollato nella text box attiva.

FreeFlow upstream dipende da **Groq** (cloud) per due servizi:
1. **Trascrizione audio** (`whisper-large-v3`) — endpoint `/audio/transcriptions`
2. **Pulizia testo post-trascrizione** (`openai/gpt-oss-20b` con fallback
   `meta-llama/llama-4-scout-17b-16e-instruct`) — endpoint `/chat/completions`

Il costo Groq è bassissimo (~$1/mese per uso intenso) ma **l'audio esce dalla
macchina**. L'obiettivo di questo fork è ottenere una pipeline **100% locale**:

- Trascrizione audio → **whisper.cpp** (o WhisperKit) in locale
- Pulizia testo → **Gemma 4** (E4B) via **Ollama** in locale
- Zero chiamate a Groq, zero API key richiesta, zero dati fuori dalla macchina

Motivazione: privacy (non costo). Bonus: system prompt personalizzabile,
vocabolario italiano più curato, nessun rate limit.

---

## 2. Architettura attuale (upstream)

Pipeline a 3 stage in [Sources/AppState.swift](../../Sources/AppState.swift):

```
[Fn pressed] → AudioRecorder → TranscriptionService → PostProcessingService → paste
                                     ↓                          ↓
                             Groq /audio/transcriptions    Groq /chat/completions
                             (whisper-large-v3)            (gpt-oss-20b)
```

### File chiave

| File | Ruolo |
|---|---|
| [Sources/AppState.swift](../../Sources/AppState.swift) | Stato globale, istanzia i servizi, tiene `apiBaseURL` + `apiKey` |
| [Sources/TranscriptionService.swift](../../Sources/TranscriptionService.swift) | Chiama `{baseURL}/audio/transcriptions` con multipart/form-data |
| [Sources/PostProcessingService.swift](../../Sources/PostProcessingService.swift) | Chiama `{baseURL}/chat/completions`, ha system prompt ricco |
| [Sources/AppContextService.swift](../../Sources/AppContextService.swift) | **Terzo consumer** del baseURL — anche questo fa `/chat/completions` per capire il contesto dell'app attiva |
| [Sources/LLMAPITransport.swift](../../Sources/LLMAPITransport.swift) | Thin wrapper su URLSession, **nessun vendor-specific code qui** |
| [Sources/SetupView.swift](../../Sources/SetupView.swift) | Onboarding: chiede API key Groq, valida (`TranscriptionService.validateAPIKey`) |
| [Sources/SettingsView.swift](../../Sources/SettingsView.swift) | UI settings: permette già di cambiare `apiBaseURL`, `transcriptionModel`, `postProcessingModel` |
| [Sources/KeychainStorage.swift](../../Sources/KeychainStorage.swift) | Persiste l'API key |

### Limitazione critica del codice attuale

**Esiste un solo `apiBaseURL` condiviso** tra tutti e tre i servizi
(Transcription, PostProcessing, AppContext). Questo è il nodo: il README upstream
afferma che "puoi puntare a Ollama per l'LLM" — in pratica se fai quello,
**la trascrizione si rompe** perché Ollama non espone `/audio/transcriptions`.

Il primo refactor strutturale del fork è **separare i baseURL**.

---

## 3. Roadmap in 4+1 step

### Step 0 — Build e run upstream invariato (1 ora)

Prima di modificare qualsiasi cosa, verificare che il progetto compili e giri
sulla macchina attuale. È Swift nativo macOS, niente Electron/npm.

```bash
cd ~/Documents/Documenti/Startup/geMMaFloW
cat Makefile       # capire i target
make               # probabilmente build via swift build o xcodebuild
```

Verificare:
- [ ] App compila senza errori
- [ ] Launch, setup con chiave Groq (temporanea), dettatura base funziona
- [ ] Capire quale versione macOS minima (vedere Info.plist)

Se non ci sono toolchain Swift installate: `xcode-select --install` e
installare Xcode completo dallo App Store (serve anche per firmare).

### Step 1 — Split baseURL: transcription separato da LLM (2-3 ore)

Obiettivo: poter usare Groq per Whisper e Ollama per LLM nello stesso tempo.
**Non rimuoviamo ancora Groq** — lo disaccoppiamo soltanto.

**Stato attuale (2026-04-20): ~40% fatto.** I tre servizi sono già parametrizzati
(Transcription/PostProcessing/Context ricevono `apiKey` e `baseURL` dal
costruttore, non hardcodati — vedi [TranscriptionService.swift:7-24](../../Sources/TranscriptionService.swift#L7-L24)).
I **modelli** sono configurabili separatamente in Settings
([SettingsView.swift:128-229](../../Sources/SettingsView.swift#L128-L229), commit
`ace3ce1` / `f8c43ad`). **Manca lo split di baseURL e API key** in AppState —
oggi c'è ancora un solo `apiBaseURL` + una sola `apiKey` condivisi
([AppState.swift:211-216](../../Sources/AppState.swift#L211-L216),
[:557](../../Sources/AppState.swift#L557)).

#### Già fatto ✅
- Modelli configurabili (transcription / postProcessing / postProcessingFallback / context)
- Validazione base URL di transcription ([commit `f2aa6d7`](../../))
- I tre servizi leggono `apiKey` + `baseURL` da parametri del costruttore

#### Da fare
1. In [AppState.swift](../../Sources/AppState.swift), aggiungere:
   - `@Published var transcriptionBaseURL: String` (default `https://api.groq.com/openai/v1`)
   - `@Published var llmBaseURL: String` (default `https://api.groq.com/openai/v1`)
   - `transcriptionAPIKey` e `llmAPIKey` via Keychain (oggi c'è una sola `apiKey`)
   - Mantenere `apiBaseURL` come fallback retrocompatibile: se i nuovi campi sono vuoti, usare `apiBaseURL`. Migrazione one-shot al primo avvio della versione nuova.

2. Propagare ai costruttori in [AppState.swift:476-477](../../Sources/AppState.swift#L476-L477), [:604-605](../../Sources/AppState.swift#L604-L605), [:705-706](../../Sources/AppState.swift#L705-L706):
   - `TranscriptionService(apiKey: transcriptionAPIKey, baseURL: transcriptionBaseURL, ...)`
   - `PostProcessingService(apiKey: llmAPIKey, baseURL: llmBaseURL, ...)`
   - `AppContextService(apiKey: llmAPIKey, baseURL: llmBaseURL, ...)`

3. In [SettingsView.swift](../../Sources/SettingsView.swift):
   - Sdoppiare il campo `apiBaseURL` in due: **Transcription provider** e **LLM provider**
   - Ogni sezione: base URL, API key (stringa vuota accettata per local), model(s)
   - Aggiungere preset rapidi: "Groq" | "Ollama locale" | "Custom"

4. In [SetupView.swift](../../Sources/SetupView.swift):
   - L'onboarding può chiedere solo la chiave Groq iniziale (come oggi) — non complichiamo
   - L'utente poi sdoppia in Settings

**Test**: imposta `llmBaseURL = http://localhost:11434/v1`, `llmAPIKey = ollama`,
`postProcessingModel = gemma4:e4b` (o `gemma3n:e4b` se Ollama non ha ancora il
tag Gemma 4). Tieni transcription su Groq. Detta qualcosa. Deve funzionare e il
log di Groq deve mostrare SOLO chiamate Whisper, zero `/chat/completions`.

### Step 2 — Whisper locale (1 giornata)

Due strade, in ordine di preferenza:

**Opzione A (consigliata): WhisperKit di Argmax** — Swift-native, Apple-ottimizzato,
API pulita, modelli mlcompute/ANE, gira su Apple Silicon e Intel.
- Repo: https://github.com/argmaxinc/WhisperKit
- Aggiungerlo come Swift Package dependency
- Sostituire l'implementazione interna di `TranscriptionService.transcribe(fileURL:)`
  con `WhisperKit.transcribe(audioPath:)` quando `transcriptionBaseURL == "local://whisperkit"`
  (o analogo sentinel)
- Al primo run, scarica il modello scelto (`large-v3-turbo` o `medium`) in `Application Support/`

**Opzione B: whisper.cpp via binding** — più lavoro (bundle binario, gestione
path), ma totale controllo. Da valutare solo se WhisperKit ha problemi con
italiano.

Implementazione:

1. Aggiungere WhisperKit al progetto:
   - Se è SwiftPM: aggiungere al `Package.swift`
   - Se è Xcode project: File → Add Packages → URL repo

2. Refactoring `TranscriptionService`:
   - Introdurre un protocol `TranscriptionBackend` con metodo `transcribe(url:) async throws -> String`
   - Due implementazioni: `GroqTranscriptionBackend` (l'attuale) e `WhisperKitTranscriptionBackend` (nuova)
   - `TranscriptionService` sceglie il backend in base a `transcriptionBaseURL`

3. UI: in Settings, aggiungere toggle "Use local transcription (WhisperKit)"
   con dropdown modello (Turbo / Medium / Small).

4. First-run UX: se locale, mostrare un pop-up "Scaricamento modello Whisper
   (~1.5GB)" con progress bar. Modello in `~/Library/Application Support/geMMaFloW/models/`.

**Test**: disabilita rete o metti firewall. Detta. Deve funzionare.
Verifica qualità italiano con frasi tecniche — se Turbo non basta, provare Medium.

### Step 3 — Bundle LLM locale con llama.cpp (2-3 giorni)

Obiettivo: eliminare la dipendenza esterna da Ollama per l'utente finale. L'app
deve essere "download and go" — zero setup manuale di runtime LLM.

**Scelta runtime: llama.cpp** (non MLX Swift). Motivo: llama.cpp supporta universal
binary (arm64 + Intel), mentre MLX è arm64-only. I Mac Intel 2018-2022 sono ancora
in circolazione e non vogliamo escluderli. Vedi memoria progetto
`llm_runtime_choice.md`.

Lavoro:

1. **Integrazione llama.cpp**:
   - Swift Package (llama.cpp ha SwiftPM nativo dalle release recenti) oppure
     wrapper esistente (es. `LLM.swift` di eastriverlee)
   - Compilazione con Metal per GPU Apple Silicon + CPU fallback per Intel
   - Verificare support Gemma 4 in llama.cpp (uscita modello 2026-04-02; llama.cpp
     è solitamente tra i primi a supportare nuovi Gemma)

2. **Abstracting del backend LLM**:
   - Protocol `LLMBackend` con metodo `complete(messages: [Message]) async throws -> String`
   - Due implementazioni: `OpenAICompatibleBackend` (l'attuale, via HTTP) e
     `LocalLlamaBackend` (nuovo, in-process)
   - `PostProcessingService` e `AppContextService` scelgono il backend

3. **Gestione modello** (UX first-run):
   - Modello in `~/Library/Application Support/geMMaFloW/models/gemma-4-e4b-q4.gguf`
     (~3-4 GB per Q4_K_M)
   - Pop-up first-run "Download Gemma 4 locale (3.8 GB)" con progress bar
   - Verifica SHA256 del modello scaricato
   - Opzionale: selettore quantizzazione (Q4 default, Q5/Q8 per chi ha RAM)

4. **Settings UI**:
   - Toggle "Use bundled LLM (llama.cpp + Gemma 4)" come default
   - Fallback "Use external OpenAI-compatible API" per power user
   - Override provider esistente (Step 1) resta disponibile

**Test**: rete disconnessa + Ollama spento. Detta → deve funzionare tutto locale.
Qualità italiano Gemma 4 E4B Q4 sui prompt di post-processing: 80%+ pari a
Gemma 4 full precision.

### Step 4 — Rimuovere cloud come default e polish first-run (1 giorno)

Solo dopo che Step 2 + 3 funzionano bene per 1-2 settimane reali.

- Default dell'app: WhisperKit locale + llama.cpp + Gemma 4 locale
- Setup view: niente più "Enter Groq API key" obbligatorio. Primo avvio guida al
  download dei due modelli (Whisper + Gemma) con progress visibile.
- Le opzioni cloud (Groq, OpenAI, altri) restano disponibili in Settings come
  opt-in per power user.
- Firma, notarizzazione, DMG per distribuzione.

---

## 4. Dettagli tecnici da ricordare

### Formato audio

[TranscriptionService.swift:192-198](../../Sources/TranscriptionService.swift#L192-L198)
già normalizza l'audio a WAV 16kHz mono PCM-Int16 via `AudioNormalization.writePreferredAudioCopy`.
Questo è **esattamente** il formato che whisper.cpp/WhisperKit si aspettano. Zero lavoro extra.

### System prompt

[PostProcessingService.swift:32-92](../../Sources/PostProcessingService.swift#L32-L92)
contiene un system prompt enorme e molto ben scritto. Funziona con qualsiasi LLM
decente — Gemma 4 E4B dovrebbe gestirlo. Se Gemma non tiene, provare:
- Gemma 4 E2B con prompt abbreviato
- Qwen 2.5 7B
- Llama 3.2 8B

### Fallback model

[PostProcessingService.swift:319-330](../../Sources/PostProcessingService.swift#L319-L330)
ha logica di retry su un modello di fallback per status 429 (rate limit) o empty
output. Con Ollama locale il 429 non accadrà ma l'empty output sì — mantenere
la logica, con fallback tipo `gemma3n:e2b` se il primario è `gemma3n:e4b`.

### Reasoning effort

Linee 395-399 e 495-499: il payload include `reasoning_effort` e
`include_reasoning` **solo se il modello è `openai/gpt-oss-20b`**. Questo campo
non va inviato a Gemma — la condizione esistente lo esclude già, nessuna modifica
necessaria.

### API key validation

[TranscriptionService.swift:28-44](../../Sources/TranscriptionService.swift#L28-L44)
valida hitting `{baseURL}/models`. Ollama espone `/api/tags` ma anche
`/v1/models` (OpenAI-compat) — quindi la validazione dovrebbe funzionare, ma
con una chiave fittizia (es. "ollama"). Verificare.

### Hallucination filter

[TranscriptionService.swift:244-302](../../Sources/TranscriptionService.swift#L244-L302)
filtra "thank you" / "you" allucinati quando `no_speech_prob >= 0.1`. Questo
campo è nel response format `verbose_json` di Whisper. **WhisperKit lo espone?**
Da verificare — se no, il filtro diventa no-op (accettabile).

### Context awareness

[AppContextService.swift](../../Sources/AppContextService.swift) legge il nome
dell'app attiva, la finestra, e genera un `contextSummary` che finisce nel
prompt. Usa l'LLM! Anche questo va su Ollama dopo Step 1. System prompt in
quello file.

---

## 5. Setup del dev environment (prerequisiti)

```bash
# 1. Xcode (da App Store) + Command Line Tools
xcode-select --install

# 2. Ollama + Gemma 4
brew install ollama
ollama serve  # oppure: brew services start ollama
ollama pull gemma4:e4b    # uscito 2 aprile 2026 — verificare disponibilità tag
# fallback: ollama pull gemma3n:e4b
# Test: curl http://localhost:11434/v1/models

# 3. (Step 2) WhisperKit — SwiftPM dependency, nessun brew
```

---

## 6. Testing plan

Per ogni step, verificare su questi scenari:

| Scenario | Attesa |
|---|---|
| Dettatura breve italiano (5s) | Testo pulito incollato in <3s |
| Dettatura lunga italiano (60s) | Testo pulito in <8s |
| Dettatura con termini tecnici ("API", "Docker", "git push") | Preservati senza autocorrect strano |
| Dettatura in email con destinatario visibile | Nome corretto da contesto |
| Silenzio (2s di niente) | Nessun testo incollato (no "thank you" hallucination) |
| Rete disconnessa (dopo Step 2) | Funziona comunque |
| Doppia chiamata rapida | Nessuna race condition |

---

## 7. Questioni aperte per la prossima sessione

1. **Il Makefile del progetto usa SwiftPM, xcodebuild, o entrambi?** Da leggere
   prima di provare a buildare.
2. **Info.plist target min macOS**: 13? 14? Impatta su WhisperKit (richiede
   macOS 13+ per ANE).
3. **Naming del prodotto**: "geMMaFloW" è il repo — teniamo il nome per l'app
   visibile o rinominiamo a qualcosa di più pulito ("FlowLocal"?)? Decisione da
   prendere al momento del packaging, non ora.
4. **Upstream sync**: il repo originale è attivo. Politica: dopo Step 3, è
   improbabile che ci interessino PR upstream (divergeremo troppo). Prima
   tenere allineati i fix di sicurezza.

---

## 8. Riferimenti utili

- WhisperKit: https://github.com/argmaxinc/WhisperKit
- whisper.cpp: https://github.com/ggerganov/whisper.cpp
- Ollama OpenAI compat: https://github.com/ollama/ollama/blob/main/docs/openai.md
- Gemma 3n su Ollama: https://ollama.com/library/gemma3n
- Gemma 4 model card: https://ai.google.dev/gemma/docs/core/model_card_4
- Upstream FreeFlow: https://github.com/zachlatta/freeflow

---

## 9. Punto in cui siamo (2026-04-20)

- [x] Fork creato: `verdana86/geMMaFloW`
- [x] Clonato in locale: `~/Documents/Documenti/Startup/geMMaFloW`
- [x] Upstream remote configurato (`git fetch upstream`)
- [x] Codice analizzato, file chiave identificati
- [x] Piano scritto (questo file)
- [x] **Step 0 — Build e run upstream invariato** (build via Makefile+swiftc funziona, macOS min 13.0)
- [x] **Infra test** — SwiftPM affiancato al Makefile, `swift test` via swift-testing framework (serve Xcode installato, `xcode-select -s /Applications/Xcode.app/Contents/Developer`)
- [x] **Step 1 — Split baseURL** completato: `transcriptionBaseURL`/`llmBaseURL`/`transcriptionAPIKey`/`llmAPIKey` in AppState con fallback retrocompatibile al legacy `apiBaseURL`/`apiKey`; UI override opt-in in SettingsView con preset Ollama; 7 test verdi (`resolveEndpoint` pura)
- [ ] Step 2 — WhisperKit locale ← PROSSIMO
- [ ] Step 3 — Bundle llama.cpp + Gemma 4 (elimina dipendenza Ollama per utente finale)
- [ ] Step 4 — Rimuovere cloud default + polish first-run UX

### Decisioni prese (2026-04-20)

**Scartato: Gemma-only (Gemma 4 fa anche trascrizione).** Gemma 4 E4B è uscito
il 2 aprile 2026 e supporta nativamente ASR multilingue (italiano incluso).
Tentazione: un solo modello per tutto lo stack. Ragioni del NO:
1. **Ollama non supporta ancora input audio per Gemma** (solo testo). Servirebbe
   un runtime diverso: `mlx-vlm` (Python) o aspettare llama.cpp/Ollama. Significa
   impacchettare un server Python dentro l'app macOS — peggiora notarizzazione,
   firma, dimensioni, installazione.
2. **Limite duro 30s audio** per chiamata. La maggior parte delle dettature sta
   sotto, ma va chunkato per sessioni lunghe.
3. **Qualità italiano non verificata** su termini tecnici — Whisper è dedicato a
   speech, Gemma audio è general-purpose.

Rimaniamo quindi sull'architettura **due-modelli**: WhisperKit (Swift-native,
zero server esterni) + Gemma 4 via Ollama per LLM. Se in futuro Ollama aggiunge
audio a Gemma 4 con qualità decente, valutiamo un collasso a un solo modello in
uno Step 4 opzionale.

---

## Come ripartire in una nuova chat

Apri Claude Code dalla cartella `~/Documents/Documenti/Startup/geMMaFloW` e
inizia con:

> "Leggi `docs/analysis/PLAN.md`, poi procedi con lo Step 0: verifica che il
> progetto compili sulla mia macchina e guida me nei primi test."

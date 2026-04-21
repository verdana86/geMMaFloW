# GemmaFlow benchmark

Audio source: macOS `say` (voice Samantha, 16 kHz mono). Reference text: see `bench/reference.txt`.

Device: Apple Silicon (M-series), macOS Version 26.3.1 (a) (Build 25D771280a).

## Latency (ms)

| Length | Whisper | Gemma | Whisper ms | Gemma ms | Total ms |
|---|---|---|---:|---:|---:|
| 20s | Whisper Small | Gemma E2B | 1477 | 1634 | 3112 |
| 20s | Whisper Small | Gemma E4B | 1477 | 27465 | 28942 |
| 20s | Whisper Large | Gemma E2B | 6194 | 42094 | 48289 |
| 20s | Whisper Large | Gemma E4B | 6194 | 66712 | 72907 |
| 40s | Whisper Small | Gemma E2B | 2728 | 41326 | 44054 |
| 40s | Whisper Small | Gemma E4B | 2728 | 5923 | 8652 |
| 40s | Whisper Large | Gemma E2B | 5752 | 6159 | 11911 |
| 40s | Whisper Large | Gemma E4B | 5752 | 15400 | 21153 |
| 60s | Whisper Small | Gemma E2B | 4278 | 7000 | 11278 |
| 60s | Whisper Small | Gemma E4B | 4278 | 11547 | 15826 |
| 60s | Whisper Large | Gemma E2B | 6969 | 42810 | 49779 |
| 60s | Whisper Large | Gemma E4B | 6969 | 42455 | 49424 |
| full | Whisper Small | Gemma E2B | 5502 | 54224 | 59727 |
| full | Whisper Small | Gemma E4B | 5502 | 77754 | 83256 |
| full | Whisper Large | Gemma E2B | 7960 | 64048 | 72008 |
| full | Whisper Large | Gemma E4B | 7960 | 62001 | 69961 |

## Transcripts

### 20s — Whisper Small + Gemma E2B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma.

**Cleaned (Gemma):**

> Okay so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations measuring both the transcription time and the quality of the final output. The first model whisper converts my voice into raw text. The second model Gemma.

### 20s — Whisper Small + Gemma E4B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma.

**Cleaned (Gemma):**

> Okay, so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma.

### 20s — Whisper Large + Gemma E2B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma.

**Cleaned (Gemma):**

> Okay so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations measuring both the transcription time and the quality of the final output. The first model whisper converts my voice into raw text. The second model Gemma.

### 20s — Whisper Large + Gemma E4B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma.

**Cleaned (Gemma):**

> Okay, so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma.

### 40s — Whisper Small + Gemma E2B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward too, um, fix punctuation, remove hesitations like ORI mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallid, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain URI.

**Cleaned (Gemma):**

> Okay so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations measuring both the transcription time and the quality of the final output. The first model whisper converts my voice into raw text. The second model Gemma kicks in afterward too fix punctuation remove hesitations like ORI mean and correct any errors. Some specific terms to test are MacBook Swift Metallid 82.5% and the acronym API. Longer sentences tend to confuse smaller models especially when they contain URI.

### 40s — Whisper Small + Gemma E4B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward too, um, fix punctuation, remove hesitations like ORI mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallid, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain URI.

**Cleaned (Gemma):**

> Okay, so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to fix punctuation, remove hesitations like "or I mean," and correct any errors. Some specific terms to test are MacBook, Swift, Metallid, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain URI.

### 40s — Whisper Large + Gemma E2B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to, um, fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are: MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain:

**Cleaned (Gemma):**

> Okay so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations measuring both the transcription time and the quality of the final output. The first model whisper converts my voice into raw text. The second model Gemma kicks in afterward to fix punctuation remove hesitations like or I mean and correct any errors. Some specific terms to test are MacBook Swift Metallib 82.5% and the acronym API. Longer sentences tend to confuse smaller models especially when they contain

### 40s — Whisper Large + Gemma E4B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to, um, fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are: MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain:

**Cleaned (Gemma):**

> Okay, so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are: MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain:

### 60s — Whisper Small + Gemma E2B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward too, um, fix punctuation, remove hesitations like ORI mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallab, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one, first, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like Ph.D. or CEO. Domain-specific vocabulary matters to "think of terms like Kubernetes."

**Cleaned (Gemma):**

> Okay so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations measuring both the transcription time and the quality of the final output. The first model whisper converts my voice into raw text. The second model Gemma kicks in afterward too fix punctuation remove hesitations like ORI mean and correct any errors. Some specific terms to test are MacBook Swift Metallab 82.5% and the acronym API. Longer sentences tend to confuse smaller models especially when they contain parenthetical clauses or bulleted lists like this one first second third fourth. Consider also how the model handles numbers like 2026 ordinals like the 21st century and abbreviations like Ph.D. or CEO. Domain specific vocabulary matters to think of terms like Kubernetes.

### 60s — Whisper Small + Gemma E4B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward too, um, fix punctuation, remove hesitations like ORI mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallab, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one, first, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like Ph.D. or CEO. Domain-specific vocabulary matters to "think of terms like Kubernetes."

**Cleaned (Gemma):**

> Okay, so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to fix punctuation, remove hesitations like "or I mean," and correct any errors. Some specific terms to test are MacBook, Swift, Metallab, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one: first, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like Ph.D. or CEO. Domain-specific vocabulary matters, so think of terms like Kubernetes.

### 60s — Whisper Large + Gemma E2B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to, um, fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one. First, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like PhD or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes.

**Cleaned (Gemma):**

> Okay so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations measuring both the transcription time and the quality of the final output. The first model whisper converts my voice into raw text. The second model Gemma kicks in afterward to fix punctuation remove hesitations like or I mean and correct any errors. Some specific terms to test are MacBook Swift Metallib 82.5% and the acronym API. Longer sentences tend to confuse smaller models especially when they contain parenthetical clauses or bulleted lists like this one first second third fourth. Consider also how the model handles numbers like 2026 ordinals like the 21st century and abbreviations like PhD or CEO. Domain specific vocabulary matters too. Think of terms like Kubernetes.

### 60s — Whisper Large + Gemma E4B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to, um, fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one. First, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like PhD or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes.

**Cleaned (Gemma):**

> Okay, so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one. First, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like PhD or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes.

### full — Whisper Small + Gemma E2B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward too, um, fix punctuation, remove hesitations like ORI mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallab, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one, first, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like Ph.D. or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes, asynchronous, encapsulation, or factorial. A good dictation pipeline should preserve the user's intent. Stay faithful to the spoken words and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question. Can we, uh, get quality comparable to the large model while paying only a third of the agency? We'll see.

**Cleaned (Gemma):**

> Okay, today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward too, to fix punctuation, remove hesitations like ORI mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallab, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain parenthetical clauses or bulleted lists like this one, first, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like Ph.D. or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes, asynchronous, encapsulation, or factorial. A good dictation pipeline should preserve the user's intent. Stay faithful to the spoken words and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question. Can we get quality comparable to the large model while paying only a third of the agency? We'll see.

### full — Whisper Small + Gemma E4B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward too, um, fix punctuation, remove hesitations like ORI mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallab, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one, first, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like Ph.D. or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes, asynchronous, encapsulation, or factorial. A good dictation pipeline should preserve the user's intent. Stay faithful to the spoken words and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question. Can we, uh, get quality comparable to the large model while paying only a third of the agency? We'll see.

**Cleaned (Gemma):**

> Okay, so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to fix punctuation, remove hesitations like "or I mean," and correct any errors. Some specific terms to test are MacBook, Swift, Metallab, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one: first, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like Ph.D. or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes, asynchronous, encapsulation, or factorial. A good dictation pipeline should preserve the user's intent. Stay faithful to the spoken words and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question: Can we get quality comparable to the large model while paying only a third of the agency? We'll see.

### full — Whisper Large + Gemma E2B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to, um, fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one. First, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like PhD or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes, asynchronous, encapsulation, or factorial. A good dictation pipeline should preserve the user's intent. Stay faithful to the spoken words, and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question. Can we, uh, get quality comparable to the large model while paying only a third of the latency? We'll see.

**Cleaned (Gemma):**

> Okay so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations measuring both the transcription time and the quality of the final output. The first model Whisper converts my voice into raw text. The second model Gemma kicks in afterward to fix punctuation remove hesitations like or I mean and correct any errors. Some specific terms to test are MacBook Swift Metallib 82.5% and the acronym API. Longer sentences tend to confuse smaller models especially when they contain parenthetical clauses or bulleted lists like this one first second third fourth. Consider also how the model handles numbers like 2026 ordinals like the 21st century and abbreviations like PhD or CEO. Domain specific vocabulary matters too. Think of terms like Kubernetes asynchronous encapsulation or factorial. A good dictation pipeline should preserve the user's intent. Stay faithful to the spoken words and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question. Can we get quality comparable to the large model while paying only a third of the latency? We'll see.

### full — Whisper Large + Gemma E4B

**Raw (Whisper):**

> Okay so, um, today I'm testing a local dictation app called Gemma Flow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to, um, fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one. First, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like PhD or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes, asynchronous, encapsulation, or factorial. A good dictation pipeline should preserve the user's intent. Stay faithful to the spoken words, and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question. Can we, uh, get quality comparable to the large model while paying only a third of the latency? We'll see.

**Cleaned (Gemma):**

> Okay, so today I'm testing a local dictation app called Gemma Flow. The goal is to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to fix punctuation, remove hesitations like uh or I mean, and correct any errors. Some specific terms to test are MacBook, Swift, Metallib, 82.5%, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one: first, second, third, fourth. Consider also how the model handles numbers like 2026, ordinals like the 21st century, and abbreviations like PhD or CEO. Domain-specific vocabulary matters too. Think of terms like Kubernetes, asynchronous, encapsulation, or factorial. A good dictation pipeline should preserve the user's intent. Stay faithful to the spoken words, and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question: Can we get quality comparable to the large model while paying only a third of the latency? We'll see.


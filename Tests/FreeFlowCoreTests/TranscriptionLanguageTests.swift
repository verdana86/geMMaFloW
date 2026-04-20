import Testing
@testable import FreeFlowCore

@Suite("TranscriptionLanguage — ISO code round-trip")
struct TranscriptionLanguageTests {
    @Test("Auto maps to empty ISO code (auto-detect)")
    func autoIsEmpty() {
        #expect(TranscriptionLanguage.auto.isoCode == "")
    }

    @Test("Named languages map to their ISO 639-1 code")
    func namedLanguagesMapCorrectly() {
        #expect(TranscriptionLanguage.italian.isoCode == "it")
        #expect(TranscriptionLanguage.english.isoCode == "en")
        #expect(TranscriptionLanguage.spanish.isoCode == "es")
        #expect(TranscriptionLanguage.french.isoCode == "fr")
        #expect(TranscriptionLanguage.german.isoCode == "de")
        #expect(TranscriptionLanguage.portuguese.isoCode == "pt")
    }

    @Test("Round-trip: ISO code parses back to the right case")
    func roundTrip() {
        for language in TranscriptionLanguage.allCases {
            let parsed = TranscriptionLanguage.fromISO(language.isoCode)
            #expect(parsed == language)
        }
    }

    @Test("Empty or whitespace ISO parses to .auto")
    func emptyParsesToAuto() {
        #expect(TranscriptionLanguage.fromISO("") == .auto)
        #expect(TranscriptionLanguage.fromISO("   ") == .auto)
    }

    @Test("Unknown ISO code falls back to .auto")
    func unknownFallsBackToAuto() {
        #expect(TranscriptionLanguage.fromISO("xx") == .auto)
        #expect(TranscriptionLanguage.fromISO("hu") == .auto)
    }

    @Test("ISO parsing is case-insensitive and trims whitespace")
    func parsingNormalizes() {
        #expect(TranscriptionLanguage.fromISO("IT") == .italian)
        #expect(TranscriptionLanguage.fromISO("  en  ") == .english)
    }
}

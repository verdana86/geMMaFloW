import Testing
@testable import GemmaFlowCore

@Suite("LocalBackendIdentifier — parses runtime and optional variant")
struct LocalBackendIdentifierTests {
    @Test("Bare runtime name has no variant")
    func bareRuntime() {
        let parsed = LocalBackendIdentifier.parse("whisperkit")
        #expect(parsed.runtime == "whisperkit")
        #expect(parsed.modelVariant == nil)
    }

    @Test("Runtime with single slash splits into runtime + variant")
    func runtimeWithVariant() {
        let parsed = LocalBackendIdentifier.parse("whisperkit/large-v3-turbo")
        #expect(parsed.runtime == "whisperkit")
        #expect(parsed.modelVariant == "large-v3-turbo")
    }

    @Test("Extra slashes are preserved in the variant (maxSplits 1)")
    func runtimeWithMultiSlashVariant() {
        let parsed = LocalBackendIdentifier.parse("whisperkit/large-v3/turbo")
        #expect(parsed.runtime == "whisperkit")
        #expect(parsed.modelVariant == "large-v3/turbo")
    }

    @Test("Empty identifier is accepted (caller's responsibility to validate upstream)")
    func empty() {
        let parsed = LocalBackendIdentifier.parse("")
        #expect(parsed.runtime == "")
        #expect(parsed.modelVariant == nil)
    }
}

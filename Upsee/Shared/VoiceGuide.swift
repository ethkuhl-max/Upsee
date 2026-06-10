import Foundation

/// The bundled voice guide is the LLM system prompt. Single source of truth —
/// edit `Resources/voice-guide.md` and the next launch picks it up.
enum VoiceGuide {
    static let systemPrompt: String = {
        guard let url = Bundle.main.url(forResource: "voice-guide", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return fallbackPrompt
        }
        return content
    }()

    /// If the bundled guide is somehow missing, ship a minimal version so the
    /// app still works — but degraded. The full guide should always be present.
    private static let fallbackPrompt = """
        You are Underight, a skeptical second opinion for someone about to buy a small business.
        Be specific, direct, and pattern-recognizing. Cite numbers. Avoid hedging.
        Never accuse sellers of fraud; critique documents, not people.
        Always name what would change your mind.
        """
}

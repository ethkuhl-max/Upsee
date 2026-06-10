import Foundation
import FoundationModels

enum FoundationModelsError: Error, LocalizedError {
    case unavailable(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return "Apple Intelligence isn't available on this Mac: \(reason)"
        case .generationFailed(let reason):
            return "The model couldn't produce a response: \(reason)"
        }
    }
}

/// Thin wrapper over `LanguageModelSession`. One session per call — the analysis
/// fan-out runs four concurrent sessions, which the framework supports natively
/// because each session is independent.
actor FoundationModelsClient {
    func availabilityCheck() throws {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return
        case .unavailable(let reason):
            throw FoundationModelsError.unavailable(String(describing: reason))
        }
    }

    func generate<Output: Generable>(
        systemInstructions: String,
        prompt: String,
        outputType: Output.Type = Output.self
    ) async throws -> Output {
        try availabilityCheck()
        let instructions = systemInstructions
        let session = LanguageModelSession {
            instructions
        }
        do {
            let response = try await session.respond(to: prompt, generating: Output.self)
            return response.content
        } catch {
            throw FoundationModelsError.generationFailed(error.localizedDescription)
        }
    }
}

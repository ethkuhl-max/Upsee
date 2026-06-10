import Foundation

/// The full analysis output for a deal — the structured form of what
/// `AnalysisDocumentView` renders.
struct Analysis: Codable, Equatable {
    var deal: Deal
    var normalized: NormalizedSDE
    var primaryDSCR: DSCRResult
    var maxOffer: Decimal
    var multipleReading: MultipleReading
    var stress: [SensitivityRow]
    var verdict: Verdict
    var addBackReview: AddBackReview
    var brokerQuestions: BrokerQuestions
    var changeMyMind: ChangeMyMind
    var generatedAt: Date
}

struct Verdict: Codable, Equatable {
    enum Disposition: String, Codable, Equatable {
        case pass
        case marginal
        case worthPursuing
        case worthPursuingWithConditions
    }
    var disposition: Disposition
    var headline: String
    var oneLineSummary: String
}

struct AddBackReview: Codable, Equatable {
    var items: [AddBackComment]
    var overallNote: String?
}

struct AddBackComment: Codable, Equatable {
    var addBackID: UUID
    var label: String
    var verdict: AddBackVerdict
    var commentary: String
    var confidence: Confidence
}

enum AddBackVerdict: String, Codable, Equatable {
    case accepted
    case discounted
    case rejected
    case requiresVerification
}

enum Confidence: String, Codable, Equatable, CaseIterable {
    case high
    case medium
    case low
}

struct BrokerQuestions: Codable, Equatable {
    var questions: [BrokerQuestion]
}

struct BrokerQuestion: Codable, Equatable {
    var topic: String
    var question: String
    var why: String
    var confidence: Confidence
}

struct ChangeMyMind: Codable, Equatable {
    var conditions: [ChangeMyMindCondition]
}

struct ChangeMyMindCondition: Codable, Equatable {
    var condition: String
    var impact: String
}


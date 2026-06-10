import Foundation
import Observation

@MainActor
@Observable
final class AnalysisCoordinator {
    enum Phase: Equatable {
        case idle
        case extracting(filename: String)
        case reviewing(Deal)
        case analyzing(Deal)
        case complete(Analysis)
        case failed(String)
    }

    var phase: Phase = .idle

    private let dealExtractor: DealExtractor
    private let runner: AnalysisRunner

    init(
        dealExtractor: DealExtractor = DealExtractor(),
        runner: AnalysisRunner = AnalysisRunner()
    ) {
        self.dealExtractor = dealExtractor
        self.runner = runner
    }

    func acceptDroppedPDF(at url: URL) {
        phase = .extracting(filename: url.lastPathComponent)
        Task { [weak self] in
            guard let self else { return }
            do {
                let extracted = try PDFExtractor.extract(from: url)
                let deal = try await dealExtractor.extract(from: extracted, sourcePDFPath: url.path)
                phase = .reviewing(deal)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func startAnalysis(of deal: Deal) {
        phase = .analyzing(deal)
        Task { [weak self] in
            guard let self else { return }
            do {
                let analysis = try await runner.run(deal)
                phase = .complete(analysis)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        phase = .idle
    }
}

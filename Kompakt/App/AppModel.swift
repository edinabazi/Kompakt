import AppKit
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @AppStorage("compressionMode") var compressionMode: CompressionMode = .ask
    @AppStorage("outputMode") var outputMode: OutputMode = .replaceOriginals

    @Published private(set) var jobs: [CompressionJob] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var lastMessage = "Drop files to optimize."
    @Published private(set) var pendingAskSummary: OptimizableFileSummary?
    @Published private(set) var externalDragActive = false
    @Published private(set) var externalDragSummary = OptimizableFileSummary.fallback

    private let queue = CompressionQueue()
    private weak var menuBarController: MenuBarController?
    private weak var externalDropZoneController: ExternalDropZoneController?
    private var pendingAskURLs: [URL] = []

    private init() {}

    var completedJobs: [CompressionJob] {
        jobs.filter { $0.status.isFinished }
    }

    var totalBytesSaved: Int64 {
        jobs.compactMap(\.result?.bytesSaved).reduce(0, +)
    }

    func attachMenuBarController(_ controller: MenuBarController) {
        menuBarController = controller
    }

    func attachExternalDropZoneController(_ controller: ExternalDropZoneController) {
        externalDropZoneController = controller
    }

    func beginExternalDrag(urls: [URL]) {
        externalDragSummary = OptimizableFileSummary.from(urls)
        externalDragActive = true
    }

    func endExternalDrag(didDrop: Bool) {
        guard externalDragActive else { return }
        externalDragActive = false
        externalDragSummary = .fallback
        externalDropZoneController?.endDrag(didDrop: didDrop)
    }

    func handleDropped(paths: [String]) {
        let urls = paths.map { URL(fileURLWithPath: $0) }
        handleDropped(urls: urls)
    }

    func handleDropped(urls: [URL]) {
        let fileURLs = FileCollector.collectFiles(from: urls)

        guard !fileURLs.isEmpty else {
            lastMessage = "No supported files found."
            return
        }

        menuBarController?.showPopover()

        switch compressionMode {
        case .ask:
            pendingAskURLs = fileURLs
            pendingAskSummary = OptimizableFileSummary.fromCollectedFiles(fileURLs)
            lastMessage = "Choose compression for \(fileURLs.count) file\(fileURLs.count == 1 ? "" : "s")."
        case .lossless, .smaller:
            start(urls: fileURLs, mode: compressionMode)
        }
    }

    func handleExternalDropZoneDrop(urls: [URL], onFinished: ((CompressionBatchSummary?) -> Void)? = nil) {
        let fileURLs = FileCollector.collectFiles(from: urls)

        guard !fileURLs.isEmpty else {
            lastMessage = "No supported files found."
            onFinished?(nil)
            return
        }

        pendingAskURLs = []
        pendingAskSummary = nil
        start(urls: fileURLs, mode: compressionMode, onFinished: onFinished)
    }

    func choosePendingAskMode(_ mode: CompressionMode) {
        let urls = pendingAskURLs
        pendingAskURLs = []
        pendingAskSummary = nil

        guard !urls.isEmpty else { return }
        start(urls: urls, mode: mode)
    }

    func choosePendingVideoMode(_ videoMode: VideoCompressionMode) {
        let urls = pendingAskURLs
        pendingAskURLs = []
        pendingAskSummary = nil

        guard !urls.isEmpty else { return }
        start(urls: urls, mode: .smaller, videoMode: videoMode)
    }

    func cancelPendingAsk() {
        pendingAskURLs = []
        pendingAskSummary = nil
        lastMessage = "Ready."
    }

    func start(
        urls: [URL],
        mode: CompressionMode,
        videoMode: VideoCompressionMode? = nil,
        onFinished: ((CompressionBatchSummary?) -> Void)? = nil
    ) {
        let runnableMode: CompressionMode = mode == .ask ? .lossless : mode
        let effectiveVideoMode = videoMode ?? (runnableMode == .smaller ? .sameResolution : nil)
        let newJobs = urls.map { CompressionJob(url: $0, mode: runnableMode, videoMode: effectiveVideoMode, outputMode: outputMode) }
        jobs.insert(contentsOf: newJobs, at: 0)
        lastMessage = "Queued \(newJobs.count) file\(newJobs.count == 1 ? "" : "s")."
        run(jobs: newJobs, onFinished: onFinished)
    }

    func clearCompleted() {
        jobs.removeAll { $0.status.isFinished }
        updateProgress()
    }

    func reveal(_ job: CompressionJob) {
        let url = job.result?.outputURL ?? job.url
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func dismissExternalDropZone() {
        externalDropZoneController?.endDrag(didDrop: false)
    }

    private func run(jobs queuedJobs: [CompressionJob], onFinished: ((CompressionBatchSummary?) -> Void)? = nil) {
        isProcessing = true
        let queuedJobIDs = Set(queuedJobs.map(\.id))

        Task {
            await queue.process(jobs: queuedJobs) { [weak self] updatedJob in
                await MainActor.run {
                    self?.update(job: updatedJob)
                }
            }

            await MainActor.run {
                self.isProcessing = self.jobs.contains { $0.status == .running || $0.status == .queued }
                self.updateProgress()
                if !self.isProcessing {
                    self.lastMessage = self.summaryMessage()
                }
                let batchJobs = self.jobs.filter { queuedJobIDs.contains($0.id) }
                onFinished?(CompressionBatchSummary.from(batchJobs))
            }
        }
    }

    private func update(job: CompressionJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index] = job
        lastMessage = job.status.message
        updateProgress()
    }

    private func updateProgress() {
        guard !jobs.isEmpty else {
            progress = 0
            return
        }

        let finished = jobs.filter { $0.status.isFinished }.count
        progress = Double(finished) / Double(jobs.count)
    }

    private func summaryMessage() -> String {
        let finished = completedJobs.count
        let saved = ByteCountFormatter.string(fromByteCount: totalBytesSaved, countStyle: .file)
        return finished == 0 ? "Ready." : "Finished \(finished) file\(finished == 1 ? "" : "s") · saved \(saved)."
    }
}

import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @AppStorage("compressionMode") var compressionMode: CompressionMode = .ask
    @AppStorage("outputMode") var outputMode: OutputMode = .replaceOriginals
    @AppStorage("defaultVideoMode") var defaultVideoMode: VideoCompressionMode = .sameResolution
    @AppStorage("showEscapeHint") var showEscapeHint = true

    @Published private(set) var jobs: [CompressionJob] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var lastMessage = "Drop files to Kompakt."
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

    var canRevertLastCompression: Bool {
        jobs.contains { $0.result != nil }
    }

    var opensAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func attachMenuBarController(_ controller: MenuBarController) {
        menuBarController = controller
    }

    func attachExternalDropZoneController(_ controller: ExternalDropZoneController) {
        externalDropZoneController = controller
    }

    func beginExternalDrag(urls: [URL]) {
        externalDragSummary = urls.isEmpty ? .fallback : OptimizableFileSummary.fromFileHints(urls)
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

        switch compressionMode {
        case .ask:
            pendingAskURLs = fileURLs
            pendingAskSummary = OptimizableFileSummary.fromCollectedFiles(fileURLs)
            lastMessage = "Choose optimization for \(fileURLs.count) file\(fileURLs.count == 1 ? "" : "s")."
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
        let effectiveVideoMode = videoMode ?? (runnableMode == .smaller ? defaultVideoMode : nil)
        let batchID = UUID()
        let newJobs = urls.map {
            CompressionJob(batchID: batchID, url: $0, mode: runnableMode, videoMode: effectiveVideoMode, outputMode: outputMode)
        }
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

    func revealLatestOutput() {
        guard let job = jobs.first(where: { $0.result != nil }) else { return }
        reveal(job)
    }

    func revertLastCompression() {
        guard let batchID = jobs.first(where: { $0.result != nil })?.batchID else {
            lastMessage = "Nothing to revert."
            return
        }

        let indexes = jobs.indices.filter { jobs[$0].batchID == batchID && jobs[$0].result != nil }
        var revertedCount = 0

        do {
            for index in indexes {
                guard let result = jobs[index].result else { continue }

                switch jobs[index].outputMode {
                case .createCopies:
                    if FileManager.default.fileExists(atPath: result.outputURL.path) {
                        try FileManager.default.removeItem(at: result.outputURL)
                    }
                case .replaceOriginals:
                    guard let backupURL = result.backupURL,
                          FileManager.default.fileExists(atPath: backupURL.path) else {
                        lastMessage = "Original backup not found."
                        return
                    }

                    if FileManager.default.fileExists(atPath: jobs[index].url.path) {
                        _ = try FileManager.default.replaceItemAt(
                            jobs[index].url,
                            withItemAt: backupURL,
                            backupItemName: nil,
                            options: [.usingNewMetadataOnly]
                        )
                    } else {
                        try FileManager.default.moveItem(at: backupURL, to: jobs[index].url)
                    }
                }

                jobs[index].result = nil
                jobs[index].status = .reverted
                revertedCount += 1
            }

            lastMessage = "Reverted \(revertedCount) file\(revertedCount == 1 ? "" : "s")."
            updateProgress()
        } catch {
            lastMessage = "Revert failed: \(error.localizedDescription)"
        }
    }

    func showExternalDropZone() {
        externalDropZoneController?.show()
    }

    func dismissExternalDropZone() {
        externalDropZoneController?.endDrag(didDrop: false)
    }

    func setOpensAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }

            objectWillChange.send()
        } catch {
            lastMessage = "Open at Login failed: \(error.localizedDescription)"
        }
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
        return finished == 0 ? "Ready." : "\(finished) file\(finished == 1 ? "" : "s") kompakted · \(saved) saved."
    }
}

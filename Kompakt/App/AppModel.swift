import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @AppStorage("compressionMode") var compressionMode: CompressionMode = .smaller
    @AppStorage("outputMode") var outputMode: OutputMode = .replaceOriginals
    @AppStorage("defaultVideoMode") var defaultVideoMode: VideoCompressionMode = .sameResolution
    @AppStorage("successSoundEnabled") var successSoundEnabled = true
    @AppStorage("showEscapeHint") var showEscapeHint = true
    @AppStorage("hasSeenFirstLaunchOnboarding") private var hasSeenFirstLaunchOnboarding = false

    @Published private(set) var jobs: [CompressionJob] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var lastMessage = "Drop files to Kompakt."
    @Published private(set) var pendingAskSummary: OptimizableFileSummary?
    @Published private(set) var externalDragActive = false
    @Published private(set) var externalDragSummary = OptimizableFileSummary.fallback
    @Published private var jobSummary = JobSummary()

    private let queue = CompressionQueue()
    private let successSoundPlayer = SuccessSoundPlayer()
    private weak var menuBarController: MenuBarController?
    private weak var externalDropZoneController: ExternalDropZoneController?
    private var pendingAskURLs: [URL] = []
    private var firstLaunchOnboardingActive = false
    private var receivedFileOpenRequest = false

    private init() {
        if compressionMode == .ask {
            compressionMode = .smaller
        }
    }

    var opensAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var completedJobs: [CompressionJob] {
        jobSummary.completedJobs
    }

    var totalBytesSaved: Int64 {
        jobSummary.totalBytesSaved
    }

    var latestJob: CompressionJob? {
        jobSummary.latestJob
    }

    var recentCompletedJobs: [CompressionJob] {
        jobSummary.recentCompletedJobs
    }

    var progress: Double {
        jobSummary.progress
    }

    enum RevertError: LocalizedError {
        case backupMissing

        var errorDescription: String? {
            switch self {
            case .backupMissing:
                "Original backup not found."
            }
        }
    }

    func attachMenuBarController(_ controller: MenuBarController) {
        menuBarController = controller
    }

    func attachExternalDropZoneController(_ controller: ExternalDropZoneController) {
        externalDropZoneController = controller
    }

    func beginExternalDrag(urls: [URL]) {
        finishFirstLaunchOnboarding()
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
        Task {
            let fileURLs = await FileCollector.collectFilesAsync(from: urls)
            handleCollectedDrop(fileURLs)
        }
    }

    func handleExternalDropZoneDrop(urls: [URL], onFinished: ((CompressionBatchSummary?) -> Void)? = nil) {
        Task {
            let fileURLs = await FileCollector.collectFilesAsync(from: urls)

            guard !fileURLs.isEmpty else {
                lastMessage = "No supported files found."
                onFinished?(nil)
                return
            }

            pendingAskURLs = []
            pendingAskSummary = nil
            start(urls: fileURLs, mode: compressionMode, onFinished: onFinished)
        }
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

    func noteFileOpenRequest() {
        receivedFileOpenRequest = true
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
        refreshJobSummary()
        run(jobs: newJobs, onFinished: onFinished)
    }

    func clearCompleted() {
        jobs.removeAll { $0.status.isFinished }
        refreshJobSummary()
    }

    func reveal(_ job: CompressionJob) {
        let url = job.result?.outputURL ?? job.url
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revert(job: CompressionJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }),
              jobs[index].result != nil else {
            lastMessage = "Nothing to revert."
            return
        }

        do {
            try revertJob(at: index)
            lastMessage = "Reverted \(job.displayName)."
            refreshJobSummary()
        } catch {
            lastMessage = "Revert failed: \(error.localizedDescription)"
        }
    }

    func showExternalDropZone() {
        firstLaunchOnboardingActive = false
        externalDropZoneController?.show(mode: .drag)
    }

    func showFirstLaunchOnboardingIfNeeded() {
        let forceOnboarding = ProcessInfo.processInfo.environment["KOMPAKT_FORCE_FIRST_LAUNCH_ONBOARDING"] == "1"

        guard forceOnboarding || (
            !hasSeenFirstLaunchOnboarding &&
            !receivedFileOpenRequest &&
            !externalDragActive &&
            !isProcessing &&
            jobs.isEmpty &&
            pendingAskSummary == nil
        ) else {
            return
        }

        firstLaunchOnboardingActive = true
        externalDropZoneController?.show(mode: .onboarding)
    }

    func dismissExternalDropZone() {
        if firstLaunchOnboardingActive {
            finishFirstLaunchOnboarding()
        }
        externalDropZoneController?.endDrag(didDrop: false)
    }

    func finishFirstLaunchOnboarding() {
        guard firstLaunchOnboardingActive || !hasSeenFirstLaunchOnboarding else { return }
        hasSeenFirstLaunchOnboarding = true
        firstLaunchOnboardingActive = false
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

    private func revertJob(at index: Int) throws {
        guard let result = jobs[index].result else { return }

        switch jobs[index].outputMode {
        case .createCopies:
            if FileManager.default.fileExists(atPath: result.outputURL.path) {
                try FileManager.default.removeItem(at: result.outputURL)
            }
        case .replaceOriginals:
            guard let backupURL = result.backupURL,
                  FileManager.default.fileExists(atPath: backupURL.path) else {
                throw RevertError.backupMissing
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
    }

    private func handleCollectedDrop(_ fileURLs: [URL]) {
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
                self.refreshJobSummary()
                if !self.isProcessing {
                    self.lastMessage = self.summaryMessage()
                }
                let batchJobs = self.jobs.filter { queuedJobIDs.contains($0.id) }
                let summary = CompressionBatchSummary.from(batchJobs)
                if self.successSoundEnabled, summary?.optimizedCount ?? 0 > 0 {
                    self.successSoundPlayer.play()
                }
                onFinished?(summary)
            }
        }
    }

    private func update(job: CompressionJob) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index] = job
        lastMessage = job.status.message
        refreshJobSummary()
    }

    private func refreshJobSummary() {
        var completedJobs: [CompressionJob] = []
        var recentCompletedJobs: [CompressionJob] = []
        var totalBytesSaved: Int64 = 0

        for job in jobs {
            if job.status.isFinished {
                completedJobs.append(job)
            }

            if let result = job.result {
                totalBytesSaved += result.bytesSaved

                if recentCompletedJobs.count < 10 {
                    recentCompletedJobs.append(job)
                }
            }
        }

        jobSummary = JobSummary(
            completedJobs: completedJobs,
            totalBytesSaved: totalBytesSaved,
            latestJob: jobs.first,
            recentCompletedJobs: recentCompletedJobs,
            progress: jobs.isEmpty ? 0 : Double(completedJobs.count) / Double(jobs.count)
        )
    }

    private func summaryMessage() -> String {
        let finished = completedJobs.count
        let saved = ByteCountFormatter.string(fromByteCount: totalBytesSaved, countStyle: .file)
        return finished == 0 ? "Ready." : "\(finished) file\(finished == 1 ? "" : "s") kompakted · \(saved) saved."
    }
}

#if DEBUG
extension AppModel {
    func replaceJobsForTesting(_ jobs: [CompressionJob]) {
        self.jobs = jobs
        refreshJobSummary()
    }
}
#endif

private struct JobSummary {
    var completedJobs: [CompressionJob] = []
    var totalBytesSaved: Int64 = 0
    var latestJob: CompressionJob?
    var recentCompletedJobs: [CompressionJob] = []
    var progress: Double = 0
}

import AppKit
import AVFoundation
import ImageIO
import SwiftUI

struct ExternalDropZoneView: View {
    let effectLeadingGutter: CGFloat
    let mode: ExternalDropZoneMode

    @AppStorage("showEscapeHint") private var showEscapeHint = true
    @State private var isTargeted = false
    @State private var dragLocation: CGPoint?
    @State private var phase: DropZonePhase = .idle
    @State private var pendingURLs: [URL] = []
    @State private var previewURLs: [URL] = []
    @State private var previewTotalCount = 0
    @State private var fileSummary = OptimizableFileSummary.fallback
    @State private var completionSummary: CompressionBatchSummary?

    private var appModel: AppModel {
        AppModel.shared
    }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            ZStack {
                ProgressiveBlurView()
                    .ignoresSafeArea()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black.opacity(0.06), location: 0.34),
                        .init(color: .black.opacity(0.22), location: 0.72),
                        .init(color: .black.opacity(0.48), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()

                if isTargeted && phase.acceptsDrops {
                    HoverColorBloomView()
                        .ignoresSafeArea()
                }
            }

            centerContent
                .padding(.leading, effectLeadingGutter)

            if phase.acceptsDrops {
                DropReceiverView(isTargeted: $isTargeted, dragLocation: $dragLocation, onDrop: loadDroppedURLs)
                    .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.25), value: phase)
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
    }

    @ViewBuilder
    private var centerContent: some View {
        if case .choosing(let summary) = phase {
            VStack(spacing: 14) {
                FilePreviewStack(urls: previewURLs, totalCount: summary.count)

                Text(summary.kind == .video ? "Choose video size" : "Choose optimization")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.64)

                Text("\(summary.count) \(summary.noun)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))

                Group {
                    if summary.kind == .video {
                        VStack(spacing: 8) {
                            videoChoiceButton(.sameResolution)
                            HStack(spacing: 8) {
                                videoChoiceButton(.downscale1080)
                                videoChoiceButton(.downscale720)
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            choiceButton("Lossless", mode: .lossless)
                            choiceButton("Smaller", mode: .smaller)
                        }
                    }
                }
                .padding(.top, 4)

                if showEscapeHint {
                    escapeHint
                        .padding(.top, 2)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else if phase == .finished {
            VStack(spacing: 14) {
                if phase.showsPreview {
                    FilePreviewStack(urls: previewURLs, totalCount: previewTotalCount)
                }

                completionBadge

                if showEscapeHint {
                    escapeHint
                }
            }
            .compositingGroup()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        } else if phase == .idle && mode == .onboarding {
            onboardingContent
        } else {
            VStack(spacing: 16) {
                if phase.showsPreview {
                    FilePreviewStack(urls: previewURLs, totalCount: previewTotalCount)
                }

                titleView
                    .scaleEffect(phase.textScale(isTargeted: isTargeted))
                    .blur(radius: phase.textBlur)
                    .modifier(HoverTextMagnet(isActive: isTargeted && phase.acceptsDrops, dragLocation: dragLocation))

                if showEscapeHint {
                    escapeHint
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var onboardingContent: some View {
        VStack(spacing: 16) {
            OnboardingDropMark(isTargeted: isTargeted)

            VStack(spacing: 7) {
                Text("Welcome to Kompakt")
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(-0.72)
                    .foregroundStyle(.white)

                Group {
                    if isTargeted {
                        Text("Release to Kompakt")
                            .font(.system(size: 16, weight: .medium))
                            .tracking(-0.64)
                            .foregroundStyle(.white)
                    } else {
                        ThinkingText("Drop your files here")
                    }
                }
                .frame(height: 22)
                .modifier(HoverTextMagnet(isActive: isTargeted, dragLocation: dragLocation))
            }
            .scaleEffect(isTargeted ? 1.03 : 1)

            VStack(spacing: 8) {
                escapeHint

                Text("Next time, just drag an image\nand Kompakt will be ready.")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(.white.opacity(0.54))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: 310)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    @ViewBuilder
    private var titleView: some View {
        if phase == .processing {
            ThinkingText(phase.title(summary: effectiveSummary))
        } else {
            Text(phase.title(summary: effectiveSummary))
                .font(.system(size: 16, weight: .medium))
                .tracking(-0.64)
                .foregroundStyle(.white.opacity(phase == .idle && !isTargeted ? 0.88 : 1))
        }
    }

    private var escapeHint: some View {
        HStack(spacing: 6) {
            Text("ESC")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }

            Text("to hide")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .accessibilityLabel("Escape to hide")
    }

    private var completionBadge: some View {
        VStack(spacing: 5) {
            if let completionSummary {
                Text(completionSummary.percentSmallerText)
                    .font(.system(size: 25, weight: .semibold))
                    .tracking(-1)
                    .foregroundStyle(.white)

                Text(completionSummary.sizeChangeText)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(-0.26)
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                Text("Nothing changed")
                    .font(.system(size: 21, weight: .semibold))
                    .tracking(-0.72)
                    .foregroundStyle(.white)

                Text("Already compact")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(-0.26)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .compositingGroup()
    }

    private func choiceButton(_ title: String, mode: CompressionMode) -> some View {
        Button {
            startPending(mode: mode)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.26)
                .frame(width: 92, height: 34)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func videoChoiceButton(_ mode: VideoCompressionMode) -> some View {
        Button {
            startPending(videoMode: mode)
        } label: {
            VStack(spacing: 2) {
                Text(mode.title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.26)
                Text(mode == .sameResolution ? "No resize" : "Resize")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(width: mode == .sameResolution ? 192 : 92, height: 42)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadDroppedURLs(_ urls: [URL]) {
        if mode == .onboarding {
            appModel.finishFirstLaunchOnboarding()
        }

        fileSummary = OptimizableFileSummary.fromFileHintExtensions(urls)
        phase = .processing
        appModel.endExternalDrag(didDrop: true)

        Task {
            let fileURLs = await FileCollector.collectFilesAsync(from: urls)
            let summary = await OptimizableFileSummary.fromCollectedFilesAsync(fileURLs)

            await MainActor.run {
                finishLoadingDroppedFiles(fileURLs, summary: summary)
            }
        }
    }

    private func finishLoadingDroppedFiles(_ fileURLs: [URL], summary: OptimizableFileSummary) {
        guard !fileURLs.isEmpty else {
            previewURLs = []
            previewTotalCount = 0
            completionSummary = nil
            completeAndDismiss()
            return
        }

        previewURLs = Array(fileURLs.prefix(4))
        previewTotalCount = fileURLs.count
        fileSummary = summary

        if appModel.compressionMode == .ask {
            pendingURLs = fileURLs
            phase = .choosing(fileSummary)
            return
        }

        phase = .processing
        appModel.start(urls: fileURLs, mode: appModel.compressionMode, onFinished: completeAndDismiss)
    }

    private func startPending(mode: CompressionMode) {
        let urls = pendingURLs
        pendingURLs = []

        guard !urls.isEmpty else {
            completeAndDismiss()
            return
        }

        phase = .processing
        appModel.start(urls: urls, mode: mode, onFinished: completeAndDismiss)
    }

    private func startPending(videoMode: VideoCompressionMode) {
        let urls = pendingURLs
        pendingURLs = []

        guard !urls.isEmpty else {
            completeAndDismiss()
            return
        }

        phase = .processing
        appModel.start(urls: urls, mode: .smaller, videoMode: videoMode, onFinished: completeAndDismiss)
    }

    private func cancelChoosing() {
        guard phase.isChoosing else { return }
        pendingURLs = []
        previewURLs = []
        previewTotalCount = 0
        fileSummary = .fallback
        completionSummary = nil
        appModel.dismissExternalDropZone()
    }

    private func completeAndDismiss(_ summary: CompressionBatchSummary? = nil) {
        pendingURLs = []
        completionSummary = summary
        phase = .finished
        DispatchQueue.main.asyncAfter(deadline: .now() + (summary == nil ? 0.85 : 1.65)) {
            appModel.dismissExternalDropZone()
        }
    }

    private var effectiveSummary: OptimizableFileSummary {
        phase == .idle ? appModel.externalDragSummary : fileSummary
    }
}

private enum DropZonePhase: Equatable {
    case idle
    case accepted
    case choosing(OptimizableFileSummary)
    case processing
    case finished

    var isChoosing: Bool {
        if case .choosing = self { return true }
        return false
    }

    var showsPreview: Bool {
        switch self {
        case .accepted, .processing, .finished:
            true
        case .idle, .choosing:
            false
        }
    }

    var acceptsDrops: Bool {
        switch self {
        case .idle, .accepted:
            true
        case .choosing, .processing, .finished:
            false
        }
    }

    func title(summary: OptimizableFileSummary) -> String {
        switch self {
        case .idle: "Kompakt \(summary.noun)"
        case .accepted: "Drop received"
        case .choosing: "Choose optimization"
        case .processing: "Kompakting \(summary.noun)"
        case .finished: "Kompakted \(summary.noun)"
        }
    }

    var textBlur: CGFloat {
        switch self {
        case .accepted: 1.4
        default: 0
        }
    }

    func textScale(isTargeted: Bool) -> CGFloat {
        switch self {
        case .accepted: 1.08
        case .finished: 1.04
        default: isTargeted ? 1.03 : 1
        }
    }
}

private struct OnboardingDropMark: View {
    let isTargeted: Bool

    var body: some View {
        Image("MenuBarIcon")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .frame(width: 126, height: 72)
        .allowsHitTesting(false)
    }
}

private struct FilePreviewStack: View {
    let urls: [URL]
    let totalCount: Int

    var body: some View {
        Group {
            if urls.count == 1, let url = urls.first {
                PreviewCard(url: url, size: 82)
                    .shadow(color: .black.opacity(0.32), radius: 18, y: 10)
            } else if !urls.isEmpty {
                ZStack {
                    ForEach(Array(urls.prefix(3).enumerated()), id: \.element) { index, url in
                        PreviewCard(url: url, size: 78)
                            .rotationEffect(.degrees(rotation(for: index)))
                            .offset(x: offset(for: index).x, y: offset(for: index).y)
                            .zIndex(Double(index))
                    }

                    if totalCount > 3 {
                        Text("+\(totalCount - 3)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 20)
                            .background(.black.opacity(0.46), in: Capsule())
                            .overlay {
                                Capsule().stroke(.white.opacity(0.16), lineWidth: 1)
                            }
                            .offset(x: 54, y: 42)
                            .zIndex(4)
                    }
                }
                .frame(width: 128, height: 102)
                .shadow(color: .black.opacity(0.34), radius: 20, y: 12)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .allowsHitTesting(false)
    }

    private func rotation(for index: Int) -> Double {
        [-8, 4, 13][min(index, 2)]
    }

    private func offset(for index: Int) -> CGPoint {
        [CGPoint(x: -22, y: 10), CGPoint(x: 0, y: 0), CGPoint(x: 22, y: 12)][min(index, 2)]
    }
}

private struct ThinkingText: View {
    let title: String
    @State private var shimmerOffset = -0.58

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .tracking(-0.64)
                .foregroundStyle(.white.opacity(0.46))

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .tracking(-0.64)
                .foregroundStyle(.white.opacity(0.96))
                .mask {
                    GeometryReader { proxy in
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.18), location: 0.32),
                                .init(color: .white, location: 0.5),
                                .init(color: .white.opacity(0.18), location: 0.68),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(42, proxy.size.width * 0.52), height: proxy.size.height)
                        .offset(x: proxy.size.width * shimmerOffset)
                    }
                }
        }
        .fixedSize()
        .onAppear {
            shimmerOffset = -0.58
            withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.1
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PreviewCard: View {
    let url: URL
    let size: CGFloat
    @State private var previewImage: NSImage?
    @State private var isVideo = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: previewImage ?? FileIconCache.shared.icon(for: url))
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)

            if isVideo {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(.black.opacity(0.48), in: Circle())
                    .padding(5)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.22))
        }
        .task(id: url) {
            await loadPreview()
        }
    }

    @MainActor
    private func loadPreview() async {
        let size = size
        let url = url
        let preview = await Task.detached(priority: .userInitiated) {
            PreviewLoader.load(url: url, size: size)
        }.value

        previewImage = preview.image
        isVideo = preview.isVideo
    }
}

private enum PreviewLoader {
    struct Preview {
        let image: NSImage?
        let isVideo: Bool
    }

    static func load(url: URL, size: CGFloat) -> Preview {
        let isVideo = FileFormatDetector.detect(url)?.isVideo == true
        let image = isVideo ? videoPreviewImage(for: url, size: size) : imagePreview(for: url, size: size)
        return Preview(image: image, isVideo: isVideo)
    }

    private static func imagePreview(for url: URL, size: CGFloat) -> NSImage? {
        let maxPixelSize = max(1, Int((size * 3).rounded()))
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
    }

    private static func videoPreviewImage(for url: URL, size: CGFloat) -> NSImage? {
        guard FileFormatDetector.detect(url)?.isVideo == true else { return nil }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: size * 3, height: size * 3)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)

        guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }

        return NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
    }
}

private struct DropReceiverView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    @Binding var dragLocation: CGPoint?
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> DropReceiverNSView {
        let view = DropReceiverNSView()
        view.onTargetChanged = { isTargeted = $0 }
        view.onDragLocationChanged = { dragLocation = $0 }
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: DropReceiverNSView, context: Context) {
        nsView.onTargetChanged = { isTargeted = $0 }
        nsView.onDragLocationChanged = { dragLocation = $0 }
        nsView.onDrop = onDrop
    }
}

private final class DropReceiverNSView: NSView {
    var onTargetChanged: ((Bool) -> Void)?
    var onDragLocationChanged: ((CGPoint?) -> Void)?
    var onDrop: (([URL]) -> Void)?
    private var isTargeted = false
    private var acceptsCurrentDrag = false
    private var lastDragLocation: CGPoint?
    private let dragLocationThreshold: CGFloat = 0.05

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let acceptsDrop = acceptsFileURLs(from: sender)
        acceptsCurrentDrag = acceptsDrop
        updateTargetState(acceptsDrop)
        updateDragLocation(acceptsDrop ? dragLocation(from: sender) : nil, force: true)
        return acceptsDrop ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateTargetState(acceptsCurrentDrag)
        updateDragLocation(acceptsCurrentDrag ? dragLocation(from: sender) : nil)
        return acceptsCurrentDrag ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        acceptsCurrentDrag = false
        updateTargetState(false)
        updateDragLocation(nil, force: true)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        acceptsCurrentDrag || acceptsFileURLs(from: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = supportedURLs(from: sender)
        acceptsCurrentDrag = false
        updateTargetState(false)
        updateDragLocation(nil, force: true)

        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        acceptsCurrentDrag = false
        updateTargetState(false)
        updateDragLocation(nil, force: true)
    }

    private func updateTargetState(_ isTargeted: Bool) {
        guard self.isTargeted != isTargeted else { return }
        self.isTargeted = isTargeted
        onTargetChanged?(isTargeted)

        if isTargeted {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    private func supportedURLs(from sender: NSDraggingInfo) -> [URL] {
        ExternalDragClassifier.fileURLs(from: sender.draggingPasteboard)
    }

    private func acceptsFileURLs(from sender: NSDraggingInfo) -> Bool {
        ExternalDragClassifier.hasFileURLs(sender.draggingPasteboard)
    }

    private func dragLocation(from sender: NSDraggingInfo) -> CGPoint {
        let location = convert(sender.draggingLocation, from: nil)
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        return CGPoint(
            x: ((location.x / width) - 0.5) * 2,
            y: (((bounds.height - location.y) / height) - 0.5) * 2
        )
    }

    private func updateDragLocation(_ location: CGPoint?, force: Bool = false) {
        guard force || shouldPublish(location) else { return }
        lastDragLocation = location
        onDragLocationChanged?(location)
    }

    private func shouldPublish(_ location: CGPoint?) -> Bool {
        guard let location else {
            return lastDragLocation != nil
        }

        guard let lastDragLocation else {
            return true
        }

        return abs(location.x - lastDragLocation.x) >= dragLocationThreshold
            || abs(location.y - lastDragLocation.y) >= dragLocationThreshold
    }
}

private struct HoverColorBloomView: View {
    @State private var revealProgress = 0.0
    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            let maxDimension = max(proxy.size.width, proxy.size.height)
            let ripple = maxDimension * (0.16 + 1.25 * revealProgress)

            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.0), location: 0),
                        .init(color: .white.opacity(0.0), location: 0.34),
                        .init(color: .white.opacity(0.03), location: 0.58),
                        .init(color: .white.opacity(0.08), location: 0.78),
                        .init(color: .white.opacity(0.14), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                RadialGradient(
                    colors: [
                        .white.opacity(0.10),
                        .white.opacity(0.05),
                        .clear
                    ],
                    center: UnitPoint(x: pulse ? 0.80 : 0.74, y: pulse ? 0.50 : 0.42),
                    startRadius: 20,
                    endRadius: maxDimension * 0.54
                )

                RadialGradient(
                    colors: [
                        .white.opacity(0.08),
                        .white.opacity(0.04),
                        .clear
                    ],
                    center: UnitPoint(x: pulse ? 0.88 : 0.93, y: pulse ? 0.66 : 0.72),
                    startRadius: 8,
                    endRadius: maxDimension * 0.42
                )

                RippleRing(progress: revealProgress)
                    .frame(width: proxy.size.height * 1.55, height: proxy.size.height * 1.55)
                    .position(x: proxy.size.width * 0.94, y: proxy.size.height * (pulse ? 0.54 : 0.5))
                    .opacity(max(0, 1 - revealProgress) * 0.72)
            }
            .opacity(1)
            .scaleEffect(0.98 + 0.04 * revealProgress, anchor: .trailing)
            .blur(radius: 8)
            .blendMode(.screen)
            .mask {
                RadialGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.72),
                        .init(color: .white.opacity(0), location: 1)
                    ],
                    center: UnitPoint(x: 0.96, y: 0.5),
                    startRadius: max(0, ripple * 0.08),
                    endRadius: ripple
                )
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.34),
                        .init(color: .white.opacity(0.34), location: 0.62),
                        .init(color: .white, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 112, damping: 13)) {
                revealProgress = 1
            }
            withAnimation(.easeInOut(duration: 1.8)) {
                pulse = true
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RippleRing: View {
    let progress: Double

    var body: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0),
                        .white.opacity(0.22),
                        .white.opacity(0.12),
                        .white.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 10
            )
            .scaleEffect(0.18 + 1.15 * progress)
            .blur(radius: 7)
            .blendMode(.screen)
    }
}

private struct HoverTextMagnet: ViewModifier {
    let isActive: Bool
    let dragLocation: CGPoint?

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let vector = magnetVector(from: center, in: proxy.size)

            content
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(isActive ? 1.16 : 1)
                .offset(x: vector.x, y: vector.y)
                .animation(.interpolatingSpring(stiffness: 185, damping: 18), value: isActive)
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.72), value: dragLocation)
        }
        .frame(height: 24)
    }

    private func magnetVector(from center: CGPoint, in size: CGSize) -> CGPoint {
        guard isActive, let dragLocation else { return .zero }

        let x = max(-1, min(1, dragLocation.x))
        let y = max(-1, min(1, dragLocation.y))

        return CGPoint(
            x: x * 38 + max(0, x) * 8,
            y: y * 32
        )
    }
}

private struct ProgressiveBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ProgressiveBlurHostView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ProgressiveBlurHostView: NSView {
    private let blurLayers: [(view: NSVisualEffectView, mask: CAGradientLayer)] = [
        ProgressiveBlurHostView.makeBlurLayer(locations: [0, 0.18, 0.64, 1], opacities: [0, 0, 0.55, 1]),
        ProgressiveBlurHostView.makeBlurLayer(locations: [0, 0.28, 0.72, 1], opacities: [0, 0, 0.72, 1]),
        ProgressiveBlurHostView.makeBlurLayer(locations: [0, 0.46, 0.80, 1], opacities: [0, 0, 0.82, 1]),
        ProgressiveBlurHostView.makeBlurLayer(locations: [0, 0.66, 0.88, 1], opacities: [0, 0, 0.88, 1])
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        blurLayers.forEach { layer in
            layer.view.autoresizingMask = [.width, .height]
            layer.view.frame = bounds
            addSubview(layer.view)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blurLayers.forEach { layer in
            layer.view.frame = bounds
            layer.mask.frame = bounds
        }
        CATransaction.commit()
    }

    private static func makeBlurLayer(locations: [NSNumber], opacities: [CGFloat]) -> (view: NSVisualEffectView, mask: CAGradientLayer) {
        let blur = NSVisualEffectView()
        blur.wantsLayer = true
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.isEmphasized = true

        let mask = CAGradientLayer()
        mask.colors = opacities.map { NSColor.black.withAlphaComponent($0).cgColor }
        mask.locations = locations
        mask.startPoint = CGPoint(x: 0, y: 0.5)
        mask.endPoint = CGPoint(x: 1, y: 0.5)
        blur.layer?.mask = mask

        return (blur, mask)
    }
}

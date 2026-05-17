import AppKit
import SwiftUI

struct ExternalDropZoneView: View {
    let effectLeadingGutter: CGFloat

    @EnvironmentObject private var appModel: AppModel
    @State private var isTargeted = false
    @State private var phase: DropZonePhase = .idle
    @State private var isPulsing = false
    @State private var pendingURLs: [URL] = []
    @State private var previewURLs: [URL] = []
    @State private var previewTotalCount = 0
    @State private var fileSummary = OptimizableFileSummary.fallback
    @State private var completionSummary: CompressionBatchSummary?

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
                        .init(color: .black.opacity(0), location: 0.22),
                        .init(color: .black.opacity(0.84), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()

                SideGlowView(phase: phase, isTargeted: isTargeted, isPulsing: isPulsing)

                if phase == .processing {
                    ProcessingBackgroundPulse()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }

            centerContent
                .padding(.leading, effectLeadingGutter)

            if phase.acceptsDrops {
                DropReceiverView(isTargeted: $isTargeted, onDrop: loadDroppedURLs)
                    .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.25), value: phase)
        .animation(.easeInOut(duration: 0.18), value: isTargeted)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        if case .choosing(let summary) = phase {
            VStack(spacing: 14) {
                FilePreviewStack(urls: previewURLs, totalCount: summary.count)

                Text(summary.kind == .video ? "Choose video size" : "Choose compression")
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
        } else {
            VStack(spacing: 16) {
                if phase.showsPreview {
                    FilePreviewStack(urls: previewURLs, totalCount: previewTotalCount)
                }

                Text(phase.title(summary: effectiveSummary))
                    .font(.system(size: 16, weight: .medium))
                    .tracking(-0.64)
                    .foregroundStyle(.white.opacity(phase == .idle && !isTargeted ? 0.88 : 1))
                    .scaleEffect(phase.textScale(isTargeted: isTargeted))
                    .blur(radius: phase.textBlur)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
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
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
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
        phase = .accepted
        appModel.endExternalDrag(didDrop: true)

        let fileURLs = FileCollector.collectFiles(from: urls)

        guard !fileURLs.isEmpty else {
            previewURLs = []
            previewTotalCount = 0
            completionSummary = nil
            completeAndDismiss()
            return
        }

        previewURLs = Array(fileURLs.prefix(4))
        previewTotalCount = fileURLs.count
        fileSummary = OptimizableFileSummary.fromCollectedFiles(fileURLs)

        if appModel.compressionMode == .ask {
            pendingURLs = fileURLs
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                guard phase == .accepted else { return }
                phase = .choosing(fileSummary)
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard phase == .accepted else { return }
            phase = .processing
        }

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
        case .idle: "Optimize \(summary.noun)"
        case .accepted: "Drop received"
        case .choosing: "Choose compression"
        case .processing: "Optimizing \(summary.noun)"
        case .finished: "Optimized \(summary.noun)"
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

private struct PreviewCard: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        Image(nsImage: previewImage)
            .resizable()
            .scaledToFill()
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
    }

    private var previewImage: NSImage {
        NSImage(contentsOf: url) ?? NSWorkspace.shared.icon(forFile: url.path)
    }
}

private struct DropReceiverView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> DropReceiverNSView {
        let view = DropReceiverNSView()
        view.onTargetChanged = { isTargeted = $0 }
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: DropReceiverNSView, context: Context) {
        nsView.onTargetChanged = { isTargeted = $0 }
        nsView.onDrop = onDrop
    }
}

private final class DropReceiverNSView: NSView {
    var onTargetChanged: ((Bool) -> Void)?
    var onDrop: (([URL]) -> Void)?

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
        let urls = supportedURLs(from: sender)
        let acceptsDrop = !urls.isEmpty
        onTargetChanged?(acceptsDrop)
        return acceptsDrop ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let acceptsDrop = !supportedURLs(from: sender).isEmpty
        onTargetChanged?(acceptsDrop)
        return acceptsDrop ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetChanged?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !supportedURLs(from: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = supportedURLs(from: sender)
        onTargetChanged?(false)

        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onTargetChanged?(false)
    }

    private func supportedURLs(from sender: NSDraggingInfo) -> [URL] {
        ExternalDragClassifier.supportedURLs(from: sender.draggingPasteboard)
    }
}

private struct ProcessingBackgroundPulse: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let pulse = pulseValue(at: timeline.date)

            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.18),
                        .init(color: Color(red: 0.18, green: 0.62, blue: 1).opacity(0.18 + 0.18 * pulse), location: 0.44),
                        .init(color: Color(red: 0.42, green: 0.84, blue: 1).opacity(0.5 + 0.34 * pulse), location: 0.78),
                        .init(color: .white.opacity(0.24 + 0.24 * pulse), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.34),
                        .init(color: Color(red: 0.66, green: 0.9, blue: 1).opacity(0.18 * pulse), location: 0.6),
                        .init(color: .white.opacity(0.28 * pulse), location: 0.9),
                        .init(color: .white.opacity(0.18 * pulse), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .opacity(0.72 + 0.28 * pulse)
            .scaleEffect(x: 1 + 0.035 * pulse, y: 1, anchor: .trailing)
            .blur(radius: 10 + 8 * (1 - pulse))
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
    }

    private func pulseValue(at date: Date) -> Double {
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.45) / 1.45
        return 0.5 + 0.5 * sin(cycle * 2 * .pi)
    }
}

private struct SideGlowView: View {
    let phase: DropZonePhase
    let isTargeted: Bool
    let isPulsing: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.18),
                    .init(color: glowColor.opacity(edgeOpacity), location: 0.68),
                    .init(color: glowColor.opacity(peakOpacity), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    glowColor.opacity(centerOpacity),
                    glowColor.opacity(centerOpacity * 0.35),
                    .clear
                ],
                center: .trailing,
                startRadius: 12,
                endRadius: phase == .accepted ? 620 : 430
            )
            .scaleEffect(x: phase == .accepted ? 1.35 : 1, y: phase == .accepted ? 1.08 : 1)
            .blur(radius: phase == .finished ? 34 : 22)
            .blendMode(.screen)
        }
        .opacity(phase == .idle && !isTargeted ? 0.58 : 1)
        .scaleEffect(x: isPulsing && phase == .processing ? 1.035 : 1, y: 1)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var glowColor: Color {
        switch phase {
        case .finished:
            Color(red: 0.45, green: 1, blue: 0.78)
        case .idle, .accepted, .choosing, .processing:
            Color(red: 0.35, green: 0.72, blue: 1)
        }
    }

    private var edgeOpacity: Double {
        switch phase {
        case .accepted: 0.4
        case .choosing: 0.34
        case .processing: isPulsing ? 0.3 : 0.2
        case .finished: 0.5
        case .idle: isTargeted ? 0.26 : 0.12
        }
    }

    private var peakOpacity: Double {
        switch phase {
        case .accepted: 0.86
        case .choosing: 0.74
        case .processing: isPulsing ? 0.7 : 0.48
        case .finished: 0.92
        case .idle: isTargeted ? 0.62 : 0.34
        }
    }

    private var centerOpacity: Double {
        switch phase {
        case .accepted: 0.44
        case .choosing: 0.34
        case .processing: isPulsing ? 0.32 : 0.2
        case .finished: 0.5
        case .idle: isTargeted ? 0.25 : 0.12
        }
    }

}

private struct ProgressiveBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ProgressiveBlurHostView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.needsLayout = true
    }
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

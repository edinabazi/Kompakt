import AppKit
import Combine
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appModel: AppModel

    private var isDropActive: Bool {
        appModel.externalDragActive
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let pendingAskSummary = appModel.pendingAskSummary {
                askModeChoices(summary: pendingAskSummary)
            } else {
                dropZone
            }
            footer
        }
        .frame(width: 360, height: 480)
        .background(AppBackground())
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kompakt")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(appModel.lastMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .background(.white.opacity(0.08), in: Circle())
            .help("Settings")
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(isDropActive ? 0.16 : 0.08))
                    .frame(width: 92, height: 92)

                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.mint)
            }

            VStack(spacing: 6) {
                Text("Drop files to Kompakt")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                Text("Images and videos optimized locally on your Mac.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: appModel.progress)
                .progressViewStyle(.linear)
                .tint(.mint)
                .frame(width: 240)
                .opacity(appModel.isProcessing ? 1 : 0.35)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            isDropActive ? .mint.opacity(0.65) : .white.opacity(0.11),
                            lineWidth: 1.2)
                )
        )
        .padding(.horizontal, 22)
    }

    private func askModeChoices(summary: OptimizableFileSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kompakt \(summary.count) \(summary.noun)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text(
                        summary.kind == .video
                            ? "Choose the video output size."
                            : "Choose how aggressively Kompakt should work."
                    )
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    appModel.cancelPendingAsk()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(.white.opacity(0.08), in: Circle())
                .accessibilityLabel("Cancel")
            }

            if summary.kind == .video {
                VStack(spacing: 10) {
                    VideoChoiceButton(mode: .sameResolution) {
                        appModel.choosePendingVideoMode(.sameResolution)
                    }
                    VideoChoiceButton(mode: .downscale1080) {
                        appModel.choosePendingVideoMode(.downscale1080)
                    }
                    VideoChoiceButton(mode: .downscale720) {
                        appModel.choosePendingVideoMode(.downscale720)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ChoiceButton(
                        title: "Lossless", subtitle: "Pixels stay intact",
                        systemImage: "shield.checkered"
                    ) {
                        appModel.choosePendingAskMode(.lossless)
                    }

                    ChoiceButton(
                        title: "Smaller", subtitle: "Balanced lossy optimization",
                        systemImage: "arrow.down.right.and.arrow.up.left"
                    ) {
                        appModel.choosePendingAskMode(.smaller)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.mint.opacity(0.35), lineWidth: 1.2)
                )
        )
        .padding(.horizontal, 22)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        ByteCountFormatter.string(
                            fromByteCount: appModel.totalBytesSaved, countStyle: .file)
                    )
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("saved across this session")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appModel.clearCompleted()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.08), in: Circle())
                .disabled(appModel.completedJobs.isEmpty)
                .help("Clear completed")
            }

            if let latest = appModel.latestJob {
                HStack(spacing: 10) {
                    Image(
                        systemName: latest.status.isFinished
                            ? "checkmark.circle.fill" : "clock.fill"
                    )
                    .foregroundStyle(latest.status == .finished ? .mint : .secondary)
                    Text(latest.displayName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        appModel.reveal(latest)
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.08), in: Circle())
                    .disabled(latest.result == nil)
                    .help("Reveal")
                }
                .padding(10)
                .background(
                    .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }

            HStack {
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(22)
    }

}

private struct VideoChoiceButton: View {
    let mode: VideoCompressionMode
    let action: () -> Void

    var body: some View {
        ChoiceButton(title: mode.title, subtitle: mode.subtitle, systemImage: "film") {
            action()
        }
    }
}

private struct ChoiceButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                .white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.09),
                    Color(red: 0.10, green: 0.13, blue: 0.12),
                    Color(red: 0.04, green: 0.05, blue: 0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    for index in stride(from: -height, through: width, by: 22) {
                        path.move(to: CGPoint(x: index, y: height))
                        path.addLine(to: CGPoint(x: index + height, y: 0))
                    }
                }
                .stroke(.white.opacity(0.035), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }
}

struct MenuBarPopoverView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var popoverState: MenuBarPopoverState
    let onContentSizeChange: (NSSize) -> Void

    init(onContentSizeChange: @escaping (NSSize) -> Void = { _ in }) {
        self.onContentSizeChange = onContentSizeChange
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            Color(nsColor: .windowBackgroundColor).opacity(0.24)

            VStack(spacing: 0) {
                activeScreen
                .clipped()
                .frame(height: popoverState.screen.contentHeight)

                PopoverFooter(
                    status: footerStatus,
                    updateAction: { AppCommands.checkForUpdates() },
                    quitAction: { AppCommands.quit() }
                )
            }
        }
        .frame(width: MenuBarPopoverMetrics.width, height: popoverState.screen.height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .foregroundStyle(.primary)
        .animation(.smooth(duration: 0.24), value: popoverState.screen)
        .onAppear {
            onContentSizeChange(popoverState.screen.size)
        }
        .onChange(of: popoverState.screen) { _, newScreen in
            onContentSizeChange(newScreen.size)
        }
    }

    @ViewBuilder
    private var activeScreen: some View {
        switch popoverState.screen {
        case .history:
            historyScreen
                .frame(width: MenuBarPopoverMetrics.width, height: popoverState.screen.contentHeight, alignment: .top)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .settings:
            settingsScreen
                .frame(width: MenuBarPopoverMetrics.width, height: popoverState.screen.contentHeight, alignment: .top)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        }
    }

    private var historyScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(appModel.isProcessing ? .mint : .secondary)

                Text(popoverTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Button {
                    appModel.clearCompleted()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .contentShape(Circle())
                .disabled(appModel.completedJobs.isEmpty)
                .help("Clear kompaktions")

                Button {
                    popoverState.screen = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .contentShape(Circle())
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let pendingAskSummary = appModel.pendingAskSummary {
                PopoverPendingAsk(
                    summary: pendingAskSummary,
                    cancelAction: { appModel.cancelPendingAsk() },
                    chooseModeAction: { appModel.choosePendingAskMode($0) },
                    chooseVideoModeAction: { appModel.choosePendingVideoMode($0) }
                )
            } else if appModel.recentCompletedJobs.isEmpty {
                PopoverEmptyHistory()
            } else {
                let recentJobs = appModel.recentCompletedJobs
                let lastJobID = recentJobs.last?.id

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(recentJobs) { job in
                            PopoverHistoryRow(
                                job: job,
                                revealAction: { appModel.reveal(job) },
                                copyPathAction: { appModel.copyPath(job) },
                                removeAction: { appModel.removeFromHistory(job) },
                                revertAction: { appModel.revert(job: job) }
                            )
                            if job.id != lastJobID {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var settingsScreen: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button {
                        popoverState.screen = .history
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .fixedSize(horizontal: true, vertical: false)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .contentShape(Rectangle())

                    Spacer()
                }

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            VStack(spacing: 0) {
                PopoverSegmentRow(title: "Default optimization", subtitle: "Used for new drops.") {
                    PopoverSegmentedControl(
                        selection: compressionModeBinding,
                        options: visibleCompressionModes.map { ($0, $0.title) }
                    )
                }
                .padding(.horizontal, 16)

                PopoverDivider()

                PopoverSegmentRow(title: "Video size", subtitle: "When Smaller is selected.") {
                    PopoverSegmentedControl(
                        selection: videoModeBinding,
                        options: VideoCompressionMode.allCases.map { ($0, $0.popoverTitle) }
                    )
                }
                .padding(.horizontal, 16)

                PopoverDivider()

                PopoverSegmentRow(title: "Output", subtitle: "Where optimized files go. Konversions always keep originals.") {
                    PopoverSegmentedControl(
                        selection: outputModeBinding,
                        options: OutputMode.allCases.map { ($0, $0.popoverTitle) }
                    )
                }
                .padding(.horizontal, 16)

                PopoverDivider()

                PopoverSegmentRow(title: "Position", subtitle: "Choose which side the drop zone opens on.") {
                    PopoverSegmentedControl(
                        selection: sideSheetSideBinding,
                        options: SideSheetSide.allCases.map { ($0, $0.title) }
                    )
                }
                .padding(.horizontal, 16)

                PopoverDivider()

                PopoverToggleRow(
                    title: "Launch at login",
                    subtitle: "Start Kompakt when you log in.",
                    isOn: openAtLoginBinding
                )
                .padding(.horizontal, 16)

                PopoverDivider()

                PopoverToggleRow(
                    title: "Success sound",
                    subtitle: "Play a sound when done.",
                    isOn: successSoundBinding
                )
                .padding(.horizontal, 16)

                PopoverDivider()

                PopoverToggleRow(
                    title: "Show ESC hint",
                    subtitle: "Show the hide shortcut while dragging.",
                    isOn: escapeHintBinding
                )
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
        }
    }

    private var footerStatus: String {
        if appModel.isProcessing {
            return "Kompakting..."
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return "Kompakt \(version ?? "1.0")"
    }

    private var popoverTitle: String {
        appModel.lastMessage == "Drop files to Kompakt." ? "Kompakt" : appModel.lastMessage
    }

    private var visibleCompressionModes: [CompressionMode] {
        [.lossless, .smaller]
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding {
            appModel.opensAtLogin
        } set: { isEnabled in
            appModel.setOpensAtLogin(isEnabled)
        }
    }

    private var compressionModeBinding: Binding<CompressionMode> {
        Binding {
            appModel.compressionMode == .ask ? .smaller : appModel.compressionMode
        } set: { mode in
            guard appModel.compressionMode != mode else { return }
            DispatchQueue.main.async {
                appModel.compressionMode = mode
            }
        }
    }

    private var videoModeBinding: Binding<VideoCompressionMode> {
        Binding {
            appModel.defaultVideoMode
        } set: { mode in
            guard appModel.defaultVideoMode != mode else { return }
            DispatchQueue.main.async {
                appModel.defaultVideoMode = mode
            }
        }
    }

    private var outputModeBinding: Binding<OutputMode> {
        Binding {
            appModel.outputMode
        } set: { mode in
            guard appModel.outputMode != mode else { return }
            DispatchQueue.main.async {
                appModel.outputMode = mode
            }
        }
    }

    private var sideSheetSideBinding: Binding<SideSheetSide> {
        Binding {
            appModel.sideSheetSide
        } set: { side in
            guard appModel.sideSheetSide != side else { return }
            DispatchQueue.main.async {
                appModel.sideSheetSide = side
            }
        }
    }

    private var escapeHintBinding: Binding<Bool> {
        Binding {
            appModel.showEscapeHint
        } set: { isEnabled in
            guard appModel.showEscapeHint != isEnabled else { return }
            DispatchQueue.main.async {
                appModel.showEscapeHint = isEnabled
            }
        }
    }

    private var successSoundBinding: Binding<Bool> {
        Binding {
            appModel.successSoundEnabled
        } set: { isEnabled in
            guard appModel.successSoundEnabled != isEnabled else { return }
            DispatchQueue.main.async {
                appModel.successSoundEnabled = isEnabled
            }
        }
    }
}

@MainActor
final class MenuBarPopoverState: ObservableObject {
    @Published var screen: PopoverScreen = .history
}

enum PopoverScreen {
    case history
    case settings

    var height: CGFloat {
        switch self {
        case .history:
            return MenuBarPopoverMetrics.historyHeight
        case .settings:
            return MenuBarPopoverMetrics.settingsHeight
        }
    }

    var size: NSSize {
        NSSize(width: MenuBarPopoverMetrics.width, height: height)
    }

    var contentHeight: CGFloat {
        height - MenuBarPopoverMetrics.footerHeight
    }
}

private extension VideoCompressionMode {
    var popoverTitle: String {
        switch self {
        case .sameResolution:
            "Same"
        case .downscale1080:
            "1080p"
        case .downscale720:
            "720p"
        }
    }
}

private extension OutputMode {
    var popoverTitle: String {
        switch self {
        case .replaceOriginals:
            "Replace Original"
        case .createCopies:
            "Make Copies"
        }
    }
}

private struct PopoverHistoryRow: View {
    let job: CompressionJob
    let revealAction: () -> Void
    let copyPathAction: () -> Void
    let removeAction: () -> Void
    let revertAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: FileIconCache.shared.icon(for: job.url))
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(detailText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: revealAction) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(.white.opacity(0.08), in: Circle())
            .help("Reveal in Finder")

            Button(action: revertAction) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(.white.opacity(0.08), in: Circle())
            .help("Rollback")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: revealAction) {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }

            Button(action: copyPathAction) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive, action: removeAction) {
                Label("Remove from History", systemImage: "xmark")
            }
        }
    }

    private var detailText: String {
        guard let result = job.result else { return job.status.message(for: job.operation) }
        if case .convert(let format) = job.operation {
            return "Konverted to \(format.displayName) · Original kept"
        }
        let saved = ByteCountFormatter.string(fromByteCount: result.bytesSaved, countStyle: .file)
        return "\(saved) saved · \(job.outputMode.title)"
    }
}

private struct PopoverPendingAsk: View {
    let summary: OptimizableFileSummary
    let cancelAction: () -> Void
    let chooseModeAction: (CompressionMode) -> Void
    let chooseVideoModeAction: (VideoCompressionMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kompakt \(summary.count) \(summary.noun)")
                        .font(.system(size: 15, weight: .semibold))
                    Text(summary.kind == .video ? "Choose output size." : "Choose optimization.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: cancelAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(.white.opacity(0.08), in: Circle())
            }

            if summary.kind == .video {
                ForEach(VideoCompressionMode.allCases) { mode in
                    PopoverChoiceButton(title: mode.title, subtitle: mode.subtitle) {
                        chooseVideoModeAction(mode)
                    }
                }
            } else {
                PopoverChoiceButton(title: "Lossless", subtitle: "Pixels stay intact.") {
                    chooseModeAction(.lossless)
                }
                PopoverChoiceButton(title: "Smaller", subtitle: "Balanced lossy optimization.") {
                    chooseModeAction(.smaller)
                }
            }

            Spacer()
        }
        .padding(14)
    }
}

private struct PopoverChoiceButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PopoverEmptyHistory: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image("MenuBarIcon")
                .resizable()
                .renderingMode(.template)
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
            Text("No Kompaktions yet")
                .font(.system(size: 15, weight: .semibold))
            Text("Your recently kompakted files\nwill show up here.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Spacer()
        }
        .padding(24)
    }
}

private struct PopoverFooter: View {
    let status: String
    let updateAction: () -> Void
    let quitAction: () -> Void

    var body: some View {
        HStack {
            Text(status)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button("Check for Updates", action: updateAction)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Button("Quit", action: quitAction)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: MenuBarPopoverMetrics.footerHeight)
        .background(.black.opacity(0.08))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct PopoverToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MenuBarPopoverMetrics.settingsSubtitleColor(for: colorScheme))
                    .lineLimit(2)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(MenuBarPopoverMetrics.accentColor)
        }
        .frame(minHeight: 50)
    }
}

private struct PopoverSegmentRow<Control: View>: View {
    let title: String
    let subtitle: String
    let control: Control
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, subtitle: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MenuBarPopoverMetrics.settingsSubtitleColor(for: colorScheme))
                }
                Spacer()
            }
            control
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
    }
}

private struct PopoverSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    @Namespace private var activeTabAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]

                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .foregroundStyle(selection == option.value ? Color.white : Color.primary)
                        .background(
                            Group {
                                if selection == option.value {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(MenuBarPopoverMetrics.accentColor)
                                        .matchedGeometryEffect(id: "active-tab", in: activeTabAnimation)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PopoverSegmentButtonStyle())
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
        }
        .padding(2)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
        .animation(.smooth(duration: 0.2), value: selection)
    }
}

private struct PopoverSegmentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

enum MenuBarPopoverMetrics {
    static let width: CGFloat = 320
    static let historyHeight: CGFloat = 382
    static let settingsHeight: CGFloat = 622
    static let footerHeight: CGFloat = 30
    static let size = NSSize(width: width, height: historyHeight)
    static let accentColor = Color(red: 0x10 / 255, green: 0x41 / 255, blue: 0xc7 / 255)

    static func settingsSubtitleColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.54)
    }
}

private struct PopoverButtonRow: View {
    let title: String
    let subtitle: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PopoverDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.075))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

#Preview {
    MainView()
        .environmentObject(AppModel.shared)
}

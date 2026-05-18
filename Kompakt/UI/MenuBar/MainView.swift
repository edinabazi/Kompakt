import AppKit
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

            if let latest = appModel.jobs.first {
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

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedSection: SettingsSection? = .settings
    private let sidebarWidth: CGFloat = 224
    private let windowWidth: CGFloat = 860
    private let windowHeight: CGFloat = 620

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .tag(section)
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 42)
            }
            .navigationSplitViewColumnWidth(
                min: sidebarWidth, ideal: sidebarWidth, max: sidebarWidth)
        } detail: {
            SettingsDetail(
                section: selectedSection ?? .settings,
                openAtLoginBinding: openAtLoginBinding
            )
            .frame(width: windowWidth - sidebarWidth)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                EmptyView()
            }
        }
        .background(SettingsBackground())
        .frame(width: windowWidth, height: windowHeight)
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding {
            appModel.opensAtLogin
        } set: {
            appModel.setOpensAtLogin($0)
        }
    }
}

private struct SettingsDetail: View {
    @EnvironmentObject private var appModel: AppModel
    let section: SettingsSection
    let openAtLoginBinding: Binding<Bool>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsHeader(section: section)

                if let pendingAskSummary = appModel.pendingAskSummary {
                    PendingOptimizationPanel(summary: pendingAskSummary)
                }

                SettingsContentFrame {
                    switch section {
                    case .settings:
                        CombinedSettingsSection(openAtLoginBinding: openAtLoginBinding)
                    case .history:
                        HistorySettingsSection()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(SettingsBackground())
    }
}

private enum SettingsSection: String, CaseIterable, Hashable, Identifiable {
    case settings = "Settings"
    case history = "History"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .settings: "slider.horizontal.3"
        case .history: "clock.arrow.circlepath"
        }
    }

    var subtitle: String {
        switch self {
        case .settings: "Optimization, output, automation, and app controls."
        case .history: "Session results and latest output."
        }
    }
}

private struct SettingsContentFrame<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct SettingsHeader: View {
    let section: SettingsSection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: section.icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 23, height: 23)
                .background(
                    .white.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(section.rawValue)
                .font(.system(size: 16, weight: .semibold))

            Spacer()
        }
        .padding(.bottom, 4)
    }
}

private struct PendingOptimizationPanel: View {
    @EnvironmentObject private var appModel: AppModel
    let summary: OptimizableFileSummary

    var body: some View {
        SettingsGroup {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Kompakt \(summary.count) \(summary.noun)")
                            .font(.headline)
                        Text(
                            summary.kind == .video
                                ? "Choose the video output size."
                                : "Choose how aggressively Kompakt should work."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Cancel") {
                        appModel.cancelPendingAsk()
                    }
                }

                if summary.kind == .video {
                    Picker("Video size", selection: pendingVideoSelection) {
                        ForEach(VideoCompressionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    HStack(spacing: 10) {
                        ActionTile(
                            title: "Lossless", subtitle: "Pixels stay intact",
                            systemImage: "shield.checkered"
                        ) {
                            appModel.choosePendingAskMode(.lossless)
                        }
                        ActionTile(
                            title: "Smaller", subtitle: "Balanced lossy optimization",
                            systemImage: "arrow.down.right.and.arrow.up.left"
                        ) {
                            appModel.choosePendingAskMode(.smaller)
                        }
                    }
                }
            }
        }
    }

    private var pendingVideoSelection: Binding<VideoCompressionMode> {
        Binding {
            .sameResolution
        } set: { mode in
            appModel.choosePendingVideoMode(mode)
        }
    }
}

private struct KompaktSettingsSection: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 14) {
            SettingsGroup {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: appModel.isProcessing ? "bolt.fill" : "checkmark.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(appModel.isProcessing ? Color.accentColor : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(appModel.lastMessage)
                                .font(.system(size: 13, weight: .semibold))
                            Text("Images, PDFs, videos, and audio optimized locally on your Mac.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    ProgressView(value: appModel.progress)
                        .opacity(appModel.isProcessing ? 1 : 0.45)

                    HStack(spacing: 10) {
                        ActionTile(
                            title: "Kompakt Files...", subtitle: "Pick one or more files",
                            systemImage: "doc.badge.plus"
                        ) {
                            AppCommands.kompaktFiles(appModel: appModel)
                        }
                        ActionTile(
                            title: "Kompakt Folder...", subtitle: "Process a folder",
                            systemImage: "folder.badge.plus"
                        ) {
                            AppCommands.kompaktFolder(appModel: appModel)
                        }
                    }
                }
            }

            MetricsGroup {
                MetricGrid()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct OptimizationSettingsSection: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 14) {
            SettingsGroup {
                SettingRow(
                    title: "Default optimization",
                    subtitle: "Used for file drops unless Kompakt asks first."
                ) {
                    Picker("Default optimization", selection: $appModel.compressionMode) {
                        ForEach(CompressionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }

            SettingsGroup {
                SettingRow(
                    title: "Video size", subtitle: "Used when Smaller is selected for video files."
                ) {
                    Picker("Video size", selection: $appModel.defaultVideoMode) {
                        ForEach(VideoCompressionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                Divider().padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(VideoCompressionMode.allCases) { mode in
                        LabelledDescription(title: mode.title, subtitle: mode.subtitle)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct OutputSettingsSection: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        SettingsGroup {
            SettingRow(
                title: "Output",
                subtitle: "Choose whether Kompakt replaces originals or creates copies."
            ) {
                Picker("Output", selection: $appModel.outputMode) {
                    ForEach(OutputMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
        }
    }
}

private struct CombinedSettingsSection: View {
    @EnvironmentObject private var appModel: AppModel
    let openAtLoginBinding: Binding<Bool>

    var body: some View {
        VStack(spacing: 14) {
            SettingsListGroup {
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Default optimization",
                        subtitle: "Used for drops unless Kompakt asks first."
                    ) {
                        Picker("Default optimization", selection: $appModel.compressionMode) {
                            ForEach(CompressionMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }

                    SettingsDivider()

                    SettingRow(
                        title: "Video size", subtitle: "Used when Smaller is selected for videos."
                    ) {
                        Picker("Video size", selection: $appModel.defaultVideoMode) {
                            ForEach(VideoCompressionMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }

                    SettingsDivider()

                    SettingRow(
                        title: "Output", subtitle: "Replace originals or create optimized copies."
                    ) {
                        Picker("Output", selection: $appModel.outputMode) {
                            ForEach(OutputMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }
                }
            }

            SettingsListGroup {
                VStack(spacing: 0) {
                    SettingToggle(
                        title: "Open at Login",
                        subtitle: "Start Kompakt automatically when you sign in.",
                        isOn: openAtLoginBinding)

                    SettingsDivider()

                    SettingToggle(
                        title: "Show ESC hint",
                        subtitle: "Show the hide shortcut in the drag overlay.",
                        isOn: $appModel.showEscapeHint)
                }
            }

            SettingsListGroup {
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Updates", subtitle: "Check whether a newer version is available."
                    ) {
                        Button("Check for Updates...") {
                            AppCommands.checkForUpdates()
                        }
                    }

                    SettingsDivider()

                    SettingRow(title: "About", subtitle: "Version, credits, and app information.") {
                        Button("About Kompakt") {
                            AppCommands.showAbout()
                        }
                    }

                    SettingsDivider()

                    SettingRow(title: "Quit", subtitle: "Close Kompakt.") {
                        Button("Quit Kompakt", role: .destructive) {
                            AppCommands.quit()
                        }
                    }
                }
            }
        }
    }
}

private struct AutomationSettingsSection: View {
    @EnvironmentObject private var appModel: AppModel
    let openAtLoginBinding: Binding<Bool>

    var body: some View {
        VStack(spacing: 14) {
            SettingsGroup {
                SettingToggle(
                    title: "Open at Login",
                    subtitle: "Start Kompakt automatically when you sign in.",
                    isOn: openAtLoginBinding)
            }

            SettingsGroup {
                SettingToggle(
                    title: "Show ESC hint", subtitle: "Show the hide shortcut in the drag overlay.",
                    isOn: $appModel.showEscapeHint)
            }
        }
    }
}

private struct HistorySettingsSection: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingClearHistoryConfirmation = false

    var body: some View {
        VStack(spacing: 14) {
            MetricsGroup {
                MetricGrid()
            }

            SettingsListGroup {
                VStack(spacing: 0) {
                    SettingRow(
                        title: "Show last output",
                        subtitle: "Reveal the latest Kompakted file in Finder."
                    ) {
                        Button("Show in Finder") {
                            appModel.revealLatestOutput()
                        }
                        .disabled(!appModel.canRevertLastCompression)
                    }

                    SettingsDivider()

                    SettingRow(
                        title: "Revert Last Kompakt",
                        subtitle: "Restore the most recent batch when backups are available."
                    ) {
                        Button("Revert") {
                            appModel.revertLastCompression()
                        }
                        .disabled(!appModel.canRevertLastCompression)
                    }

                    SettingsDivider()

                    SettingRow(
                        title: "Clear History",
                        subtitle: "Clears completed session results. Files stay untouched."
                    ) {
                        Button("Clear History", role: .destructive) {
                            showingClearHistoryConfirmation = true
                        }
                        .disabled(appModel.completedJobs.isEmpty)
                    }
                }
            }
            .alert("Clear History?", isPresented: $showingClearHistoryConfirmation) {
                Button("Clear History", role: .destructive) {
                    appModel.clearCompleted()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Completed session results will be removed from this window. Files stay untouched."
                )
            }

            if let latest = appModel.jobs.first {
                SettingsGroup {
                    LabelledDescription(title: "Latest item", subtitle: latest.displayName)
                }
            } else {
                SettingsGroup {
                    LabelledDescription(
                        title: "No session history",
                        subtitle: "Kompakted items will appear here after a run.")
                }
            }
        }
    }
}

private struct AppSettingsSection: View {
    var body: some View {
        SettingsGroup {
            VStack(spacing: 10) {
                SettingRow(
                    title: "Updates",
                    subtitle: "Check whether a newer version of Kompakt is available."
                ) {
                    Button("Check for Updates...") {
                        AppCommands.checkForUpdates()
                    }
                }

                Divider()

                SettingRow(title: "About", subtitle: "Version, credits, and app information.") {
                    Button("About Kompakt") {
                        AppCommands.showAbout()
                    }
                }

                Divider()

                SettingRow(
                    title: "Quit", subtitle: "Close Kompakt and stop watching for file drops."
                ) {
                    Button("Quit Kompakt", role: .destructive) {
                        AppCommands.quit()
                    }
                }
            }
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.18),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
            }
    }
}

private struct SettingsListGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.18),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
            }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.42))
            .frame(height: 1)
    }
}

private struct MetricsGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingRow<Control: View>: View {
    let title: String
    let subtitle: String
    let control: Control

    init(title: String, subtitle: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, alignment: .leading)

            Spacer(minLength: 20)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct SettingToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(title: title, subtitle: subtitle) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct ActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                Color(nsColor: .textBackgroundColor).opacity(0.28),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MetricGrid: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        HStack(spacing: 12) {
            MetricTile(
                title: "Saved",
                value: ByteCountFormatter.string(
                    fromByteCount: appModel.totalBytesSaved, countStyle: .file),
                systemImage: "arrow.down.circle"
            )
            MetricTile(
                title: "Completed",
                value: "\(appModel.completedJobs.count)",
                systemImage: "checkmark.circle"
            )
            MetricTile(
                title: "Queued",
                value: "\(appModel.jobs.filter { !$0.status.isFinished }.count)",
                systemImage: "clock"
            )
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.18),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
        }
    }
}

private struct LabelledDescription: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color(nsColor: .windowBackgroundColor).opacity(0.24)
        }
        .ignoresSafeArea()
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
    @State private var screen: PopoverScreen = .history

    private var recentJobs: [CompressionJob] {
        Array(appModel.jobs.filter { $0.result != nil }.prefix(10))
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            Color(nsColor: .windowBackgroundColor).opacity(0.24)

            VStack(spacing: 0) {
                ZStack {
                    historyScreen
                        .offset(x: screen == .history ? 0 : -320)
                        .opacity(screen == .history ? 1 : 0.4)

                    settingsScreen
                        .offset(x: screen == .settings ? 0 : 320)
                        .opacity(screen == .settings ? 1 : 0.4)
                }
                .clipped()

                PopoverFooter(
                    status: footerStatus,
                    updateAction: { AppCommands.checkForUpdates() },
                    quitAction: { AppCommands.quit() }
                )
            }
        }
        .frame(width: 320, height: 382)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .foregroundStyle(.primary)
        .animation(.smooth(duration: 0.24), value: screen)
    }

    private var historyScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(appModel.isProcessing ? .mint : .secondary)

                Text(popoverTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Button {
                    screen = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(.white.opacity(0.08), in: Circle())
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let pendingAskSummary = appModel.pendingAskSummary {
                PopoverPendingAsk(summary: pendingAskSummary)
            } else if recentJobs.isEmpty {
                PopoverEmptyHistory()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(recentJobs) { job in
                            PopoverHistoryRow(job: job)
                            if job.id != recentJobs.last?.id {
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
                        screen = .history
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Spacer()
                }

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    PopoverSegmentRow(title: "Default optimization", subtitle: "Used for new drops.") {
                        PopoverSegmentedControl(
                            selection: compressionModeBinding,
                            options: visibleCompressionModes.map { ($0, $0.title) }
                        )
                    }

                    PopoverDivider()

                    PopoverSegmentRow(title: "Video size", subtitle: "When Smaller is selected.") {
                        PopoverSegmentedControl(
                            selection: videoModeBinding,
                            options: VideoCompressionMode.allCases.map { ($0, $0.popoverTitle) }
                        )
                    }

                    PopoverDivider()

                    PopoverSegmentRow(title: "Output", subtitle: "Where optimized files go.") {
                        PopoverSegmentedControl(
                            selection: outputModeBinding,
                            options: OutputMode.allCases.map { ($0, $0.popoverTitle) }
                        )
                    }

                    PopoverDivider()

                    PopoverToggleRow(
                        title: "Launch at login",
                        subtitle: "Start Kompakt when you log in.",
                        isOn: openAtLoginBinding
                    )

                    PopoverDivider()

                    PopoverToggleRow(
                        title: "Show ESC hint",
                        subtitle: "Show the hide shortcut while dragging.",
                        isOn: escapeHintBinding
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.never)
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
}

private enum PopoverScreen {
    case history
    case settings
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
    @EnvironmentObject private var appModel: AppModel
    let job: CompressionJob

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: job.url.path))
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

            Button {
                appModel.reveal(job)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(.white.opacity(0.08), in: Circle())
            .help("Reveal in Finder")

            Button {
                appModel.revert(job: job)
            } label: {
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
    }

    private var detailText: String {
        guard let result = job.result else { return job.status.message }
        let saved = ByteCountFormatter.string(fromByteCount: result.bytesSaved, countStyle: .file)
        return "\(saved) saved · \(job.outputMode.title)"
    }
}

private struct PopoverPendingAsk: View {
    @EnvironmentObject private var appModel: AppModel
    let summary: OptimizableFileSummary

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

                Button {
                    appModel.cancelPendingAsk()
                } label: {
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
                        appModel.choosePendingVideoMode(mode)
                    }
                }
            } else {
                PopoverChoiceButton(title: "Lossless", subtitle: "Pixels stay intact.") {
                    appModel.choosePendingAskMode(.lossless)
                }
                PopoverChoiceButton(title: "Smaller", subtitle: "Balanced lossy optimization.") {
                    appModel.choosePendingAskMode(.smaller)
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
        .frame(height: 30)
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(PopoverAccent.color)
        }
        .frame(minHeight: 50)
    }
}

private struct PopoverSegmentRow<Control: View>: View {
    let title: String
    let subtitle: String
    let control: Control

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
                        .foregroundStyle(.secondary)
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
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == option.value ? PopoverAccent.color : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
    }
}

private enum PopoverAccent {
    static let color = Color(red: 0x3c / 255, green: 0x81 / 255, blue: 0x6d / 255)
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
            .fill(Color.white.opacity(0.095))
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

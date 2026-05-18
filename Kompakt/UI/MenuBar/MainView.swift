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

            SettingsLink {
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
                        .stroke(isDropActive ? .mint.opacity(0.65) : .white.opacity(0.11), lineWidth: 1.2)
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
                    Text(summary.kind == .video ? "Choose the video output size." : "Choose how aggressively Kompakt should work.")
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
                    ChoiceButton(title: "Lossless", subtitle: "Pixels stay intact", systemImage: "shield.checkered") {
                        appModel.choosePendingAskMode(.lossless)
                    }

                    ChoiceButton(title: "Smaller", subtitle: "Balanced lossy optimization", systemImage: "arrow.down.right.and.arrow.up.left") {
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
                    Text(ByteCountFormatter.string(fromByteCount: appModel.totalBytesSaved, countStyle: .file))
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
                    Image(systemName: latest.status.isFinished ? "checkmark.circle.fill" : "clock.fill")
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
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    var body: some View {
        Form {
            Picker("Default optimization", selection: $appModel.compressionMode) {
                ForEach(CompressionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Picker("Output", selection: $appModel.outputMode) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Toggle("Show ESC hint", isOn: $appModel.showEscapeHint)
            Toggle("Open at Login", isOn: openAtLoginBinding)
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 390)
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding {
            appModel.opensAtLogin
        } set: {
            appModel.setOpensAtLogin($0)
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.09),
                    Color(red: 0.10, green: 0.13, blue: 0.12),
                    Color(red: 0.04, green: 0.05, blue: 0.05)
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

#Preview {
    MainView()
        .environmentObject(AppModel.shared)
}

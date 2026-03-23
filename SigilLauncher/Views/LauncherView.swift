import SwiftUI

public struct LauncherView: View {
    @EnvironmentObject var vm: VMManager
    @State private var showQuitConfirmation = false
    @State private var showBuildLog = false

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Status header
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title2)
                Text("Sigil")
                    .font(.title2.bold())
                Spacer()
                Text(vm.state.displayName)
                    .foregroundColor(statusColor)
                    .font(.subheadline)
            }

            Divider()

            // Readiness indicators
            HStack(spacing: 16) {
                ReadinessIndicator(label: "VM", ready: vm.state == .running)
                ReadinessIndicator(label: "SSH", ready: vm.sshReady)
                ReadinessIndicator(label: "Daemon", ready: vm.daemonReady)
            }

            // No VM image warning
            if !vm.imageReady && vm.state == .stopped {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("No VM image found")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    Button("Build Image") {
                        Task { await vm.rebuild() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }

            // Build progress section
            if vm.imageBuilder.state == .building {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text(vm.imageBuilder.progressMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Collapsible build log
                    DisclosureGroup("Build Log", isExpanded: $showBuildLog) {
                        ScrollView {
                            ScrollViewReader { proxy in
                                Text(vm.imageBuilder.logOutput)
                                    .font(.system(.caption2, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("logBottom")
                                    .onChange(of: vm.imageBuilder.logOutput) { _ in
                                        proxy.scrollTo("logBottom", anchor: .bottom)
                                    }
                            }
                        }
                        .frame(maxHeight: 120)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(4)
                    }
                    .font(.caption)
                }
            }

            // Build error
            if vm.imageBuilder.state == .error, let buildError = vm.imageBuilder.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Build failed")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                    Text(buildError)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    Button("Retry Build") {
                        Task { await vm.rebuild() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .font(.caption)
                }
            }

            // Build complete
            if vm.imageBuilder.state == .complete {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Build complete")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Error messages with retry
            if let error = vm.errorMessage {
                VStack(spacing: 6) {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)

                    if error.contains("SSH") || error.contains("sigild") || error.contains("Daemon") {
                        Button("Retry") {
                            Task {
                                vm.errorMessage = nil
                                await vm.start()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .font(.caption)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        if vm.state == .stopped || vm.state == .error {
                            await vm.start()
                        } else if vm.state == .running {
                            showQuitConfirmation = true
                        }
                    }
                }) {
                    Text(vm.state == .running ? "Stop" : "Start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.state == .running ? .red : .indigo)
                .disabled(vm.state.isTransitioning || (!vm.imageReady && vm.state != .running))
                .keyboardShortcut(vm.state == .running ? "." : "r", modifiers: .command)

                Button("Open Shell") {
                    vm.launchShell()
                }
                .buttonStyle(.bordered)
                .disabled(!vm.daemonReady)
            }

            // Rebuild button
            if vm.imageReady && vm.imageBuilder.state != .building {
                Button("Rebuild Image") {
                    Task { await vm.rebuild() }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 360, height: 400)
        .confirmationDialog(
            "Stop VM?",
            isPresented: $showQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop VM", role: .destructive) {
                Task { await vm.stop() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The VM is currently running. Are you sure you want to stop it?")
        }
    }

    private var statusIcon: String {
        switch vm.state {
        case .stopped: return "stop.circle"
        case .starting: return "arrow.clockwise.circle"
        case .running: return "play.circle.fill"
        case .stopping: return "arrow.clockwise.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch vm.state {
        case .stopped: return .secondary
        case .starting, .stopping: return .orange
        case .running: return .green
        case .error: return .red
        }
    }
}

public struct ReadinessIndicator: View {
    public let label: String
    public let ready: Bool

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ready ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

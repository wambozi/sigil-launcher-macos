import SwiftUI

struct LauncherView: View {
    @EnvironmentObject var vm: VMManager

    var body: some View {
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

            Spacer()

            // Error message
            if let error = vm.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        if vm.state == .stopped || vm.state == .error {
                            await vm.start()
                        } else if vm.state == .running {
                            await vm.stop()
                        }
                    }
                }) {
                    Text(vm.state == .running ? "Stop" : "Start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.state == .running ? .red : .indigo)
                .disabled(vm.state.isTransitioning)

                Button("Open Shell") {
                    vm.launchShell()
                }
                .buttonStyle(.bordered)
                .disabled(!vm.daemonReady)
            }
        }
        .padding(24)
        .frame(width: 360, height: 280)
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

struct ReadinessIndicator: View {
    let label: String
    let ready: Bool

    var body: some View {
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

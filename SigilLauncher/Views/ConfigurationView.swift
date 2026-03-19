import SwiftUI

struct ConfigurationView: View {
    @EnvironmentObject var vm: VMManager

    @State private var memoryGB: Double
    @State private var cpuCores: Double
    @State private var workspacePath: String
    @State private var saved = false

    init() {
        let profile = LauncherProfile.load()
        _memoryGB = State(initialValue: Double(profile.memorySize) / (1024 * 1024 * 1024))
        _cpuCores = State(initialValue: Double(profile.cpuCount))
        _workspacePath = State(initialValue: profile.workspacePath)
    }

    var body: some View {
        Form {
            Section("Resources") {
                VStack(alignment: .leading) {
                    Text("Memory: \(Int(memoryGB)) GB")
                    Slider(value: $memoryGB, in: 2...16, step: 1)
                }

                VStack(alignment: .leading) {
                    Text("CPU Cores: \(Int(cpuCores))")
                    Slider(value: $cpuCores, in: 1...Double(ProcessInfo.processInfo.processorCount), step: 1)
                }
            }

            Section("Workspace") {
                HStack {
                    TextField("Path", text: $workspacePath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            workspacePath = url.path
                        }
                    }
                }
            }

            Section("Images") {
                let profile = vm.currentProfile
                LabeledContent("Kernel", value: profile.kernelPath)
                LabeledContent("Initrd", value: profile.initrdPath)
                LabeledContent("Disk", value: profile.diskImagePath)
            }

            Section {
                HStack {
                    Button("Save") {
                        var profile = vm.currentProfile
                        profile.memorySize = UInt64(memoryGB * 1024 * 1024 * 1024)
                        profile.cpuCount = Int(cpuCores)
                        profile.workspacePath = workspacePath
                        vm.updateProfile(profile)
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            saved = false
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if saved {
                        Text("Saved")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(width: 480, height: 400)
    }
}

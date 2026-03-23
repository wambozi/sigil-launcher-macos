import SwiftUI

public struct ConfigurationView: View {
    @EnvironmentObject var vm: VMManager

    @State private var memoryGB: Double
    @State private var cpuCores: Double
    @State private var workspacePath: String
    @State private var editor: String
    @State private var containerEngine: String
    @State private var shell: String
    @State private var notificationLevel: Int
    @State private var modelId: String?
    @State private var saved = false

    /// Snapshot of the saved profile to detect rebuild-requiring changes
    @State private var savedProfile: LauncherProfile

    public init() {
        let profile = LauncherProfile.load()
        _memoryGB = State(initialValue: Double(profile.memorySize) / (1024 * 1024 * 1024))
        _cpuCores = State(initialValue: Double(profile.cpuCount))
        _workspacePath = State(initialValue: profile.workspacePath)
        _editor = State(initialValue: profile.editor)
        _containerEngine = State(initialValue: profile.containerEngine)
        _shell = State(initialValue: profile.shell)
        _notificationLevel = State(initialValue: profile.notificationLevel)
        _modelId = State(initialValue: profile.modelId)
        _savedProfile = State(initialValue: profile)
    }

    /// Build a profile from the current UI state for comparison
    private var currentEditedProfile: LauncherProfile {
        var profile = savedProfile
        profile.memorySize = UInt64(memoryGB * 1024 * 1024 * 1024)
        profile.cpuCount = Int(cpuCores)
        profile.workspacePath = workspacePath
        profile.editor = editor
        profile.containerEngine = containerEngine
        profile.shell = shell
        profile.notificationLevel = notificationLevel
        profile.modelId = modelId
        return profile
    }

    /// Whether the current edits require a VM image rebuild
    private var rebuildRequired: Bool {
        currentEditedProfile.needsRebuild(comparedTo: savedProfile)
    }

    /// Models available given the current memory allocation
    private var availableModels: [ModelInfo] {
        ModelCatalog.availableModels(forVMRAMGB: Int(memoryGB))
    }

    public var body: some View {
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

            Section("Tools") {
                Picker("Editor", selection: $editor) {
                    Text("VS Code").tag("vscode")
                    Text("Neovim").tag("neovim")
                    Text("Both").tag("both")
                    Text("None").tag("none")
                }

                Picker("Container Engine", selection: $containerEngine) {
                    Text("Docker").tag("docker")
                    Text("None").tag("none")
                }

                Picker("Shell", selection: $shell) {
                    Text("Zsh").tag("zsh")
                    Text("Bash").tag("bash")
                }

                Picker("Notification Level", selection: $notificationLevel) {
                    Text("Silent").tag(0)
                    Text("Digest").tag(1)
                    Text("Ambient").tag(2)
                    Text("Conversational").tag(3)
                    Text("Autonomous").tag(4)
                }
            }

            Section("Local Model") {
                Picker("Model", selection: Binding(
                    get: { modelId ?? "__none__" },
                    set: { modelId = $0 == "__none__" ? nil : $0 }
                )) {
                    Text("Cloud only (no local model)").tag("__none__")
                    ForEach(availableModels) { model in
                        VStack(alignment: .leading) {
                            Text(model.name)
                            Text("\(model.parameters) \u{2022} \(String(format: "%.1f", model.sizeGB)) GB \u{2022} \(model.quantization)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .tag(model.id)
                    }
                }

                if availableModels.isEmpty {
                    Text("Increase VM memory to enable local models (minimum 3 GB)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let selectedId = modelId,
                   let model = ModelCatalog.models.first(where: { $0.id == selectedId }),
                   !availableModels.contains(where: { $0.id == selectedId }) {
                    Label("Selected model requires more RAM than currently allocated", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section("Images") {
                LabeledContent("Kernel", value: savedProfile.kernelPath)
                LabeledContent("Initrd", value: savedProfile.initrdPath)
                LabeledContent("Disk", value: savedProfile.diskImagePath)
            }

            Section {
                HStack {
                    Button("Save") {
                        let profile = currentEditedProfile
                        vm.updateProfile(profile)
                        savedProfile = profile
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

                    Spacer()

                    if rebuildRequired {
                        Label("Rebuild required", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .frame(width: 480, height: 560)
    }
}

import SwiftUI

struct SetupWizard: View {
    @State private var step = 0
    @State private var hardware: HardwareInfo
    @State private var recommendation: ResourceRecommendation
    @State private var profile = LauncherProfile.defaultProfile
    @State private var selectedModelId: String? = "qwen2.5-1.5b-q4"
    @State private var requirementError: String? = nil
    @State private var buildError: String? = nil
    @State private var buildFinished = false

    @ObservedObject var imageBuilder: ImageBuilder

    var onComplete: (LauncherProfile) -> Void

    init(imageBuilder: ImageBuilder, onComplete: @escaping (LauncherProfile) -> Void) {
        self.imageBuilder = imageBuilder
        self.onComplete = onComplete
        let hw = HardwareDetector.detect()
        self._hardware = State(initialValue: hw)
        self._recommendation = State(initialValue: HardwareDetector.recommend(for: hw))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            HStack(spacing: 4) {
                ForEach(0..<6) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 16)

            Spacer()

            // Step content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: hardwareStep
                case 2: resourcesStep
                case 3: toolsStep
                case 4: modelStep
                case 5: buildStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer()

            // Navigation
            HStack {
                if step > 0 && step < 5 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                if step < 4 {
                    Button("Next") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .disabled(step == 1 && requirementError != nil)
                } else if step == 4 {
                    Button("Build Workspace") {
                        finalizeProfile()
                        step = 5
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 520, height: 560)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Text("\u{2B21}").font(.system(size: 64))
            Text("Welcome to Sigil").font(.title).bold()
            Text("Set up your AI-powered development workspace")
                .foregroundColor(.secondary)
            Button("Get Started") { step = 1 }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    private var hardwareStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hardware Detection").font(.title2).bold()
            Text("We detected the following hardware:").foregroundColor(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("RAM").foregroundColor(.secondary)
                    Text("\(hardware.totalRAMGB) GB")
                }
                GridRow {
                    Text("CPU").foregroundColor(.secondary)
                    Text("\(hardware.cpuCores) cores (\(hardware.cpuArch))")
                }
                GridRow {
                    Text("Disk").foregroundColor(.secondary)
                    Text("\(hardware.diskAvailableGB) GB available")
                }
                if let gpu = hardware.gpuName {
                    GridRow {
                        Text("GPU").foregroundColor(.secondary)
                        Text(gpu)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor)))

            if hardware.totalRAMGB < 8 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Sigil requires at least 8 GB of RAM. Your system has \(hardware.totalRAMGB) GB.")
                        .foregroundColor(.red)
                        .font(.callout)
                }
            }

            if let error = requirementError {
                Text(error).foregroundColor(.red).font(.callout)
            }
        }
        .padding()
        .onAppear {
            let (meets, error) = HardwareDetector.meetsMinimumRequirements(hardware)
            requirementError = meets ? nil : error
        }
    }

    private var resourcesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resource Allocation").font(.title2).bold()
            Text("How much of your machine should Sigil use?").foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Memory: \(Int(profile.memorySize / (1024*1024*1024))) GB")
                Slider(
                    value: Binding(
                        get: { Double(profile.memorySize) / (1024*1024*1024) },
                        set: { profile.memorySize = UInt64($0) * 1024*1024*1024 }
                    ),
                    in: 4...Double(min(hardware.totalRAMGB, 16)),
                    step: 1
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CPU Cores: \(profile.cpuCount)")
                Slider(
                    value: Binding(
                        get: { Double(profile.cpuCount) },
                        set: { profile.cpuCount = Int($0) }
                    ),
                    in: 2...Double(hardware.cpuCores),
                    step: 1
                )
            }
        }
        .padding()
        .onAppear {
            profile.memorySize = UInt64(recommendation.memoryGB) * 1024*1024*1024
            profile.cpuCount = recommendation.cpus
        }
    }

    private var toolsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tool Selection").font(.title2).bold()
            Text("Choose your development tools").foregroundColor(.secondary)

            Picker("Editor", selection: $profile.editor) {
                Text("VS Code").tag("vscode")
                Text("Neovim").tag("neovim")
                Text("Both").tag("both")
                Text("None").tag("none")
            }

            Picker("Container Engine", selection: $profile.containerEngine) {
                Text("Docker").tag("docker")
                Text("None").tag("none")
            }

            Picker("Shell", selection: $profile.shell) {
                Text("Zsh").tag("zsh")
                Text("Bash").tag("bash")
            }

            Picker("Suggestion Style", selection: $profile.notificationLevel) {
                Text("Silent").tag(0)
                Text("Digest").tag(1)
                Text("Ambient (recommended)").tag(2)
                Text("Conversational").tag(3)
                Text("Autonomous").tag(4)
            }
        }
        .padding()
    }

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local AI Model").font(.title2).bold()
            Text("Choose a model for on-device inference").foregroundColor(.secondary)

            let vmRAMGB = Int(profile.memorySize / (1024*1024*1024))
            let available = ModelCatalog.availableModels(forVMRAMGB: vmRAMGB)

            // "No model" option
            Button(action: { selectedModelId = nil }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Cloud Only").bold()
                        Text("No local model \u{2014} uses cloud inference")
                            .font(.callout).foregroundColor(.secondary)
                    }
                    Spacer()
                    if selectedModelId == nil {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(selectedModelId == nil ? Color.accentColor.opacity(0.1) : Color.clear))
            }
            .buttonStyle(.plain)

            ForEach(ModelCatalog.models) { model in
                let isAvailable = available.contains(where: { $0.id == model.id })
                Button(action: { if isAvailable { selectedModelId = model.id } }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.name).bold()
                            Text("\(model.description) (\(String(format: "%.1f", model.sizeGB))GB)")
                                .font(.callout).foregroundColor(.secondary)
                        }
                        Spacer()
                        if !isAvailable {
                            Text("Needs \(Int(model.minRAMGB))GB+ VM RAM")
                                .font(.caption).foregroundColor(.red)
                        } else if selectedModelId == model.id {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(selectedModelId == model.id ? Color.accentColor.opacity(0.1) : Color.clear))
                    .opacity(isAvailable ? 1.0 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable)
            }
        }
        .padding()
    }

    private var buildStep: some View {
        VStack(spacing: 16) {
            // Nix not installed
            if ImageBuilder.nixPath() == nil {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Nix is not installed").font(.title3).bold()
                    Text("Sigil requires Nix to build the workspace image.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Link("Install Nix", destination: URL(string: "https://nixos.org/download/")!)
                        .buttonStyle(.borderedProminent)
                    Button("Retry") {
                        // Re-trigger build attempt
                        startBuild()
                    }
                    .buttonStyle(.bordered)
                }
            } else if let error = buildError {
                // Build error with retry
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Build Failed").font(.title3).bold()
                    Text(error)
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)

                    // Show build log excerpt
                    if !imageBuilder.logOutput.isEmpty {
                        DisclosureGroup("Build Log") {
                            ScrollView {
                                Text(imageBuilder.logOutput)
                                    .font(.system(.caption2, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 120)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(4)
                        }
                        .font(.caption)
                    }

                    Button("Retry") {
                        buildError = nil
                        startBuild()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Back") {
                        buildError = nil
                        step = 4
                    }
                    .buttonStyle(.bordered)
                }
            } else if buildFinished {
                // Build complete
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("Workspace Ready").font(.title3).bold()
                    Text("Your Sigil workspace has been built successfully.")
                        .foregroundColor(.secondary)
                }
            } else {
                // Building in progress
                ProgressView()
                    .controlSize(.large)
                Text("Building your workspace...")
                    .font(.title3)
                Text(imageBuilder.progressMessage)
                    .foregroundColor(.secondary)
                    .font(.callout)

                if !imageBuilder.logOutput.isEmpty {
                    DisclosureGroup("Build Log") {
                        ScrollView {
                            ScrollViewReader { proxy in
                                Text(imageBuilder.logOutput)
                                    .font(.system(.caption2, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("wizardLogBottom")
                                    .onChange(of: imageBuilder.logOutput) { _ in
                                        proxy.scrollTo("wizardLogBottom", anchor: .bottom)
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
        }
        .padding()
        .onAppear {
            startBuild()
        }
    }

    // MARK: - Helpers

    private func finalizeProfile() {
        profile.modelId = selectedModelId
        if let modelId = selectedModelId,
           let model = ModelCatalog.models.first(where: { $0.id == modelId }) {
            profile.modelPath = ModelManager.modelsDirectory
                .appendingPathComponent(model.filename).path
        } else {
            profile.modelPath = nil
        }
    }

    private func startBuild() {
        buildFinished = false
        buildError = nil
        Task {
            do {
                try profile.save()
                try await imageBuilder.build(profile: profile)
                buildFinished = true
                onComplete(profile)
            } catch {
                buildError = error.localizedDescription
            }
        }
    }
}

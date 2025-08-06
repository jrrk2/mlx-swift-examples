// Copyright © 2024 Apple Inc.

import AsyncAlgorithms
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import MarkdownUI
import Metal
import SwiftUI
import Tokenizers
import Hub

struct ContentView: View {
    @Environment(DeviceStat.self) private var deviceStat

    @State var llm = LLMEvaluator()

    enum displayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }

    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                HStack {
                    Text(llm.modelInfo)
                        .textFieldStyle(.roundedBorder)

                    Spacer()

                    Text(llm.stat)
                }
                HStack {
                    if llm.running {
                        ProgressView()
                            .frame(maxHeight: 20)
                        Spacer()
                    }
                }
            }

            // show the model output
            ScrollView(.vertical) {
                ScrollViewReader { sp in
                    Group {
                             Markdown(llm.output)
                                .textSelection(.enabled)
                    }
                    .onChange(of: llm.output) { _, _ in
                        sp.scrollTo("bottom")
                    }

                    Spacer()
                        .frame(width: 1, height: 1)
                        .id("bottom")
                }
            }

            HStack {
                TextField("prompt", text: Bindable(llm).prompt)
                    .onSubmit(generate)
                    .disabled(llm.running)
                    #if os(visionOS)
                        .textFieldStyle(.roundedBorder)
                    #endif
                Button(llm.running ? "stop" : "generate", action: llm.running ? cancel : generate)
            }
        }
        #if os(visionOS)
            .padding(40)
        #else
            .padding()
        #endif
        .toolbar {
            ToolbarItem {
                Label(
                    "Memory Usage: \(deviceStat.gpuUsage.activeMemory.formatted(.byteCount(style: .memory)))",
                    systemImage: "info.circle.fill"
                )
                .labelStyle(.titleAndIcon)
                .padding(.horizontal)
                .help(
                    Text(
                        """
                        Active Memory: 
                        Cache Memory: 
                        Peak Memory:
                        """
                    )
                )
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        copyToClipboard(llm.output)
                    }
                } label: {
                    Label("Copy Output", systemImage: "doc.on.doc.fill")
                }
                .disabled(llm.output == "")
                .labelStyle(.titleAndIcon)
            }

        }
        .task {
            // pre-load the weights on launch to speed up the first generation
            _ = try? await llm.load()
        }
    }

    private func generate() {
        llm.generate()
    }

    private func cancel() {
        llm.cancelGeneration()
    }

    private func copyToClipboard(_ string: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        #else
            UIPasteboard.general.string = string
        #endif
    }
}

@Observable
@MainActor
class LLMEvaluator {

    var running = false

    var prompt = ""
    var output = ""
    var modelInfo = ""
    var stat = ""

    /// This controls which model loads. `qwen2_5_1_5b` is one of the smaller ones, so this will fit on
    /// more devices.
    let modelConfiguration = LLMRegistry.qwen3_1_7b_4bit

    /// parameters controlling the output
    let generateParameters = GenerateParameters(
        maxTokens: 8192,                   // Add this as a safety net
        temperature: 0.7,
        topP: 1.0,
        repetitionPenalty: 1.1,          // Add this
        repetitionContextSize: 20        // Add this
     )
    let updateInterval = Duration.seconds(0.25)

    /// A task responsible for handling the generation process.
    var generationTask: Task<Void, Error>?

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle

    // Add this function to your ContentView.swift or wherever your load() function is located

    func setupBundledModel() throws -> URL {
        // Create destination directory
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelDir = documentsDir
            .appendingPathComponent("Models")
            .appendingPathComponent("Phi-3.5-mini-instruct-mlx-4bit")
        
        if FileManager.default.fileExists(atPath: modelDir.path) {
            print("Model already exists at: \(modelDir.path)")
            return modelDir
        }
        
        // Create the model directory
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        
        // Copy the flattened files from bundle
        let filesToCopy = [
            "added_tokens.json",
            "chat_template.jinja",
            "config.json",
            "configuration_phi3.py",
            "generation_config.json",
            "model.safetensors",
            "model.safetensors.index.json",
            "modeling_phi3.py",
            "README.md",
            "sample_finetune.py",
            "special_tokens_map.json",
            "tokenizer_config.json",
            "tokenizer.json",
            "tokenizer.model",
        ]
        
        for filename in filesToCopy {
            guard let bundleFile = Bundle.main.url(forResource: filename, withExtension: nil) else {
                print("⚠️ Warning: \(filename) not found in bundle")
                continue
            }
            
            let destinationFile = modelDir.appendingPathComponent(filename)
            
            // Remove if exists (in case of re-copying)
            if FileManager.default.fileExists(atPath: destinationFile.path) {
                try FileManager.default.removeItem(at: destinationFile)
            }
            
            try FileManager.default.copyItem(at: bundleFile, to: destinationFile)
            print("✅ Copied \(filename)")
        }
        
        print("🎉 Successfully set up bundled model at: \(modelDir.path)")
        return modelDir
    }
    
    // Then update your existing load() function to use it:
    func load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            // Set up bundled model
            let modelDir = try setupBundledModel()
            
            // Use ModelConfiguration(directory:) to point directly to the model
            let bundledModelConfig = ModelConfiguration(
                directory: modelDir,
//                 overrideTokenizer: "PreTrainedTokenizer",
                defaultPrompt: "History of Hong Kong"
            )
            
            let modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: bundledModelConfig
            ) { progress in
                Task { @MainActor in
                    self.modelInfo = "Loading bundled model: \(Int(progress.fractionCompleted * 100))%"
                }
            }
            
            let numParams = await modelContainer.perform { context in
                context.model.numParameters()
            }

            self.prompt = bundledModelConfig.defaultPrompt
            self.modelInfo = "Loaded bundled model offline"
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    private func generate(prompt: String) async {

        self.output = ""
        let chat: [Chat.Message] = [
            .system("You are an age appropriate assistant for 8-9 year olds"),
            .user(prompt),
        ]
        let userInput = UserInput(chat: chat)

        do {
            let modelContainer = try await load()

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            try await modelContainer.perform { (context: ModelContext) -> Void in
                let lmInput = try await context.processor.prepare(input: userInput)
                let stream = try MLXLMCommon.generate(
                    input: lmInput, parameters: generateParameters, context: context)

                // generate and output in batches
                for await batch in stream._throttle(
                    for: updateInterval, reducing: Generation.collect)
                {
                    let output = batch.compactMap { $0.chunk }.joined(separator: "")
                    if !output.isEmpty {
                        Task { @MainActor [output] in
                            self.output += output
                        }
                    }

                    if let completion = batch.compactMap({ $0.info }).first {
                        Task { @MainActor in
                            self.stat = String(format: "%.1f tokens/s", completion.tokensPerSecond)
                        }
                    }
                }
            }

        } catch {
            output = "Failed: \(error)"
        }
    }

    func generate() {
        guard !running else { return }
        let currentPrompt = prompt
        prompt = ""
        generationTask = Task {
            running = true
            await generate(prompt: currentPrompt)
            running = false
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        running = false
    }
}

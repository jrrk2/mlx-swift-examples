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

    @State var llm = LLMEvaluatorWithLogging()
    @StateObject private var teacherAuth = TeacherAuthManager()

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
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    teacherAuth.requestAccess()
                } label: {
                    Label("Teacher Logs", systemImage: "person.badge.key")
                }
                .help("Access student interaction logs (teacher only)")
            }

        }
        // Add these sheet modifiers at the end of your body:
        .sheet(isPresented: $teacherAuth.showingPasswordPrompt) {
            TeacherPasswordView(authManager: teacherAuth)
        }
        .sheet(isPresented: $teacherAuth.isAuthenticated) {
            AuthenticatedTeacherLogView(authManager: teacherAuth)
                .onDisappear {
                    teacherAuth.logout()
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


// MARK: - Enhanced LLMEvaluator with Logging

@Observable
@MainActor
class LLMEvaluatorWithLogging {
    
    var running = false
    var prompt = ""
    var output = ""
    var modelInfo = ""
    var stat = ""
    
    let modelConfiguration = LLMRegistry.qwen3_1_7b_4bit
    let generateParameters = GenerateParameters(
        maxTokens: 8192,
        temperature: 0.7,
        topP: 1.0,
        repetitionPenalty: 1.1,
        repetitionContextSize: 20
    )
    let updateInterval = Duration.seconds(0.25)
    
    var generationTask: Task<Void, Error>?
    
    // Logging-related properties
    private var currentPrompt = ""
    private var generationStartTime: Date?
    private var finalStats: String = ""
    
    // Load state management
    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }
    var loadState = LoadState.idle
    
    init() {
        // Initialize a new logging session when the evaluator starts
        TeacherLogger.shared.startNewSession()
    }
    
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
    
    func load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            // Set up bundled model first
            let modelDir = try setupBundledModel()
            
            // Use ModelConfiguration(directory:) to point directly to the bundled model
            let bundledModelConfig = ModelConfiguration(
                directory: modelDir,
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
        // Store the original prompt for logging
        currentPrompt = prompt
        generationStartTime = Date()
        
        // Clear previous output but store it for potential logging
        let previousOutput = output
        output = ""
        
        let chat: [Chat.Message] = [
            .system("You are an age appropriate assistant for 8-9 year olds"),
            .user(prompt),
        ]
        let userInput = UserInput(chat: chat)
        
        do {
            let modelContainer = try await load()
            
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
            
            try await modelContainer.perform { (context: ModelContext) -> Void in
                let lmInput = try await context.processor.prepare(input: userInput)
                let stream = try MLXLMCommon.generate(
                    input: lmInput, parameters: generateParameters, context: context)
                
                var accumulatedOutput = ""
                
                for await batch in stream._throttle(
                    for: updateInterval, reducing: Generation.collect)
                {
                    let batchOutput = batch.compactMap { $0.chunk }.joined(separator: "")
                    if !batchOutput.isEmpty {
                        accumulatedOutput += batchOutput
                        Task { @MainActor [batchOutput] in
                            self.output += batchOutput
                        }
                    }
                    
                    if let completion = batch.compactMap({ $0.info }).first {
                        let statsString = String(format: "%.1f tokens/s", completion.tokensPerSecond)
                        Task { @MainActor in
                            self.stat = statsString
                            self.finalStats = statsString
                        }
                        
                        // Log the complete interaction
                        await self.logCompleteInteraction(
                            prompt: prompt,
                            response: accumulatedOutput,
                            completion: completion
                        )
                    }
                }
            }
            
        } catch {
            let errorMessage = "Failed: \(error)"
            output = errorMessage
            
            // Log the error as well
            TeacherLogger.shared.logInteraction(
                userPrompt: prompt,
                modelResponse: errorMessage,
                modelInfo: "Bundled Phi-3.5-mini (offline)", // ← Fixed
		tokensPerSecond: 0.0,
		promptTokens: 0,
		responseTokens: 0,
                processingTime: Date().timeIntervalSince(generationStartTime ?? Date())
            )
        }
    }
    
    private func logCompleteInteraction(
	prompt: String, 
	response: String, 
	completion: GenerateCompletionInfo
    ) {
	let processingTime = Date().timeIntervalSince(generationStartTime ?? Date())

	TeacherLogger.shared.logInteraction(
	    userPrompt: prompt,
	    modelResponse: response,
	    modelInfo: "Bundled Phi-3.5-mini (offline)",
	    tokensPerSecond: completion.tokensPerSecond,
	    promptTokens: completion.promptTokenCount,
	    responseTokens: completion.generationTokenCount,
	    processingTime: processingTime
	)
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
        // Log cancellation
        if !currentPrompt.isEmpty {
            TeacherLogger.shared.logInteraction(
                userPrompt: currentPrompt,
                modelResponse: "[GENERATION CANCELLED]",
                modelInfo: modelConfiguration.name,
		tokensPerSecond: 0.0,
		promptTokens: 0,
		responseTokens: 0,
                processingTime: Date().timeIntervalSince(generationStartTime ?? Date())
            )
        }
        
        generationTask?.cancel()
        running = false
    }
}

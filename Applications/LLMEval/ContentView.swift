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
import MessageUI

// Replace your ContentView with this version that makes the Teacher button more visible

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
            // Add teacher access button at the top - MORE VISIBLE
            HStack {
                Button {
                    teacherAuth.requestAccess()
                } label: {
                    HStack {
                        Image(systemName: "person.badge.key.fill")
                        Text("Teacher Logs")
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.blue)
                .help("Access student interaction logs (teacher only)")
                
                Spacer()
                
                // Status indicator
                if teacherAuth.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Teacher Authenticated")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
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
        // Sheet modifiers for teacher authentication
        .sheet(isPresented: $teacherAuth.showingPasswordPrompt) {
            TeacherPasswordView(authManager: teacherAuth)
        }
        .sheet(isPresented: $teacherAuth.isAuthenticated) {
            SimpleTeacherLogViewWithExport(authManager: teacherAuth)
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

// Updated LLMEvaluator that uses teacher preferences

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
    
    // Enhanced logging-related properties
    private var currentPrompt = ""
    private var generationStartTime: Date?
    private var finalStats: String = ""
    private var accumulatedResponse = ""
    private var lastCompletionInfo: GenerateCompletionInfo?
    
    // Reference to teacher preferences
    private let teacherPreferences = TeacherPreferences.shared
    
    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }
    var loadState = LoadState.idle
    
    init() {
        TeacherLogger.shared.startNewSession()
        print("🔧 LLMEvaluator initialized with system message: \(teacherPreferences.systemMessage)")
    }
    
    // ... (keeping all the existing setupBundledModel and load methods the same) ...
    
    func setupBundledModel() throws -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelDir = documentsDir
            .appendingPathComponent("Models")
            .appendingPathComponent("Phi-3.5-mini-instruct-mlx-4bit")
        
        if FileManager.default.fileExists(atPath: modelDir.path) {
            print("Model already exists at: \(modelDir.path)")
            return modelDir
        }
        
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        
        let filesToCopy = [
            "added_tokens.json", "chat_template.jinja", "config.json", "configuration_phi3.py",
            "generation_config.json", "model.safetensors", "model.safetensors.index.json",
            "modeling_phi3.py", "README.md", "sample_finetune.py", "special_tokens_map.json",
            "tokenizer_config.json", "tokenizer.json", "tokenizer.model",
        ]
        
        for filename in filesToCopy {
            guard let bundleFile = Bundle.main.url(forResource: filename, withExtension: nil) else {
                print("⚠️ Warning: \(filename) not found in bundle")
                continue
            }
            
            let destinationFile = modelDir.appendingPathComponent(filename)
            
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
            let modelDir = try setupBundledModel()
            
            let bundledModelConfig = ModelConfiguration(
                directory: modelDir,
                defaultPrompt: "Help"
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
    
    // MainActor isolated methods for updating state
    @MainActor
    private func updateAccumulatedResponse(_ newContent: String) {
        accumulatedResponse += newContent
    }
    
    @MainActor
    private func updateLastCompletionInfo(_ completion: GenerateCompletionInfo) {
        lastCompletionInfo = completion
    }
    
    @MainActor
    private func resetGenerationState(prompt: String) {
        currentPrompt = prompt
        generationStartTime = Date()
        accumulatedResponse = ""
        lastCompletionInfo = nil
    }
    
    private func generate(prompt: String) async {
        await resetGenerationState(prompt: prompt)
        
        let previousOutput = output
        output = ""
        
        // Use the teacher's custom system message
        let systemMessage = teacherPreferences.systemMessage
        print("🔧 Using system message: \(systemMessage)")
        
        let chat: [Chat.Message] = [
            .system(systemMessage),  // ← Now uses teacher preference!
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
                
                for await batch in stream._throttle(
                    for: updateInterval, reducing: Generation.collect)
                {
                    let batchOutput = batch.compactMap { $0.chunk }.joined(separator: "")
                    if !batchOutput.isEmpty {
                        await self.updateAccumulatedResponse(batchOutput)
                        
                        Task { @MainActor [batchOutput] in
                            self.output += batchOutput
                        }
                    }
                    
                    if let completion = batch.compactMap({ $0.info }).first {
                        await self.updateLastCompletionInfo(completion)
                        
                        let statsString = String(format: "%.1f tokens/s", completion.tokensPerSecond)
                        Task { @MainActor in
                            self.stat = statsString
                            self.finalStats = statsString
                        }
                        
                        await self.logCompleteInteractionAsync(
                            prompt: prompt,
                            completion: completion
                        )
                    }
                }
            }
            
        } catch {
            let errorMessage = "Failed: \(error)"
            await MainActor.run {
                self.output = errorMessage
            }
            
            await self.logErrorAsync(prompt: prompt, error: error)
        }
    }
    
    @MainActor
    private func logCompleteInteractionAsync(prompt: String, completion: GenerateCompletionInfo) {
        let processingTime = Date().timeIntervalSince(generationStartTime ?? Date())
        
        // Include teacher info in the model info for logs
        let modelInfo = buildModelInfoForLogs()

        TeacherLogger.shared.logInteraction(
            userPrompt: prompt,
            modelResponse: accumulatedResponse,
            modelInfo: modelInfo,
            tokensPerSecond: completion.tokensPerSecond,
            promptTokens: completion.promptTokenCount,
            responseTokens: completion.generationTokenCount,
            processingTime: processingTime
        )
    }
    
    @MainActor
    private func logErrorAsync(prompt: String, error: Error) {
        let responseToLog = accumulatedResponse.isEmpty ? "Failed: \(error)" : accumulatedResponse + "\n\n[Error: \(error)]"
        let modelInfo = buildModelInfoForLogs()
        
        TeacherLogger.shared.logInteraction(
            userPrompt: prompt,
            modelResponse: responseToLog,
            modelInfo: modelInfo,
            tokensPerSecond: lastCompletionInfo?.tokensPerSecond ?? 0.0,
            promptTokens: lastCompletionInfo?.promptTokenCount ?? 0,
            responseTokens: lastCompletionInfo?.generationTokenCount ?? 0,
            processingTime: Date().timeIntervalSince(generationStartTime ?? Date())
        )
    }
    
    private func buildModelInfoForLogs() -> String {
        var info = "Phi-3.5-mini (offline)"
        
        if !teacherPreferences.teacherName.isEmpty {
            info += " | Teacher: \(teacherPreferences.teacherName)"
        }
        
        if !teacherPreferences.schoolName.isEmpty {
            info += " | \(teacherPreferences.schoolName)"
        }
        
        info += " | \(teacherPreferences.studentAgeRange)"
        
        return info
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
        print("🔍 Cancelling generation. Accumulated response so far: '\(accumulatedResponse)'")
        
        if !currentPrompt.isEmpty {
            let responseToLog: String
            
            if accumulatedResponse.isEmpty {
                responseToLog = "[GENERATION CANCELLED - No response generated]"
            } else {
                responseToLog = accumulatedResponse + "\n\n[GENERATION CANCELLED - Response incomplete]"
            }
            
            let modelInfo = buildModelInfoForLogs()
            
            TeacherLogger.shared.logInteraction(
                userPrompt: currentPrompt,
                modelResponse: responseToLog,
                modelInfo: modelInfo,
                tokensPerSecond: lastCompletionInfo?.tokensPerSecond ?? 0.0,
                promptTokens: lastCompletionInfo?.promptTokenCount ?? 0,
                responseTokens: lastCompletionInfo?.generationTokenCount ?? 0,
                processingTime: Date().timeIntervalSince(generationStartTime ?? Date())
            )
            
            print("✅ Logged cancelled conversation with partial response")
        }
        
        generationTask?.cancel()
        running = false
    }
    
    func testLogging() {
        print("🔍 Manual test logging called...")
        
        TeacherLogger.shared.logInteraction(
            userPrompt: "Manual test: What's the weather like?",
            modelResponse: "I don't have access to real-time weather data, but I can help you understand weather patterns!",
            modelInfo: buildModelInfoForLogs(),
            tokensPerSecond: 35.2,
            promptTokens: 7,
            responseTokens: 18,
            processingTime: 2.3
        )
        
        print("✅ Manual test log entry created!")
        print("📁 Log file location: \(TeacherLogger.shared.getLogFileURL().path)")
    }
}

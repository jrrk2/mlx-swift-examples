// Copyright © 2024 Apple Inc.

import SwiftUI

@main
struct LLMEvalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(DeviceStat())
                .onAppear {
                    debugBundleContents()
                    debugModelPaths()
                }
        }
    }
}

import Hub
func debugModelPaths() {
    let hub = HubApi()
    
    // Check different models
    let models = [
        "mlx-community/SmolLM-135M-Instruct-4bit",
        "mlx-community/Llama-3.2-1B-Instruct-4bit"
    ]
    
    for modelId in models {
        let repo = Hub.Repo(id: modelId)
        let location = hub.localRepoLocation(repo)
        print("Model: \(modelId)")
        print("Expected location: \(location.path)")
        print("Exists: \(FileManager.default.fileExists(atPath: location.path))")
        print("---")
    }
}

func debugBundleContents() {
    print("=== Bundle Debug ===")
    
    if let bundlePath = Bundle.main.resourcePath {
        print("ALL Bundle contents:")
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            for item in contents {
                print("  - \(item)")
            }
        } catch {
            print("Error listing bundle: \(error)")
        }
    }
    
    print("===================")
}


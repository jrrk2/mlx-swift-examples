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
                }
        }
    }
}

import Hub

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


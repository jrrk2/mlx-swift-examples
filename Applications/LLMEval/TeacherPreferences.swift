//
//  TeacherPreferences.swift
//  mlx-swift-examples
//
//  Created by Jonathan Kimmitt on 07/08/2025.
//


import SwiftUI
import Foundation

// MARK: - Teacher Preferences Manager

class TeacherPreferences: ObservableObject {
    static let shared = TeacherPreferences()
    
    @Published var systemMessage: String {
        didSet {
            UserDefaults.standard.set(systemMessage, forKey: "TeacherSystemMessage")
            print("🔧 System message updated: \(systemMessage)")
        }
    }
    
    @Published var studentAgeRange: String {
        didSet {
            UserDefaults.standard.set(studentAgeRange, forKey: "TeacherAgeRange")
            print("🔧 Age range updated: \(studentAgeRange)")
        }
    }
    
    @Published var schoolName: String {
        didSet {
            UserDefaults.standard.set(schoolName, forKey: "TeacherSchoolName")
        }
    }
    
    @Published var teacherName: String {
        didSet {
            UserDefaults.standard.set(teacherName, forKey: "TeacherName")
        }
    }
    
    // Quick presets for common age ranges
    static let agePresets = [
        "5-6 year olds (Kindergarten)",
        "7-8 year olds (Grade 1-2)",
        "8-9 year olds (Grade 2-3)",
        "9-10 year olds (Grade 3-4)",
        "10-11 year olds (Grade 4-5)",
        "11-12 year olds (Grade 5-6)",
        "12-13 year olds (Middle School)",
        "Custom Age Range"
    ]
    
    private init() {
        // Load saved preferences or use defaults
        self.systemMessage = UserDefaults.standard.string(forKey: "TeacherSystemMessage") 
            ?? "You are an age appropriate assistant for 8-9 year olds"
        self.studentAgeRange = UserDefaults.standard.string(forKey: "TeacherAgeRange")
            ?? "8-9 year olds (Grade 2-3)"
        self.schoolName = UserDefaults.standard.string(forKey: "TeacherSchoolName")
            ?? ""
        self.teacherName = UserDefaults.standard.string(forKey: "TeacherName")
            ?? ""
        
        print("🔧 Loaded preferences - Age: \(studentAgeRange), Message: \(systemMessage)")
    }
    
    // Generate system message from age range
    func updateSystemMessageFromAge() {
        systemMessage = "You are an age appropriate assistant for \(studentAgeRange.lowercased())"
    }
    
    // Reset to defaults
    func resetToDefaults() {
        systemMessage = "You are an age appropriate assistant for 8-9 year olds"
        studentAgeRange = "8-9 year olds (Grade 2-3)"
        schoolName = ""
        teacherName = ""
    }
}

// MARK: - Teacher Preferences View

import SwiftUI

// MARK: - Fixed Teacher Preferences View with Better Layout

struct TeacherPreferencesView: View {
    @ObservedObject var preferences = TeacherPreferences.shared
    @State private var selectedAgePreset = "8-9 year olds (Grade 2-3)"
    @State private var customAgeRange = ""
    @State private var selectedPromptPreset = "What would you like to learn about today?"
    @State private var customPrompt = ""
    @State private var showingResetAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            HStack {
                Text("Teacher Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Scrollable content with fixed width
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Class Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Class Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Teacher Name:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Enter your name (optional)", text: $preferences.teacherName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("School Name:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Enter school name (optional)", text: $preferences.schoolName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Age Range Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Student Age Range")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select age group:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Age Group", selection: $selectedAgePreset) {
                                ForEach(TeacherPreferences.agePresets, id: \.self) { preset in
                                    Text(preset).tag(preset)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: selectedAgePreset) { _, newValue in
                                if newValue != "Custom Age Range" {
                                    preferences.studentAgeRange = newValue
                                    preferences.updateSystemMessageFromAge()
                                }
                            }
                            
                            if selectedAgePreset == "Custom Age Range" {
                                TextField("Enter custom age range (e.g., 6-7 year olds)", text: $customAgeRange)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: customAgeRange) { _, newValue in
                                        if !newValue.isEmpty {
                                            preferences.studentAgeRange = newValue
                                            preferences.updateSystemMessageFromAge()
                                        }
                                    }
                            }
                            
                            Text("Current: **\(preferences.studentAgeRange)**")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Default Prompt Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Default Startup Question")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose what students see when they start:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Picker("Prompt Preset", selection: $selectedPromptPreset) {
                                ForEach(TeacherPreferences.promptPresets, id: \.self) { preset in
                                    Text(preset).tag(preset)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: selectedPromptPreset) { _, newValue in
                                if newValue != "Custom Question" {
                                    preferences.defaultPrompt = newValue
                                }
                            }
                            
                            if selectedPromptPreset == "Custom Question" {
                                TextField("Enter custom startup question", text: $customPrompt)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: customPrompt) { _, newValue in
                                        if !newValue.isEmpty {
                                            preferences.defaultPrompt = newValue
                                        }
                                    }
                            }
                            
                            Text("Current: **\"\(preferences.defaultPrompt)\"**")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // AI Instructions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Assistant Instructions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("System Message:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextEditor(text: $preferences.systemMessage)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(.separatorColor), lineWidth: 1)
                                )
                            
                            Text("This tells the AI how to behave when talking to your students.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Button("Auto-Generate from Age") {
                                preferences.updateSystemMessageFromAge()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Reset All Settings") {
                                showingResetAlert = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Preview Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("When students ask questions, the AI will receive:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("System: \"\(preferences.systemMessage)\"")
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("User: \"\(preferences.defaultPrompt)\"")
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
        .background(Color(.windowBackgroundColor))
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                preferences.resetToDefaults()
                selectedAgePreset = "8-9 year olds (Grade 2-3)"
                customAgeRange = ""
                selectedPromptPreset = "What would you like to learn about today?"
                customPrompt = ""
            }
        } message: {
            Text("This will reset all teacher preferences to default values.")
        }
        .onAppear {
            // Set initial picker selections based on current preferences
            if TeacherPreferences.agePresets.contains(preferences.studentAgeRange) {
                selectedAgePreset = preferences.studentAgeRange
            } else {
                selectedAgePreset = "Custom Age Range"
                customAgeRange = preferences.studentAgeRange
            }
            
            if TeacherPreferences.promptPresets.contains(preferences.defaultPrompt) {
                selectedPromptPreset = preferences.defaultPrompt
            } else {
                selectedPromptPreset = "Custom Question"
                customPrompt = preferences.defaultPrompt
            }
        }
    }
}

// MARK: - Enhanced Teacher Log View with Settings Access

struct EnhancedTeacherLogView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @ObservedObject var preferences = TeacherPreferences.shared
    @State private var logEntries: [TeacherLogger.LogEntry] = []
    @State private var isLoading = true
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced header with settings access
            HStack {
                VStack(alignment: .leading) {
                    Text("Student Conversations")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        if !preferences.teacherName.isEmpty {
                            Text("Teacher: \(preferences.teacherName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !preferences.schoolName.isEmpty {
                            Text("• \(preferences.schoolName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("• \(preferences.studentAgeRange)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                HStack {
                    Text("(\(logEntries.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Settings") {
                        showingSettings = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Refresh") {
                        loadLogs()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Close") {
                        authManager.logout()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            Divider()
            
            // Current system message display
            if !preferences.systemMessage.isEmpty {
                HStack {
                    Text("AI Instructions: ")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(preferences.systemMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Divider()
            }
            
            // Log content (same as before)
            if isLoading {
                Spacer()
                VStack {
                    ProgressView()
                    Text("Loading conversations...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
            } else if logEntries.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No conversations yet")
                        .font(.headline)
                    
                    Text("Student conversations will appear here.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button("Create Test Conversation") {
                        createTestEntries()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(logEntries.enumerated()), id: \.offset) { index, entry in
                            ConversationCard(entry: entry, index: index + 1)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $showingSettings) {
            TeacherPreferencesView()
        }
        .onAppear {
            loadLogs()
        }
    }
    
    // Same loadLogs and createTestEntries methods as before...
    private func loadLogs() {
        print("🔍 Loading logs...")
        isLoading = true
        
        Task {
            do {
                let entries = try TeacherLogger.shared.getAllLogEntries()
                print("🔍 Found \(entries.count) log entries")
                
                await MainActor.run {
                    self.logEntries = entries.sorted { $0.timestamp > $1.timestamp }
                    self.isLoading = false
                    print("🔍 Loaded \(self.logEntries.count) entries into UI")
                }
            } catch {
                print("❌ Error loading logs: \(error)")
                await MainActor.run {
                    self.logEntries = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createTestEntries() {
        print("🔍 Creating test entries...")
        
        TeacherLogger.shared.logInteraction(
            userPrompt: "What is 5 + 5?",
            modelResponse: "5 + 5 equals 10! This is a basic addition problem in math.",
            modelInfo: "Test Model",
            tokensPerSecond: 25.0,
            promptTokens: 5,
            responseTokens: 12,
            processingTime: 1.0
        )
        
        print("✅ Test entries created, reloading...")
        loadLogs()
    }
}
//
//  TeacherPreferences.swift
//  mlx-swift-examples
//
//  Created by Jonathan Kimmitt on 07/08/2025.
//


import SwiftUI
import Foundation
// import Colours

extension Color {
    static var mysystemBackground: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var mysecondarySystemBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var mysystemGray6: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #elseif os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #endif
    }

    static var myseparator: Color {
        #if os(iOS)
        return Color(.separator)
        #elseif os(macOS)
        return Color(nsColor: .separatorColor)
        #endif
    }
}
// MARK: - Teacher Preferences Manager

// Add these missing pieces to your TeacherPreferences class:

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
    
    // ADD THIS MISSING PROPERTY:
    @Published var defaultPrompt: String {
        didSet {
            UserDefaults.standard.set(defaultPrompt, forKey: "TeacherDefaultPrompt")
            print("🔧 Default prompt updated: \(defaultPrompt)")
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
    
    // ADD THIS MISSING ARRAY:
    static let promptPresets = [
        "What would you like to learn about today?",
        "Ask me any question about math!",
        "What science topic interests you?",
        "Tell me about something you're curious about",
        "What homework can I help you with?",
        "Ask me about history, science, or any subject!",
        "What's your favorite topic to explore?",
        "Custom Question"
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
        // ADD THIS MISSING INITIALIZATION:
        self.defaultPrompt = UserDefaults.standard.string(forKey: "TeacherDefaultPrompt")
            ?? "What would you like to learn about today?"
        
        print("🔧 Loaded preferences - Age: \(studentAgeRange), Message: \(systemMessage), Prompt: \(defaultPrompt)")
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
        // ADD THIS MISSING RESET:
        defaultPrompt = "What would you like to learn about today?"
    }
}

// MARK: - Teacher Preferences View

import SwiftUI

// MARK: - Broken into smaller components to fix compiler issue

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
            PreferencesHeader(dismiss: dismiss)
            Divider()
            PreferencesContent(
                preferences: preferences,
                selectedAgePreset: $selectedAgePreset,
                customAgeRange: $customAgeRange,
                selectedPromptPreset: $selectedPromptPreset,
                customPrompt: $customPrompt,
                showingResetAlert: $showingResetAlert
            )
        }
        .frame(width: 600, height: 700)
        .background(Color.mysystemBackground)
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all teacher preferences to default values.")
        }
        .onAppear {
            setupInitialSelections()
        }
    }
    
    private func resetAllSettings() {
        preferences.resetToDefaults()
        selectedAgePreset = "8-9 year olds (Grade 2-3)"
        customAgeRange = ""
        selectedPromptPreset = "What would you like to learn about today?"
        customPrompt = ""
    }
    // Replace the setupInitialSelections method in your TeacherPreferencesView:

    private func setupInitialSelections() {
	if TeacherPreferences.agePresets.contains(preferences.studentAgeRange) {
	    selectedAgePreset = preferences.studentAgeRange
	} else {
	    selectedAgePreset = "Custom Age Range"
	    customAgeRange = preferences.studentAgeRange
	}

	// FIX: Remove the binding $ and access the property directly
	if TeacherPreferences.promptPresets.contains(preferences.defaultPrompt) {
	    selectedPromptPreset = preferences.defaultPrompt
	} else {
	    selectedPromptPreset = "Custom Question"
	    customPrompt = preferences.defaultPrompt
	}
    }
}

// MARK: - Header Component

struct PreferencesHeader: View {
    let dismiss: DismissAction
    
    var body: some View {
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
        .background(Color.mysecondarySystemBackground)
    }
}

// MARK: - Main Content Component

struct PreferencesContent: View {
    @ObservedObject var preferences: TeacherPreferences
    @Binding var selectedAgePreset: String
    @Binding var customAgeRange: String
    @Binding var selectedPromptPreset: String
    @Binding var customPrompt: String
    @Binding var showingResetAlert: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ClassInfoSection(preferences: preferences)
                AgeRangeSection(
                    preferences: preferences,
                    selectedAgePreset: $selectedAgePreset,
                    customAgeRange: $customAgeRange
                )
                DefaultPromptSection(
                    preferences: preferences,
                    selectedPromptPreset: $selectedPromptPreset,
                    customPrompt: $customPrompt
                )
                SystemMessageSection(preferences: preferences)
                QuickActionsSection(
                    preferences: preferences,
                    showingResetAlert: $showingResetAlert
                )
                PreviewSection(preferences: preferences)
            }
            .padding()
        }
    }
}

// MARK: - Individual Section Components

struct ClassInfoSection: View {
    @ObservedObject var preferences: TeacherPreferences
    
    var body: some View {
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
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("School Name:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Enter school name (optional)", text: $preferences.schoolName)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(Color.mysecondarySystemBackground)
        .cornerRadius(8)
    }
}

struct AgeRangeSection: View {
    @ObservedObject var preferences: TeacherPreferences
    @Binding var selectedAgePreset: String
    @Binding var customAgeRange: String
    
    var body: some View {
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
                .onChange(of: selectedAgePreset) { _, newValue in
                    if newValue != "Custom Age Range" {
                        preferences.studentAgeRange = newValue
                        preferences.updateSystemMessageFromAge()
                    }
                }
                
                if selectedAgePreset == "Custom Age Range" {
                    TextField("Enter custom age range", text: $customAgeRange)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: customAgeRange) { _, newValue in
                            if !newValue.isEmpty {
                                preferences.studentAgeRange = newValue
                                preferences.updateSystemMessageFromAge()
                            }
                        }
                }
                
                Text("Current: \(preferences.studentAgeRange)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.mysecondarySystemBackground)
        .cornerRadius(8)
    }
}

struct DefaultPromptSection: View {
    @ObservedObject var preferences: TeacherPreferences
    @Binding var selectedPromptPreset: String
    @Binding var customPrompt: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Default Startup Question")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose what students see:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Prompt Preset", selection: $selectedPromptPreset) {
                    ForEach(TeacherPreferences.promptPresets, id: \.self) { preset in
                        Text(preset).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPromptPreset) { _, newValue in
                    if newValue != "Custom Question" {
                        preferences.defaultPrompt = newValue
                    }
                }
                
                if selectedPromptPreset == "Custom Question" {
                    TextField("Enter custom question", text: $customPrompt)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: customPrompt) { _, newValue in
                            if !newValue.isEmpty {
                                preferences.defaultPrompt = newValue
                            }
                        }
                }
                
                Text("Current: \"\(preferences.defaultPrompt)\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.mysecondarySystemBackground)
        .cornerRadius(8)
    }
}

struct SystemMessageSection: View {
    @ObservedObject var preferences: TeacherPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Assistant Instructions")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("System Message:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextEditor(text: $preferences.systemMessage)
                    .frame(height: 100)
                    .padding(4)
                    .background(Color.mysystemGray6)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.myseparator, lineWidth: 1)
                    )
                
                Text("This tells the AI how to behave with students.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.mysecondarySystemBackground)
        .cornerRadius(8)
    }
}

struct QuickActionsSection: View {
    @ObservedObject var preferences: TeacherPreferences
    @Binding var showingResetAlert: Bool
    
    var body: some View {
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
        .background(Color.mysecondarySystemBackground)
        .cornerRadius(8)
    }
}

struct PreviewSection: View {
    @ObservedObject var preferences: TeacherPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Students will see:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("System: \"\(preferences.systemMessage)\"")
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                
                Text("User: \"\(preferences.defaultPrompt)\"")
                    .font(.caption)
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.mysecondarySystemBackground)
        .cornerRadius(8)
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

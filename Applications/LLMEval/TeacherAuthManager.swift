//
//  TeacherAuthManager.swift
//  mlx-swift-examples
//
//  Created by Jonathan Kimmitt on 06/08/2025.
//


import SwiftUI
import CryptoKit

// MARK: - Teacher Authentication Manager

class TeacherAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var showingPasswordPrompt = false
    
    // Store hashed password (in production, this should be in Keychain or secure storage)
    // Default password: "teacher123" - change this!
    private let storedPasswordHash = "ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f"
    
    private var authenticationTimer: Timer?
    
    // Auto-logout after 15 minutes of inactivity
    private let sessionTimeout: TimeInterval = 15 * 60
    
    func requestAccess() {
        showingPasswordPrompt = true
    }
    
    func authenticate(password: String) -> Bool {
        let hashedInput = hashPassword(password)
        
        if hashedInput == storedPasswordHash {
            isAuthenticated = true
            startSessionTimer()
            showingPasswordPrompt = false
            return true
        } else {
            return false
        }
    }
    
    func logout() {
        isAuthenticated = false
        authenticationTimer?.invalidate()
        authenticationTimer = nil
    }
    
    private func startSessionTimer() {
        authenticationTimer?.invalidate()
        authenticationTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeout, repeats: false) { _ in
            DispatchQueue.main.async {
                self.logout()
            }
        }
    }
    
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Call this to generate a new password hash (for setup)
    static func generatePasswordHash(for password: String) -> String {
        let data = Data(password.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Password Entry View

struct TeacherPasswordView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var password = ""
    @State private var showingError = false
    @State private var attempts = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Teacher Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Enter the teacher password to view student interaction logs")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(attemptAuthentication)
                    .padding(.horizontal)
                
                if showingError {
                    Text("Incorrect password. \(3 - attempts) attempts remaining.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button("Access Logs") {
                    attemptAuthentication()
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty || attempts >= 3)
                
                if attempts >= 3 {
                    Text("Too many failed attempts. Please restart the app.")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top)
                }
            }
            .navigationTitle("Teacher Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func attemptAuthentication() {
        if authManager.authenticate(password: password) {
            dismiss()
        } else {
            attempts += 1
            showingError = true
            password = ""
            
            // Add haptic feedback for failed attempt
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
            
            // Auto-hide error after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showingError = false
            }
        }
    }
}

// MARK: - Enhanced Teacher Log View

struct AuthenticatedTeacherLogView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var logEntries: [TeacherLogger.LogEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedUser: String = "All Users"
    @State private var showingExportSheet = false
    
    private var availableUsers: [String] {
        let users = Set(logEntries.map { $0.userId })
        return ["All Users"] + Array(users).sorted()
    }
    
    private var filteredEntries: [TeacherLogger.LogEntry] {
        var filtered = logEntries
        
        // Filter by user
        if selectedUser != "All Users" {
            filtered = filtered.filter { $0.userId == selectedUser }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.userPrompt.localizedCaseInsensitiveContains(searchText) ||
                entry.modelResponse.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filters and search
                VStack {
                    HStack {
                        Picker("User", selection: $selectedUser) {
                            ForEach(availableUsers, id: \.self) { user in
                                Text(user).tag(user)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Button("Export") {
                            showingExportSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    TextField("Search conversations...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                // Log entries list
                Group {
                    if isLoading {
                        ProgressView("Loading logs...")
                    } else if let error = errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    } else if filteredEntries.isEmpty {
                        Text(searchText.isEmpty ? "No log entries found" : "No entries match your search")
                            .foregroundColor(.secondary)
                    } else {
                        List(filteredEntries, id: \.timestamp) { entry in
                            TeacherLogEntryView(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("Student Interactions (\(filteredEntries.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Refresh", action: loadLogs)
                    
                    Button("Logout") {
                        authManager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportLogView(entries: filteredEntries)
            }
        }
        .onAppear(perform: loadLogs)
    }
    
    private func loadLogs() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let entries = try TeacherLogger.shared.getAllLogEntries()
                await MainActor.run {
                    self.logEntries = entries
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Individual Log Entry View

struct TeacherLogEntryView: View {
    let entry: TeacherLogger.LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with timestamp and stats
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("User: \(entry.userId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(entry.generationStats.tokensPerSecond, specifier: "%.1f") tok/s")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("\(entry.generationStats.responseTokens) tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // User prompt
            VStack(alignment: .leading, spacing: 4) {
                Text("Student Question:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(entry.userPrompt)
                    .font(.body)
                    .padding(.leading, 8)
            }
            
            // Model response (collapsible)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("AI Response:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(isExpanded ? "Show Less" : "Show More") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                
                Text(entry.modelResponse)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 3)
                    .padding(.leading, 8)
            }
            
            // Session info
            Text("Session: \(entry.sessionId.prefix(8))...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Export View

struct ExportLogView: View {
    let entries: [TeacherLogger.LogEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat = "CSV"
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Format", selection: $exportFormat) {
                    Text("CSV").tag("CSV")
                    Text("JSON").tag("JSON")
                    Text("Text").tag("Text")
                }
                .pickerStyle(.segmented)
                .padding()
                
                Text("\(entries.count) entries will be exported")
                    .foregroundColor(.secondary)
                
                Button("Export to File") {
                    exportLogs()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Export Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportLogs() {
        // Implementation depends on your export requirements
        // This is a simplified version that copies to clipboard
        
        var exportContent = ""
        
        switch exportFormat {
        case "CSV":
            exportContent = generateCSV()
        case "JSON":
            exportContent = generateJSON()
        case "Text":
            exportContent = generateText()
        default:
            exportContent = generateText()
        }
        
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportContent, forType: .string)
        #else
        UIPasteboard.general.string = exportContent
        #endif
        
        dismiss()
    }
    
    private func generateCSV() -> String {
        var csv = "Timestamp,User,Prompt,Response,Tokens/Sec,Processing Time\n"
        for entry in entries {
            let timestamp = entry.timestamp.formatted(.iso8601)
            let user = entry.userId.replacingOccurrences(of: ",", with: ";")
            let prompt = entry.userPrompt.replacingOccurrences(of: ",", with: ";")
            let response = entry.modelResponse.replacingOccurrences(of: ",", with: ";")
            let tokensPerSec = String(format: "%.1f", entry.generationStats.tokensPerSecond)
            let processingTime = String(format: "%.2f", entry.generationStats.processingTime)
            
            csv += "\(timestamp),\(user),\"\(prompt)\",\"\(response)\",\(tokensPerSec),\(processingTime)\n"
        }
        return csv
    }
    
    private func generateJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        if let data = try? encoder.encode(entries),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "Export failed"
    }
    
    private func generateText() -> String {
        var text = "Teacher Log Export\n"
        text += "Generated: \(Date().formatted())\n"
        text += "Total Entries: \(entries.count)\n\n"
        
        for entry in entries {
            text += "=== \(entry.timestamp.formatted()) ===\n"
            text += "User: \(entry.userId)\n"
            text += "Session: \(entry.sessionId)\n\n"
            text += "QUESTION: \(entry.userPrompt)\n\n"
            text += "RESPONSE: \(entry.modelResponse)\n\n"
            text += "Stats: \(entry.generationStats.tokensPerSecond, specifier: "%.1f") tokens/sec, "
            text += "\(entry.generationStats.processingTime, specifier: "%.2f")s processing\n\n"
            text += "---\n\n"
        }
        
        return text
    }
}
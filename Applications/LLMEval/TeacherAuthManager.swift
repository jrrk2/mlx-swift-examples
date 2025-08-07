import SwiftUI

// MARK: - Simplified, Crash-Free Log Viewer

struct SimpleTeacherLogView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var logEntries: [TeacherLogger.LogEntry] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            // Simple header
            HStack {
                Text("Student Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("(\(logEntries.count) entries)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Close") {
                    authManager.logout()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Content
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading conversations...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
                
            } else if logEntries.isEmpty {
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
                .frame(maxHeight: .infinity)
                
            } else {
                // Simple list of conversations
                List {
                    ForEach(Array(logEntries.enumerated()), id: \.offset) { index, entry in
                        ConversationRow(entry: entry, index: index + 1)
                    }
                }
            }
        }
        .onAppear {
            loadLogs()
        }
    }
    
    private func loadLogs() {
        Task {
            do {
                let entries = try TeacherLogger.shared.getAllLogEntries()
                await MainActor.run {
                    self.logEntries = entries.sorted { $0.timestamp > $1.timestamp }
                    self.isLoading = false
                }
            } catch {
                print("Error loading logs: \(error)")
                await MainActor.run {
                    self.logEntries = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createTestEntries() {
        print("Creating test entries...")
        
        TeacherLogger.shared.logInteraction(
            userPrompt: "What is 5 + 5?",
            modelResponse: "5 + 5 equals 10! This is a basic addition problem in math.",
            modelInfo: "Test Model",
            tokensPerSecond: 25.0,
            promptTokens: 5,
            responseTokens: 12,
            processingTime: 1.0
        )
        
        TeacherLogger.shared.logInteraction(
            userPrompt: "Tell me about cats",
            modelResponse: "Cats are wonderful pets! They are independent, playful, and love to purr when they're happy. They have excellent night vision and are great hunters.",
            modelInfo: "Test Model",
            tokensPerSecond: 30.0,
            promptTokens: 4,
            responseTokens: 22,
            processingTime: 1.5
        )
        
        // Reload logs
        loadLogs()
    }
}

// MARK: - Simple Conversation Row

struct ConversationRow: View {
    let entry: TeacherLogger.LogEntry
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Conversation #\(index)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Student info
            HStack {
                Text("Student: \(entry.userId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(entry.generationStats.tokensPerSecond)) tokens/sec")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            // Question
            Text("Q: \(entry.userPrompt)")
                .font(.body)
                .foregroundColor(.green)
                .padding(.vertical, 2)
            
            // Answer
            Text("A: \(entry.modelResponse)")
                .font(.body)
                .foregroundColor(.blue)
                .padding(.bottom, 4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ultra Simple Password View (to avoid crashes)

struct TeacherPasswordView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var password = ""
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Text("🔑 Teacher Access")
                .font(.title)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                Text("Password:")
                    .font(.headline)
                
                SecureField("Enter password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                
                if showError {
                    Text("Wrong password")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Text("(Hint: teacher123)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Login") {
                    if authManager.authenticate(password: password) {
                        dismiss()
                    } else {
                        showError = true
                        password = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: 400, maxHeight: 300)
    }
}

// MARK: - Simplified Auth Manager (to prevent crashes)

class TeacherAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var showingPasswordPrompt = false
    
    func requestAccess() {
        showingPasswordPrompt = true
    }
    
    func authenticate(password: String) -> Bool {
        print("🔍 DEBUG: Trying password: '\(password)'")
        
        if password == "teacher123" {
            isAuthenticated = true
            showingPasswordPrompt = false
            print("✅ Authentication successful!")
            return true
        } else {
            print("❌ Wrong password")
            return false
        }
    }
    
    func logout() {
        isAuthenticated = false
    }
}

import SwiftUI

// MARK: - Fixed Log Viewer with Proper List Display

struct SimpleTeacherLogView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var logEntries: [TeacherLogger.LogEntry] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Student Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("(\(logEntries.count) entries)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Refresh") {
                    loadLogs()
                }
                .buttonStyle(.bordered)
                
                Button("Close") {
                    authManager.logout()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Main content area
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
                // Conversations list - FIXED
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
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            print("🔍 SimpleTeacherLogView appeared")
            loadLogs()
        }
    }
    
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
        
        TeacherLogger.shared.logInteraction(
            userPrompt: "Tell me about cats",
            modelResponse: "Cats are wonderful pets! They are independent, playful, and love to purr when they're happy. They have excellent night vision and are great hunters.",
            modelInfo: "Test Model",
            tokensPerSecond: 30.0,
            promptTokens: 4,
            responseTokens: 22,
            processingTime: 1.5
        )
        
        print("✅ Test entries created, reloading...")
        loadLogs()
    }
}

// MARK: - Conversation Card (Better Layout)

struct ConversationCard: View {
    let entry: TeacherLogger.LogEntry
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with conversation number and time
            HStack {
                Text("Conversation #\(index)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(entry.generationStats.tokensPerSecond)) tok/s")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Student info
            Text("Student: \(entry.userId)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
            
            // Question section
            VStack(alignment: .leading, spacing: 4) {
                Text("Question:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(entry.userPrompt)
                    .font(.body)
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Answer section
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Response:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(entry.modelResponse)
                    .font(.body)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
            }
            
            // Stats footer
            HStack {
                Text("Processing: \(String(format: "%.1f", entry.generationStats.processingTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Tokens: \(entry.generationStats.promptTokens) → \(entry.generationStats.responseTokens)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Keep the Simple Password View

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

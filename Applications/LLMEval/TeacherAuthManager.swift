import SwiftUI

// MARK: - Fixed Log Viewer with Proper List Display

struct SimpleTeacherLogView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var logEntries: [TeacherLogger.LogEntry] = []
    @State private var isLoading = true
    @State private var showingSettings = false  // ← Add this
    
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
                
                Button("Settings") {         // ← Add Settings button
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
        .sheet(isPresented: $showingSettings) {     // ← Add Settings sheet
            TeacherPreferencesView()
        }
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
// Enhanced Conversation Card that handles cancelled conversations better

struct ConversationCard: View {
    let entry: TeacherLogger.LogEntry
    let index: Int
    
    // Detect if this is a cancelled conversation
    private var isCancelled: Bool {
        entry.modelResponse.contains("[GENERATION CANCELLED") || 
        entry.modelResponse.contains("[CANCELLED]") ||
        entry.modelResponse.contains("[PARTIAL]")
    }
    
    private var isPartialResponse: Bool {
        entry.modelResponse.contains("[PARTIAL]") || 
        (entry.modelResponse.contains("[GENERATION CANCELLED") && !entry.modelResponse.contains("No response generated"))
    }
    
    private var cleanedResponse: String {
        // Remove the cancellation markers for display
        var cleaned = entry.modelResponse
        cleaned = cleaned.replacingOccurrences(of: "\n\n[GENERATION CANCELLED - Response incomplete]", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\n\n[GENERATION CANCELLED - No response generated]", with: "")
        cleaned = cleaned.replacingOccurrences(of: "[GENERATION CANCELLED - No response generated]", with: "No response was generated before cancellation.")
        return cleaned
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with conversation number, time, and status
            HStack {
                HStack(spacing: 8) {
                    Text("Conversation #\(index)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Status indicator for cancelled conversations
                    if isCancelled {
                        HStack(spacing: 4) {
                            Image(systemName: isPartialResponse ? "pause.circle.fill" : "stop.circle.fill")
                                .foregroundColor(isPartialResponse ? .orange : .red)
                            Text(isPartialResponse ? "PARTIAL" : "CANCELLED")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(isPartialResponse ? .orange : .red)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((isPartialResponse ? Color.orange : Color.red).opacity(0.1))
                        .cornerRadius(4)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("COMPLETE")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if entry.generationStats.tokensPerSecond > 0 {
                        Text("\(Int(entry.generationStats.tokensPerSecond)) tok/s")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
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
            
            // Answer section with different styling for cancelled/partial
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("AI Response:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    if isCancelled {
                        Text(isPartialResponse ? "(Interrupted)" : "(Not Generated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                if cleanedResponse.isEmpty || cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // No response case
                    Text("No response was generated before the conversation was cancelled.")
                        .font(.body)
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    // Response available (complete or partial)
                    Text(cleanedResponse)
                        .font(.body)
                        .padding(8)
                        .background(isCancelled ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            // Stats footer with enhanced info for cancelled conversations
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Processing: \(String(format: "%.1f", entry.generationStats.processingTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isCancelled && !isPartialResponse {
                        Text("Cancelled before response generation")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if isCancelled && isPartialResponse {
                        Text("Response interrupted mid-generation")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
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
                .stroke(isCancelled ? (isPartialResponse ? Color.orange : Color.red) : Color(.separatorColor), lineWidth: isCancelled ? 2 : 1)
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

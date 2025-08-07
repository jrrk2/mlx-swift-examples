import SwiftUI

// MARK: - Simple Teacher Log Viewer
// DEBUGGING VERSION - Let's see what's happening

struct SimpleTeacherLogView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var logEntries: [TeacherLogger.LogEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var debugInfo = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with count and refresh
                HStack {
                    Text("Student Conversations (\(logEntries.count))")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Refresh") {
                        loadLogs()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Add Test Log") {
                        addTestLog()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                }
                .padding(.horizontal)
                
                // Debug info section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Info:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(debugInfo.isEmpty ? "No debug info yet" : debugInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Content area
                if isLoading {
                    VStack {
                        ProgressView("Loading logs...")
                        Text("Please wait...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Text("Error Loading Logs")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.red)
                        Button("Try Again") {
                            loadLogs()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if logEntries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No Conversations Yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Student conversations will appear here once they start using the AI assistant.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Add Test Conversation") {
                            addTestLog()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    // Show logs in scrollable list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(logEntries.sorted { $0.timestamp > $1.timestamp }, id: \.timestamp) { entry in
                                LogEntryCard(entry: entry)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Teacher Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") {
                        authManager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            debugInfo = "View appeared, starting to load logs..."
            loadLogs()
        }
    }
    
    private func loadLogs() {
        isLoading = true
        errorMessage = nil
        debugInfo = "Loading logs from TeacherLogger..."
        
        Task {
            do {
                debugInfo = "Attempting to read log file..."
                let entries = try TeacherLogger.shared.getAllLogEntries()
                
                await MainActor.run {
                    self.logEntries = entries
                    self.isLoading = false
                    self.debugInfo = "Found \(entries.count) log entries. Log file location: \(TeacherLogger.shared.getLogFileURL().path)"
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.debugInfo = "Error reading logs: \(error.localizedDescription). Log file: \(TeacherLogger.shared.getLogFileURL().path)"
                }
            }
        }
    }
    
    private func addTestLog() {
        debugInfo = "Adding test log entry..."
        
        TeacherLogger.shared.logInteraction(
            userPrompt: "What is 2 + 2?",
            modelResponse: "2 + 2 equals 4. This is basic addition in mathematics!",
            modelInfo: "Test Model",
            tokensPerSecond: 25.5,
            promptTokens: 5,
            responseTokens: 12,
            processingTime: 1.2
        )
        
        // Add a second test entry
        TeacherLogger.shared.logInteraction(
            userPrompt: "Tell me about dinosaurs",
            modelResponse: "Dinosaurs were amazing creatures that lived millions of years ago! They came in many shapes and sizes. Some were huge like the T-Rex, and others were small like chickens.",
            modelInfo: "Test Model",
            tokensPerSecond: 30.1,
            promptTokens: 4,
            responseTokens: 25,
            processingTime: 2.1
        )
        
        debugInfo = "Added 2 test log entries. Refreshing..."
        
        // Refresh the logs
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadLogs()
        }
    }
}

// Enhanced log card with better layout
struct LogEntryCard: View {
    let entry: TeacherLogger.LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with timestamp and user
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Student: \(entry.userId)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(entry.generationStats.tokensPerSecond)) tok/s")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("\(String(format: "%.1f", entry.generationStats.processingTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Student question
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.green)
                    Text("Question:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Text(entry.userPrompt)
                    .font(.body)
                    .padding(10)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
            }
            
            // AI response
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                    Text("AI Answer:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Text(entry.modelResponse)
                    .font(.body)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            
            // Footer with session info
            HStack {
                Text("Session: \(entry.sessionId.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(entry.generationStats.promptTokens) + \(entry.generationStats.responseTokens) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
//        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
//                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// Also update your ContentView to make sure logging is working
// Add this to your LLMEvaluatorWithLogging class to test logging:

extension LLMEvaluatorWithLogging {
    func testLogging() {
        print("🔍 Testing logging system...")
        
        TeacherLogger.shared.logInteraction(
            userPrompt: "Test question from ContentView",
            modelResponse: "Test response to verify logging works",
            modelInfo: "Bundled Phi-3.5-mini (offline)",
            tokensPerSecond: 42.0,
            promptTokens: 6,
            responseTokens: 8,
            processingTime: 1.5
        )
        
        print("✅ Test log entry created!")
    }
}


// MARK: - Simplified Authentication Manager

class TeacherAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var showingPasswordPrompt = false
    
    private var authenticationTimer: Timer?
    private let sessionTimeout: TimeInterval = 15 * 60
    
    func requestAccess() {
        showingPasswordPrompt = true
    }
    
    func authenticate(password: String) -> Bool {
        print("🔍 DEBUG: Trying password: '\(password)'")
        
        // Simple password check - you can change this password here
        let correctPassword = "teacher123"
        
        if password == correctPassword {
            isAuthenticated = true
            startSessionTimer()
            showingPasswordPrompt = false
            print("✅ Authentication successful!")
            return true
        } else {
            print("❌ Wrong password. Correct password is: '\(correctPassword)'")
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
}

// MARK: - Simple Password Entry

struct TeacherPasswordView: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var password = ""
    @State private var showingError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Teacher Access")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter password to view student conversations")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .onSubmit(attemptLogin)
            
            if showingError {
                Text("Incorrect password")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Login") {
                    attemptLogin()
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
            
            // Debug hint
            Text("Hint: password is 'teacher123'")
                .font(.caption)
                .foregroundColor(.gray)
                .opacity(0.7)
        }
        .padding(40)
        .frame(maxWidth: 400)
    }
    
    private func attemptLogin() {
        if authManager.authenticate(password: password) {
            dismiss()
        } else {
            showingError = true
            password = ""
            
            // Hide error after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showingError = false
            }
        }
    }
}

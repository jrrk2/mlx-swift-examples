import SwiftUI
// Add these imports at the top of TeacherAuthManager.swift
import MessageUI
import SwiftUI

// MARK: - Email Export Manager
class EmailExportManager: NSObject, ObservableObject, MFMailComposeViewControllerDelegate {
    @Published var showingMailComposer = false
    @Published var showingEmailUnavailableAlert = false
    
    func exportLogsViaEmail(entries: [TeacherLogger.LogEntry]) {
        guard MFMailComposeViewController.canSendMail() else {
            showingEmailUnavailableAlert = true
            return
        }
        
        showingMailComposer = true
    }
    
    func createMailComposer(entries: [TeacherLogger.LogEntry]) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        
        // Email setup
        let preferences = TeacherPreferences.shared
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        var subject = "Student AI Conversations - \(dateFormatter.string(from: Date()))"
        if !preferences.schoolName.isEmpty {
            subject += " - \(preferences.schoolName)"
        }
        composer.setSubject(subject)
        
        // Create detailed HTML report
        let htmlBody = createHTMLReport(entries: entries, preferences: preferences)
        composer.setMessageBody(htmlBody, isHTML: true)
        
        // Also attach as CSV for data analysis
        if let csvData = createCSVReport(entries: entries) {
            composer.addAttachmentData(csvData, mimeType: "text/csv", fileName: "student_conversations.csv")
        }
        
        // Pre-fill recipient if teacher email available
        // You could add teacher email to preferences if needed
        
        return composer
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
        
        switch result {
        case .sent:
            print("✅ Email sent successfully")
        case .saved:
            print("📝 Email saved as draft")
        case .cancelled:
            print("❌ Email cancelled")
        case .failed:
            print("❌ Email failed: \(error?.localizedDescription ?? "Unknown error")")
        @unknown default:
            print("❓ Unknown email result")
        }
    }
    
    // MARK: - Report Generation
    private func createHTMLReport(entries: [TeacherLogger.LogEntry], preferences: TeacherPreferences) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateStyle = .short
        shortDateFormatter.timeStyle = .short
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Student AI Conversation Report</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 20px; line-height: 1.6; }
                .header { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
                .summary { background: #e3f2fd; padding: 15px; border-radius: 6px; margin-bottom: 20px; }
                .conversation { background: #fff; border: 1px solid #ddd; border-radius: 8px; margin-bottom: 15px; overflow: hidden; }
                .conv-header { background: #f5f5f5; padding: 12px; border-bottom: 1px solid #ddd; font-weight: bold; }
                .user-prompt { background: #e8f5e8; padding: 12px; border-left: 4px solid #4caf50; }
                .ai-response { background: #f0f8ff; padding: 12px; border-left: 4px solid #2196f3; }
                .cancelled { background: #fff3e0; border-left: 4px solid #ff9800; }
                .partial { background: #ffebee; border-left: 4px solid #f44336; }
                .stats { font-size: 0.9em; color: #666; padding: 8px 12px; background: #fafafa; }
                .status-complete { color: #4caf50; font-weight: bold; }
                .status-cancelled { color: #ff9800; font-weight: bold; }
                .status-partial { color: #f44336; font-weight: bold; }
                table { width: 100%; border-collapse: collapse; margin-top: 10px; }
                th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
                th { background-color: #f5f5f5; font-weight: bold; }
            </style>
        </head>
        <body>
        """
        
        // Header section
        html += """
        <div class="header">
            <h1>🎓 Student AI Conversation Report</h1>
            <p><strong>Generated:</strong> \(dateFormatter.string(from: Date()))</p>
        """
        
        if !preferences.teacherName.isEmpty {
            html += "<p><strong>Teacher:</strong> \(preferences.teacherName)</p>"
        }
        if !preferences.schoolName.isEmpty {
            html += "<p><strong>School:</strong> \(preferences.schoolName)</p>"
        }
        html += "<p><strong>Student Age Group:</strong> \(preferences.studentAgeRange)</p>"
        html += "<p><strong>AI Instructions:</strong> \(preferences.systemMessage)</p>"
        html += "</div>"
        
        // Summary statistics
        let totalConversations = entries.count
        let completedConversations = entries.filter { !$0.modelResponse.contains("[GENERATION CANCELLED") }.count
        let cancelledConversations = totalConversations - completedConversations
        let avgTokensPerSecond = entries.compactMap { $0.generationStats.tokensPerSecond > 0 ? $0.generationStats.tokensPerSecond : nil }.reduce(0, +) / Double(max(completedConversations, 1))
        
        html += """
        <div class="summary">
            <h2>📊 Summary</h2>
            <table>
                <tr><th>Total Conversations</th><td>\(totalConversations)</td></tr>
                <tr><th>Completed</th><td class="status-complete">\(completedConversations)</td></tr>
                <tr><th>Cancelled</th><td class="status-cancelled">\(cancelledConversations)</td></tr>
                <tr><th>Average Speed</th><td>\(String(format: "%.1f", avgTokensPerSecond)) tokens/sec</td></tr>
            </table>
        </div>
        """
        
        // Individual conversations
        html += "<h2>💬 Individual Conversations</h2>"
        
        for (index, entry) in entries.enumerated() {
            let isCancelled = entry.modelResponse.contains("[GENERATION CANCELLED")
            let isPartial = entry.modelResponse.contains("[GENERATION CANCELLED") && !entry.modelResponse.contains("No response generated")
            
            var statusClass = "status-complete"
            var statusText = "✅ COMPLETE"
            
            if isCancelled {
                if isPartial {
                    statusClass = "status-partial"
                    statusText = "⚠️ PARTIAL"
                } else {
                    statusClass = "status-cancelled" 
                    statusText = "❌ CANCELLED"
                }
            }
            
            // Clean response for display
            var displayResponse = entry.modelResponse
            displayResponse = displayResponse.replacingOccurrences(of: "\n\n[GENERATION CANCELLED - Response incomplete]", with: "")
            displayResponse = displayResponse.replacingOccurrences(of: "\n\n[GENERATION CANCELLED - No response generated]", with: "")
            displayResponse = displayResponse.replacingOccurrences(of: "[GENERATION CANCELLED - No response generated]", with: "<em>No response was generated before cancellation.</em>")
            
            html += """
            <div class="conversation">
                <div class="conv-header">
                    Conversation #\(index + 1) - \(shortDateFormatter.string(from: entry.timestamp))
                    <span class="\(statusClass)" style="float: right;">\(statusText)</span>
                </div>
                <div class="user-prompt">
                    <strong>👤 Student:</strong><br>
                    \(entry.userPrompt.replacingOccurrences(of: "\n", with: "<br>"))
                </div>
                <div class="ai-response \(isCancelled ? (isPartial ? "partial" : "cancelled") : "")">
                    <strong>🤖 AI Assistant:</strong><br>
                    \(displayResponse.replacingOccurrences(of: "\n", with: "<br>"))
                </div>
                <div class="stats">
                    <strong>User:</strong> \(entry.userId) | 
                    <strong>Processing:</strong> \(String(format: "%.1f", entry.generationStats.processingTime))s | 
                    <strong>Speed:</strong> \(String(format: "%.1f", entry.generationStats.tokensPerSecond)) tok/s | 
                    <strong>Tokens:</strong> \(entry.generationStats.promptTokens) → \(entry.generationStats.responseTokens)
                </div>
            </div>
            """
        }
        
        html += """
        <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 0.9em; color: #666;">
            <p>This report was automatically generated by the AI Learning Assistant. All conversations are logged for educational assessment purposes.</p>
        </div>
        </body>
        </html>
        """
        
        return html
    }
    
    private func createCSVReport(entries: [TeacherLogger.LogEntry]) -> Data? {
        var csvString = "Timestamp,User,Question,Response,Status,Tokens_Per_Second,Prompt_Tokens,Response_Tokens,Processing_Time\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for entry in entries {
            let isCancelled = entry.modelResponse.contains("[GENERATION CANCELLED")
            let status = isCancelled ? "CANCELLED" : "COMPLETE"
            
            // Clean and escape CSV fields
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let user = entry.userId.replacingOccurrences(of: "\"", with: "\"\"")
            let question = entry.userPrompt.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ")
            let response = entry.modelResponse.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ")
            
            csvString += "\"\(timestamp)\",\"\(user)\",\"\(question)\",\"\(response)\",\"\(status)\",\(entry.generationStats.tokensPerSecond),\(entry.generationStats.promptTokens),\(entry.generationStats.responseTokens),\(entry.generationStats.processingTime)\n"
        }
        
        return csvString.data(using: .utf8)
    }
}

// MARK: - Mail Composer Wrapper for SwiftUI
struct MailComposerView: UIViewControllerRepresentable {
    let entries: [TeacherLogger.LogEntry]
    let emailManager: EmailExportManager
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        return emailManager.createMailComposer(entries: entries)
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

// MARK: - Updated SimpleTeacherLogView with Export Button
// Add this updated version to replace your existing SimpleTeacherLogView:

struct SimpleTeacherLogViewWithExport: View {
    @ObservedObject var authManager: TeacherAuthManager
    @State private var logEntries: [TeacherLogger.LogEntry] = []
    @State private var isLoading = true
    @State private var showingSettings = false
    @StateObject private var emailManager = EmailExportManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Export button
            HStack {
                Text("Student Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("(\(logEntries.count) entries)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Export button
                Button("📧 Export") {
                    emailManager.exportLogsViaEmail(entries: logEntries)
                }
                .buttonStyle(.bordered)
                .disabled(logEntries.isEmpty)
                
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
            .padding()
            
            Divider()
            
            // Main content area (same as before)
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
                // Conversations list
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
        .sheet(isPresented: $showingSettings) {
            TeacherPreferencesView()
        }
        .sheet(isPresented: $emailManager.showingMailComposer) {
            MailComposerView(entries: logEntries, emailManager: emailManager)
        }
        .alert("Email Not Available", isPresented: $emailManager.showingEmailUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("Please set up Mail on this device to export conversation logs via email.")
        }
        .onAppear {
            print("🔍 SimpleTeacherLogView appeared")
            loadLogs()
        }
    }
    
    // Same methods as before...
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
        .background(Color.mysecondarySystemBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCancelled ? (isPartialResponse ? Color.orange : Color.red) : Color.myseparator, lineWidth: isCancelled ? 2 : 1)
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
                
                Text("(Hint: ask teacher)")
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

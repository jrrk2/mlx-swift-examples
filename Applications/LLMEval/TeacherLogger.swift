import Foundation
import os.log

// MARK: - Teacher Logging System

/// A secure logging system that captures all user-model interactions
/// Only accessible to teachers/administrators
class TeacherLogger {
    static let shared = TeacherLogger()
    
    private let logger = Logger(subsystem: "com.yourapp.llmeval", category: "teacher")
    private let logFileURL: URL
    private let logQueue = DispatchQueue(label: "teacher.logging", qos: .utility)
    
    // MARK: - Log Entry Structure
    struct LogEntry: Codable {
        let timestamp: Date
        let sessionId: String
        let userId: String
        let userPrompt: String
        let modelResponse: String
        let modelInfo: String
        let generationStats: GenerationStats
        
        struct GenerationStats: Codable {
            let tokensPerSecond: Double
            let promptTokens: Int
            let responseTokens: Int
            let processingTime: TimeInterval
        }
    }
    
    private var currentSessionId: String
    private let userId: String
    
    private init() {
        // Generate unique session ID
        self.currentSessionId = UUID().uuidString
        
        // Use system username or fallback to UUID
        self.userId = NSUserName()
        
        // Create secure log file path in Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("LLMEval")
        let teacherDirectory = appDirectory.appendingPathComponent("TeacherLogs")
        
        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: teacherDirectory,
                                               withIntermediateDirectories: true)
        
        // Create log file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "teacher_log_\(dateFormatter.string(from: Date())).jsonl"
        self.logFileURL = teacherDirectory.appendingPathComponent(fileName)
        
        // Set restrictive file permissions (readable only by owner)
        self.setupSecurePermissions()
        
        logger.info("Teacher logging initialized for session: \(self.currentSessionId)")
    }
    
    private func setupSecurePermissions() {
        logQueue.async {
            do {
                // Ensure the file exists
                if !FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    FileManager.default.createFile(atPath: self.logFileURL.path, contents: nil)
                }
                
                // Set permissions: owner read/write only (600)
                try FileManager.default.setAttributes([
                    .posixPermissions: NSNumber(value: 0o600)
                ], ofItemAtPath: self.logFileURL.path)
                
                // Hide from normal file browsing
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = true
                try self.logFileURL.setResourceValues(resourceValues)
                
            } catch {
                self.logger.error("Failed to set secure permissions: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Public Logging Interface
    
    /// Log a complete user-model interaction
    func logInteraction(
        userPrompt: String,
        modelResponse: String,
        modelInfo: String,
        tokensPerSecond: Double = 0.0,
        promptTokens: Int = 0,
        responseTokens: Int = 0,
        processingTime: TimeInterval = 0.0
    ) {
        let stats = LogEntry.GenerationStats(
            tokensPerSecond: tokensPerSecond,
            promptTokens: promptTokens,
            responseTokens: responseTokens,
            processingTime: processingTime
        )
        
        let entry = LogEntry(
            timestamp: Date(),
            sessionId: currentSessionId,
            userId: userId,
            userPrompt: userPrompt,
            modelResponse: modelResponse,
            modelInfo: modelInfo,
            generationStats: stats
        )
        
        writeLogEntry(entry)
    }
    
    /// Start a new session (useful for multiple conversations)
    func startNewSession() {
        currentSessionId = UUID().uuidString
        logger.info("Started new logging session: \(currentSessionId)")
    }
    
    private func writeLogEntry(_ entry: LogEntry) {
        logQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(entry)
                
                // Write as JSONL (one JSON object per line)
                var jsonString = String(data: data, encoding: .utf8) ?? ""
                jsonString += "\n"
                
                // Append to log file
                if let logData = jsonString.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                        let fileHandle = try FileHandle(forWritingTo: self.logFileURL)
                        defer { fileHandle.closeFile() }
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(logData)
                    } else {
                        try logData.write(to: self.logFileURL)
                    }
                }
                
                self.logger.debug("Logged interaction for session: \(entry.sessionId)")
                
            } catch {
                self.logger.error("Failed to write log entry: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Teacher Access Methods
    
    /// Get the log file URL for teacher access
    /// Should only be called by teacher/admin interface
    func getLogFileURL() -> URL {
        return logFileURL
    }
    
    /// Read all log entries for teacher review
    /// Should only be called by teacher/admin interface
    func getAllLogEntries() throws -> [LogEntry] {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            return []
        }
        
        let content = try String(contentsOf: logFileURL)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return lines.compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(LogEntry.self, from: data)
        }
    }
    
    /// Get log entries for a specific session
    func getLogEntries(for sessionId: String) throws -> [LogEntry] {
        let allEntries = try getAllLogEntries()
        return allEntries.filter { $0.sessionId == sessionId }
    }
    
    /// Get log entries for a specific user
    func getLogEntries(for userId: String) throws -> [LogEntry] {
        let allEntries = try getAllLogEntries()
        return allEntries.filter { $0.userId == userId }
    }
}

// MARK: - Teacher Access View (Example)

#if DEBUG
import SwiftUI

struct TeacherLogView: View {
    @State private var logEntries: [TeacherLogger.LogEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading logs...")
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else if logEntries.isEmpty {
                    Text("No log entries found")
                        .foregroundColor(.secondary)
                } else {
                    List(logEntries, id: \.timestamp) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(entry.timestamp.formatted())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(entry.generationStats.tokensPerSecond, specifier: "%.1f") tokens/s")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            Text("User: \(entry.userPrompt)")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(entry.modelResponse)
                                .font(.body)
                                .padding(.top, 4)
                            
                            Text("Session: \(entry.sessionId.prefix(8))... | User: \(entry.userId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Teacher Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh", action: loadLogs)
                }
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
                    self.logEntries = entries.sorted { $0.timestamp > $1.timestamp }
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
#endif

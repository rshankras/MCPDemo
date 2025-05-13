//
//  Logger.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import Foundation
import os.log

/// Central logging utility
struct Logger {

    static var fileLoggingEnabled = true // Set to false to disable file logging
    static var daysToKeepLogs = 3 // How many days of log files to retain

    // Log categories
    enum Category: String {
        case general = "General"
        case network = "Network"
        case llm = "LLM"
        case settings = "Settings"
        case ui = "UI"
    }

    // Log levels
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"

        // Emoji prefix for visual distinction
        var prefix: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }

        // Whether this level should be included in the file log
        var logToFile: Bool {
            switch self {
            case .debug: return false
            case .info, .warning, .error: return true
            }
        }
    }

    // MARK: - File logging properties

    private static let fileManager = FileManager.default

    // Date formatter for filenames (YYYY-MM-DD)
    private static let logFileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Ensure consistency
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC for date calculation consistency
        return formatter
    }()

    // Date formatter for timestamps within the log file (ISO8601)
    private static let logEntryTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    private static var logDirectoryURL: URL? {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("Error: Could not find Application Support directory.")
            return nil
        }
        let dir = appSupportURL.appendingPathComponent("MCPDemo/Logs", isDirectory: true)

        // Create logs directory if needed
        if !fileManager.fileExists(atPath: dir.path) {
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                print("Log directory created at: \(dir.path)")
            } catch {
                print("Error: Failed to create log directory at \(dir.path): \(error)")
                return nil
            }
        }
        return dir
    }

    private static var currentLogFileURL: URL? {
        guard let logDir = logDirectoryURL else { return nil }
        let today = logFileDateFormatter.string(from: Date())
        return logDir.appendingPathComponent("mcpdemo_\(today).log")
    }

    // MARK: - OS Logger instances

    private static let generalLogger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcpdemo.app", category: Category.general.rawValue)
    private static let networkLogger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcpdemo.app", category: Category.network.rawValue)
    private static let llmLogger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcpdemo.app", category: Category.llm.rawValue)
    private static let settingsLogger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcpdemo.app", category: Category.settings.rawValue)
    private static let uiLogger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcpdemo.app", category: Category.ui.rawValue)

    // Get appropriate logger for category
    private static func getLogger(for category: Category) -> os.Logger {
        switch category {
        case .general: return generalLogger
        case .network: return networkLogger
        case .llm: return llmLogger
        case .settings: return settingsLogger
        case .ui: return uiLogger
        }
    }

    // MARK: - File Management

    /// Delete old log files, keeping logs from the last `daysToKeepLogs` days.
    static func cleanupOldLogs() {
        guard let logDir = logDirectoryURL else { return }
        guard daysToKeepLogs > 0 else {
            print("Log cleanup skipped: daysToKeepLogs is not positive.")
            return // No cleanup if keeping 0 or fewer days
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Calculate the cutoff date (N days ago)
        guard let cutoffDate = calendar.date(byAdding: .day, value: -(daysToKeepLogs), to: today) else {
            print("Error: Could not calculate log cleanup cutoff date.")
            return
        }
        // Format the cutoff date for comparison (YYYY-MM-DD)
        let cutoffDateString = logFileDateFormatter.string(from: cutoffDate)

        do {
            // Get URLs of all .log files in the directory
            let logFiles = try fileManager.contentsOfDirectory(at: logDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "log" && $0.lastPathComponent.starts(with: "mcpdemo_") }

            for fileURL in logFiles {
                let filename = fileURL.deletingPathExtension().lastPathComponent
                // Extract the date part (e.g., "mcpdemo_2024-01-15" -> "2024-01-15")
                guard let dateString = filename.components(separatedBy: "_").last else { continue }

                // If the log file's date string is older than the cutoff date string, delete it
                if dateString < cutoffDateString {
                    print("Cleaning up old log file: \(fileURL.lastPathComponent)")
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Error during log cleanup: \(error)")
        }
    }

    // MARK: - Public API

    /// Log a message at the specified level and category
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level
    ///   - category: The functional category
    ///   - file: Source file (automatic)
    ///   - function: Function name (automatic)
    ///   - line: Line number (automatic)
    static func log(
        _ message: String,
        level: Level = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        // Construct the core message part
        let coreMessage = "\(level.prefix) [\(level.rawValue)] [\(category.rawValue)] \(message) (\(fileName):\(line))"

        // Log to system log (os_log)
        let logger = getLogger(for: category)
        switch level {
        case .debug:
            logger.debug("\(coreMessage, privacy: .public)")
        case .info:
            logger.info("\(coreMessage, privacy: .public)")
        case .warning:
            logger.warning("\(coreMessage, privacy: .public)")
        case .error:
            logger.error("\(coreMessage, privacy: .public)")
        }

#if DEBUG
        // Also print to Xcode console for easier debugging during development
        print(coreMessage)
#endif

        // Write to file log if enabled and level requires it
        if fileLoggingEnabled && level.logToFile {
            writeToLogFile(coreMessage)
        }
    }

    // Write a message to the log file
    private static func writeToLogFile(_ message: String) {
        guard let fileURL = currentLogFileURL else {
            print("Error: Could not get current log file URL for writing.")
            return
        }

        let timestamp = logEntryTimestampFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"

        // Check if file exists before trying to open handle
        let fileExists = fileManager.fileExists(atPath: fileURL.path)

        // Append to the log file
        do {
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            defer { fileHandle.closeFile() } // Ensure handle is closed
            fileHandle.seekToEndOfFile()
            if let data = logEntry.data(using: .utf8) {
                fileHandle.write(data)
            } else {
                print("Error: Could not encode log entry to UTF-8.")
            }
        } catch {
            // If handle creation failed, it might be because the file doesn't exist yet
            if !fileExists {
                // Attempt to create the file and write the first entry
                do {
                    try logEntry.data(using: .utf8)?.write(to: fileURL, options: .atomic)
                    print("Created new log file: \(fileURL.path)")
                    // Clean up old logs after successfully creating a new daily log
                    cleanupOldLogs()
                } catch let createError {
                    print("Error: Failed to create and write initial log entry to \(fileURL.path): \(createError)")
                }
            } else {
                // File existed, but opening/writing failed for another reason
                print("Error: Failed to write to log file \(fileURL.path): \(error)")
            }
        }
    }

    // Convenience methods
    static func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    static func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    /// Get the path to the current log file (for support purposes)
    static func currentLogFilePath() -> String? {
        return currentLogFileURL?.path
    }

    /// Get the path to the log directory
    static func logDirectoryPath() -> String? {
        return logDirectoryURL?.path
    }
} 

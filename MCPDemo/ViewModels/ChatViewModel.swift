import Foundation
import SwiftUI
import MCP  // Import MCP

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputMessage: String = ""
    @Published var isProcessing = false
    @Published var error: String? = nil
    @Published var useMCP = false  // Toggle for using MCP
    
    private let settings = AppSettings()
    private let mcpIntegration = MCPIntegrationViewModel.shared
    
    
    init() {
         #if DEBUG
         print("ChatViewModel initialized")
         #endif
         
         // Set self as the chat view model for MCP integration
         mcpIntegration.setViewModel(self)
     }

    /// Resolves relative paths to absolute paths
    private func resolveExecutablePath(_ path: String) -> String {
        if path.hasPrefix("/") {
            // Already an absolute path
            return path
        }
        
        // Get the app's working directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        
        #if DEBUG
        print("Current directory: \(currentDirectory)")
        print("Resolving path: \(path)")
        #endif
        
        // Combine the current directory with the relative path
        let resolvedPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(path).path
        
        #if DEBUG
        print("Resolved path: \(resolvedPath)")
        #endif
        
        return resolvedPath
    }
    
    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Logger.info("User sending message: \"\(inputMessage.prefix(50))...\"")
        
        let userMessage = ChatMessage(content: inputMessage, isUser: true)
        messages.append(userMessage)
        let userPrompt = inputMessage
        inputMessage = ""
        
        Task {
            if useMCP && MCPClient.shared.isConnected {
                // Use MCP integration if enabled and connected
                Logger.info("Using MCP integration for message processing")
                isProcessing = true
                do {
                    try await mcpIntegration.processQuery(userPrompt)
                } catch {
                    Logger.error("MCP integration error: \(error.localizedDescription)")
                    self.error = "MCP Error: \(error.localizedDescription)"
                    let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", isUser: false, isSystem: true)
                    messages.append(errorMessage)
                }
                isProcessing = false
            } else {
                await sendToLLM(prompt: userPrompt)
            }
        }
    }
    
    private func sendWithMCP(prompt: String) async {
        isProcessing = true
        error = nil
        
        #if DEBUG
        print("Processing message with MCP integration")
        #endif
        
        do {
            // Use MCP integration
            try await mcpIntegration.processQuery(prompt)
            
            // For simplicity, we're not displaying intermediate results yet
            // In a full implementation, you'd want to show the tool results in the chat
            
        } catch {
            self.error = "MCP Error: \(error.localizedDescription)"
            #if DEBUG
            print("MCP error: \(error.localizedDescription)")
            #endif
        }
        
        isProcessing = false
    }
    
    private func sendToLLM(prompt: String) async {
        isProcessing = true
        error = nil
        
        #if DEBUG
        print("Processing message with LLM")
        #endif
        
        guard let llmService = settings.getCurrentLLMService() else {
            error = "No API key set. Please configure in Settings."
            #if DEBUG
            print("No API key configured for LLM service")
            #endif
            isProcessing = false
            return
        }
        
        // Prepare the final prompt with additional context
        var finalPrompt = prompt
        
        do {
            #if DEBUG
            print("Requesting response from LLM service")
            #endif
            
            let response = try await llmService.generateResponse(to: finalPrompt)
            
            #if DEBUG
            print("Received response from LLM")
            #endif
            
            let assistantMessage = ChatMessage(content: response, isUser: false)
            messages.append(assistantMessage)
        } catch let error as LLMError {
            #if DEBUG
            print("LLM error occurred: \(error)")
            #endif
            
            switch error {
            case .apiError(let message):
                self.error = "API Error: \(message)"
                #if DEBUG
                print("API Error: \(message)")
                #endif
            case .networkError:
                self.error = "Network error. Please check your connection."
                #if DEBUG
                print("Network error with LLM service")
                #endif
            case .decodingError:
                self.error = "Error parsing the response. Please try again."
                #if DEBUG
                print("Response parsing error")
                #endif
            case .invalidAPIKey:
                self.error = "Invalid API key. Please check your settings."
                #if DEBUG
                print("Invalid API key")
                #endif
            }
        } catch {
            self.error = "An unexpected error occurred: \(error.localizedDescription)"
            #if DEBUG
            print("Unexpected error: \(error.localizedDescription)")
            #endif
        }
        
        isProcessing = false
        #if DEBUG
        print("LLM processing completed")
        #endif
    }
    
    /// Format query results as a Markdown table
    private func formatQueryResults(_ results: [[String: Any]]) -> String {
        guard let firstRow = results.first, !firstRow.isEmpty else {
            return "No results found."
        }
        
        // Extract column names from the first row
        let columns = Array(firstRow.keys).sorted()
        
        // Create table header
        var table = "| " + columns.joined(separator: " | ") + " |\n"
        table += "| " + columns.map { _ in "---" }.joined(separator: " | ") + " |\n"
        
        // Add table rows
        for row in results {
            table += "| "
            table += columns.map { key -> String in
                if let value = row[key] {
                    return "\(value)"
                } else {
                    return ""
                }
            }.joined(separator: " | ")
            table += " |\n"
        }
        
        return table
    }
}

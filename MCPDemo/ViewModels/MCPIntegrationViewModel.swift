import Foundation
import OSLog
import SwiftUI
import MCP

private let log = Logger()

class MCPIntegrationViewModel: ObservableObject {
    static let shared = MCPIntegrationViewModel()
    
    private let mcpClient = MCPClient.shared
    private let settings = AppSettings()
    private var llmService: LLMService
    
    // Reference to chat view model for updating messages
    private weak var chatViewModel: ChatViewModel?
    
    @Published private(set) var isProcessing = false
    @Published private(set) var error: String?
    
    init() {
        // Initialize LLM service using the key directly from settings
        let provider = settings.selectedProvider
        let apiKey = settings.getAPIKey(for: provider) ?? ""
        
        if !apiKey.isEmpty {
            Logger.info("Using API key from settings")
        } else {
            Logger.warning("No API key available in settings")
        }
        
        self.llmService = LLMServiceFactory.createService(provider: provider, apiKey: apiKey)
    }
    
    func setViewModel(_ viewModel: ChatViewModel) {
        self.chatViewModel = viewModel
    }
    
    func processQuery(_ query: String) async throws {
        isProcessing = true
        error = nil
        
        do {
            // Check if we're connected to the MCP server
            if !mcpClient.isConnected {
                Logger.info("MCP client not connected, attempting to connect...")
                try await mcpClient.connect()
            }
            
            // Format available tools for the LLM
            let toolsDescription = formatToolsForLLM(mcpClient.availableTools)
            Logger.info("Available tools: \(mcpClient.availableTools.map { $0.name }.joined(separator: ", "))")
            
            // Send query to LLM with tool information
            Logger.info("Sending query to LLM with tools description")
            let response = try await sendQueryToLLM(query, tools: toolsDescription)
            
            // Add assistant's response to chat
            await addAssistantMessage(response)
            
            // Process LLM response and execute any tool calls
            if let toolCall = extractToolCall(from: response) {
                // Show tool execution in the chat
                Logger.info("Extracted tool call: \(toolCall.name)")
                await addSystemMessage("Executing tool: \(toolCall.name)")
                
                // Execute the tool
                do {
                    let result = try await mcpClient.executeTool(
                        name: toolCall.name,
                        arguments: toolCall.arguments
                    )
                    
                    // Display tool results in the chat
                    if let formattedResult = (result as? [String: Any])?["formatted"] as? String {
                        Logger.info("Tool execution successful")
                        await addSystemMessage("Tool result: \n```\n\(formattedResult)\n```")
                        
                        // Send the tool result back to the LLM for a follow-up response
                        let followupPrompt = """
                        Tool result:
                        \(formattedResult)
                        
                        Based on this tool result, please provide a response to the user's query.
                        """
                        
                        let finalResponse = try await llmService.generateResponse(to: followupPrompt)
                        await addAssistantMessage(finalResponse)
                    } else {
                        Logger.error("Tool result was not in the expected format")
                        await addSystemMessage("⚠️ Error: Tool returned an unexpected result format")
                    }
                } catch {
                    Logger.error("Tool execution failed: \(error.localizedDescription)")
                    await addSystemMessage("⚠️ Error executing tool: \(error.localizedDescription)")
                }
            } else {
                Logger.info("No tool call was extracted from the LLM response")
            }
            
        } catch {
            self.error = error.localizedDescription
            Logger.error("Error processing query: \(error.localizedDescription)")
            await addSystemMessage("⚠️ Error: \(error.localizedDescription)")
        }
        
        isProcessing = false
    }
    
    private func formatToolsForLLM(_ tools: [Tool]) -> String {
        var description = "Available tools:\n"
        for tool in tools {
            description += "- \(tool.name): \(tool.description ?? "No description")\n"
            if let schema = tool.inputSchema as? [String: Any] {
                description += "  Parameters: \(schema)\n"
            }
        }
        return description
    }
    
    private func sendQueryToLLM(_ query: String, tools: String) async throws -> String {
        let prompt = """
        You have access to the following tools:
        \(tools)
        
        User query: \(query)
        
        If you need to use any tools to answer the query, please specify the tool name and arguments in a clear, easily parsable format.
        
        For example, if using a database tool, say:
        "I'll use the executeQuery tool with the following SQL: SELECT * FROM employees"
        
        Or if you don't need tools: "I can answer this directly without using tools..."
        """
        
        return try await llmService.generateResponse(to: prompt)
    }
    
    private func extractToolCall(from response: String) -> ToolCall? {
        // Look for patterns that indicate a tool call
        
        // Check if we have any tools to work with
        guard !mcpClient.availableTools.isEmpty else {
            Logger.info("No tools available to extract")
            return nil
        }
        
        // Extract tool names from the response
        let availableToolNames = mcpClient.availableTools.map { $0.name.lowercased() }
        var detectedTool: Tool? = nil
        
        // Check for each tool by name
        for tool in mcpClient.availableTools {
            if response.lowercased().contains("use the \(tool.name.lowercased())") ||
               response.lowercased().contains("using the \(tool.name.lowercased())") ||
               response.lowercased().contains("call \(tool.name.lowercased())") ||
               response.lowercased().contains("execute \(tool.name.lowercased())") {
                detectedTool = tool
                break
            }
        }
        
        // If no tool was detected, look for SQL query patterns for database tool
        if detectedTool == nil && mcpClient.availableTools.contains(where: { $0.name == "executeQuery" }) {
            if response.lowercased().contains("sql query") ||
               response.lowercased().contains("select ") {
                detectedTool = mcpClient.availableTools.first(where: { $0.name == "executeQuery" })
            }
        }
        
        guard let tool = detectedTool else {
            return nil
        }
        
        // Extract arguments based on the tool type
        switch tool.name {
        case "executeQuery":
            // For SQL queries, look for SQL statements
            let sqlPattern = #"SELECT\s+.+?(?:FROM|from)\s+.+?(?:;|$)"#
            guard let regex = try? NSRegularExpression(pattern: sqlPattern, options: [.dotMatchesLineSeparators]) else {
                return nil
            }
            
            let nsString = response as NSString
            let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))
            
            guard let match = matches.first else {
                return nil
            }
            
            let sqlQuery = nsString.substring(with: match.range)
            Logger.info("Extracted SQL query: \(sqlQuery)")
            
            // Make sure the SQL query is properly formatted as a string
            return ToolCall(name: "executeQuery", arguments: ["sql": sqlQuery as Any])
        case "searchDocumentation":
            // Look for the query parameter in the response
            let queryPattern = #"(?:search|find|look for)(?:.+?)(?:in|through|within|about)(?:.+?)["'](.+?)["']"#
            guard let regex = try? NSRegularExpression(pattern: queryPattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
                return nil
            }
            
            let nsString = response as NSString
            let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))
            
            guard let match = matches.first else {
                return nil
            }
            
            let searchQuery = nsString.substring(with: match.range(at: 1))
            Logger.info("Extracted search query: \(searchQuery)")
            
            return ToolCall(name: "searchDocumentation", arguments: ["query": searchQuery])

        case "getDocumentationSummary":
            // Check if detailed format is requested
            let formatPattern = #"(?:detailed|comprehensive|full|in-depth|complete)"#
            let formatRegex = try? NSRegularExpression(pattern: formatPattern, options: [.caseInsensitive])
            
            let nsString = response as NSString
            let formatMatches = formatRegex?.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))
            
            // If detailed format is requested, pass "detailed", otherwise use "brief"
            let format = formatMatches?.isEmpty == false ? "detailed" : "brief"
            
            return ToolCall(name: "getDocumentationSummary", arguments: ["format": format])
            
        default:
            // For other tools, attempt to parse arguments based on the response context
            Logger.info("Unknown tool: \(tool.name), no specific parser available")
            return nil
        }
    }
    
    @MainActor
    private func addAssistantMessage(_ content: String) {
        let message = ChatMessage(content: content, isUser: false)
        chatViewModel?.messages.append(message)
    }
    
    @MainActor
    private func addSystemMessage(_ content: String) {
        // System messages are shown as special assistant messages
        // Could be styled differently in the UI if needed
        let message = ChatMessage(content: content, isUser: false, isSystem: true)
        chatViewModel?.messages.append(message)
    }
    
    struct ToolCall {
        let name: String
        let arguments: [String: Any]
    }
}

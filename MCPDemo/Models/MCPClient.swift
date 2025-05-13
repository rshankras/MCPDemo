import Foundation
import MCP
import OSLog

private let log = Logger()

class MCPClient: ObservableObject {
    static let shared = MCPClient()
    
    private var session = URLSession.shared
    private var serverURL: URL?
    
    @Published private(set) var isConnected = false
    @Published private(set) var error: String?
    @Published private(set) var availableTools: [Tool] = []
    
    private init() {}
    
    // Our custom MCP implementation using direct HTTP requests
    func connect() async throws {
        Logger.info("Connecting to MCP server")
        
        // Load configuration
        let config = try MCPConfig.load()
        guard let serverConfig = config.servers["default"] else {
            throw NSError(domain: "MCPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No default server configuration found"])
        }
        
        // Determine server port based on server path
        var port = "3000" // Default port
        if serverConfig.command.contains("database-server.js") {
            port = "3001"
        }
        
        serverURL = URL(string: "http://localhost:\(port)")
        guard let serverURL = serverURL else {
            throw NSError(domain: "MCPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"])
        }
        
        Logger.info("Connecting to MCP server at: \(serverURL.absoluteString)")
        
        // Initialize with a simple request
        let response = try await sendMCPRequest(method: "initialize", params: [
            "clientInfo": [
                "name": "MCPDemo",
                "version": "1.0.0"
            ],
            "capabilities": [:],
            "protocolVersion": "2025-03-26"
        ])
        
        Logger.info("Server response: \(response)")
        
        // Set connected state
        await MainActor.run {
            isConnected = true
            Logger.info("Connected to MCP server successfully")
        }
        
        // Discover tools
        try await discoverServerTools()
    }
    
    private func discoverServerTools() async throws {
        Logger.info("Discovering available tools...")
        
        let response = try await sendMCPRequest(method: "tools", params: nil)
        
        if let toolsArray = response["result"] as? [[String: Any]] {
            var tools: [Tool] = []
            
            for toolData in toolsArray {
                let name = toolData["name"] as? String ?? "unknown"
                let description = toolData["description"] as? String
                let parameters = toolData["parameters"] as? [String: Any]
                
                let tool = Tool(
                    name: name,
                    description: description,
                    inputSchema: parameters
                )
                tools.append(tool)
            }
            
            await MainActor.run {
                self.availableTools = tools
                Logger.info("Discovered \(tools.count) tools")
            }
        } else {
            Logger.warning("Unexpected tools response format")
        }
    }
    
    func executeTool(name: String, arguments: [String: Any]) async throws -> Any {
        Logger.info("Executing tool: \(name) with args: \(arguments)")
        
        let response = try await sendMCPRequest(method: name, params: arguments)
        
        if let errorObj = response["error"] as? [String: Any] {
            let errorMessage = errorObj["message"] as? String ?? "Unknown error"
            Logger.error("Tool execution failed: \(errorMessage)")
            throw NSError(domain: "MCPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        if let result = response["result"] as? [String: Any],
           let content = result["content"] as? [[String: Any]] {
            
            // Process the content based on type
            var toolResultText = ""
            
            for item in content {
                if let type = item["type"] as? String {
                    switch type {
                    case "text":
                        if let text = item["text"] as? String {
                            toolResultText += text + "\n"
                        }
                    case "json":
                        if let json = item["json"] {
                            if let jsonData = try? JSONSerialization.data(withJSONObject: json),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                toolResultText += jsonString + "\n"
                            }
                        }
                    default:
                        toolResultText += "Received \(type) content (not shown)\n"
                    }
                }
            }
            
            Logger.info("Tool execution completed")
            return [
                "raw": content,
                "formatted": toolResultText
            ]
        }
        
        return ["formatted": "No content returned"]
    }
    
    func disconnect() async {
        serverURL = nil
        isConnected = false
        availableTools = []
        Logger.info("Disconnected from MCP server")
    }
    
    // Helper method to send MCP JSON-RPC requests
    private func sendMCPRequest(method: String, params: Any?) async throws -> [String: Any] {
        guard let serverURL = serverURL else {
            throw NSError(domain: "MCPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No server URL configured"])
        }
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method
        ]
        
        if let params = params {
            requestBody["params"] = params
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "MCPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "MCPClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "MCPClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        return jsonResponse
    }
}

// Define a Tool struct to match what the SDK would provide
struct Tool {
    let name: String
    let description: String?
    let inputSchema: Any?
}

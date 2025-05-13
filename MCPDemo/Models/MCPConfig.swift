import Foundation

struct MCPConfig: Codable {
    struct Server: Codable {
        var command: String
        var args: [String]?
        var env: [String: String]?
    }
    
    var servers: [String: Server]
    
    static let defaultConfig: MCPConfig = {
        // Default configuration pointing to the existing MCPServer
        let server = Server(
            command: "/Users/\(NSUserName())/Library/Application Support/Claude/MacOS/imcp-server",
            args: nil,
            env: nil
        )
        return MCPConfig(servers: ["default": server])
    }()
    
    static func load() throws -> MCPConfig {
        let configURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MCPDemo")
            .appendingPathComponent("mcp_config.json")
        
        guard let configURL = configURL else {
            throw NSError(domain: "MCPConfig", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not determine config file location"])
        }
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if FileManager.default.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(MCPConfig.self, from: data)
        } else {
            // Create default config if it doesn't exist
            let config = defaultConfig
            let data = try JSONEncoder().encode(config)
            try data.write(to: configURL)
            return config
        }
    }
    
    func save() throws {
        let configURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MCPDemo")
            .appendingPathComponent("mcp_config.json")
        
        guard let configURL = configURL else {
            throw NSError(domain: "MCPConfig", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not determine config file location"])
        }
        
        let data = try JSONEncoder().encode(self)
        try data.write(to: configURL)
    }
} 
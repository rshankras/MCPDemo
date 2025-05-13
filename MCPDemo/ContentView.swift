//
//  ContentView.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var settings = AppSettings()
    @State private var showingSettings = false
    @State private var showingMCPConnector = false
    @State private var mcpServerName = ""
    @State private var mcpServerPath = ""
    @State private var mcpServerArgs = ""
    @State private var connectedServers: [String] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and settings button
            HStack {
                Text("LLM Assistant")
                    .font(.headline)
                Spacer()
                
                // MCP toggle
                if !connectedServers.isEmpty {
                    Toggle("Use MCP", isOn: $viewModel.useMCP)
                        .toggleStyle(.switch)
                        .fixedSize()
                        .padding(.trailing, 8)
                }
                
                // MCP button
                Button(action: {
                    showingMCPConnector.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                            .font(.system(size: 16))
                        if !connectedServers.isEmpty {
                            Text("\(connectedServers.count)")
                                .font(.caption)
                                .padding(3)
                                .background(Circle().fill(Color.green))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .buttonStyle(.borderless)

                // Settings button
                Button(action: {
                    showingSettings.toggle()
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 18))
                }
            }
            .padding()
            
            // Error message display
            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            
            // Chat messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: viewModel.messages) { newValue in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Processing indicator
            if viewModel.isProcessing {
                HStack {
                    Spacer()
                    ProgressView()
                    Text("Thinking...")
                        .font(.caption)
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Input area
            HStack {
                TextField("Type a message...", text: $viewModel.inputMessage)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isProcessing)
                    .onSubmit {
                        viewModel.sendMessage()
                    }
                
                Button(action: {
                    viewModel.sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                }
                .disabled(viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showingMCPConnector) {
            MCPConnectorView(
                mcpServerName: $mcpServerName,
                mcpServerPath: $mcpServerPath,
                mcpServerArgs: $mcpServerArgs,
                connectedServers: connectedServers,
                connectServer: { name, path, args in
                    Task {
                        do {
                            // Create/update MCP configuration
                            var config = try MCPConfig.load()
                            let resolvedPath = resolveExecutablePath(path)
                            let server = MCPConfig.Server(
                                command: resolvedPath,
                                args: args.split(separator: " ").map(String.init),
                                env: nil
                            )
                            config.servers["default"] = server
                            try config.save()
                            
                            // Connect to the server
                            try await MCPClient.shared.connect()
                            
                            // Update connected servers list on the main thread
                            await MainActor.run {
                                if !connectedServers.contains(name) {
                                    connectedServers.append(name)
                                }
                            }
                        } catch {
                            viewModel.error = "Failed to connect: \(error.localizedDescription)"
                        }
                    }
                },
                disconnectServer: { name in
                    Task {
                        await MCPClient.shared.disconnect()
                        if let index = connectedServers.firstIndex(of: name) {
                            connectedServers.remove(at: index)
                        }
                        if connectedServers.isEmpty {
                            viewModel.useMCP = false
                        }
                    }
                },
                getResources: { serverName in
                    return Task {
                        // This would be implemented to return resources
                        // from the specified server
                        return MCPClient.shared.availableTools.map { $0.name }
                    }
                },
                dismiss: { showingMCPConnector = false }
            )
        }
    }
    
    /// Resolves relative paths to absolute paths
    private func resolveExecutablePath(_ path: String) -> String {
        if path.hasPrefix("/") {
            // Already an absolute path
            return path
        }
        
        // Get the app's working directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        
        // Combine the current directory with the relative path
        return URL(fileURLWithPath: currentDirectory).appendingPathComponent(path).path
    }
}

struct MCPConnectorView: View {
    @Binding var mcpServerName: String
    @Binding var mcpServerPath: String
    @Binding var mcpServerArgs: String
    let connectedServers: [String]
    let connectServer: (String, String, String) -> Void
    let disconnectServer: (String) -> Void
    let getResources: (String) -> Task<[String], Never>
    let dismiss: () -> Void
    
    @State private var selectedServer: String? = nil
    @State private var resources: [String] = []
    @State private var isLoading = false
    @State private var selectedPreset: ServerPreset? = nil
    @State private var serverValidationStatus: [String: Bool] = [:]
    
    // Predefined server presets
    let serverPresets: [ServerPreset] = [
        ServerPreset(
            name: "Documentation Server",
            path: "MCPServer/server.js",
            arguments: ""
        ),
        ServerPreset(
            name: "Database Server",
            path: "MCPServer/database-server.js", 
            arguments: ""
        )
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Add a header with a dismiss button
            HStack {
                Text("MCP Server Connection")
                    .font(.headline)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 8)
            
            Form {
                Section(header: Text("Server Presets")) {
                    ForEach(serverPresets) { preset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .fontWeight(.medium)
                                Text(preset.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if connectedServers.contains(preset.name) {
                                // Connected status
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                
                                Button(action: {
                                    disconnectServer(preset.name)
                                }) {
                                    Text("Disconnect")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            } else {
                                // Server file validation status
                                if let isValid = serverValidationStatus[preset.name] {
                                    Circle()
                                        .fill(isValid ? Color.blue : Color.red)
                                        .frame(width: 8, height: 8)
                                }
                                
                                Button(action: {
                                    connectServer(preset.name, preset.path, preset.arguments)
                                }) {
                                    Text("Connect")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                                .disabled(serverValidationStatus[preset.name] == false)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPreset = preset
                            mcpServerName = preset.name
                            mcpServerPath = preset.path
                            mcpServerArgs = preset.arguments
                        }
                    }
                }
                
                Section(header: Text("Custom Server")) {
                    TextField("Server Name", text: $mcpServerName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Executable Path", text: $mcpServerPath)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Arguments (space-separated)", text: $mcpServerArgs)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Connect Custom Server") {
                        connectServer(mcpServerName, mcpServerPath, mcpServerArgs)
                        mcpServerName = ""
                        mcpServerPath = ""
                        mcpServerArgs = ""
                    }
                    .disabled(mcpServerName.isEmpty || mcpServerPath.isEmpty)
                }
                
                Section(header: Text("Connected Servers")) {
                    if connectedServers.isEmpty {
                        Text("No servers connected")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        List(connectedServers, id: \.self) { server in
                            HStack {
                                Text(server)
                                Spacer()
                                Button("View") {
                                    selectedServer = server
                                    isLoading = true
                                    Task {
                                        resources = await getResources(server).value
                                        isLoading = false
                                    }
                                }
                                .buttonStyle(.borderless)
                                
                                Button("Disconnect") {
                                    disconnectServer(server)
                                    if selectedServer == server {
                                        selectedServer = nil
                                        resources = []
                                    }
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                if let selectedServer = selectedServer {
                    Section(header: Text("Resources from \(selectedServer)")) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if resources.isEmpty {
                            Text("No resources available")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            List(resources, id: \.self) { resource in
                                Text(resource)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            validateServerFiles()
        }
    }
    
    /// Validate that server files exist
    private func validateServerFiles() {
        for preset in serverPresets {
            let resolvedPath = resolveExecutablePath(preset.path)
            let isValid = FileManager.default.fileExists(atPath: resolvedPath)
            serverValidationStatus[preset.name] = isValid
        }
    }
    
    /// Resolves relative paths to absolute paths
    private func resolveExecutablePath(_ path: String) -> String {
        if path.hasPrefix("/") {
            // Already an absolute path
            return path
        }
        
        // Get the app's working directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        
        // Combine the current directory with the relative path
        return URL(fileURLWithPath: currentDirectory).appendingPathComponent(path).path
    }
}

// Server preset model
struct ServerPreset: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let arguments: String
}

#Preview {
    ContentView()
}

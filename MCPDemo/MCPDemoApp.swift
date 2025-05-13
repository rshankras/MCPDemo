//
//  MCPDemoApp.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import SwiftUI
import AppKit
import MCP  // Import the MCP module

@main
struct MCPDemoApp: App {
    init() {
        #if DEBUG
        print("Application starting up")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Set window appearance
                    NSWindow.allowsAutomaticWindowTabbing = false
                    if let window = NSApplication.shared.windows.first {
                        window.title = "LLM Assistant"
                        window.setFrameAutosaveName("LLMAssistant")
                        #if DEBUG
                        print("Window configuration applied")
                        #endif
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

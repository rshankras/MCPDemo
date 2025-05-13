//
//  SettingsView.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    
    var body: some View {
        VStack {
            // Header with title and done button
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            Form {
                Section(header: Text("LLM Provider")) {
                    Picker("Provider", selection: $settings.selectedProvider) {
                        Text("Anthropic Claude").tag(LLMProvider.anthropic)
                        Text("OpenAI").tag(LLMProvider.openai)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("API Keys")) {
                    if settings.selectedProvider == .anthropic {
                        SecureField("Anthropic API Key", text: $anthropicKey)
                        Button("Save Anthropic API Key") {
                            settings.setAPIKey(anthropicKey, for: .anthropic)
                            settings.saveSettings()
                            alertMessage = "Anthropic API key saved successfully"
                            showingAlert = true
                            anthropicKey = ""  // Clear for security
                        }
                        .disabled(anthropicKey.isEmpty)
                    } else {
                        SecureField("OpenAI API Key", text: $openaiKey)
                        Button("Save OpenAI API Key") {
                            settings.setAPIKey(openaiKey, for: .openai)
                            settings.saveSettings()
                            alertMessage = "OpenAI API key saved successfully"
                            showingAlert = true
                            openaiKey = ""  // Clear for security
                        }
                        .disabled(openaiKey.isEmpty)
                    }
                }
                
                Section {
                    Button("Save Settings") {
                        settings.saveSettings()
                        alertMessage = "Settings saved successfully"
                        showingAlert = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.bottom)
        .frame(minWidth: 400, minHeight: 300)
        .alert(alertMessage, isPresented: $showingAlert) {
            Button("OK") { }
        }
        .onAppear {
            // Initialize fields with masked values if keys exist
            if let key = settings.getAPIKey(for: .anthropic), !key.isEmpty {
                anthropicKey = "••••••••••••••••••••••"
            }
            
            if let key = settings.getAPIKey(for: .openai), !key.isEmpty {
                openaiKey = "••••••••••••••••••••••"
            }
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings())
} 

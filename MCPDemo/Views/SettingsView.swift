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
                    Picker("Provider", selection: $settings.currentProvider) {
                        Text("Anthropic Claude").tag(LLMProvider.anthropic)
                        Text("OpenAI").tag(LLMProvider.openAI)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("API Keys")) {
                    if settings.currentProvider == .anthropic {
                        SecureField("Anthropic API Key", text: $settings.anthropicAPIKey)
                    } else if settings.currentProvider == .openAI {
                        SecureField("OpenAI API Key", text: $settings.openAIAPIKey)
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
    }
}

#Preview {
    SettingsView(settings: AppSettings())
} 
//
//  AppSettings.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @Published var selectedProvider: LLMProvider = .anthropic
    
    // Dictionary to store API keys in memory
    private var apiKeys: [LLMProvider: String] = [:]
    
    private let keychainService = "com.mcpdemo.apikeys"
    private let anthropicKey = "anthropicAPIKey"
    private let openAIKey = "openAIAPIKey"
    private let providerKey = "currentProvider"
    
    init() {
        Logger.info("Initializing AppSettings")
        loadSettings()
    }
    
    // Get API key for specific provider
    func getAPIKey(for provider: LLMProvider) -> String? {
        return apiKeys[provider]
    }
    
    // Set API key for specific provider
    func setAPIKey(_ key: String, for provider: LLMProvider) {
        apiKeys[provider] = key
    }
    
    // Load settings from storage
    func loadSettings() {
        Logger.info("Loading settings from keychain and UserDefaults")
        
        // Load API keys from keychain
        if let anthropicKey = KeychainManager.shared.getAPIKey(for: .anthropic) {
            apiKeys[.anthropic] = anthropicKey
            Logger.info("Loaded Anthropic API key from keychain")
        } else {
            Logger.info("No Anthropic API key found in keychain")
        }
        
        if let openaiKey = KeychainManager.shared.getAPIKey(for: .openai) {
            apiKeys[.openai] = openaiKey
            Logger.info("Loaded OpenAI API key from keychain")
        } else {
            Logger.info("No OpenAI API key found in keychain")
        }
        
        // Load selected provider from UserDefaults
        if let providerString = UserDefaults.standard.string(forKey: "selectedProvider"),
           let provider = LLMProvider(rawValue: providerString) {
            selectedProvider = provider
            Logger.info("Loaded provider preference: \(providerString)")
        }
        
        Logger.info("Settings loaded successfully")
    }
    
    // Save settings to storage
    func saveSettings() {
        Logger.info("Saving settings to keychain and UserDefaults")
        
        // Save API keys to keychain
        if let anthropicKey = apiKeys[.anthropic] {
            let success = KeychainManager.shared.saveAPIKey(anthropicKey, for: .anthropic)
            if success {
                Logger.info("Saving Anthropic API key to keychain")
            } else {
                Logger.error("Failed to save Anthropic API key to keychain")
            }
        }
        
        if let openaiKey = apiKeys[.openai] {
            let success = KeychainManager.shared.saveAPIKey(openaiKey, for: .openai)
            if success {
                Logger.info("Saving OpenAI API key to keychain")
            } else {
                Logger.error("Failed to save OpenAI API key to keychain")
            }
        }
        
        // Save selected provider to UserDefaults
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
        Logger.info("Saving provider preference: \(selectedProvider.rawValue)")
        
        Logger.info("Settings saved successfully")
    }
    
    // Create and return appropriate LLM service
    func getCurrentLLMService() -> LLMService? {
        if let apiKey = getAPIKey(for: selectedProvider), !apiKey.isEmpty {
            return LLMServiceFactory.createService(provider: selectedProvider, apiKey: apiKey)
        }
        return nil
    }
    
    // MARK: - Keychain Helper Methods
    
    private func setKeychainValue(_ value: String, forKey key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            #if DEBUG
            print("Failed to delete existing keychain item: \(deleteStatus)")
            #endif
        }
        
        // Add the new item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus != errSecSuccess {
            #if DEBUG
            print("Failed to add keychain item: \(addStatus)")
            #endif
        }
    }
    
    private func getKeychainValue(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        } else if status != errSecItemNotFound {
            #if DEBUG
            print("Failed to read keychain item: \(status)")
            #endif
        }
        
        return nil
    }
} 

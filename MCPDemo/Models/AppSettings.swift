//
//  AppSettings.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @Published var currentProvider: LLMProvider = .anthropic
    @Published var anthropicAPIKey: String = ""
    @Published var openAIAPIKey: String = ""
    
    private let keychainService = "com.mcpdemo.apikeys"
    private let anthropicKey = "anthropicAPIKey"
    private let openAIKey = "openAIAPIKey"
    private let providerKey = "currentProvider"
    
    init() {
        #if DEBUG
        print("Initializing AppSettings")
        #endif
        loadSettings()
    }
    
    func saveSettings() {
        #if DEBUG
        print("Saving settings to keychain and UserDefaults")
        #endif
        
        // Save API keys to keychain
        if !anthropicAPIKey.isEmpty {
            #if DEBUG
            print("Saving Anthropic API key to keychain")
            #endif
            setKeychainValue(anthropicAPIKey, forKey: anthropicKey)
        }
        
        if !openAIAPIKey.isEmpty {
            #if DEBUG
            print("Saving OpenAI API key to keychain")
            #endif
            setKeychainValue(openAIAPIKey, forKey: openAIKey)
        }
        
        // Save provider preference to UserDefaults
        #if DEBUG
        print("Saving provider preference: \(currentProvider.rawValue)")
        #endif
        UserDefaults.standard.setValue(currentProvider.rawValue, forKey: providerKey)
        
        #if DEBUG
        print("Settings saved successfully")
        #endif
    }
    
    func loadSettings() {
        #if DEBUG
        print("Loading settings from keychain and UserDefaults")
        #endif
        
        // Load API keys from keychain
        if let anthropicKey = getKeychainValue(forKey: anthropicKey) {
            self.anthropicAPIKey = anthropicKey
            #if DEBUG
            print("Loaded Anthropic API key from keychain")
            #endif
        } else {
            #if DEBUG
            print("No Anthropic API key found in keychain")
            #endif
        }
        
        if let openAIKey = getKeychainValue(forKey: openAIKey) {
            self.openAIAPIKey = openAIKey
            #if DEBUG
            print("Loaded OpenAI API key from keychain")
            #endif
        } else {
            #if DEBUG
            print("No OpenAI API key found in keychain")
            #endif
        }
        
        // Load provider preference from UserDefaults
        if let providerValue = UserDefaults.standard.string(forKey: providerKey),
           let provider = LLMProvider(rawValue: providerValue) {
            self.currentProvider = provider
            #if DEBUG
            print("Loaded provider preference: \(provider.rawValue)")
            #endif
        } else {
            #if DEBUG
            print("No provider preference found, using default: \(currentProvider.rawValue)")
            #endif
        }
        
        #if DEBUG
        print("Settings loaded successfully")
        #endif
    }
    
    func getCurrentLLMService() -> LLMService? {
        #if DEBUG
        print("Getting LLM service for provider: \(currentProvider.rawValue)")
        #endif
        
        switch currentProvider {
        case .anthropic:
            guard !anthropicAPIKey.isEmpty else {
                #if DEBUG
                print("Anthropic API key not set")
                #endif
                return nil
            }
            #if DEBUG
            print("Creating Anthropic service")
            #endif
            return AnthropicService(apiKey: anthropicAPIKey)
        case .openAI:
            guard !openAIAPIKey.isEmpty else {
                #if DEBUG
                print("OpenAI API key not set")
                #endif
                return nil
            }
            #if DEBUG
            print("OpenAI service not yet implemented")
            #endif
            // Will be implemented later
            return nil
        }
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

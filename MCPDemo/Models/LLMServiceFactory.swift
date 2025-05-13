//
//  LLMServiceFactory.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import Foundation

enum LLMProvider: String {
    case anthropic = "anthropic"
    case openai = "openai"
    // Add other providers as needed
}

class LLMServiceFactory {
    static func createService(provider: LLMProvider, apiKey: String = "") -> LLMService {
        var key = apiKey
        
        // If no key is provided, try to get it from the keychain
        if key.isEmpty {
            key = KeychainManager.shared.getAPIKey(for: provider) ?? ""
        }
        
        switch provider {
        case .anthropic:
            return AnthropicService(apiKey: key)
        case .openai:
            // Implement OpenAI service if needed
            return AnthropicService(apiKey: key) // Placeholder, replace with actual OpenAI service
        }
    }
} 
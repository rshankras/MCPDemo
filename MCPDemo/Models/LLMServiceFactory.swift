//
//  LLMServiceFactory.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import Foundation

enum LLMProvider: String {
    case anthropic
    case openAI
    // Add more providers as needed
}

class LLMServiceFactory {
    static func createService(provider: LLMProvider, apiKey: String) -> LLMService {
        switch provider {
        case .anthropic:
            return AnthropicService(apiKey: apiKey)
        case .openAI:
            // This will be implemented later
            fatalError("OpenAI service not yet implemented")
        }
    }
} 
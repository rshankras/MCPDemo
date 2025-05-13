//
//  LLMService.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import Foundation

protocol LLMService {
    func generateResponse(to prompt: String) async throws -> String
}

// First, explicitly define the LLMError enum here
enum LLMError: Error {
    case apiError(String)
    case networkError
    case decodingError
    case invalidAPIKey
}

// Helper functions to create errors
func createInvalidAPIKeyError() -> Error {
    return LLMError.invalidAPIKey
}

func createNetworkError() -> Error {
    return LLMError.networkError
}

func createDecodingError() -> Error {
    return LLMError.decodingError
}

func createAPIError(_ message: String) -> Error {
    return LLMError.apiError(message)
}

// Concrete implementation for Anthropic's Claude
class AnthropicService: LLMService {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String = "claude-3-7-sonnet-20250219") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func generateResponse(to prompt: String) async throws -> String {
        Logger.info("Generating response with Anthropic Claude")
        Logger.info("Using model: \(model)")

        var currentApiKey = apiKey
        
        // If key is empty, try to get from AppSettings directly
        if currentApiKey.isEmpty {
            Logger.error("API key is empty - trying to get from AppSettings")
            let settings = AppSettings()
            if let settingsKey = settings.getAPIKey(for: .anthropic), !settingsKey.isEmpty {
                Logger.info("Got API key from AppSettings")
                currentApiKey = settingsKey
            } else {
                // If still empty, try keychain directly as a last resort
                Logger.error("No API key in AppSettings - trying keychain directly")
                if let keychainKey = KeychainManager.shared.getAPIKey(for: .anthropic), !keychainKey.isEmpty {
                    Logger.info("Got API key directly from keychain")
                    currentApiKey = keychainKey
                } else {
                    Logger.error("No API key available")
                    throw LLMError.invalidAPIKey
                }
            }
        }
        
        // Print key length for debugging (never print actual key)
        Logger.info("API key length: \(currentApiKey.count)")
        
        // Use the provided API key
        return try await generateResponseWithKey(prompt: prompt, apiKey: currentApiKey)
    }
    
    private func generateResponseWithKey(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set headers according to documentation
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")  // No Bearer prefix
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Prepare request body according to documentation
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 1024
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw createNetworkError()  // Use helper function instead
            }
            
            if httpResponse.statusCode != 200 {
                if httpResponse.statusCode == 401 {
                    throw createInvalidAPIKeyError()  // Use helper function instead
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw createAPIError("HTTP \(httpResponse.statusCode): \(errorMessage)")  // Use helper function instead
                }
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw createDecodingError()  // Use helper function instead
            }
            
            if let content = json["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String {
                return text
            } else if let content = json["content"] as? String {
                return content
            } else if let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String {
                return content
            } else {
                Logger.error("Unexpected response format: \(json)")
                throw createDecodingError()  // Use helper function instead
            }
        } catch let error as LLMError {
            // Re-throw LLM-specific errors
            throw error
        } catch {
            // Convert other errors to network error
            Logger.error("Request error: \(error.localizedDescription)")
            throw createNetworkError()  // Use helper function instead
        }
    }
} 

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

enum LLMError: Error {
    case networkError(Error)
    case apiError(String)
    case decodingError
    case invalidAPIKey
}

// Concrete implementation for Anthropic's Claude
class AnthropicService: LLMService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let modelName: String
    
    init(apiKey: String, modelName: String = "claude-3-sonnet-20240229") {
        // Trim any whitespace from the API key
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelName = modelName
        
        #if DEBUG
        print("Initialized Anthropic service with model: \(modelName)")
        
        // Validate API key format
        if !self.apiKey.isEmpty {
            if self.apiKey.hasPrefix("sk-") {
                print("API key format appears valid (starts with 'sk-')")
            } else {
                print("WARNING: API key does not start with 'sk-' - this may not be a valid Anthropic key")
            }
            
            // Only log a few characters for security
            let keyPrefix = String(self.apiKey.prefix(8))
            let keyLength = self.apiKey.count
            print("API key starts with: \(keyPrefix)... (length: \(keyLength) characters)")
        } else {
            print("WARNING: API key is empty")
        }
        #endif
    }
    
    func generateResponse(to prompt: String) async throws -> String {
        #if DEBUG
        print("Generating response with Anthropic Claude")
        print("Using model: \(modelName)")
        #endif
        
        // Validate API key before sending request
        if apiKey.isEmpty {
            #if DEBUG
            print("API key is empty - cannot make request")
            #endif
            throw LLMError.invalidAPIKey
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // New Anthropic API version format
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Updated auth header - x-api-key
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        #if DEBUG
        print("Sending request to Anthropic API")
        
        print("Headers:")
        print("x-api-key: [MASKED]")
        print("Content-Type: \(request.value(forHTTPHeaderField: "Content-Type") ?? "none")")
        print("anthropic-version: \(request.value(forHTTPHeaderField: "anthropic-version") ?? "none")")
        
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("Request body: \(bodyString)")
        }
        #endif
        
        // Perform the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            #if DEBUG
            print("Invalid response from Anthropic API")
            #endif
            throw LLMError.networkError(NSError(domain: "AnthropicService", code: -1))
        }
        
        #if DEBUG
        print("Received response with status code: \(httpResponse.statusCode)")
        if let responseStr = String(data: data, encoding: .utf8) {
            print("Response body: \(responseStr)")
        }
        #endif
        
        guard httpResponse.statusCode == 200 else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            #if DEBUG
            print("API error: \(httpResponse.statusCode), \(errorStr)")
            #endif
            throw LLMError.apiError("API error: \(httpResponse.statusCode), \(errorStr)")
        }
        
        // Parse the response
        do {
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = jsonResponse["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                #if DEBUG
                print("Failed to parse Anthropic API response")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseStr)")
                }
                #endif
                throw LLMError.decodingError
            }
            
            #if DEBUG
            print("Successfully generated response (\(text.count) chars)")
            #endif
            return text
        } catch {
            #if DEBUG
            print("JSON parsing error: \(error.localizedDescription)")
            if let responseStr = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseStr)")
            }
            #endif
            throw LLMError.decodingError
        }
    }
} 
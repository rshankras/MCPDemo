//
//  ChatMessage.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let isSystem: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool, isSystem: Bool = false, timestamp: Date = Date()) {
        self.content = content
        self.isUser = isUser
        self.isSystem = isSystem
        self.timestamp = timestamp
    }
    
    // Implementation of Equatable
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.content == rhs.content &&
               lhs.isUser == rhs.isUser &&
               lhs.isSystem == rhs.isSystem &&
               lhs.timestamp == rhs.timestamp
    }
}

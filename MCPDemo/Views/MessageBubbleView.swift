//
//  MessageBubbleView.swift
//  MCPDemo
//
//  Created by Ravi Shankar on 11/05/25.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.isUser ? Color.blue : Color.secondary)
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(16)
            
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
    }
}

#Preview {
    VStack {
        MessageBubbleView(message: ChatMessage(content: "Hello!", isUser: true))
        MessageBubbleView(message: ChatMessage(content: "Hi there! How can I help you?", isUser: false))
    }
} 

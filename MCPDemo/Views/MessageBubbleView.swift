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
            
            VStack(alignment: message.isUser ? .trailing : .leading) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
                
                if message.isSystem {
                    Text("System")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                }
            }
            
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
    }
    
    private var backgroundColor: Color {
        if message.isUser {
            return Color.blue
        } else if message.isSystem {
            return Color.gray.opacity(0.7)
        } else {
            return Color.secondary
        }
    }
    
    private var textColor: Color {
        if message.isUser || message.isSystem {
            return .white
        } else {
            return .primary
        }
    }
}
#Preview {
    VStack {
        MessageBubbleView(message: ChatMessage(content: "Hello!", isUser: true))
        MessageBubbleView(message: ChatMessage(content: "Hi there! How can I help you?", isUser: false))
    }
} 

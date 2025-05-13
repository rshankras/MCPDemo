import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    func saveAPIKey(_ key: String, for provider: LLMProvider) -> Bool {
        let providerString = provider.rawValue
        
        // Create a query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: providerString,
            kSecAttrService as String: "com.rshankar.MCPDemo.apikeys",
            kSecValueData as String: key.data(using: .utf8)!
        ]
        
        // First delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getAPIKey(for provider: LLMProvider) -> String? {
        let providerString = provider.rawValue
        
        // Create a query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: providerString,
            kSecAttrService as String: "com.rshankar.MCPDemo.apikeys",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
} 
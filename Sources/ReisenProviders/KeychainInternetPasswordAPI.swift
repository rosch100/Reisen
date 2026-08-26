import Foundation
import Security

internal protocol KeychainInternetPasswordKeychainAPI: Sendable {
    func itemCopyMatching(query: CFDictionary) -> (status: OSStatus, item: CFTypeRef?)
    func itemUpdate(existingQuery: CFDictionary, update: CFDictionary) -> OSStatus
    func itemAdd(add: CFDictionary) -> OSStatus
}

internal struct SecurityInternetPasswordKeychainAPI: KeychainInternetPasswordKeychainAPI {
    func itemCopyMatching(query: CFDictionary) -> (status: OSStatus, item: CFTypeRef?) {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)
        return (status: status, item: item)
    }

    func itemUpdate(existingQuery: CFDictionary, update: CFDictionary) -> OSStatus {
        SecItemUpdate(existingQuery, update)
    }

    func itemAdd(add: CFDictionary) -> OSStatus {
        SecItemAdd(add, nil)
    }
}

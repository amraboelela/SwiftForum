//
//  Message.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 2/5/22.
//

import Foundation
import SwiftLevelDB

public struct Message: Codable, Equatable, Sendable {
    public static let prefix = "message-"

    public var fromUsername: String
    public var toUsername: String
    public var message: String
    public var timeSent: Int
    public var timeRead: Int?
    
    // MARK: - Accessors

    public var key: String {
        return Message.prefix + toUsername + "-\(timeSent)-" + fromUsername
    }
    
    public var sentDate: String {
        return Date.friendlyDateStringFrom(epochTime: TimeInterval(timeSent))
    }
    
    public var readDate: String? {
        if let timeRead = timeRead {
            return Date.friendlyDateStringFrom(epochTime: TimeInterval(timeRead))
        } else {
            return nil
        }
    }
    
    // MARK: - Factory methods
    
    public static func createWith(fromUsername: String, toUsername: String, message: String) -> Message {
        return Message(fromUsername: fromUsername, toUsername: toUsername, message: message, timeSent: Date.secondsSince1970)
    }

    public static func messageWith(toUsername: String, time: Int, fromUsername: String) async -> Message? {
        let messageKey = prefix + toUsername + "-\(time)" + "-" + fromUsername
        return await messageWith(key: messageKey)
    }
    
    public static func messageWith(key: String) async -> Message? {
        if let message: Message = await database.value(forKey: key) {
            return message
        }
        return nil
    }
    
    // MARK: - Reading data

    public static func messages(toUsername: String, fromUsername: String? = nil, nonReadOnly: Bool = false, count: Int = 200) async -> [Message] {
        var result = [Message]()
        //NSLog("messages toUsername: \(toUsername)")
        if let fromUsername = fromUsername {
            //NSLog("fromUsername: \(fromUsername)")
            await database.enumerateKeysAndValues(backward: true, andPrefix: prefix + toUsername + "-") { (key, message: Message, stop) in
                if fromUsername == message.fromUsername &&
                    (!nonReadOnly || message.timeRead == nil) {
                    result.append(message)
                }
            }
            await database.enumerateKeysAndValues(backward: true, andPrefix: prefix + fromUsername + "-") { (key, message: Message, stop) in
                if toUsername == message.fromUsername &&
                    (!nonReadOnly || message.timeRead == nil) {
                    result.append(message)
                }
            }
            result = result.sorted { $0.timeSent < $1.timeSent }
        } else {
            await database.enumerateKeysAndValues(backward: true, andPrefix: prefix + toUsername + "-") { (key, message: Message, stop) in
                NSLog("message: \(message)")
                if !nonReadOnly || message.timeRead == nil {
                    result.append(message)
                }
            }
        }
        NSLog("result: \(result)")
        if result.count > count {
            result.removeFirst(result.count - count)
        }
        return result
    }

    // MARK: - Saving data
    
    public func save() async {
        do {
            let messageKey = Message.prefix + toUsername + "-\(timeSent)-" + fromUsername
            try await database.setValue(self, forKey: messageKey)
        } catch {
            NSLog("Message save failed, error: \(error)")
        }
    }
    
    // MARK: - Convenience methods
    
    public static func key(ofMessage message: Message) -> String {
        return prefix + message.toUsername +  "-\(message.timeSent)-" + message.fromUsername
    }
    
    public static func fromUsername(fromMessageKey messageKey: String) -> String {
        let arr = messageKey.components(separatedBy: "-")
        var result = ""
        if arr.count > 2 {
            result = arr[1]
        }
        return result
    }
    
    public static func time(fromMessageKey messageKey: String?) -> Int {
        var result = 0
        if let messageKey = messageKey {
            let arr = messageKey.components(separatedBy: "-")
            if arr.count > 2 {
                result = Int(arr[2]) ?? 0
            }
        }
        return result
    }
    
    public static func messages(forKeys keys: [String]) async -> [Message] {
        var result = [Message]()
        for messageKey in keys {
            if let message: Message = await database.value(forKey: messageKey) {
                result.append(message)
            }
        }
        return result
    }
    
    // MARK: - Util methods
    
    /*public static func deleteReadMessages() async {
        var keysToBeDeleted = [String]()
        await database.enumerateKeysAndValues(backward: false, startingAtKey: nil, andPrefix: prefix) { (key, message: Message, stop) in
            if let timeRead = message.timeRead, Date.secondsSince1970 - timeRead > Int(Date.oneDay) {
                keysToBeDeleted.append(key)
            }
        }
        for keyToBeDeleted in keysToBeDeleted {
            await database.removeValue(forKey: keyToBeDeleted)
        }
    }*/
    
}

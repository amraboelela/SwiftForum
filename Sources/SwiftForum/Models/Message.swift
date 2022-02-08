//
//  Message.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 2/5/22.
//

import Foundation
import SwiftLevelDB

public struct Message: Codable {
    public static let prefix = "message-"

    public var toUsername: String
    public var fromUsername: String
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
    
    public var readDate: String {
        return Date.friendlyDateStringFrom(epochTime: TimeInterval(timeRead))
    }
    
    // MARK: - Factory methods
    
    public static func createWith(toUsername: String, fromUsername: String, message: String) -> Message {
        return Message(toUsername: toUsername, timeSent: Date.now, fromUsername: fromUsername, message: message)
    }

    public static func messageWith(toUsername: String, time: Int, fromUsername: String) -> Message? {
        let messageKey = prefix + toUsername + "-\(time)" + "-" + fromUsername
        return messageWith(key: messageKey)
    }
    
    public static func messageWith(key: String) -> Message? {
        if let message: Message = forumDB[key] {
            return message
        }
        return nil
    }
    
    // MARK: - Reading data

    public static func messages(toUsername: String, time: Int? = nil, before: Bool = true, count: Int) -> [Message] {
        var result = [Message]()
        var startAtKey: String? = nil
        if let time = time {
            startAtKey = prefix + toUsername + "-\(time)"
        }
        forumDB.enumerateKeysAndValues(backward: before, startingAtKey: startAtKey, andPrefix: prefix) { (key, message: Message, stop) in
            if result.count < count {
                result.append(message)
            } else {
                stop.pointee = true
            }
        }
        return result
    }

    // MARK: - Saving data
    
    public func save() {
        let messageKey = Message.prefix + toUsername + "-\(timeSent)-" + fromUsername
        forumDB[messageKey] = self
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
    
    public static func messages(forKeys keys: [String]) -> [Message] {
        var result = [Message]()
        for messageKey in keys {
            if let message: Message = forumDB[messageKey] {
                result.append(message)
            }
        }
        return result
    }
    
    // MARK: - Util methods
    
    public static func deleteReadMessages() {
        var keysToBeDeleted = [String]()
        forumDB.enumerateKeysAndValues(backward: false, startingAtKey: nil, andPrefix: prefix) { (key, message: Message, stop) in
            if let timeRead = message.timeRead, Date.now - timeRead > Int(Date.oneDay) {
                keysToBeDeleted.append(key)
            }
        }
        for keyToBeDeleted in keysToBeDeleted {
            forumDB.removeValueForKey(keyToBeDeleted)
        }
    }
    
}

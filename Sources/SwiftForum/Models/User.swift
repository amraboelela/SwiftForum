//
//  User.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation
import SwiftLevelDB

public enum UserRole: String {
    case member
    case moderator
    case admin
}

public enum UserStatus: String {
    case pending // pending membership when a user first register.
    case active
    case suspended
}

public struct User: Codable, Hashable, Sendable {
    public static let prefix = "user-"
    public static let avatars = "avatars"
    
    public var username: String
    public var password: String
    public var role: String?
    public var status: String?
    public var timeJoined: Int
    public var timeLoggedin: Int?
    public var fullname: String?
    public var bio: String?
    public var location: String?
    public var url: String?
    public var avatar: String?
    public var viewed: Bool?
    
    // MARK: - Accessors

    public var key: String {
        return User.prefix + username
    }
    
    public var userRole: UserRole {
        get {
            if let role = role, let result = UserRole(rawValue:role) {
                return result
            }
            return .member
        }
        set {
            self.role = newValue.rawValue
        }
    }
    
    public var userStatus: UserStatus {
        get {
            if let status = status, let result = UserStatus(rawValue:status) {
                return result
            }
            return .active
        }
        set {
            self.status = newValue.rawValue
        }
    }
    
    public static func guestUser(id: String) -> User {
        let username = "guest_" + id.lowercased().suffix(5)
        return User(username: username, password: "", timeJoined: Date.secondsSince1970)
    }
    
    public var arabicUserRole: String {
        let userRole = self.userRole
        switch userRole {
        case .member:
            return "عضو"
        case .moderator:
            return "مشرف"
        case .admin:
            return "إداري"
        }
    }
    
    public var arabicUserStatus: String {
        let userStatus = self.userStatus
        switch userStatus {
        case .pending:
            return "معلَّق"
        case .active:
            return ""
        case .suspended:
            return "موقوف"
        }
    }
    
    public var moderatorOrAdmin: Bool {
        return userRole == .moderator || userRole == .admin
    }
    
    public var active: Bool {
        return userStatus == .active
    }
    
    public var userFullname: String {
        var result = fullname ?? ""
        if result.isVacant {
            result = username
        }
        return result
    }
    
    public var joinedDate: String {
        return Date.friendlyDateStringFrom(epochTime: TimeInterval(timeJoined))
    }
    
    public var loggedinDate: String {
        if let timeLoggedin = timeLoggedin {
            return Date.friendlyDateStringFrom(epochTime: TimeInterval(timeLoggedin))
        } else {
            return ""
        }
    }
    
    public var lastActiveTime: Int {
        return timeLoggedin ?? timeJoined
    }
    
    public var lastActiveDate: String {
        return Date.friendlyDateStringFrom(epochTime: TimeInterval(lastActiveTime))
    }
    
    public func nonReadMessages() async -> [Message]? {
        let result = await Message.messages(toUsername: username, nonReadOnly: true)
        if result.count > 0 {
            return result
        }
        return nil
    }
    
    public func messages() async -> [Message]? {
        let result = await Message.messages(toUsername: username)
        if result.count > 0 {
            return result
        }
        return nil
    }
    
    // MARK: - Factory methods
    
    public static func createWith(username: String) -> User {
        return User(username: username, password: "", timeJoined: Date.secondsSince1970)
    }

    public static func userWith(username: String) async -> User? {
        if let user: User = await database.value(forKey: prefix + username) {
            return user
        } else {
            return nil
        }
    }
    
    // MARK: - Reading data

    public static func users(withUsernamePrefix usernamePrefix: String) async -> [User] {
        var result = [User]()
        await database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: prefix + usernamePrefix) { (key, user: User, stop) in
            if user.userStatus != .suspended {
                result.append(user)
            }
        }
        return result
    }
    
    public static func users(withSearchText searchText: String? = nil, count: Int? = nil) async -> [User] {
        var result = [User]()
        await database.enumerateKeysAndValues(backward: false, andPrefix: prefix) { (key, user: User, stop) in
            if let count = count {
                if result.count < count {
                    result.append(user)
                } else {
                    stop.pointee = true
                }
            } else {
                result.append(user)
            }
        }
        let sortedResult = result.sorted { $0.lastActiveTime > $1.lastActiveTime }
        return sortedResult
    }
    
    public static func newUsers() async -> [User] {
        var result = [User]()
        await database.enumerateKeysAndValues(backward: false, andPrefix: prefix) { (key, user: User, stop) in
            if user.viewed != true {
                result.append(user)
            }
        }
        return result
    }
    
    // MARK: - updating data

    public func update(location: String, bio: String, url: String) -> User {
        var result = self
        result.location = location
        result.bio = bio
        result.url = url
        return result
    }

    public func save() async {
        try? await database.setValue(self, forKey: User.prefix + username)
    }
    
    public func delete() async {
        await database.removeValue(forKey: key)
    }
    
    // MARK: - Delegates

    public func hash(into hasher: inout Hasher) {
        hasher.combine(username)
    }
    
    // MARK: - Public static functions

    public static func usernameExists(_ username: String) async -> Bool {
        if let _: User = await database.value(forKey: User.prefix + username) {
            return true
        } else {
            return false
        }
    }
    
}

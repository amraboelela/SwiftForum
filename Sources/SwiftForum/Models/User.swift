//
//  User.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation
import SwiftLevelDB

public enum UserRole: String, Codable {
    case member
    case moderator
    case admin
}

public enum UserStatus: String, Codable {
    case pending // pending membership when a user first register.
    case active
    case suspended
}

public struct User: Codable, Hashable {
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

    // MARK: - Accessors

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
    
    public var nonReadMessages: [Message]? {
        let result = Message.messages(toUsername: username, nonReadOnly: true)
        if result.count > 0 {
            return result
        }
        return nil
    }
    
    public var messages: [Message]? {
        let result = Message.messages(toUsername: username)
        if result.count > 0 {
            return result
        }
        return nil
    }
    
    // MARK: - Factory methods
    
    public static func createWith(username: String) -> User {
        return User(username: username, password: "", timeJoined: Date.now)
    }

    public static func userWith(username: String) -> User? {
        if let user: User = forumDB[prefix + username] {
            return user
        } else {
            return nil
        }
    }

    // MARK: - Data handling

    public func update(location: String, bio: String, url: String) -> User {
        var result = self
        result.location = location
        result.bio = bio
        result.url = url
        return result
    }

    // MARK: - Delegates

    public func hash(into hasher: inout Hasher) {
        hasher.combine(username)
    }
    
    // MARK: - Public functions

    public static func usernameExists(_ username: String) -> Bool {
        if let _: User = forumDB[User.prefix + username] {
            return true
        } else {
            return false
        }
    }
    
    public static func users(withUsernamePrefix usernamePrefix: String) -> [User] {
        var result = [User]()
        forumDB.enumerateKeysAndValues(backward: false, startingAtKey: nil, andPrefix: prefix + usernamePrefix) { (key, user: User, stop) in
            if user.userStatus != .suspended {
                result.append(user)
            }
        }
        return result
    }
    
}

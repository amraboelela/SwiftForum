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

public struct User: Codable, Hashable {
    public static let prefix = "user-"
    public static let avatars = "avatars"
    
    public var username: String
    public var password: String
    public var timeJoined: Int
    public var role: String?
    public var timeLoggedin: Int?
    public var fullname: String?
    public var bio: String?
    public var location: String?
    public var url: String?
    public var avatar: String?
    public var suspended: Bool?

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
    
    // MARK: - Factory methods
    
    public static func createWith(username: String) -> User {
        return User(username: username, password: "", timeJoined: Date.now)
    }

    public static func userWith(username: String) -> User {
        if let user: User = forumDB[prefix + username] {
            return user
        } else {
            return createWith(username: username)
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
            if !(user.suspended == true) {
                result.append(user)
            }
        }
        return result
    }
    
}

//
//  User.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation
import SwiftLevelDB

public enum UserRole: String {
    case regular
    case moderator
    case admin
}

public struct User: Codable, Hashable {
    public static let prefix = "user-"

    public static let avatars = "avatars"

    public var username: String
    public var rawRole: String
    public var password: String
    public var timeJoined: Int
    public var bio: String?
    public var location: String?
    public var url: String?
    public var avatar: String?
    public var isSuspended: Bool?

    enum CodingKeys : String, CodingKey {
        case username = "u"
        case rawRole = "r"
        case password = "p"
        case timeJoined = "t"
        case bio
        case location
        case url
        case avatar
        case isSuspended
    }

    // MARK: - Accessors

    public var role: UserRole {
        get {
            if let result = UserRole(rawValue:rawRole) {
                return result
            }
            return .regular
        }
        set {
            self.rawRole = newValue.rawValue
        }
    }

    // MARK: - Static functions
    
    public static func createWith(username: String) -> User {
        return User(username: username, rawRole: UserRole.regular.rawValue, password: "", timeJoined: Date.now)
    }

    public static func userWith(username: String) -> User {
        if let user: User = swiftForumDB[prefix + username] {
            return user
        } else {
            return User(username: username, rawRole: UserRole.regular.rawValue, password: "", timeJoined: Date.now)
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
        if let _: User = swiftForumDB[User.prefix + username] {
            return true
        } else {
            return false
        }
    }
    
    public static func users(withUsernamePrefix usernamePrefix: String) -> [User] {
        var result = [User]()
        swiftForumDB.enumerateKeysAndValues(backward: false, startingAtKey: nil, andPrefix: prefix + usernamePrefix) { (key, user: User, stop) in
            if !(user.isSuspended == true) { //blockedUsernames.contains(user.username) {
                result.append(user)
            }
        }
        return result
    }
    
}

//
//  User.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation

public enum UserStatus : String {
    case pending
    case error
    case active
    case reported
    case blocked
    
    case unknown
}

public struct User: Codable, Hashable {
    public static let prefix = "user-"

    public static let numberOfUsersToLoad = 90126
    public static let avatars = "avatars"

    private static let currentUsernameKey = "currentusername"

    public var username: String?
    public var rawStatus: String?
    public var time: Int?
    //public var privateKey: String?
    public var fullname: String?
    public var bio: String?
    public var location: String?
    public var url: String?
    public var avatar: String?
    //public var followers: [String]?
    //public var followees: [String]?
    public var blockedBy: [String]?
    public var reportedBy: [String]?

    enum CodingKeys : String, CodingKey {
        case username = "u"
        case rawStatus = "s"
        case time = "t"
        //case privateKey = "pk"
        case fullname
        case bio
        case location
        case url
        case avatar
        //case followers = "fr"
        //case followees = "fe"
        case blockedBy = "bb"
        case reportedBy = "rb"
    }

    // MARK: - Accessors

    /*public var status: UserStatus {
        get {
            if let rawStatus = rawStatus, let result = UserStatus(rawValue:rawStatus) {
                return result
            }
            return .unknown
        }
        set {
            self.rawStatus = newValue.rawValue
        }
    }*/

    public static var currentUser: User? {
        get {
            if let currentUser: User = swiftForumDB[currentUsernameKey] {
                return currentUser
            } else {
                //let user = guestUser
                //swiftForumDB[currentUsernameKey] = guestUser
                return nil
            }
        }
        set {
            swiftForumDB[currentUsernameKey] = newValue
            swiftForumDB[User.prefix + User.currentUsername] = newValue
        }
    }

    public static var currentUsername: String {
        get {
            return currentUser?.username ?? ""
        }
    }

    /*public static var guestUser: User {
        return User(username: "guest_" + myDevice.id.lowercased().suffix(5))
    }

    public static var isCurrentUserGuest: Bool {
        get {
            return currentUsername == guestUser.username
        }
    }

    public static var followees: Set<String> {
        if let user: User = swiftForumDB[currentUsernameKey], let followees = user.followees {
            return Set(followees)
        }
        return Set<String>()
    }*/

    // MARK: - Static functions
    
    public static func createWith(username: String) -> User {
        return User(username: username)
    }

    public static func isGuest(username: String) -> Bool {
        if username.count != 11 {
            return false
        }
        if username.prefix(6) != "guest_" {
            return false
        }
        let hexSet = CharacterSet(charactersIn: "0123456789abcdef")
        if username.suffix(5).rangeOfCharacter(from: hexSet.inverted) != nil {
            return false
        }
        return true
    }

    public static func userWith(username: String) -> User {
        if let user: User = swiftForumDB[prefix + username] {
            return user
        } else {
            return User(username: username)
        }
    }

    public static func blocked(user: User) -> Bool {
        if let blockedBy = user.blockedBy, blockedBy.contains(currentUsername) {
            return true
        } else {
            return false
        }
    }

    public static func block(user: User) -> User {
        var result = user
        if let blockedBy = user.blockedBy, !blockedBy.contains(currentUsername) {
            result.blockedBy?.append(currentUsername)
        } else {
            result.blockedBy = [currentUsername]
        }
        return result
    }

    public static func unblock(user: User) -> User {
        var result = user
        if let blockedBy = user.blockedBy, blockedBy.contains(currentUsername) {
            result.blockedBy?.removeAll { $0 == currentUsername }
        }
        return result
    }

    public static func report(user: User) -> User {
        var result = user
        if let reportedBy = user.reportedBy, reportedBy.contains(currentUsername) {
            result.reportedBy?.append(currentUsername)
        } else {
            result.reportedBy = [currentUsername]
        }
        return result
    }

    public static func unreport(user: User) -> User {
        var result = user
        if let reportedBy = user.reportedBy, reportedBy.contains(currentUsername) {
            result.reportedBy?.removeAll { $0 == currentUsername }
        }
        return result
    }

    public static func reported(user: User) -> Bool {
        if let reportedBy = user.reportedBy, reportedBy.contains(currentUsername) {
            return true
        } else {
            return false
        }
    }

    // MARK: - Data handling

    public func update(fullname: String, location: String, bio: String, url: String) -> User {
        var result = self
        result.fullname = fullname
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
        let blockedUsers = User.blockedUsers
        var result = [User]()
        let blockedUsernames = blockedUsers.map { $0.username }
        swiftForumDB.enumerateKeysAndValues(backward: false, startingAtKey: nil, andPrefix: prefix + usernamePrefix) { (key, user: User, stop) in
            if !blockedUsernames.contains(user.username) {
                result.append(user)
            }
        }
        return result
    }

    public static var blockedUsers: [User] {
        var result = [User]()
        swiftForumDB.enumerateKeysAndValues(backward: false, startingAtKey: nil, andPrefix: prefix) { (key, user: User, stop) in
            result.append(user)
        }
        result.removeAll { user in
            if User.blocked(user: user) {
                return false
            }
            return true
        }
        return result
    }

    /*public static func isFollowingUser(withUsername username: String) -> Bool {
        if let followees = currentUser.followees, followees.contains(username) {
            return true
        }
        return false
    }
    
    public static func followUser(withUsername username: String) {
        if var user: User = swiftForumDB[User.prefix + username] {
            if let followers = user.followers {
                var followersSet = Set(followers)
                followersSet.insert(User.currentUsername)
                user.followers = Array(followersSet)
            } else {
                user.followers = [User.currentUsername]
            }
            swiftForumDB[User.prefix + username] = user
        }
        addFollowee(withUsername: username)
    }
    
    public static func unfollowUser(withUsername username: String) {
        if var user: User = swiftForumDB[User.prefix + username] {
            if var followers = user.followers {
                followers.remove(object: User.currentUsername)
                if followers.count > 0 {
                    user.followers = followers
                } else {
                    user.followers = nil
                }
            }
            swiftForumDB[User.prefix + username] = user
        }
        removeFollowee(withUsername: username)
    }*/
    
    // MARK: - Private functions

    /*static func addFollowee(withUsername username: String) {
        var user = User.currentUser
        if let followees = user.followees {
            var followeesSet = Set(followees)
            followeesSet.insert(username)
            user.followees = Array(followeesSet)
        } else {
            user.followees = [username]
        }
        User.currentUser = user
    }

    static func removeFollowee(withUsername username: String) {
        var user = User.currentUser
        if var followees = user.followees {
            followees.remove(object: username)
            if followees.count > 0 {
                user.followees = followees
            } else {
                user.followees = nil
            }
        }
        User.currentUser = user
    }*/
}

//
//  Post.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation
import SwiftLevelDB

public struct Post: Codable {
    public static let prefix = "post-"
    public static var numberOfReports = 0

    public var time: Int
    public var username: String
    public var message: String
    public var parent: String? // parent key
    public var children: [String]? // children post keys
    public var replyTo: String? // reply to post key
    public var closed: Bool?
    public var isPrivate: Bool?
    public var pinned: Bool?
    public var reportedBy: [String]? // usernames
    
    // MARK: - Accessors
    
    public static var lastKey: String {
        var result = ""
        forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: prefix) { (key, post: Post, stop) in
            result = key
            stop.pointee = true
        }
        return result
    }

    static var firstKey: String? {
        var result : String?
        forumDB.enumerateKeys(backward: false, startingAtKey: nil, andPrefix: prefix) { key, stop in
            result = key
            stop.pointee = true
        }
        return result
    }
    
    public static var firstPostTime: Int? {
        return time(fromPostKey: firstKey)
    }
    
    public static var lastPostTime: Int? {
        return time(fromPostKey: lastKey)
    }

    public var key: String {
        return Post.prefix + "\(time)-" + username
    }

    public var parentPost: Post? {
        if let parentKey = parent, let post: Post = forumDB[parentKey] {
            return post
        }
        return nil
    }
    
    public var postDate: String {
        return Date.friendlyDateStringFrom(epochTime: TimeInterval(time))
    }
    
    // MARK: - Factory methods
    
    public static func createWith(username: String, message: String) -> Post {
        return Post(time: Date.now, username: username, message: message)
    }

    public static func postWith(time: Int, username: String) -> Post? {
        let postKey = prefix + "\(time)" + "-" + username
        return postWith(key: postKey)
    }
    
    public static func postWith(key: String) -> Post? {
        if let post: Post = forumDB[key] {
            return post
        }
        return nil
    }
    
    // MARK: - Reading data

    public static func posts(
        withSearchText searchText: String,
        time: Int? = nil,
        before: Bool = true,
        parentsOnly: Bool = false,
        includePrivate: Bool = false,
        count: Int
    ) -> [Post] {
        var result = [Post]()
        let searchWords = Word.words(fromText: searchText)
        if let firstWord = searchWords.first {
            var wordPostKeys = [String]()
            forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: Word.prefix + firstWord) { (key, word: Word, stop) in
                if time == nil {
                    wordPostKeys.append(word.postKey)
                } else if let time = time {
                    if before {
                        if Word.time(fromKey: key) <= time {
                            wordPostKeys.append(word.postKey)
                        }
                    } else {
                        if Word.time(fromKey: key) >= time {
                            wordPostKeys.append(word.postKey)
                        }
                    }
                }
            }
            for wordPostKey in wordPostKeys {
                var foundTheSearch = true
                if let post: Post = forumDB[wordPostKey] {
                    for i in 1..<searchWords.count {
                        let searchWord = searchWords[i]
                        if post.message.lowercased().range(of: searchWord) == nil {
                            foundTheSearch = false
                            break
                        }
                    }
                    if foundTheSearch {
                        result.append(post)
                    }
                }
            }
            result = result.sorted { $0.time > $1.time }
            if result.count > count {
                result.removeLast(result.count - count)
            }
        } else {
            //logger.log("getPosts, searchText is empty")
            var startAtKey: String? = nil
            if let time = time {
                startAtKey = prefix + "\(time)"
            }
            if parentsOnly {
                var parentsKeys = [String]()
                forumDB.enumerateKeysAndValues(backward: before, startingAtKey: startAtKey, andPrefix: prefix) { (key, post: Post, stop) in
                    if parentsKeys.count < count {
                        if includePrivate || (!includePrivate && post.isPrivate != true) {
                            let parentKey = post.parent ?? post.key
                            if !parentsKeys.contains(parentKey) {
                                parentsKeys.append(parentKey)
                            }
                        }
                    } else {
                        stop.pointee = true
                    }
                }
                for parentKey in parentsKeys {
                    if let post: Post = forumDB[parentKey] {
                        if includePrivate || (!includePrivate && post.isPrivate != true) {
                            result.append(post)
                        }
                    }
                }
                result = result.sorted { post1, post2 in
                    if post1.pinned == true && post2.pinned != true {
                        return true
                    }
                    if post1.pinned != true && post2.pinned == true {
                        return false
                    }
                    return post1.time > post1.time
                }
            } else {
                forumDB.enumerateKeysAndValues(backward: before, startingAtKey: startAtKey, andPrefix: prefix) { (key, post: Post, stop) in
                    if result.count < count {
                        result.append(post)
                    } else {
                        stop.pointee = true
                    }
                }
            }
            
        }
        return result
    }

    // if this post is a child then show parent and siblings starting from current child
    public func childPosts(withSearchText searchText: String? = nil, count: Int, before: Bool = false, activeUsersOnly: Bool) -> [Post] {
        var result = [Post]()
        let theChildPosts = childPosts(count: count, before: before, activeUsersOnly: activeUsersOnly)
        let searchWords = Word.words(fromText: searchText ?? "")
        if let firstWord = searchWords.first {
            var wordPostKeys = [String]()
            forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: Word.prefix + firstWord) { (key, word: Word, stop) in
                wordPostKeys.append(word.postKey)
            }
            for wordPostKey in wordPostKeys {
                var foundTheSearch = true
                if let post: Post = forumDB[wordPostKey] {
                    for i in 1..<searchWords.count {
                        let searchWord = searchWords[i]
                        if post.message.lowercased().range(of: searchWord) == nil {
                            foundTheSearch = false
                            break
                        }
                    }
                    if foundTheSearch {
                        result.append(post)
                    }
                }
            }
            result = result.sorted { $0.time > $1.time }
            let childPostsKeys = theChildPosts.map { $0.key }
            result = result.filter { childPostsKeys.contains($0.key) }
            if result.count > count {
                result.removeLast(result.count - count)
            }
        } else {
            return theChildPosts
        }
        return result
    }
    
    // if this post is a child then show parent and siblings starting from current child
    private func childPosts(count: Int, before: Bool = false, activeUsersOnly: Bool) -> [Post] {
        var result = [Post]()
        if let parentPost = parentPost {
            if let childrenKeys = parentPost.children, let childIndex = childrenKeys.firstIndex(of: self.key) {
                if before {
                    let firstIndex = (childIndex - count > 0) ? childIndex - count : 0
                    for i in firstIndex..<childrenKeys.count {
                        if result.count < count {
                            if let childPost = Post.postWith(key: childrenKeys[i]) {
                                if !activeUsersOnly {
                                    result.append(childPost)
                                } else if childPost.username == parentPost.username {
                                    result.append(childPost)
                                } else if let user = User.userWith(username: childPost.username), user.userStatus == .active {
                                    result.append(childPost)
                                }
                            }
                        } else {
                            break
                        }
                    }
                } else {
                    for i in childIndex..<childrenKeys.count {
                        if result.count < count {
                            if let childPost = Post.postWith(key: childrenKeys[i]) {
                                if !activeUsersOnly {
                                    result.append(childPost)
                                } else if childPost.username == parentPost.username {
                                    result.append(childPost)
                                } else if let user = User.userWith(username: childPost.username), user.userStatus == .active {
                                    result.append(childPost)
                                }
                            }
                        } else {
                            break
                        }
                    }
                }
            }
        } else {
            if let childrenKeys = children {
                for childKey in childrenKeys {
                    if result.count < count {
                        if let childPost = Post.postWith(key: childKey) {
                            if !activeUsersOnly {
                                result.append(childPost)
                            } else if childPost.username == parentPost.username {
                                result.append(childPost)
                            } else if let user = User.userWith(username: childPost.username), user.userStatus == .active {
                                result.append(childPost)
                            }
                        }
                    } else {
                        break
                    }
                }
            }
        }
        return result
    }
    
    public static func posts(withHashtagOrMention hashtagOrMention: String, searchText: String? = nil, beforePostTime: Int? = nil, count: Int) -> [Post] {
        var result = [Post]()
        
        var postKeys = [String]()
        if let searchText = searchText, !searchText.isEmpty {
            if let beforePostTime = beforePostTime {
                forumDB.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if !postKeys.contains(hashtagOrMention.postKey) {
                        postKeys.append(hashtagOrMention.postKey)
                    }
                }
            } else {
                forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    postKeys.append(hashtagOrMention.postKey)
                }
            }
            postKeys = postKeys.sorted { $0 > $1 }
            for postKey in postKeys {
                if let post: Post = forumDB[postKey] {
                    let theTextSearch = searchText.lowercased()
                    if post.message.lowercased().range(of: theTextSearch) != nil {
                        if result.count < count {
                            result.append(post)
                        } else {
                            break
                        }
                    }
                }
            }
        } else {
            if let beforePostTime = beforePostTime {
                forumDB.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if postKeys.count < count {
                        if !postKeys.contains(hashtagOrMention.postKey) {
                            postKeys.append(hashtagOrMention.postKey)
                        }
                    } else {
                        stop.pointee = true
                    }
                }
            } else {
                forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if postKeys.count < count {
                        if !postKeys.contains(hashtagOrMention.postKey) {
                            postKeys.append(hashtagOrMention.postKey)
                        }
                    } else {
                        stop.pointee = true
                    }
                }
            }
            postKeys = postKeys.sorted { $0 > $1 }
            for postKey in postKeys {
                if let post: Post = forumDB[postKey] {
                    result.append(post)
                }
            }
        }
        return result
    }

    public static func posts(forUsername username: String, searchText: String = "", count: Int) -> [Post] {
        var result = [Post]()
        var postKeys = [String]()
        var postKeySet = Set<String>()
        if searchText == "" {
            forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
                if postKeys.count < count {
                    if !postKeySet.contains(userPost.postKey) {
                        postKeySet.insert(userPost.postKey)
                        postKeys.append(userPost.postKey)
                    }
                } else {
                    stop.pointee = true
                }
            }
            for postKey in postKeys {
                if let post: Post = forumDB[postKey] {
                    result.append(post)
                }
            }
        } else {
            let theTextSearch = searchText.lowercased()
            var userPostKeys = [String]()
            forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
                userPostKeys.append(userPost.postKey)
            }
            for userPostKey in userPostKeys {
                if let post: Post = forumDB[userPostKey], post.message.lowercased().range(of: theTextSearch) != nil {
                    if result.count < count {
                        result.append(post)
                    } else {
                        break
                    }
                }
            }
            
        }
        return result
    }

    public static func posts(forUsernameOrMention username: String, searchText: String = "", count: Int) -> [Post] {
        var result = posts(forUsername: username, searchText: searchText, count: count)
        let result2 = posts(withHashtagOrMention: "@" + username, searchText: searchText, count: count)
        result.append(contentsOf: result2)
        result = result.sorted { $0.time > $1.time }
        if result.count > count {
            result.removeLast(result.count - count)
        }
        return result
    }
    
    public func pagePost(pageSize: Int) -> Post {
        var childrenKeys = [String]()
        if let children = self.children {
            childrenKeys = children
        } else if let theParentPost = self.parentPost, let theChildrenKeys = theParentPost.children {
            childrenKeys = theChildrenKeys
            var postIndex = 0
            if let theIndex = childrenKeys.firstIndex(of: self.key), theIndex > 0 {
                postIndex = theIndex - 1
            }
            let pageNumber = postIndex / pageSize
            let postKey = childrenKeys[pageNumber * pageSize]
            if let post = Post.postWith(key: postKey) {
                return post
            }
        }
        if childrenKeys.count > pageSize {
            var lastPageSize = childrenKeys.count % pageSize
            if lastPageSize == 0 {
                lastPageSize = pageSize
            }
            let lastPagePostKey = childrenKeys[childrenKeys.count - lastPageSize]
            if let lastPagePost = Post.postWith(key: lastPagePostKey) {
                return lastPagePost
            }
        }
        return self
    }
    
    // MARK: - Updating data
    
    public mutating func addChild(postKey: String) {
        if children == nil {
            children = [String]()
        }
        if children?.contains(postKey) == false {
            children?.append(postKey)
        }
    }
    
    public func save() {
        let postKey = Post.prefix + "\(time)-" + username
        forumDB[postKey] = self
        if isPrivate == true || parentPost?.isPrivate == true {
            return // do not index private "admin" posts
        }
        let userPostKey = UserPost.prefix + username + "-\(time)"
        forumDB[userPostKey] = UserPost(postKey: postKey)
        for hashtag in message.hashtags {
            forumDB[hashtag + "-\(time)-" + username] = HashtagOrMention(postKey: postKey)
        }
        for mention in message.mentions {
            forumDB[mention + "-\(time)-" + username] = HashtagOrMention(postKey: postKey)
        }
        for word in Word.words(fromText: message) {
            forumDB[Word.prefix + word + "-\(time)-" + username] = Word(postKey: postKey)
        }
    }
    
    public func delete() {
        //print("delete: \(key)")
        if let children = children {
            //print("delete: let children = children")
            for childKey in children {
                forumDB.removeValueForKey(childKey)
            }
        } else if var parentPost = parentPost {
            //print("delete: parentPost: \(parentPost)")
            parentPost.children = parentPost.children?.filter { $0 != key }
            parentPost.save()
        }
        //print("delete: removeValueForKey: \(key)")
        forumDB.removeValueForKey(key)
    }
    
    // MARK: - Public functions
    
    public static func key(ofPost post: Post) -> String {
        return prefix + "\(post.time)-" + post.username
    }
    
    public static func username(fromPostKey postKey: String) -> String {
        let arr = postKey.components(separatedBy: "-")
        var result = ""
        if arr.count > 2 {
            result = arr[2]
        }
        return result
    }
    
    public static func time(fromPostKey postKey: String?) -> Int {
        var result = 0
        if let postKey = postKey {
            let arr = postKey.components(separatedBy: "-")
            if arr.count > 1 {
                result = Int(arr[1]) ?? 0
            }
        }
        return result
    }
    
    public static func posts(forKeys keys: [String]) -> [Post] {
        var result = [Post]()
        for postKey in keys {
            if let post: Post = forumDB[postKey] {
                result.append(post)
            }
        }
        return result
    }
    
}

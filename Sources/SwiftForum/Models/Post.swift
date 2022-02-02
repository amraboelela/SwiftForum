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
    public var parentKey: String?
    public var childrenKeys: [String]? // children post keys
    public var replyToPostKey: String? // reference post key
    public var isClosed: Bool?
    public var isDeleted: Bool?
    public var reportedBy: [String]? // usernames
    
    public enum CodingKeys: String, CodingKey {
        case time = "t"
        case username = "u"
        case message = "msg"
        case parentKey = "pk"
        case childrenKeys = "ck"
        case replyToPostKey = "rtpk"
        case isClosed
        case isDeleted
        case reportedBy
    }
    
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

    public var parent: Post? {
        if let parentKey = parentKey, let post: Post = forumDB[parentKey] {
            return post
        }
        return nil
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
    
    // MARK: - Updating data
    
    public mutating func addChild(postKey: String) {
        if childrenKeys == nil {
            childrenKeys = [String]()
        }
        if childrenKeys?.contains(postKey) == false {
            childrenKeys?.append(postKey)
        }
    }
    
    // MARK: - Reading data

    public static func posts(withSearchText searchText: String, time: Int? = nil, before: Bool = true, parentsOnly: Bool = false, count: Int) -> [Post] {
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
                        if !(post.isDeleted == true) {
                            result.append(post)
                        }
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
                        if !(post.isDeleted == true) && !(post.parent?.isDeleted == true) {
                            let parentKey = post.parentKey ?? post.key
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
                        result.append(post)
                    }
                }
            } else {
                forumDB.enumerateKeysAndValues(backward: before, startingAtKey: startAtKey, andPrefix: prefix) { (key, post: Post, stop) in
                    if result.count < count {
                        if !(post.isDeleted == true) {
                            result.append(post)
                        }
                    } else {
                        stop.pointee = true
                    }
                }
            }
            
        }
        return result
    }

    // if this post is a child then show parent and siblings starting from current child
    public func childPosts(withSearchText searchText: String, count: Int) -> [Post] {
        var result = [Post]()
        let searchWords = Word.words(fromText: searchText)
        if let firstWord = searchWords.first {
            var wordPostKeys = [String]()
            forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: Word.prefix + firstWord) { (key, word: Word, stop) in
                if Word.time(fromKey: key) >= time {
                    wordPostKeys.append(word.postKey)
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
                        if !(post.isDeleted == true) {
                            result.append(post)
                        }
                    }
                }
            }
            result = result.sorted { $0.time > $1.time }
            if result.count > count {
                result.removeLast(result.count - count)
            }
        } else {
            if let parent = parent {
                //result.append(parent)
                if let childrenKeys = parent.childrenKeys, let childIndex = childrenKeys.firstIndex(of: self.key) {
                    for i in childIndex..<childrenKeys.count {
                        if result.count < count {
                            if let childPost = Post.postWith(key: childrenKeys[i]), !(childPost.isDeleted == true) {
                                result.append(childPost)
                            }
                        } else {
                            break
                        }
                    }
                }
            } else {
                //result.append(self)
                if let childrenKeys = childrenKeys {
                    for childKey in childrenKeys {
                        if result.count < count {
                            if let childPost = Post.postWith(key: childKey), !(childPost.isDeleted == true) {
                                result.append(childPost)
                            }
                        } else {
                            break
                        }
                    }
                }
            }
        }
        return result
    }
    
    public static func posts(withHashtagOrMention hashtagOrMention: String, searchText: String? = nil, beforePostTime: Int? = nil, count: Int) -> [Post] {
        var result = [Post]()
        
        var mentionPostKeys = [String]()
        if let searchText = searchText, !searchText.isEmpty {
            if let beforePostTime = beforePostTime {
                forumDB.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    mentionPostKeys.append(hashtagOrMention.postKey)
                }
            } else {
                forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    mentionPostKeys.append(hashtagOrMention.postKey)
                }
            }
            for mentionPostKey in mentionPostKeys {
                if let post: Post = forumDB[mentionPostKey] {
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
                    if mentionPostKeys.count < count {
                        mentionPostKeys.append(hashtagOrMention.postKey)
                    } else {
                        stop.pointee = true
                    }
                }
            } else {
                forumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if mentionPostKeys.count < count {
                        mentionPostKeys.append(hashtagOrMention.postKey)
                    } else {
                        stop.pointee = true
                    }
                }
            }
            for mentionPostKey in mentionPostKeys {
                if let post: Post = forumDB[mentionPostKey] {
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
            var startingAtKey: String? = nil
            /*if let beforePostID = beforePostID {
                startingAtKey = UserPost.prefix + username + "-" + beforePostID
            }*/
            forumDB.enumerateKeysAndValues(backward: true, startingAtKey: startingAtKey, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
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

    // MARK: - Saving data
    
    public func save() {
        let postKey = Post.prefix + "\(time)-" + username
        let userPostKey = UserPost.prefix + username + "-\(time)"
        forumDB[userPostKey] = UserPost(postKey: postKey)
        forumDB[postKey] = self
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

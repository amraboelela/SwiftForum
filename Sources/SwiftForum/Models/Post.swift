//
//  Post.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 12/16/19.
//  Copyright © 2019 Amr Aboelela. All rights reserved.
//

import Foundation

public struct PostsContainer: Codable {
    public var posts: [Post]
}

public struct PostReference: Codable {
    public var username: String
    public var id: String
    
    public enum CodingKeys: String, CodingKey {
        case username = "u"
        case id = "k"
    }
}

public struct Post: Codable {
    public static let prefix = "post-"
    public static var posts = [Post]()

    static var newPostsLastFileSize = 0
    
    public var username: String
    public var message: String?
    public var urlContent: String?
    public var id: String?
    public var time: Int?
    public var replyTo: PostReference?
    public var replies: [PostReference]?
    public var reposted: PostReference?
    public var isNew: Bool?
    public var signature: String?
    public var lastK: Int?
    public var height: Int?
    public var translation: [String:String]?
    
    public enum CodingKeys: String, CodingKey {
        case username = "u"
        case message = "msg"
        case urlContent
        case id = "k"
        case time = "t"
        case replyTo = "r"
        case replies = "rs"
        case reposted = "rt"
        case isNew = "in"
        case signature = "sig"
        case lastK
        case height
        case translation
    }
    
    public static func postKey(forUsername username: String, postID: String) -> String? {
        let key = UserPost.prefix + username + "-" + zeroPaddedPostID(postID)
        if let userPost: UserPost = database[key] {
            return userPost.postKey
        }
        return nil
    }
    
    static func zeroPaddedPostID(_ postID: String) -> String {
        return String(format: "%010d", Int(postID) ?? 0)
    }
    
    // MARK: - Accessors
    
    public static var lastKey: String {
        var result = ""
        database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: prefix) { (key, post: Post, stop) in
            if post.isNew == true {
                print("post at key: \(key) is news")
            } else {
                result = key
                stop.pointee = true
            }
        }
        return result
    }

    static var firstKey: String? {
        var result : String?
        database.enumerateKeys(backward: false, startingAtKey: nil, andPrefix: prefix) { key, stop in
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
        return Post.prefix + "\(time ?? 0)-" + username
    }
    
    public var repliesThread: [Post] {
        var result = self.replyToPosts
        var currentPost = self
        if let postTime = self.time {
            let postKey = Post.prefix + "\(postTime)-" + self.username
            if let thePost: Post = database[postKey] {
                currentPost = thePost
            }
        }
        result.append(currentPost)
        result.append(contentsOf: self.replyPosts)
        return result
    }
    
    var replyToPosts: [Post] {
        var result = [Post]()
        var currentPost = self
        while true {
            if let reply = currentPost.replyTo {
                if let postKey = Post.postKey(forUsername: reply.username, postID: reply.id), let post: Post = database[postKey] {
                    result.append(post)
                    currentPost = post
                    continue
                } else {
                    result.append(Post(username: reply.username, id: reply.id))
                }
            }
            break
        }
        return result.reversed()
    }
     
    var replyPosts: [Post] {
        var result = [Post]()
        if let replies = self.replies {
            if replies.count > 0 {
                for reply in replies {
                    if let postKey = Post.postKey(forUsername: reply.username, postID: reply.id), let thePost: Post = database[postKey] {
                        result.append(thePost)
                        result.append(contentsOf: (thePost.replyPosts))
                    } else {
                        result.append(Post(username: reply.username, id: reply.id))
                    }
                }
            }
        }
        return result
    }

    // MARK: - Reading data
    
    public static func with(username: String, time: Int? = 0) -> Post {
        return Post(username: username, time: time)
    }

    public static func from(key: String) -> Post {
        return Post(username: username(fromPostKey: key), time: time(fromPostKey: key))
    }

    public static func posts(withSearchText searchText: String, time: Int? = nil, before: Bool = true, followeesOnly: Bool = false, count: Int) -> [Post] {
        let blockedUsers = User.blockedUsers
        var result = [Post]()
        let blockedUsernames = blockedUsers.map { $0.username }
        var followees: Set<String>?
        if followeesOnly {
            followees = User.followees
            if followees?.count == 0 {
                return result
            }
        }
        let searchWords = Word.words(fromText: searchText)
        if let firstWord = searchWords.first {
            var wordPostKeys = [String]()
            database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: Word.prefix + firstWord) { (key, word: Word, stop) in
                if time == nil {
                    if let followees = followees {
                        if followees.contains(self.username(fromPostKey: word.postKey)) {
                            wordPostKeys.append(word.postKey)
                        }
                    } else {
                        wordPostKeys.append(word.postKey)
                    }
                } else if let time = time {
                    if before {
                        if Word.time(fromKey: key) <= time {
                            if let followees = followees {
                                if followees.contains(self.username(fromPostKey: word.postKey)) {
                                    wordPostKeys.append(word.postKey)
                                }
                            } else {
                                wordPostKeys.append(word.postKey)
                            }
                        }
                    } else {
                        if Word.time(fromKey: key) >= time {
                            if let followees = followees {
                                if followees.contains(self.username(fromPostKey: word.postKey)) {
                                    wordPostKeys.append(word.postKey)
                                }
                            } else {
                                wordPostKeys.append(word.postKey)
                            }
                        }
                    }
                }
            }
            for wordPostKey in wordPostKeys {
                var foundTheSearch = true
                if let post: Post = database[wordPostKey], let message = post.message {
                    for i in 1..<searchWords.count {
                        let searchWord = searchWords[i]
                        if message.lowercased().range(of: searchWord) == nil {
                            foundTheSearch = false
                            break
                        }
                    }
                    if foundTheSearch {
                        if !blockedUsernames.contains(post.username) {
                            result.append(post)
                        }
                    }
                }
            }
            result = result.sorted { $0.time ?? 0 > $1.time ?? 0 }
            if result.count > count {
                result.removeLast(result.count - count)
            }
        } else {
            //logger.log("getPosts, searchText is empty")
            var startAtKey: String? = nil
            if let time = time {
                startAtKey = prefix + "\(time)"
            }
            database.enumerateKeysAndValues(backward: before, startingAtKey: startAtKey, andPrefix: prefix) { (key, post: Post, stop) in
                if let followees = followees {
                    if followees.contains(self.username(fromPostKey: key)) {
                        if result.count < count {
                            if !blockedUsernames.contains(post.username) {
                                result.append(post)
                            }
                        } else {
                            stop.pointee = true
                        }
                    }
                } else {
                    if result.count < count {
                        if !blockedUsernames.contains(post.username) {
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

    public static func posts(withHashtagOrMention hashtagOrMention: String, searchText: String? = nil, beforePostTime: Int? = nil, count: Int) -> [Post] {
        var result = [Post]()
        
        var mentionPostKeys = [String]()
        if let searchText = searchText, !searchText.isEmpty {
            if let beforePostTime = beforePostTime {
                database.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    mentionPostKeys.append(hashtagOrMention.postKey)
                }
            } else {
                database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    mentionPostKeys.append(hashtagOrMention.postKey)
                }
            }
            for mentionPostKey in mentionPostKeys {
                if let post: Post = database[mentionPostKey], let message = post.message {
                    let theTextSearch = searchText.lowercased()
                    if message.lowercased().range(of: theTextSearch) != nil {
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
                database.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if mentionPostKeys.count < count {
                        mentionPostKeys.append(hashtagOrMention.postKey)
                    } else {
                        stop.pointee = true
                    }
                }
            } else {
                database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if mentionPostKeys.count < count {
                        mentionPostKeys.append(hashtagOrMention.postKey)
                    } else {
                        stop.pointee = true
                    }
                }
            }
            for mentionPostKey in mentionPostKeys {
                if let post: Post = database[mentionPostKey] {
                    result.append(post)
                }
            }
        }
        return result
    }

    public static func posts(forUsername username: String, searchText: String = "", beforePostID: String? = nil, count: Int) -> [Post] {
        var result = [Post]()
        var postKeys = [String]()
        var postKeySet = Set<String>()
        if searchText == "" {
            var startingAtKey: String? = nil
            if let beforePostID = beforePostID {
                startingAtKey = UserPost.prefix + username + "-" + beforePostID
            }
            database.enumerateKeysAndValues(backward: true, startingAtKey: startingAtKey, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
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
                if let post: Post = database[postKey] {
                    result.append(post)
                }
            }
        } else {
            let theTextSearch = searchText.lowercased()
            var userPostKeys = [String]()
            database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
                userPostKeys.append(userPost.postKey)
            }
            for userPostKey in userPostKeys {
                if let post: Post = database[userPostKey], let message = post.message, message.lowercased().range(of: theTextSearch) != nil {
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

    public static func post(withUsername username: String, postID: String) -> Post? {
        if let postKey = self.postKey(forUsername: username, postID: postID) {
            if let post: Post = database[postKey] {
                return post
            }
        }
        return nil
    }

    // MARK: - Saving data
    
    public static func save(newPost: Post) {
        var theNewPost = newPost
        theNewPost.isNew = true
        _ = self.save(post: theNewPost)
    }
    
    public static func save(posts: [Post]) -> Int {
        var saveCount = 0
        for post in posts {
            if self.save(post: post) {
                saveCount+=1;
            }
        }
        return saveCount
    }
    
    // MARK: - Public functions
    
    public static func isRepostWithEmptyMessage(post: Post) -> Bool {
        /*if (post[PostRepository.reposted] as? [String:String]) != nil {
         let postMessage = post[PostRepository.message] as? String ?? ""
         if postMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  {
         return true
         }
         }*/
        return false
    }
    
    /*public func repostUsername(ofPost post: [String:Any]) -> String? {
     if let rt = post[PostRepository.reposted] as? [String:String], let rtUsername = rt[UserRepository.username] {
     return rtUsername
     }
     return nil
     }*/
    
    public static func updateTranslation(forPost post: Post, translation: [String:String]) {
        var aPost = post
        if var aTranslation = aPost.translation {
            for (key,value) in translation {
                aTranslation.updateValue(value, forKey:key)
            }
            aPost.translation = aTranslation
        } else {
            aPost.translation = translation
        }
        let key = self.key(ofPost: post)
        database[key] = aPost
    }
    
    public static func key(ofPost post: Post) -> String {
        return prefix + "\(post.time ?? 0)-" + post.username
    }
    
    public static func removeExtraFields(fromPosts posts: [Post]) -> [Post] {
        var result = [Post]()
        for var post in posts {
            post.signature = nil
            post.lastK = nil
            post.height = nil
            result.append(post)
        }
        return result
    }
    
    public static func save(post: Post) -> Bool {
        var thereAreNewPosts = false
        guard let k = post.id, let postTime = post.time, let postMessage = post.message else {
            logger.log("save post, couldn't get k or postTime or postMessage")
            return false
        }
        let u = post.username
        let postKey = prefix + "\(postTime)-" + u
        if let _: Post = database[postKey] {
        } else {
            thereAreNewPosts = true

            //logger.log("Saving: post with key: \(postKey)")
            let userPostKey = UserPost.prefix + post.username + "-" + zeroPaddedPostID(k)
            database[userPostKey] = UserPost(postKey: postKey)
            database[postKey] = post
            for hashtag in HashtagOrMention.hashtags(fromText: postMessage) {
                database[hashtag + "-\(postTime)-" + u] = HashtagOrMention(postKey: postKey)
            }
            for mention in HashtagOrMention.mentions(fromText: postMessage) {
                database[mention + "-\(postTime)-" + u] = HashtagOrMention(postKey: postKey)
            }
            for word in Word.words(fromText: postMessage) {
                database[Word.prefix + word + "-\(postTime)-" + u] = Word(postKey: postKey)
            }
        }
        return thereAreNewPosts
    }
    
    public static func username(fromPostKey postKey: String) -> String {
        let arr = postKey.components(separatedBy: "-")
        var result = ""
        if arr.count > 2 {
            result = arr[2]
        }
        return result
    }
    
    public static func time(fromPostKey postKey: String?) -> Int? {
        var result: Int?
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
            if let post: Post = database[postKey] {
                result.append(post)
            }
        }
        return result
    }
    
}

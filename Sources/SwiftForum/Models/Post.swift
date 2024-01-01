//
//  Post.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation
import SwiftLevelDB

public struct Post: Codable, Equatable, Sendable {
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
    public var numberOfViews: Int?
    
    // MARK: - Accessors
    
    public static func lastKey() async -> String {
        var result = ""
        await database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: prefix) { (key, post: Post, stop) in
            result = key
            stop.pointee = true
        }
        return result
    }

    static func firstKey() async -> String? {
        var result : String?
        await database.enumerateKeys(backward: false, startingAtKey: nil, andPrefix: prefix) { key, stop in
            result = key
            stop.pointee = true
        }
        return result
    }
    
    public static func firstPostTime() async -> Int? {
        return await time(fromPostKey: firstKey())
    }
    
    public static func lastPostTime() async -> Int? {
        return await time(fromPostKey: lastKey())
    }

    public var key: String {
        return Post.prefix + "\(time)-" + username
    }

    public func parentPost() async -> Post? {
        if let parentKey = parent, let post: Post = await database.value(forKey: parentKey) {
            return post
        }
        return nil
    }
    
    public func subjectPost() async -> Post {
        if let parentPost = await parentPost() {
            return parentPost
        }
        return self
    }
    
    public var postDate: String {
        return Date.friendlyDateStringFrom(epochTime: TimeInterval(time))
    }
    
    // MARK: - Factory methods
    
    public static func createWith(username: String, message: String) -> Post {
        return Post(time: Date.secondsSince1970, username: username, message: message)
    }

    public static func postWith(time: Int, username: String) async -> Post? {
        let postKey = prefix + "\(time)" + "-" + username
        return await postWith(key: postKey)
    }
    
    public static func postWith(key: String) async -> Post? {
        if let post: Post = await database.value(forKey: key) {
            NSLog("postWith: key: \(key), post: \(post)")
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
    ) async -> [Post] {
        var result = [Post]()
        let searchWords = Word.words(fromText: searchText)
        if let firstWord = searchWords.first {
            var wordPostKeys = [String]()
            await database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: Word.prefix + firstWord) { (key, word: Word, stop) in
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
                if let post: Post = await database.value(forKey: wordPostKey) {
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
            logger.log("getPosts, searchText is empty")
            var startAtKey: String? = nil
            if let time = time {
                startAtKey = prefix + "\(time)"
            }
            if parentsOnly {
                var parentsKeys = [String]()
                await database.enumerateKeysAndValues(backward: before, startingAtKey: startAtKey, andPrefix: prefix) { (key, post: Post, stop) in
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
                    if let post: Post = await database.value(forKey: parentKey) {
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
                await database.enumerateKeysAndValues(backward: before, startingAtKey: startAtKey, andPrefix: prefix) { (key, post: Post, stop) in
                    if result.count < count {
                        result.append(post)
                    } else {
                        stop.pointee = true
                    }
                }
            }
            
        }
        NSLog("posts: \(result)")
        return result
    }

    // if this post is a child then show parent and siblings starting from current child
    public func childPosts(withSearchText searchText: String? = nil, count: Int, before: Bool = false, activeUsersOnly: Bool, loggedinUsername: String) async -> [Post] {
        var result = [Post]()
        let searchWords = Word.words(fromText: searchText ?? "")
        if let firstWord = searchWords.first {
            let theChildPosts = await childPosts(count: children?.count ?? count, before: before, activeUsersOnly: activeUsersOnly, loggedinUsername: loggedinUsername)
            var wordPostKeys = [String]()
            await database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: Word.prefix + firstWord) { (key, word: Word, stop) in
                wordPostKeys.append(word.postKey)
            }
            for wordPostKey in wordPostKeys {
                var foundTheSearch = true
                if let post: Post = await database.value(forKey: wordPostKey) {
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
            return result
        } else {
            return await childPosts(count: count, before: before, activeUsersOnly: activeUsersOnly, loggedinUsername: loggedinUsername)
            //return theChildPosts
        }
    }
    
    // if this post is a child then show parent and siblings starting from current child
    private func childPosts(count: Int, before: Bool = false, activeUsersOnly: Bool, loggedinUsername: String) async -> [Post] {
        var result = [Post]()
        if let parentPost = await parentPost() {
            if let childrenKeys = parentPost.children, let childIndex = childrenKeys.firstIndex(of: self.key) {
                if before {
                    let firstIndex = (childIndex - count > 0) ? childIndex - count : 0
                    for i in firstIndex..<childrenKeys.count {
                        if result.count < count {
                            if let childPost = await Post.postWith(key: childrenKeys[i]) {
                                if !activeUsersOnly {
                                    result.append(childPost)
                                } else if childPost.username == loggedinUsername {
                                    result.append(childPost)
                                } else if let user = await User.userWith(username: childPost.username), user.userStatus == .active {
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
                            if let childPost = await Post.postWith(key: childrenKeys[i]) {
                                if !activeUsersOnly {
                                    result.append(childPost)
                                } else if childPost.username == loggedinUsername {
                                    result.append(childPost)
                                } else if let user = await User.userWith(username: childPost.username), user.userStatus == .active {
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
                        if let childPost = await Post.postWith(key: childKey) {
                            if !activeUsersOnly {
                                result.append(childPost)
                            } else if let user = await User.userWith(username: childPost.username), user.userStatus == .active {
                                result.append(childPost)
                            }
                        }
                    } else {
                        break
                    }
                }
            }
        }
        NSLog("childPosts, result: \(result)")
        return result
    }
    
    public static func posts(withHashtagOrMention hashtagOrMention: String, searchText: String? = nil, beforePostTime: Int? = nil, count: Int) async -> [Post] {
        var result = [Post]()
        
        var postKeys = [String]()
        if let searchText = searchText, !searchText.isEmpty {
            if let beforePostTime = beforePostTime {
                await database.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if !postKeys.contains(hashtagOrMention.postKey) {
                        postKeys.append(hashtagOrMention.postKey)
                    }
                }
            } else {
                await database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    postKeys.append(hashtagOrMention.postKey)
                }
            }
            postKeys = postKeys.sorted { $0 > $1 }
            for postKey in postKeys {
                if let post: Post = await database.value(forKey: postKey) {
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
                await database.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if postKeys.count < count {
                        if !postKeys.contains(hashtagOrMention.postKey) {
                            postKeys.append(hashtagOrMention.postKey)
                        }
                    } else {
                        stop.pointee = true
                    }
                }
            } else {
                await database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
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
                if let post: Post = await database.value(forKey: postKey) {
                    result.append(post)
                }
            }
        }
        NSLog("postsWithHashtagOrMention, hashtagOrMention: \(hashtagOrMention), result: \(result)")
        return result
    }

    public static func posts(forUsername username: String, searchText: String = "", count: Int) async -> [Post] {
        var result = [Post]()
        var postKeys = [String]()
        var postKeySet = Set<String>()
        if searchText == "" {
            await database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
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
                if let post: Post = await database.value(forKey: postKey) {
                    result.append(post)
                }
            }
        } else {
            let theTextSearch = searchText.lowercased()
            var userPostKeys = [String]()
            await database.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
                userPostKeys.append(userPost.postKey)
            }
            for userPostKey in userPostKeys {
                if let post: Post = await database.value(forKey: userPostKey), post.message.lowercased().range(of: theTextSearch) != nil {
                    if result.count < count {
                        result.append(post)
                    } else {
                        break
                    }
                }
            }
            
        }
        NSLog("postsForUsername, username: \(username), result: \(result)")
        return result
    }

    public static func posts(forUsernameOrMention username: String, searchText: String = "", count: Int) async -> [Post] {
        var result = await posts(forUsername: username, searchText: searchText, count: count)
        let result2 = await posts(withHashtagOrMention: "@" + username, searchText: searchText, count: count)
        result.append(contentsOf: result2)
        result = result.sorted { $0.time > $1.time }
        if result.count > count {
            result.removeLast(result.count - count)
        }
        NSLog("postsForUsernameOrMention, username: \(username), result: \(result)")
        return result
    }
    
    public func pagePost(pageSize: Int) async -> Post {
        var childrenKeys = [String]()
        if let children = self.children {
            childrenKeys = children
        } else if let theParentPost = await self.parentPost(), let theChildrenKeys = theParentPost.children {
            childrenKeys = theChildrenKeys
            var postIndex = 0
            if let theIndex = childrenKeys.firstIndex(of: self.key), theIndex > 0 {
                postIndex = theIndex - 1
            }
            let pageNumber = postIndex / pageSize
            let postKey = childrenKeys[pageNumber * pageSize]
            if let post = await Post.postWith(key: postKey) {
                return post
            }
        }
        if childrenKeys.count > pageSize {
            var lastPageSize = childrenKeys.count % pageSize
            if lastPageSize == 0 {
                lastPageSize = pageSize
            }
            let lastPagePostKey = childrenKeys[childrenKeys.count - lastPageSize]
            if let lastPagePost = await Post.postWith(key: lastPagePostKey) {
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
    
    public func incrementSubjectViews() async -> Int {
        var subjectPost = await subjectPost()
        var subjectNumberOfViews = subjectPost.numberOfViews ?? 0
        subjectNumberOfViews += 1
        subjectPost.numberOfViews = subjectNumberOfViews
        await subjectPost.save()
        return subjectNumberOfViews
    }
    
    public func save() async {
        do {
            let postKey = Post.prefix + "\(time)-" + username
            try await database.setValue(self, forKey: postKey)
            let parentPost = await parentPost()
            if isPrivate == true || parentPost?.isPrivate == true {
                return // do not index private "admin" posts
            }
            let userPostKey = UserPost.prefix + username + "-\(time)"
            try await database.setValue(UserPost(postKey: postKey), forKey: userPostKey)
            for hashtag in message.hashtags {
                try await database.setValue(HashtagOrMention(postKey: postKey), forKey: hashtag + "-\(time)-" + username)
            }
            for mention in message.mentions {
                try await database.setValue(HashtagOrMention(postKey: postKey), forKey: mention + "-\(time)-" + username)
            }
            for word in Word.words(fromText: message) {
                try await database.setValue(Word(postKey: postKey), forKey: Word.prefix + word + "-\(time)-" + username)
            }
        } catch {
            NSLog("Post save failed, error: \(error)")
        }
    }
    
    public func delete() async {
        if let children = children {
            for childKey in children {
                await database.removeValue(forKey: childKey)
            }
        } else if var parentPost = await parentPost() {
            parentPost.children = parentPost.children?.filter { $0 != key }
            await parentPost.save()
        }
        await database.removeValue(forKey: key)
    }
    
    // MARK: - Public static functions
    
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
    
    public static func posts(forKeys keys: [String]) async -> [Post] {
        var result = [Post]()
        for postKey in keys {
            if let post: Post = await database.value(forKey: postKey) {
                result.append(post)
            }
        }
        NSLog("postsForKeys, keys: \(keys), result: \(result)")
        return result
    }
    
}

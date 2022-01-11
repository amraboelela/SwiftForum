//
//  Subject.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation

/*public struct PostsContainer: Codable {
    public var posts: [Subject]
}

public struct PostReference: Codable {
    public var username: String
    public var id: String
    
    public enum CodingKeys: String, CodingKey {
        case username = "u"
        case id = "k"
    }
}*/

public struct Subject: Codable {
    public static let prefix = "subject-"
    public static var posts = [Subject]()

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
        if let userPost: UserPost = swiftForumDB[key] {
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
        swiftForumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: prefix) { (key, subject: Subject, stop) in
            if subject.isNew == true {
                print("subject at key: \(key) is news")
            } else {
                result = key
                stop.pointee = true
            }
        }
        return result
    }

    static var firstKey: String? {
        var result : String?
        swiftForumDB.enumerateKeys(backward: false, startingAtKey: nil, andPrefix: prefix) { key, stop in
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
        return Subject.prefix + "\(time ?? 0)-" + username
    }
    
    public var repliesThread: [Subject] {
        var result = self.replyToPosts
        var currentPost = self
        if let postTime = self.time {
            let postKey = Subject.prefix + "\(postTime)-" + self.username
            if let thePost: Subject = swiftForumDB[postKey] {
                currentPost = thePost
            }
        }
        result.append(currentPost)
        result.append(contentsOf: self.replyPosts)
        return result
    }
    
    var replyToPosts: [Subject] {
        var result = [Subject]()
        var currentPost = self
        while true {
            if let reply = currentPost.replyTo {
                if let postKey = Subject.postKey(forUsername: reply.username, postID: reply.id), let subject: Subject = swiftForumDB[postKey] {
                    result.append(subject)
                    currentPost = subject
                    continue
                } else {
                    result.append(Subject(username: reply.username, id: reply.id))
                }
            }
            break
        }
        return result.reversed()
    }
     
    var replyPosts: [Subject] {
        var result = [Subject]()
        if let replies = self.replies {
            if replies.count > 0 {
                for reply in replies {
                    if let postKey = Subject.postKey(forUsername: reply.username, postID: reply.id), let thePost: Subject = swiftForumDB[postKey] {
                        result.append(thePost)
                        result.append(contentsOf: (thePost.replyPosts))
                    } else {
                        result.append(Subject(username: reply.username, id: reply.id))
                    }
                }
            }
        }
        return result
    }

    // MARK: - Reading data
    
    public static func with(username: String, time: Int? = 0) -> Subject {
        return Subject(username: username, time: time)
    }

    public static func from(key: String) -> Subject {
        return Subject(username: username(fromPostKey: key), time: time(fromPostKey: key))
    }

    public static func posts(withSearchText searchText: String, time: Int? = nil, before: Bool = true, count: Int) -> [Subject] {
        let blockedUsers = User.blockedUsers
        var result = [Subject]()
        let blockedUsernames = blockedUsers.map { $0.username }
        //var followees: Set<String>?
        /*if followeesOnly {
            followees = User.followees
            if followees?.count == 0 {
                return result
            }
        }*/
        let searchWords = Word.words(fromText: searchText)
        if let firstWord = searchWords.first {
            var wordPostKeys = [String]()
            swiftForumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: Word.prefix + firstWord) { (key, word: Word, stop) in
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
                if let subject: Subject = swiftForumDB[wordPostKey], let message = subject.message {
                    for i in 1..<searchWords.count {
                        let searchWord = searchWords[i]
                        if message.lowercased().range(of: searchWord) == nil {
                            foundTheSearch = false
                            break
                        }
                    }
                    if foundTheSearch {
                        if !blockedUsernames.contains(subject.username) {
                            result.append(subject)
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
            swiftForumDB.enumerateKeysAndValues(backward: before, startingAtKey: startAtKey, andPrefix: prefix) { (key, subject: Subject, stop) in
                if result.count < count {
                    if !blockedUsernames.contains(subject.username) {
                        result.append(subject)
                    }
                } else {
                    stop.pointee = true
                }
            }
        }
        return result
    }

    public static func posts(withHashtagOrMention hashtagOrMention: String, searchText: String? = nil, beforePostTime: Int? = nil, count: Int) -> [Subject] {
        var result = [Subject]()
        
        var mentionPostKeys = [String]()
        if let searchText = searchText, !searchText.isEmpty {
            if let beforePostTime = beforePostTime {
                swiftForumDB.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    mentionPostKeys.append(hashtagOrMention.postKey)
                }
            } else {
                swiftForumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    mentionPostKeys.append(hashtagOrMention.postKey)
                }
            }
            for mentionPostKey in mentionPostKeys {
                if let subject: Subject = swiftForumDB[mentionPostKey], let message = subject.message {
                    let theTextSearch = searchText.lowercased()
                    if message.lowercased().range(of: theTextSearch) != nil {
                        if result.count < count {
                            result.append(subject)
                        } else {
                            break
                        }
                    }
                }
            }
        } else {
            if let beforePostTime = beforePostTime {
                swiftForumDB.enumerateKeysAndValues(backward: true, startingAtKey: hashtagOrMention.lowercased() + "-\(beforePostTime)", andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if mentionPostKeys.count < count {
                        mentionPostKeys.append(hashtagOrMention.postKey)
                    } else {
                        stop.pointee = true
                    }
                }
            } else {
                swiftForumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: hashtagOrMention.lowercased() + "-") { (key, hashtagOrMention: HashtagOrMention, stop) in
                    if mentionPostKeys.count < count {
                        mentionPostKeys.append(hashtagOrMention.postKey)
                    } else {
                        stop.pointee = true
                    }
                }
            }
            for mentionPostKey in mentionPostKeys {
                if let subject: Subject = swiftForumDB[mentionPostKey] {
                    result.append(subject)
                }
            }
        }
        return result
    }

    public static func posts(forUsername username: String, searchText: String = "", beforePostID: String? = nil, count: Int) -> [Subject] {
        var result = [Subject]()
        var postKeys = [String]()
        var postKeySet = Set<String>()
        if searchText == "" {
            var startingAtKey: String? = nil
            if let beforePostID = beforePostID {
                startingAtKey = UserPost.prefix + username + "-" + beforePostID
            }
            swiftForumDB.enumerateKeysAndValues(backward: true, startingAtKey: startingAtKey, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
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
                if let subject: Subject = swiftForumDB[postKey] {
                    result.append(subject)
                }
            }
        } else {
            let theTextSearch = searchText.lowercased()
            var userPostKeys = [String]()
            swiftForumDB.enumerateKeysAndValues(backward: true, startingAtKey: nil, andPrefix: UserPost.prefix + username + "-") { (key, userPost: UserPost, stop) in
                userPostKeys.append(userPost.postKey)
            }
            for userPostKey in userPostKeys {
                if let subject: Subject = swiftForumDB[userPostKey], let message = subject.message, message.lowercased().range(of: theTextSearch) != nil {
                    if result.count < count {
                        result.append(subject)
                    } else {
                        break
                    }
                }
            }
            
        }
        return result
    }

    public static func subject(withUsername username: String, postID: String) -> Subject? {
        if let postKey = self.postKey(forUsername: username, postID: postID) {
            if let subject: Subject = swiftForumDB[postKey] {
                return subject
            }
        }
        return nil
    }

    // MARK: - Saving data
    
    public static func save(newPost: Subject) {
        var theNewPost = newPost
        theNewPost.isNew = true
        _ = self.save(subject: theNewPost)
    }
    
    public static func save(posts: [Subject]) -> Int {
        var saveCount = 0
        for subject in posts {
            if self.save(subject: subject) {
                saveCount+=1;
            }
        }
        return saveCount
    }
    
    // MARK: - Public functions
    
    public static func isRepostWithEmptyMessage(subject: Subject) -> Bool {
        /*if (subject[PostRepository.reposted] as? [String:String]) != nil {
         let postMessage = subject[PostRepository.message] as? String ?? ""
         if postMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  {
         return true
         }
         }*/
        return false
    }
    
    /*public func repostUsername(ofPost subject: [String:Any]) -> String? {
     if let rt = subject[PostRepository.reposted] as? [String:String], let rtUsername = rt[UserRepository.username] {
     return rtUsername
     }
     return nil
     }*/
    
    public static func updateTranslation(forPost subject: Subject, translation: [String:String]) {
        var aPost = subject
        if var aTranslation = aPost.translation {
            for (key,value) in translation {
                aTranslation.updateValue(value, forKey:key)
            }
            aPost.translation = aTranslation
        } else {
            aPost.translation = translation
        }
        let key = self.key(ofPost: subject)
        swiftForumDB[key] = aPost
    }
    
    public static func key(ofPost subject: Subject) -> String {
        return prefix + "\(subject.time ?? 0)-" + subject.username
    }
    
    public static func removeExtraFields(fromPosts posts: [Subject]) -> [Subject] {
        var result = [Subject]()
        for var subject in posts {
            subject.signature = nil
            subject.lastK = nil
            subject.height = nil
            result.append(subject)
        }
        return result
    }
    
    public static func save(subject: Subject) -> Bool {
        var thereAreNewPosts = false
        guard let k = subject.id, let postTime = subject.time, let postMessage = subject.message else {
            NSLog("save subject, couldn't get k or postTime or postMessage")
            return false
        }
        let u = subject.username
        let postKey = prefix + "\(postTime)-" + u
        if let _: Subject = swiftForumDB[postKey] {
        } else {
            thereAreNewPosts = true

            //logger.log("Saving: subject with key: \(postKey)")
            let userPostKey = UserPost.prefix + subject.username + "-" + zeroPaddedPostID(k)
            swiftForumDB[userPostKey] = UserPost(postKey: postKey)
            swiftForumDB[postKey] = subject
            for hashtag in HashtagOrMention.hashtags(fromText: postMessage) {
                swiftForumDB[hashtag + "-\(postTime)-" + u] = HashtagOrMention(postKey: postKey)
            }
            for mention in HashtagOrMention.mentions(fromText: postMessage) {
                swiftForumDB[mention + "-\(postTime)-" + u] = HashtagOrMention(postKey: postKey)
            }
            for word in Word.words(fromText: postMessage) {
                swiftForumDB[Word.prefix + word + "-\(postTime)-" + u] = Word(postKey: postKey)
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
    
    public static func posts(forKeys keys: [String]) -> [Subject] {
        var result = [Subject]()
        for postKey in keys {
            if let subject: Subject = swiftForumDB[postKey] {
                result.append(subject)
            }
        }
        return result
    }
    
}

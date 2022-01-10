//
//  User-server.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 10/12/20.
//  Copyright © 2020 Amr Aboelela. All rights reserved.
//

import CoreFoundation
import Foundation

public typealias UserCallback = (User?, TwisterError?) -> Void

extension User {
    
    public mutating func updateWith(user: User, myUsername: String? = nil) {
        if let username = user.username {
            self.username = username
        }
        if let rawStatus = user.rawStatus {
            self.rawStatus = rawStatus
        }
        if let time = user.time {
            self.time = time
        }
        if let privateKey = user.privateKey {
            self.privateKey = privateKey
        }
        if let fullname = user.fullname {
            self.fullname = fullname
        }
        if let location = user.location {
            self.location = location
        }
        if let bio = user.bio {
            self.bio = bio
        }
        if let url = user.url {
            self.url = url
        }
        if let avatar = user.avatar {
            self.avatar = avatar
        }
        if let followers = user.followers {
            self.followers = followers
        }
        if let followees = user.followees {
            self.followees = followees
        }
        var unblocking = false
        if let blockedBy = user.blockedBy {
            if let myUsername = myUsername, !blockedBy.contains(myUsername) {
                unblocking = true
            } else {
                if let selfBlockedBy = self.blockedBy {
                    for username in blockedBy {
                        if !selfBlockedBy.contains(username) {
                            self.blockedBy?.append(username)
                        }
                    }
                } else {
                    self.blockedBy = blockedBy
                }
            }
        } else {
            unblocking = true
        }
        if unblocking {
            if let myUsername = myUsername,
                let selfBlockedBy = self.blockedBy,
                selfBlockedBy.contains(myUsername) {
                self.blockedBy?.removeAll { $0 == myUsername}
            }
        }
        var unreporting = false
        if let reportedBy = user.reportedBy {
            if let myUsername = myUsername, !reportedBy.contains(myUsername) {
                unreporting = true
            } else {
                if let selfReportedBy = self.reportedBy {
                    for username in reportedBy {
                        if !selfReportedBy.contains(username) {
                            self.reportedBy?.append(username)
                        }
                    }
                } else {
                    self.reportedBy = reportedBy
                }
            }
        } else {
            unreporting = true
        }
        if unreporting {
            if let myUsername = myUsername,
                let selfReportedBy = self.reportedBy,
                selfReportedBy.contains(myUsername) {
                self.reportedBy?.removeAll { $0 == myUsername}
            }
        }
    }
    
    public static func clean(avatar: String) -> String {
        var cleanAvatar = avatar.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
        cleanAvatar = cleanAvatar.replacingOccurrences(of: "data:image/jpg;base64,", with: "")
        cleanAvatar = cleanAvatar.replacingOccurrences(of: "data:image/png;base64,", with: "")
        return cleanAvatar
    }
    
    public static func getProfile(forUsername username: String, callback: UserCallback) {
        if let user: User = database[User.prefix + username], let time = user.time {
            let updateTime = TimeInterval(time)
            let now = Date().timeIntervalSince1970
            if now - updateTime > Date.oneDay {
                //NSLog("now - updateTime > Date.oneDay")
                self.dhtgetProfile(forUsername: username) { user, error in
                    callback(user, error)
                }
            } else {
                //NSLog("now - updateTime < Date.oneDay")
                callback(user, nil)
            }
        } else {
            self.dhtgetProfile(forUsername: username) { user, error in
                callback(user, error)
            }
        }
    }
    
    static func dhtgetProfile(forUsername username: String, callback: UserCallback) {
        var resultUser: User? = nil
        var resultError: TwisterError? = nil
        defer {
            callback(resultUser, resultError)
        }
        #if os(Linux)
        do {
            if let dhtgetProfileResult = shell("python", database.libraryPath + "/dhtgetProfile.pyc", username) {
                NSLog("dhtgetProfileResult: \(dhtgetProfileResult)")
                if dhtgetProfileResult.range(of: "error") == nil {
                    if let data = dhtgetProfileResult.data(using: String.Encoding.utf8) {
                        //NSLog("dhtgetProfileResult.data: \(data.simpleDescription)")
                        var user = try JSONDecoder().decode(User.self, from: data)
                        user.time = Date.now
                        NSLog("dhtgetProfile got user: \(user)")
                        if var dbUser: User = database[User.prefix + username] {
                            dbUser.updateWith(user: user)
                            resultUser = dbUser
                            database[User.prefix + username] = dbUser
                        } else {
                            resultUser = user
                            database[User.prefix + username] = user
                        }
                    }
                }
            } else {
                resultError = TwisterError.otherError
                NSLog("couldn't get dhtgetProfileResult")
            }
        } catch {
            resultError = TwisterError.otherError
            NSLog("dhtgetProfileResult catch error: \(error)")
        }
        if var user: User = database[User.prefix + username], let dhtgetAvatarResult = shell("python", database.libraryPath + "/dhtgetAvatar.pyc", username) {
            NSLog("dhtgetAvatarResult: \(dhtgetAvatarResult)")
            user.time = Date.now
            if dhtgetAvatarResult.range(of: "error") == nil {
                let avatar = dhtgetAvatarResult
                user.avatar = clean(avatar: avatar)
            }
            resultUser = user
            database[User.prefix + username] = user
        } else {
            resultError = TwisterError.otherError
            NSLog("couldn't get dhtgetAvatarResult")
        }
        #endif
    }
    
}

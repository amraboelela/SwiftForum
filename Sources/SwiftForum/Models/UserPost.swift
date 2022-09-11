//
//  UserPost.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation

public struct UserPost: Codable, Sendable {
    public static let prefix = "userpost-"
    
    public var postKey: String

    /*static func postID(fromKey key: String) -> String {
        var result = ""
        let arr = key.components(separatedBy: "-")
        if arr.count > 2 {
            result = arr[2]
        }
        return result
    }*/

}

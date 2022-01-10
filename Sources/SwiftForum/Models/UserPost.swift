//
//  UserPost.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 12/16/19.
//  Copyright © 2019 Amr Aboelela. All rights reserved.
//

import Foundation

public struct UserPost: Codable {
    public static let prefix = "userpost-"
    
    public var postKey: String

    static func postID(fromKey key: String) -> String {
        var result = ""
        let arr = key.components(separatedBy: "-")
        if arr.count > 2 {
            result = arr[2]
        }
        return result
    }

}

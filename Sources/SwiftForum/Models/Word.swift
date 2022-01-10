//
//  Word.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 4/20/20.
//  Copyright © 2020 Amr Aboelela. All rights reserved.
//

import Foundation

public struct Word: Codable {
    public static let prefix = "word-"
    static let characters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

    public var postKey: String
    
    public static func words(fromText text: String) -> [String] {
        var result = Set<String>()
        let words = text.lowercased().components(separatedBy: characters.inverted)
        for word in words {
            if word.count > 2 {
                if let firstChar = word.unicodeScalars.first, NSCharacterSet.decimalDigits.contains(firstChar) {
                    // word contains a number, like "1"
                    // so don't add it
                } else {
                    result.insert(word)
                }
            }
        }
        return Array(result)
    }

    static func time(fromKey key: String) -> Int {
        var result = 0
        let arr = key.components(separatedBy: "-")
        if arr.count > 2 {
            result = Int(arr[2]) ?? 0
        }
        return result
    }

}

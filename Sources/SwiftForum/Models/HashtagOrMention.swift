//
//  HashtagOrMention.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/11/22.
//

import Foundation

public struct HashtagOrMention: Codable {

    static var hashtagCharacters = Word.characters.union(CharacterSet(charactersIn: "#"))
    static var mentionCharacters = Word.characters.union(CharacterSet(charactersIn: "@"))

    public var postKey: String

    public static func hashtags(fromText text: String) -> [String] {
        var result = Set<String>()

        let words = text.lowercased().components(separatedBy: hashtagCharacters.inverted)
        // tag each word if it has a hashtag
        for word in words {
            if word.count < 3 {
                continue
            }
            // found a word that is prepended by a hashtag!
            // homework for you: implement @mentions here too.
            if word.hasPrefix("#") {
                // drop the hashtag
                let stringifiedWord = word.dropFirst()
                if let firstChar = stringifiedWord.unicodeScalars.first, NSCharacterSet.decimalDigits.contains(firstChar) {
                    // hashtag contains a number, like "#1"
                    // so don't add it
                } else {
                    result.insert(word)
                }
            }
        }
        return Array(result)
    }

    public static func mentions(fromText text: String) -> [String] {
        var result = Set<String>()
        let words = text.lowercased().components(separatedBy: mentionCharacters.inverted)
        for word in words {
            if word.hasPrefix("@") {
                result.insert(word)
            }
        }
        return Array(result)
    }

}

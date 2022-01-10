//
//  Post-server.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 10/12/20.
//  Copyright © 2020 Amr Aboelela. All rights reserved.
//

import Foundation

extension Post {
    
    public static var newPosts: [Post] {
        do {
            let newPostsFilePath = database.dbPath + "/newPosts.json"
            let lastPostsFilePath = database.dbPath + "/lastSavedPosts.json"
            
            let attr = try FileManager.default.attributesOfItem(atPath: newPostsFilePath)
            if let fileSize = attr[FileAttributeKey.size] as? NSNumber, fileSize.intValue != newPostsLastFileSize {
                logger.log("newPosts.json fileSize: \(fileSize)")
                newPostsLastFileSize = fileSize.intValue
                let data = try Data(contentsOf: URL(fileURLWithPath: newPostsFilePath), options: .mappedIfSafe)
                var thereAreNewPosts = false
                logger.log("newPosts data: \(data.simpleDescription)")
                var postsContainer = try JSONDecoder().decode(PostsContainer.self, from: data)
                let theNewPosts = postsContainer.posts
                Post.posts = theNewPosts + Post.posts
                if theNewPosts.count > 0 {
                    logger.log("theNewPosts[0]: \(theNewPosts[0])")
                    thereAreNewPosts = true
                    _ = save(posts: theNewPosts)
                }
                if thereAreNewPosts {
                    try data.write(to: URL(fileURLWithPath: lastPostsFilePath))
                    if theNewPosts.count > 1000 {
                        postsContainer.posts = [posts[0]]
                        let postsData = try JSONEncoder().encode(postsContainer)
                        try postsData.write(to: URL(fileURLWithPath: newPostsFilePath))
                    }
                }
            }
        } catch {
            logger.log("newPosts error: \(error)")
        }
        return Post.posts
    }
    
}

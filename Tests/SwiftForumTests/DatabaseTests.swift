//
//  DatabaseTests.swift
//  SwiftForumTests
//
//  Created by: Amr Aboelela on 1/24/22.
//

import Foundation
import CoreFoundation
import XCTest
@testable import SwiftForum

final class DatabaseTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testInit() {
        let forumDB = ForumDB(name: "ForumDB")
        XCTAssertNotNil(forumDB)
        XCTAssertNotNil(forumDB.dbPath)
    }
    
    func testParentPath() {
        let forumDB = ForumDB(name: "ForumDB")
        forumDB.parentPath = "/path/to/Library"
        XCTAssertEqual(forumDB.dbPath, "/path/to/Library/ForumDB")
    }
}

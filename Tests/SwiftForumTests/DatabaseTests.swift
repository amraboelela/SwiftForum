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
    
    func testLibraryPath() {
        let forumDB = ForumDB(name: "ForumDB")
        forumDB.dbPath = "/path/to/Library/Database"
        XCTAssertEqual(forumDB.libraryPath, "/path/to/Library")
    }
}

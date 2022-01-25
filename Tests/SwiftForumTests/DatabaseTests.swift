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
        let database = Database(name: "ForumDB")
        XCTAssertNotNil(database)
        XCTAssertNotNil(database.dbPath)
    }
    
    func testLibraryPath() {
        let database = Database(name: "ForumDB")
        database.dbPath = "/path/to/Library/Database"
        XCTAssertEqual(database.libraryPath, "/path/to/Library")
    }
}

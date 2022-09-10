//
//  DatabaseTests.swift
//  DarkEyeCoreTests
//
//  Created by: Amr Aboelela on 9/10/22.
//

import Foundation
import XCTest
import SwiftLevelDB
@testable import SwiftForum

final class DatabaseTests: TestsBase {
    
    override func asyncSetup() async {
        await super.asyncSetup()
        let testRoot = URL(fileURLWithPath: #file.replacingOccurrences(of: "SwiftForumTests/DatabaseTests.swift", with: "/")).path
        database = LevelDB(parentPath: testRoot + "Library", name: "Database")
    }
    
    override func asyncTearDown() async {
        await super.asyncTearDown()
    }
    
    func testInit() async {
        await asyncSetup()
        XCTAssertNotNil(database)
        let parentPath = await database.parentPath
        XCTAssertNotNil(parentPath)
        await asyncTearDown()
    }
    
    func testParentPath() async {
        await asyncSetup()
        await database.setParentPath("/path/to/Library")
        let dbPath = await database.dbPath
        XCTAssertEqual(dbPath, "/path/to/Library/Database")
        await asyncTearDown()
    }
}

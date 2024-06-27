import XCTest
import SwiftLevelDB
@testable import SwiftForum

class TestsBase: XCTestCase {
    
    func asyncSetup() async {
        if database != nil {
            if await database.exists {
                try? await database.deleteDatabaseFromDisk()
            }
        }
        try? await Task.sleep(seconds: 1.0)
        let testRoot = URL(fileURLWithPath: #file.replacingOccurrences(of: "SwiftForumTests/TestsBase.swift", with: "/")).path
        database = LevelDB(parentPath: testRoot + "Library", name: "Database")
        //Crawler.crawler = nil
    }
    
    func asyncTearDown() async {
        //await Crawler.shared().canRun = false
        //usleep(1000000)
        try? await database.deleteDatabaseFromDisk()
    }
    
}

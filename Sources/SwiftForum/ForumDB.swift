//
//  ForumDB.swift
//  SwiftForum
//
//  Created by Amr Aboelela on 1/24/22.
//  Copyright © 2022 Amr Aboelela. All rights reserved.
//

import Foundation
import SwiftLevelDB
import Dispatch

public var forumDB: ForumDB!

open class ForumDB: LevelDB {
    public var dbPath = ""

    // MARK: - Life cycle
    
    required public init(path: String, name: String) {
        dbPath = path + "/" + name
        super.init(path: path, name: name)
        setupCoders()
        //fatalError("init(path:name:) has not been implemented")
    }
    
    deinit {
        //logger.log("deinit called")
    }
    
    func setupCoders() {
        if self.db == nil {
            //restore()
            //self.open()
            logger.log("db == nil")
        } else {
            backupIfNeeded()
        }
        self.encoder = {(key: String, value: Data) -> Data? in
            let data = value
            return data
        }
        self.decoder = {(key: String, data: Data) -> Data? in
            return data
        }
    }
    
    // MARK: - Public functions
    
    override open func close() {
        super.close()
    }
    
    public func backupIfNeeded() {
        //let currentTime = NSDate.timeIntervalSinceReferenceDate
        let dbBackupPath = dbPath + "1"
        serialQueue.async {
            let fileManager = FileManager.default
            let dbTempPath = dbBackupPath + ".temp"
            do {
                //logger.log("dbPath: \(dbPath)")
                try fileManager.copyItem(atPath: self.dbPath, toPath: dbTempPath)
            }
            catch {
            }
            do {
                try fileManager.removeItem(atPath: dbBackupPath)
            }
            catch {
            }
            do {
                try fileManager.moveItem(atPath: dbTempPath, toPath: dbBackupPath)
            }
            catch {
            }
        }
    }
}


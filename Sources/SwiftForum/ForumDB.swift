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

public var forumDB: ForumDB!//(name: "ForumDB")

open class ForumDB: LevelDB {
    public var dbPath = ""
/*
#if os(macOS)
    public var libraryPath: String {
        get {
            var array = dbPath.split(separator: "/")
            array.removeLast()
            return "/" + array.joined(separator: "/")
        }
    }
#else
    public var libraryPath = ""
#endif
  */
  
    var dbBackupPath = ""
    var lastBackupTime = TimeInterval(0)
#if DEBUG && os(Linux)
    let BackupInterval = TimeInterval(0)
#else
    let BackupInterval = Date.oneDay
#endif
    
    // MARK: - Life cycle
/*    
    public init(name: String) {
#if DEBUG
        //logger.log("ForumDB DEBUG")
#endif
#if os(Linux)
        libraryPath = ForumDB.getLibraryPath()
        logger.log("getLibraryPath()")
        dbPath = NSURL(fileURLWithPath: libraryPath, isDirectory: true).appendingPathComponent(name)?.path ?? ""
        //logger.log("dbPath")
        let weekday = Date().dayOfWeek()
        
        dbBackupPath = dbPath + "\(weekday)"
        logger.log("Database.dbBackupPath: \(dbBackupPath)")

#elseif os(macOS)
        let libraryDirectory = URL(fileURLWithPath: #file.replacingOccurrences(of: "Sources/SwiftForum/ForumDB.swift", with: ".build/debug/Library"))
        let libraryPath = libraryDirectory.absoluteString
        dbPath = NSURL(fileURLWithPath: libraryPath, isDirectory: true).appendingPathComponent(name)?.path ?? ""
        let weekday = 1
        dbBackupPath = dbPath + "-\(weekday)"
#else
        dbPath = NSURL(fileURLWithPath: name).path ?? ""
        if dbPath == "/" + name {
            libraryPath = ForumDB.getLibraryPath()
            dbPath = NSURL(fileURLWithPath: libraryPath, isDirectory: true).appendingPathComponent(name)?.path ?? ""
        }
        let weekday = 1
        dbBackupPath = dbPath + "-\(weekday)"
#endif
        
        //logger.log("dbBackupPath: \(dbBackupPath)")
        
        super.init(path: dbPath, name: name)
        
        //logger.log("after if self.db == nil")
        setupCoders()
        //logger.log("before ForumDB.lastBackupTime")
        //lastBackupTime = Date.timeIntervalSinceReferenceDate
        //logger.log("after ForumDB.lastBackupTime")
    }
  */
  
    required public init(path: String, name: String) {
        dbPath = path
        let weekday = 1
        dbBackupPath = dbPath + "-\(weekday)"
        super.init(path: path, name: name)
        setupCoders()
        //fatalError("init(path:name:) has not been implemented")
    }
    
    deinit {
        //logger.log("deinit called")
    }
    
    func setupCoders() {
        if self.db == nil {
            restore()
            self.open()
            logger.log("Was able to restore database")
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
        let currentTime = NSDate.timeIntervalSinceReferenceDate
        //logger.log("BackupInterval: \(BackupInterval)")
        if currentTime - lastBackupTime > BackupInterval {
            //logger.log("ForumDB backup")
            self.lastBackupTime = currentTime
            serialQueue.async {
                let fileManager = FileManager.default
                let dbTempPath = self.dbBackupPath + ".temp"
                do {
                    //logger.log("dbPath: \(dbPath)")
                    try fileManager.copyItem(atPath: self.dbPath, toPath: dbTempPath)
                }
                catch {
                }
                do {
                    try fileManager.removeItem(atPath: self.dbBackupPath)
                }
                catch {
                }
                do {
                    try fileManager.moveItem(atPath: dbTempPath, toPath: self.dbBackupPath)
                }
                catch {
                }
            }
        }
    }
    
    public func restore() {
        logger.log("Restoring database")
        let fileManager = FileManager.default
        let dbTempPath = dbBackupPath + ".temp"
        do {
            try fileManager.copyItem(atPath: dbBackupPath, toPath: dbTempPath)
        }
        catch {
        }
        do {
            try fileManager.removeItem(atPath: dbPath)
        }
        catch {
        }
        do {
            try fileManager.moveItem(atPath: dbTempPath, toPath: dbPath)
        }
        catch {
        }
    }
}


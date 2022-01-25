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

public var forumDB = ForumDB(name: "ForumDB")

open class ForumDB: LevelDB {
    public var dbPath = ""
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
    
    var dbBackupPath = ""
    var lastBackupTime = TimeInterval(0)
#if DEBUG && os(Linux)
    let BackupInterval = TimeInterval(0)
#else
    let BackupInterval = Date.oneDay
#endif
    
    // MARK: - Life cycle
    
    public init(name: String) {
        //let name = "Database"
#if DEBUG
        //logger.log("Database DEBUG")
#endif
#if os(Linux)
        libraryPath = Database.getLibraryPath()
        logger.log("getLibraryPath()")
        dbPath = NSURL(fileURLWithPath: libraryPath, isDirectory: true).appendingPathComponent(name)?.path ?? ""
        //logger.log("dbPath")
        let weekday = Date().dayOfWeek()
    #if DEBUG
        dbBackupPath = "/home/amr/backup/TwisterWebServer_dev/" + name + "\(weekday)"
    #else
        dbBackupPath = "/home/amr/backup/TwisterWebServer/" + name + "\(weekday)"
    #endif

        logger.log("Database.dbBackupPath")
#elseif os(macOS)
        let libraryDirectory = URL(fileURLWithPath: #file.replacingOccurrences(of: "Sources/SwiftForum/Database.swift", with: ".build/debug/Library"))
        let libraryPath = libraryDirectory.absoluteString
        dbPath = NSURL(fileURLWithPath: libraryPath, isDirectory: true).appendingPathComponent(name)?.path ?? ""
        let weekday = 1
        dbBackupPath = dbPath + "-\(weekday)"
#else
        dbPath = NSURL(fileURLWithPath: name).path ?? ""
        if dbPath == "/" + name {
            libraryPath = Database.getLibraryPath()
            dbPath = NSURL(fileURLWithPath: libraryPath, isDirectory: true).appendingPathComponent(name)?.path ?? ""
        }
        let weekday = 1
        dbBackupPath = dbPath + "-\(weekday)"
#endif
        
        //logger.log("dbBackupPath: \(dbBackupPath)")
        
        super.init(path: dbPath, name: name)
        
        //logger.log("after if self.db == nil")
        setupCoders()
        //logger.log("before Database.lastBackupTime")
        //lastBackupTime = Date.timeIntervalSinceReferenceDate
        //logger.log("after Database.lastBackupTime")
    }
    
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
            do {
                let data = value
                return data
            } catch {
                logger.log("Problem encoding data: \(error)")
                return nil
            }
        }
        self.decoder = {(key: String, data: Data) -> Data? in
            do {
                return data
            } catch {
                logger.log("Problem decoding data: \(data.simpleDescription) key: \(key) error: \(error)")
                return nil
            }
        }
    }
    
    // MARK: - Public functions
    
    override open func close() {
        super.close()
        //Database._instance = nil
    }
    
    public func backupIfNeeded() {
        let currentTime = NSDate.timeIntervalSinceReferenceDate
        //logger.log("BackupInterval: \(BackupInterval)")
        if currentTime - lastBackupTime > BackupInterval {
            //logger.log("Database backup")
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


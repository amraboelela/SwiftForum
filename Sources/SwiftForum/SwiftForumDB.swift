//
//  SwiftForumDB.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 2/24/18.
//  Copyright © 2018 Amr Aboelela. All rights reserved.
//

import Foundation
import SwiftLevelDB
import Dispatch

public let swiftForumDB = SwiftForumDB()

open class SwiftForumDB: LevelDB {
    public var dbPath = ""
    public var libraryPath = ""
    
    var dbBackupPath = ""
    var lastBackupTime = TimeInterval(0)
    #if DEBUG && os(Linux)
    let BackupInterval = TimeInterval(0)
    #else
    let BackupInterval = Date.oneDay
    #endif
    
    // MARK: - Life cycle
    
    public init() {
        let name = "SwiftForumDB"
        #if DEBUG
            //logger.log("SwiftForumDB DEBUG")
        #endif
        #if os(Linux)
            libraryPath = SwiftForumDB.getLibraryPath()
            logger.log("getLibraryPath()")
            dbPath = NSURL(fileURLWithPath: libraryPath, isDirectory: true).appendingPathComponent(name)?.path ?? ""
            //logger.log("dbPath")
            let weekday = Date().dayOfWeek()
            #if TwisterServer
                #if DEBUG
                    dbBackupPath = "/home/amr/backup/TwisterServer_dev/" + name + "\(weekday)"
                #else
                    dbBackupPath = "/home/amr/backup/TwisterServer/" + name + "\(weekday)"
                #endif
            #else
                dbBackupPath = dbPath + "\(weekday)"
            #endif
            logger.log("SwiftForumDB.dbBackupPath")
        #else
            dbPath = NSURL(fileURLWithPath: name).path ?? ""
            if dbPath == "/" + name {
                libraryPath = SwiftForumDB.getLibraryPath()
                dbPath = NSURL(fileURLWithPath: libraryPath, isDirectory: true).appendingPathComponent(name)?.path ?? ""
            }
            let weekday = 1
            dbBackupPath = dbPath + "-\(weekday)"
        #endif
        
        //logger.log("dbBackupPath: \(dbBackupPath)")
        
        super.init(path: dbPath, name: name)
        if self.db == nil {
            restore()
            self.open()
            logger.log("Was able to restore swiftForumDB")
        } else {
            backupIfNeeded()
        }
        //logger.log("after if self.db == nil")
        self.encoder = {(key: String, value: Data) -> Data? in
            do {
                let data = value //try JSONSerialization.data(withJSONObject: value)
                #if TwisterServer || DEBUG
                return data
                #else
                return try data.encryptedWithSaltUsing(key: myDevice.id)
                #endif
            } catch {
                logger.log("Problem encoding data: \(error)")
                return nil
            }
        }
        self.decoder = {(key: String, data: Data) -> Data? in
            do {
                #if TwisterServer || DEBUG
                return data
                #else
                if let decryptedData = try data.decryptedWithSaltUsing(key: myDevice.id) {
                    return decryptedData
                } else {
                    return nil
                }
                #endif
            } catch {
                logger.log("Problem decoding data: \(data.simpleDescription) key: \(key) error: \(error)")
                return nil
            }
        }
        //logger.log("before SwiftForumDB.lastBackupTime")
        //lastBackupTime = Date.timeIntervalSinceReferenceDate
        //logger.log("after SwiftForumDB.lastBackupTime")
    }
    
    required public init(path: String, name: String) {
        super.init(path: path, name: name)
        //fatalError("init(path:name:) has not been implemented")
    }
    
    deinit {
        //logger.log("deinit called")
    }
    
    // MARK: - Public functions
    
    override open func close() {
        super.close()
        //SwiftForumDB._instance = nil
    }
    
    // MARK: - Private functions
    
    func backupIfNeeded() {
        let currentTime = NSDate.timeIntervalSinceReferenceDate
        //logger.log("BackupInterval: \(BackupInterval)")
        if currentTime - lastBackupTime > BackupInterval {
            //logger.log("SwiftForumDB backup")
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
    
    func restore() {
        logger.log("Restoring swiftForumDB")
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


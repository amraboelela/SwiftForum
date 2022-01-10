//
//  String.swift
//  TwisterFoundation
//
//  Created by Amr Aboelela on 7/31/18.
//  Copyright © 2018 Amr Aboelela. All rights reserved.
//
//  See LICENCE for details.
//

import Foundation

public extension String {
    
    var dataFromHexadecimal: Data {
        var hex = self
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            //logger.log("dataFromHexadecimal hex: \(hex)")
            var ch: UInt32 = 0
            if Scanner(string: c).scanHexInt32(&ch) {
                var char = UInt8(ch)
                data.append(&char, count: 1)
            }
        }
        return data
    }
    
}

func DLog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    #if DEBUG
        logger.log("[\(NSString(string: filename).lastPathComponent):\(line)] \(function) - \(message)")
    #endif
}

func ALog(_ message: String, filename: String = #file, function: String = #function, line: Int = #line) {
    logger.log("[\(NSString(string: filename).lastPathComponent):\(line)] \(function) - \(message)")
}

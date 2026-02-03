//
//  Utils.swift
//  JoyConSwift
//
//  Created by magicien on 2019/06/16.
//  Copyright © 2019 DarkHorse. All rights reserved.
//

import Foundation
import os.log

// Direct os_log for JoyConSwift - avoids stdout buffering issues
private let jcsLogger = OSLog(subsystem: "app.berrry.joyful", category: "JoyConSwift")

func jcsLog(_ message: String) {
    os_log("%{public}@", log: jcsLogger, type: .default, message)
}

func ReadInt16(from ptr: UnsafePointer<UInt8>) -> Int16 {
    let byte0 = Int16(ptr[0])
    let byte1 = Int16(ptr[1])
    return byte0 | (byte1 << 8)
}

func ReadUInt16(from ptr: UnsafePointer<UInt8>) -> UInt16 {
    let byte0 = UInt16(ptr[0])
    let byte1 = UInt16(ptr[1])
    return byte0 | (byte1 << 8)
}

func ReadInt32(from ptr: UnsafePointer<UInt8>) -> Int32 {
    let byte0 = Int32(ptr[0])
    let byte1 = Int32(ptr[1])
    let byte2 = Int32(ptr[2])
    let byte3 = Int32(ptr[3])
    return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24)
}

func ReadUInt32(from ptr: UnsafePointer<UInt8>) -> UInt32 {
    let byte0 = UInt32(ptr[0])
    let byte1 = UInt32(ptr[1])
    let byte2 = UInt32(ptr[2])
    let byte3 = UInt32(ptr[3])
    return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24)
}

//
//  JoyConManager.swift
//  JoyConSwift
//
//  Created by magicien on 2019/06/16.
//  Copyright © 2019 DarkHorse. All rights reserved.
//

import Foundation
import IOKit
import IOKit.hid

let controllerTypeOutputReport: [UInt8] = [
    JoyCon.OutputType.subcommand.rawValue, // type
    0x0f, // packet counter
    0x00, 0x01, 0x00, 0x40, 0x00, 0x01, 0x00, 0x40, // rumble data
    Subcommand.CommandType.getSPIFlash.rawValue, // subcommand type
    0x12, 0x60, 0x00, 0x00, // address
    0x01, // data length
]

/// The manager class to handle controller connection/disconnection events
public class JoyConManager {
    static let vendorID: Int32 = 0x057E
    static let joyConLID: Int32 = 0x2006 // Joy-Con (L)
    static let joyConRID: Int32 = 0x2007 // Joy-Con (R), Famicom Controller 1&2
    static let proConID: Int32 = 0x2009 // Pro Controller
    static let snesConID: Int32 = 0x2017 // SNES Controller
    
    static let joyConLType: UInt8 = 0x01
    static let joyConRType: UInt8 = 0x02
    static let proConType: UInt8 = 0x03
    static let famicomCon1Type: UInt8 = 0x07
    static let famicomCon2Type: UInt8 = 0x08
    static let snesConType: UInt8 = 0x0B

    private let manager: IOHIDManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var matchingControllers: [IOHIDDevice] = []
    private var controllers: [IOHIDDevice: Controller] = [:]
    private var runLoop: RunLoop? = nil

    // Linux driver approach: sequential initialization to prevent HID contention
    private var initQueue: [(device: IOHIDDevice, controller: Controller, typeName: String)] = []
    private var isInitializing: Bool = false

    /// Handler for a controller connection event
    public var connectHandler: ((_ controller: Controller) -> Void)? = nil
    /// Handler for a controller disconnection event
    public var disconnectHandler: ((_ controller: Controller) -> Void)? = nil
    
    /// Initialize a manager
    public init() {}
    
    let handleMatchCallback: IOHIDDeviceCallback = { (context, result, sender, device) in
        let manager: JoyConManager = unsafeBitCast(context, to: JoyConManager.self)
        manager.handleMatch(result: result, sender: sender, device: device)
    }
    
    let handleInputCallback: IOHIDValueCallback = { (context, result, sender, value) in
        let manager: JoyConManager = unsafeBitCast(context, to: JoyConManager.self)
        manager.handleInput(result: result, sender: sender, value: value)
    }
    
    let handleRemoveCallback: IOHIDDeviceCallback = { (context, result, sender, device) in
        let manager: JoyConManager = unsafeBitCast(context, to: JoyConManager.self)
        manager.handleRemove(result: result, sender: sender, device: device)
    }
    
    func handleMatch(result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        let serialNumber = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String ?? "Unknown"
        let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0

        jcsLog("[JoyConManager] Device matched: \(productName) (VID: \(String(format: "0x%04X", vendorID)), PID: \(String(format: "0x%04X", productID)), Serial: \(serialNumber))")

        if (self.controllers.contains { (dev, ctrl) in dev == device }) {
            jcsLog("[JoyConManager] Device already registered, ignoring duplicate match")
            return
        }

        // Use product ID directly to determine controller type (more reliable than SPI read)
        var controller: Controller? = nil
        var typeName = "Unknown"

        switch Int32(productID) {
        case JoyConManager.joyConLID:
            controller = JoyConL(device: device)
            typeName = "Joy-Con (L)"
        case JoyConManager.joyConRID:
            // Could be Joy-Con R or Famicom controller - default to Joy-Con R
            controller = JoyConR(device: device)
            typeName = "Joy-Con (R)"
        case JoyConManager.proConID:
            controller = ProController(device: device)
            typeName = "Pro Controller"
        case JoyConManager.snesConID:
            controller = SNESController(device: device)
            typeName = "SNES Controller"
        default:
            jcsLog("[JoyConManager] Unknown product ID: \(String(format: "0x%04X", productID))")
            return
        }

        guard let ctrl = controller else {
            jcsLog("[JoyConManager] ERROR: Failed to create controller")
            return
        }

        jcsLog("[JoyConManager] Identified: \(typeName) (Serial: \(ctrl.serialID))")
        self.controllers[device] = ctrl
        ctrl.isConnected = true

        // Linux driver approach: queue for sequential initialization
        // Prevents HID contention when multiple controllers connect simultaneously
        jcsLog("[JoyConManager] Queuing \(typeName) for initialization...")
        self.initQueue.append((device: device, controller: ctrl, typeName: typeName))
        self.processInitQueue()
    }

    /// Process initialization queue sequentially (Linux driver approach)
    /// Only one controller initializes at a time to prevent HID contention
    private func processInitQueue() {
        guard !self.isInitializing else {
            jcsLog("[JoyConManager] Init already in progress, waiting...")
            return
        }
        guard !self.initQueue.isEmpty else {
            jcsLog("[JoyConManager] Init queue empty")
            return
        }

        self.isInitializing = true
        let item = self.initQueue.removeFirst()
        let ctrl = item.controller
        let typeName = item.typeName

        guard ctrl.isConnected else {
            jcsLog("[JoyConManager] Controller \(typeName) disconnected before init, skipping")
            self.isInitializing = false
            self.processInitQueue()
            return
        }

        // Delay before sending commands - Joy-Con needs time to initialize command interface
        // Linux driver waits for input report; we use 250ms delay as equivalent
        jcsLog("[JoyConManager] Waiting 250ms before initialization for \(typeName)...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self, ctrl.isConnected else {
                jcsLog("[JoyConManager] Controller disconnected during init delay, aborting")
                self?.isInitializing = false
                self?.processInitQueue()
                return
            }
            jcsLog("[JoyConManager] Reading initialization data for \(typeName)...")
            ctrl.readInitializeData { [weak self] in
                jcsLog("[JoyConManager] Controller ready: \(typeName) (Serial: \(ctrl.serialID))")
                self?.connectHandler?(ctrl)

                // Process next controller in queue
                self?.isInitializing = false
                self?.processInitQueue()
            }
        }
    }
    
    func handleControllerType(device: IOHIDDevice, result: IOReturn, value: IOHIDValue) {
        guard self.matchingControllers.contains(device) else {
            jcsLog("[JoyConManager] handleControllerType: device not in matchingControllers")
            return
        }
        let ptr = IOHIDValueGetBytePtr(value)
        let reportLength = IOHIDValueGetLength(value)

        // Log first few bytes of the report for debugging
        var hexDump = ""
        for i in 0..<min(12, reportLength) {
            hexDump += String(format: "%02X ", ptr[i])
        }
        jcsLog("[JoyConManager] Report len=\(reportLength): [\(hexDump.trimmingCharacters(in: .whitespaces))]")

        // Check byte 0 for actual report type
        let byte0 = ptr[0]
        guard byte0 == 0x21, reportLength >= 20 else {
            return
        }

        let address = ReadUInt32(from: ptr+14)
        let length = Int((ptr+18).pointee)
        jcsLog("[JoyConManager] Subcommand reply: address=0x\(String(format: "%04X", address)), length=\(length)")
        guard address == 0x6012, length == 1 else {
            jcsLog("[JoyConManager]   (ignoring - not controller type response)")
            return
        }
        let buffer = UnsafeBufferPointer(start: ptr+19, count: length)
        let data = Array(buffer)

        let typeCode = data[0]
        jcsLog("[JoyConManager] Controller type response: 0x\(String(format: "%02X", typeCode))")

        var _controller: Controller? = nil
        var typeName = "Unknown"
        switch data[0] {
        case JoyConManager.joyConLType:
            _controller = JoyConL(device: device)
            typeName = "Joy-Con (L)"
        case JoyConManager.joyConRType:
            _controller = JoyConR(device: device)
            typeName = "Joy-Con (R)"
        case JoyConManager.proConType:
            _controller = ProController(device: device)
            typeName = "Pro Controller"
        case JoyConManager.famicomCon1Type:
            _controller = FamicomController1(device: device)
            typeName = "Famicom Controller 1"
        case JoyConManager.famicomCon2Type:
            _controller = FamicomController2(device: device)
            typeName = "Famicom Controller 2"
        case JoyConManager.snesConType:
            _controller = SNESController(device: device)
            typeName = "SNES Controller"
        default:
            jcsLog("[JoyConManager] WARNING: Unknown controller type: 0x\(String(format: "%02X", typeCode))")
        }

        guard let controller = _controller else {
            jcsLog("[JoyConManager] ERROR: Failed to create controller instance for type: \(typeName)")
            return
        }

        jcsLog("[JoyConManager] Identified: \(typeName) (Serial: \(controller.serialID))")
        self.matchingControllers.removeAll { $0 == device }
        self.controllers[device] = controller
        controller.isConnected = true
        jcsLog("[JoyConManager] Reading initialization data for \(typeName)...")
        controller.readInitializeData { [weak self] in
            jcsLog("[JoyConManager] Controller ready: \(typeName) (Serial: \(controller.serialID))")
            self?.connectHandler?(controller)
        }
    }
    
    func handleInput(result: IOReturn, sender: UnsafeMutableRawPointer?, value: IOHIDValue) {
        guard let sender = sender else {
            jcsLog("[JoyConManager] WARNING: handleInput called with nil sender")
            return
        }
        let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue();

        guard let controller = self.controllers[device] else { return }
        if (result == kIOReturnSuccess) {
            controller.handleInput(value: value)
        } else {
            jcsLog("[JoyConManager] INPUT ERROR: IOReturn=\(result) (\(String(format: "0x%08X", result))) for \(controller.type) (Serial: \(controller.serialID))")
            controller.handleError(result: result, value: value)
        }
    }
    
    func handleRemove(result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice) {
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        let serialNumber = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String ?? "Unknown"

        jcsLog("[JoyConManager] DEVICE REMOVED: \(productName) (Serial: \(serialNumber))")
        jcsLog("[JoyConManager]    IOReturn result: \(result) (\(String(format: "0x%08X", result)))")

        // Remove from init queue if pending
        if let index = self.initQueue.firstIndex(where: { $0.device == device }) {
            jcsLog("[JoyConManager]    Device was in initQueue, removing...")
            self.initQueue.remove(at: index)
        }

        guard let controller = self.controllers[device] else {
            jcsLog("[JoyConManager]    WARNING: Device was not in controllers dictionary (may have been removed during matching)")
            // Also check if it was in matchingControllers
            if self.matchingControllers.contains(device) {
                jcsLog("[JoyConManager]    Device was in matchingControllers, removing...")
                self.matchingControllers.removeAll { $0 == device }
            }
            return
        }

        jcsLog("[JoyConManager]    Controller type: \(controller.type)")
        jcsLog("[JoyConManager]    Battery at disconnect: \(controller.battery) (charging: \(controller.isCharging))")
        jcsLog("[JoyConManager]    Was connected: \(controller.isConnected)")

        controller.isConnected = false

        self.controllers.removeValue(forKey: device)
        jcsLog("[JoyConManager]    Remaining controllers: \(self.controllers.count)")
        controller.cleanUp()

        self.disconnectHandler?(controller)
        jcsLog("[JoyConManager]    Disconnect handler called")
    }
    
    private func registerDeviceCallback() {
        IOHIDManagerRegisterDeviceMatchingCallback(self.manager, self.handleMatchCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
        IOHIDManagerRegisterDeviceRemovalCallback(self.manager, self.handleRemoveCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
        IOHIDManagerRegisterInputValueCallback(self.manager, self.handleInputCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
    }
    
    private func unregisterDeviceCallback() {
        IOHIDManagerRegisterDeviceMatchingCallback(self.manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(self.manager, nil, nil)
        IOHIDManagerRegisterInputValueCallback(self.manager, nil, nil)
    }
    
    private func cleanUp() {
        self.controllers.values.forEach { controller in
            controller.cleanUp()
        }
        self.controllers.removeAll()
    }
        
    /// Start waiting for controller connection/disconnection events in the current thread.
    /// If you don't want to stop the current thread, use `runAsync()` instead.
    /// - Returns: kIOReturnSuccess if succeeded. IOReturn error value if failed.
    public func run() -> IOReturn {
        jcsLog("[JoyConManager] Starting HID manager...")
        jcsLog("[JoyConManager] Vendor ID: \(String(format: "0x%04X", JoyConManager.vendorID)) (Nintendo)")
        jcsLog("[JoyConManager] Supported devices:")
        jcsLog("[JoyConManager]   - Joy-Con (L): PID \(String(format: "0x%04X", JoyConManager.joyConLID))")
        jcsLog("[JoyConManager]   - Joy-Con (R): PID \(String(format: "0x%04X", JoyConManager.joyConRID))")
        jcsLog("[JoyConManager]   - Pro Controller: PID \(String(format: "0x%04X", JoyConManager.proConID))")
        jcsLog("[JoyConManager]   - SNES Controller: PID \(String(format: "0x%04X", JoyConManager.snesConID))")

        let joyConLCriteria: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_GamePad,
            kIOHIDVendorIDKey: JoyConManager.vendorID,
            kIOHIDProductIDKey: JoyConManager.joyConLID,
        ]
        let joyConRCriteria: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_GamePad,
            kIOHIDVendorIDKey: JoyConManager.vendorID,
            kIOHIDProductIDKey: JoyConManager.joyConRID,
        ]
        let proConCriteria: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_GamePad,
            kIOHIDVendorIDKey: JoyConManager.vendorID,
            kIOHIDProductIDKey: JoyConManager.proConID,
        ]
        let snesConCriteria: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_GamePad,
            kIOHIDVendorIDKey: JoyConManager.vendorID,
            kIOHIDProductIDKey: JoyConManager.snesConID,
        ]
        let criteria = [joyConLCriteria, joyConRCriteria, proConCriteria, snesConCriteria]

        let runLoop = RunLoop.current

        IOHIDManagerSetDeviceMatchingMultiple(self.manager, criteria as CFArray)
        IOHIDManagerScheduleWithRunLoop(self.manager, runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue)
        jcsLog("[JoyConManager] Opening HID manager with seize device option...")
        let ret = IOHIDManagerOpen(self.manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if (ret != kIOReturnSuccess) {
            jcsLog("[JoyConManager] ERROR: Failed to open HID manager, IOReturn: \(ret) (\(String(format: "0x%08X", ret)))")
            return ret
        }
        jcsLog("[JoyConManager] HID manager opened successfully")

        self.registerDeviceCallback()
        jcsLog("[JoyConManager] Device callbacks registered, entering run loop...")

        self.runLoop = runLoop
        self.runLoop?.run()

        jcsLog("[JoyConManager] Run loop exited, closing HID manager...")
        IOHIDManagerClose(self.manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        IOHIDManagerUnscheduleFromRunLoop(self.manager, runLoop.getCFRunLoop(), CFRunLoopMode.defaultMode.rawValue)
        jcsLog("[JoyConManager] HID manager closed")

        return kIOReturnSuccess
    }
    
    /// Start waiting for controller connection/disconnection events in a new thread.
    /// If you want to wait for the events synchronously, use `run()` instead.
    /// - Returns: kIOReturnSuccess if succeeded. IOReturn error value if failed.
    public func runAsync() -> IOReturn {
        DispatchQueue.global().async { [weak self] in
            _ = self?.run()
        }
        return kIOReturnSuccess
    }
    
    /// Stop waiting for controller connection/disconnection events
    public func stop() {
        jcsLog("[JoyConManager] Stopping JoyConManager...")
        jcsLog("[JoyConManager]   Active controllers: \(self.controllers.count)")
        jcsLog("[JoyConManager]   Matching controllers: \(self.matchingControllers.count)")

        if let currentLoop = self.runLoop?.getCFRunLoop() {
            CFRunLoopStop(currentLoop)
        }

        self.unregisterDeviceCallback()
        self.cleanUp()
        jcsLog("[JoyConManager] JoyConManager stopped")
    }
}

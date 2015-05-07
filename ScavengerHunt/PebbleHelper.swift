//
//  PebbleHelper.swift
//  ScavengerHunt
//
//  Created by Hanna Koh on 3/26/15.
//  Copyright (c) 2015 DevPubs. All rights reserved.
//

import Foundation

protocol PebbleHelperDelegate {
    func pebbleHelper(pebbleHelper: PebbleHelper, receivedMessage: Dictionary<NSObject, AnyObject>)
}

class PebbleHelper: NSObject, PBPebbleCentralDelegate {
    
    class var instance : PebbleHelper {
        struct Static {
            static let instance : PebbleHelper = PebbleHelper()
        }
        return Static.instance
    }
    
    var watch: PBWatch?
    var delegate: PebbleHelperDelegate?
    var parts = Array<String>()
    var keys = Array<Int>()
    var dictionary = Dictionary<Int, String>()
    
    //Set the app UUID
    var UUID: String? {
        didSet {
            let myAppUUID = NSUUID(UUIDString: self.UUID!)
            var myAppUUIDbytes: UInt8 = 0
            myAppUUID?.getUUIDBytes(&myAppUUIDbytes)
            PBPebbleCentral.defaultCentral().appUUID = NSData(bytes: &myAppUUIDbytes, length: 16)
            if (self.watch != nil) {
                self.watch?.appMessagesAddReceiveUpdateHandler({ (watch, msgDictionary) -> Bool in
                    println("Message received")
                    self.delegate?.pebbleHelper(self, receivedMessage: msgDictionary)
                    return true
                })
            }
        }
        
    }
    
    override init() {
        super.init()
        PBPebbleCentral.defaultCentral().delegate = self
        self.watch = PBPebbleCentral.defaultCentral().lastConnectedWatch()
        if (self.watch != nil) {
            println("Pebble connected: \(self.watch!.name)")
        }
        
    }
    
    func pebbleCentral(central: PBPebbleCentral!, watchDidConnect watch: PBWatch!, isNew: Bool) {
        println("Pebble connected: \(watch.name)")
    }
    
    func pebbleCentral(central: PBPebbleCentral!, watchDidDisconnect watch: PBWatch!) {
        println("Pebble disconnected: \(watch.name)")
        if (self.watch == watch) {
            self.watch = nil
        }
    }
    
    func launchApp(completionHandler: (error: NSError?) -> Void) {
        self.watch?.appMessagesLaunch({ (watch, error) -> Void in
            completionHandler(error: error)
        })
    }
    
    func killApp(completionHandler: (error: NSError?) -> Void) {
        self.watch?.appMessagesKill({ (watch, error) -> Void in
            completionHandler(error: error)
        })
    }
    
    func checkCompatibility(completionHandler: (isAppMessagesSupported: Bool) -> Void) {
        self.watch?.appMessagesGetIsSupported({ (watch, isSupported) -> Void in
            completionHandler(isAppMessagesSupported: isSupported)
        })
    }
    
    func printInfo() {
        if (self.watch != nil) {
            println("Pebble name: \(self.watch!.name)")
            println("Pebble serial number: \(self.watch!.serialNumber)")
            self.watch?.getVersionInfo({ (watch, versionInfo) -> Void in
                println("Pebble firmware os version: \(versionInfo.runningFirmwareMetadata.version.os)")
                println("Pebble firmware major version: \(versionInfo.runningFirmwareMetadata.version.major)")
                println("Pebble firmware minor version: \(versionInfo.runningFirmwareMetadata.version.minor)")
                println("Pebble firmware suffix version: \(versionInfo.runningFirmwareMetadata.version.suffix)")
                }, onTimeout: { (watch) -> Void in
                    println("Timed out trying to get version info from Pebble.")
            })
        }
    }
    
    func sendDictionary(dictionary: Dictionary<Int, String>, completionHandler: (error: NSError?) -> Void) {
        if dictionary.isEmpty {
            return
        }
        self.dictionary = dictionary
        keys = dictionary.keys.array
        keys.sort { $0 < $1 }
        sendLine { (error) -> Void in
            completionHandler(error: error)
        }
    }
    
    private func sendLine(completionHandler: (error: NSError?) -> Void) {
        let key = keys[0]
        sendMessage(dictionary[keys[0]]!, key: keys[0]) { (error) -> Void in
            self.keys.removeAtIndex(0)
            if (self.keys.isEmpty) {
                completionHandler(error: nil)
            } else {
                self.sendLine(completionHandler)
            }
            
        }
    }
    
    func sendMessage(message: String, key: Int, completionHandler: (error: NSError?) -> Void) {
        
        let maxLength = 124
        parts.removeAll(keepCapacity: false)
        var msg = message
        do {
            var part = ""
            if (countElements(msg) > maxLength) {
                parts.append(msg.substringToIndex(advance(msg.startIndex,maxLength-1)))
                msg = msg.substringFromIndex(advance(msg.startIndex,maxLength-1))
            } else {
                parts.append(msg)
                msg = ""
            }
        } while !msg.isEmpty
        
        sendToWatch(key, completionHandler: completionHandler)
        /*self.watch?.appMessagesPushUpdate([0: key, 1:message], onSent: {(watch, msgDictionary, error)-> Void in
            if let e = error {
                NSLog("Error sending message. \(error.debugDescription)")
            }
            else {
                NSLog("Successfully sent message")
            }
        })*/

    }
    
    private func sendToWatch(key: Int, completionHandler: (error: NSError?) -> Void) {
        let msgDictionary = [0: key, key: parts[0]]
        self.watch?.appMessagesPushUpdate(msgDictionary, onSent: { (watch, msgDictionary, error) -> Void in
            self.parts.removeAtIndex(0)
            if (self.parts.count > 0) {
                self.sendToWatch(key, completionHandler: completionHandler)
            } else {
                completionHandler(error: error)
            }
        })
    }
}
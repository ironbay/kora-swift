//
//  LevelWrapper.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

class LevelWrapper {
  fileprivate static let LDB:LevelDB = LevelDB.databaseInLibrary(withName: "inbox") as! LevelDB
  
  class func getString(_ key:String) -> String? {
    if let string = LDB.object(forKey: key) as? String {
      return string
    }
    return nil
  }
  
  class func getValue(_ key:String) -> AnyObject? {
    return LDB.object(forKey: key) as AnyObject?
  }
  
  class func getKeys(_ prefix:String) -> [String] {
    var keys:[String] = []
    LDB.enumerateKeysBackward(false, startingAtKey:nil, filteredBy:nil, andPrefix:prefix)
    {
      (key, stop) -> Void in
      keys.append(NSStringFromLevelDBKey(key))
    }
    return keys
  }
  
  class func getKeys(_ prefix:String, limit:Int) -> [String] {
    var keys:[String] = []
    var count:Int = 0
    LDB.enumerateKeysBackward(false, startingAtKey:nil, filteredBy:nil, andPrefix:prefix)
    {
      (key, stop) -> Void in
      keys.append(NSStringFromLevelDBKey(key))
      count += 1
      if count == limit {
        let shouldStop:ObjCBool = true
        stop?.initialize(to: shouldStop)
      }
    }
    return keys
  }
  
  class func getKeys(_ prefix:String, startingKey:String, limit:Int, reverse:Bool) -> [String] {
    var keys:[String] = []
    var count:Int = 0
    
    LDB.enumerateKeysBackward(reverse, startingAtKey: startingKey, filteredBy: nil, andPrefix: prefix) { (key, stop) in
      let keyString = NSStringFromLevelDBKey(key)
//      let prefixRange = keyString?.range(of: prefix)
      
//      let newKeyString = keyString?.substring(from: (prefixRange?.upperBound)!)
      let keyArray = keyString?.components(separatedBy: ".")
      let childKey = keyArray?[2]
      
      if !keys.contains(childKey!) {
        keys.append(childKey!)
        count+=1
        if count == limit {
          let shouldStop:ObjCBool = true
          stop?.initialize(to: shouldStop)
        }
      }
    }
    
    return keys
  }
  
  class func removeObjectForKey(_ key:String) -> Bool {
    if LDB.objectExists(forKey: key) {
      LDB.removeObject(forKey: key)
      return true
    }
    return false
  }
  
  class func removeAllObjectsWithPrefix(_ prefix:String) {
    LDB.removeAllObjects(withPrefix: prefix)
  }
  
  class func removeAllObjects() {
    LDB.removeAllObjects()
  }
  
  class func dumpInfo() {
    print("--------------------------------------------------")
    LDB.enumerateKeysAndObjects { (key, value, stop) -> Void in
      let string = NSStringFromLevelDBKey(key)
      print("key:\(string), object:\(value)")
    }
    print("--------------------------------------------------")
  }
  
  class func dumpInfo(_ prefix:String) {
    print("---------- prefix = \(prefix) ----------")
    let keys:[String] = LevelWrapper.getKeys(prefix)
    for key in keys {
      let value = LevelWrapper.getValue(key)
      print("key:\(key), object:\(value)")
    }
    print("--------------------------------------------------")
  }
  
  class func objectExistsForKey(_ key:String) -> Bool {
    if LDB.objectExists(forKey: key) {
      return true
    } else {
      var objectExists:Bool = false
      LDB.enumerateKeysBackward(false, startingAtKey:key, filteredBy:nil, andPrefix:key)
      {
        (key, stop) -> Void in
        objectExists = true
        let shouldStop:ObjCBool = true
        stop?.initialize(to: shouldStop)
      }
      return objectExists
    }
  }
  
  class func setObject(_ object:AnyObject, key:String) {
    LDB.setObject(object, forKey:key)
  }
  
  class func getObjectForKey(_ key:String) -> AnyObject {
    return LDB.object(forKey: key) as AnyObject
  }
}

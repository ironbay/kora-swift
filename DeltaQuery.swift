//
//  DeltaQuery.swift
//  Inbox
//
//  Created by Hani Shabsigh on 4/15/16.
//  Copyright © 2016 Inbox. All rights reserved.
//

import Foundation

class DeltaQuery: NSObject, DeltaCommandProtocol {
  
  static let ACTION_QUERY:String = "delta.query"
  
  fileprivate var mKey:String
  fileprivate var mAction:String = DeltaQuery.ACTION_QUERY
  fileprivate var mVersion:Int = 1
  fileprivate var mBody:NSMutableDictionary = NSMutableDictionary()
  
  override init() {
    mKey = DeltaUUID.ascending()
    
    super.init()
  }
  
  deinit {
    
  }
  
  // MARK: Public

  func addPath(_ path:[String]) {
    var workingObject:NSMutableDictionary = mBody
    for part in path {
      if let nextWorkingObject = workingObject[part] as? NSMutableDictionary {
        workingObject = nextWorkingObject
      } else {
        let next = NSMutableDictionary()
        workingObject[part] = next
        workingObject = next
      }
    }
  }
  
  func mergeOperation(_ newValue:AnyObject, path:[String]) {
    var workingObject:NSMutableDictionary = mBody
    
    for i in 0 ..< path.count - 1 {
      var nextObject:NSMutableDictionary? = workingObject.object(forKey:path[i]) as? NSMutableDictionary
      if nextObject == nil {
        nextObject = NSMutableDictionary()
        workingObject[path[i]] = nextObject
      }
      workingObject = nextObject!
    }
    
    workingObject[path[path.count - 1]] = newValue
  }
  
  // MARK: DeltaCommandProtocol
  
  func getKey() -> String {
    return mKey
  }
  
  func getJSON() -> [String:AnyObject] {
    var json:[String:AnyObject] = [String:AnyObject]()
    json[DeltaEngine.KEY] = mKey as AnyObject
    json[DeltaEngine.ACTION] = mAction as AnyObject
    json[DeltaEngine.VERSION] = mVersion as AnyObject
    json[DeltaEngine.BODY] = mBody.copy() as AnyObject
    return json
  }
}

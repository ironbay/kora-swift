//
//  DeltaMutation.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/7/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

class DeltaMutation: NSObject, DeltaCommandProtocol {
  
  static let ACTION_MUTATION:String = "delta.mutation"
  
  static let ONLINE:String = "$online"
  static let EPHEMERAL:String = "$ephemeral"
  
  fileprivate var mKey:String
  fileprivate var mAction:String = DeltaMutation.ACTION_MUTATION
  fileprivate var mVersion:Int = 1
  
  fileprivate var mMerge:NSMutableDictionary = NSMutableDictionary()
  fileprivate var mDelete:NSMutableDictionary = NSMutableDictionary()
  fileprivate var mOnline:Bool = false
  fileprivate var mEphemeral:Bool = false
  
  override init() {
    mKey = DeltaUUID.ascending()
  }
  
  init(online:Bool, ephemeral:Bool) {
    mKey = DeltaUUID.ascending()
    mOnline = online
    mEphemeral = ephemeral
  }
  
  deinit {
    
  }
  
  // MARK: Public
  
  func mergeOperation(_ newValue:AnyObject, path:[String]) {
    var workingObject:NSMutableDictionary = mMerge
    
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
  
  func deleteOperation(_ path:[String]) {
    var workingObject:NSMutableDictionary = mDelete
    
    for i in 0 ..< path.count - 1 {
      var nextObject:NSMutableDictionary? = workingObject.object(forKey:path[i]) as? NSMutableDictionary
      if nextObject == nil {
        nextObject = NSMutableDictionary()
        workingObject[path[i]] = nextObject
      }
      workingObject = nextObject!
    }
    
    workingObject[path[path.count - 1]] = true
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
    let body:[String:AnyObject] = [DeltaEngine.OP_MERGE:mMerge.copy() as AnyObject,
                                   DeltaEngine.OP_DELETE:mDelete.copy() as AnyObject,
                                   DeltaMutation.ONLINE:mOnline as AnyObject,
                                   DeltaMutation.EPHEMERAL:mEphemeral as AnyObject]
    json[DeltaEngine.BODY] = body as AnyObject
    return json
  }
}

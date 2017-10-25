//
//  LevelObject.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

@objc class LevelObject: NSObject, DeltaObjectProtocol {
  
  var mRootPath:String?
  
  override init () {
    
  }
  
  init(rootPath:[String]) {
    mRootPath = Delta.convertPathToString(rootPath, root: nil)
  }
  
  func getId() -> String? {
    let lastIndex = mRootPath?.range(of: Delta.SEPARATOR, options: NSString.CompareOptions.backwards, range: nil, locale: nil)?.upperBound
    if let theLastIndex = lastIndex {
      return mRootPath?.substring(from: theLastIndex)
    }
    return nil
  }
  
  func getObject(_ path:[String]) -> DeltaObjectProtocol? {
    let obj:LevelObject = LevelObject()
    obj.mRootPath = Delta.convertPathToString(path, root: mRootPath)
    return obj
  }
  
  func getValue(_ path: [String]) -> AnyObject? {
    let key = Delta.convertPathToString(path, root: mRootPath)
    return LevelWrapper.getValue(key)
  }
  
  func getString(_ path: [String]) -> String? {
    if let value = getValue(path) as? String {
      return value
    }
    return nil
  }
  
  func getInt(_ def: Int, path: [String]) -> Int {
    if let value = getValue(path) as? Int {
      return value
    }
    return def
  }
  
  func getStringPath() -> String? {
    return mRootPath
  }
}

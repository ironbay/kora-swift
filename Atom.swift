//
//  Delta.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

class Atom:NSObject {
  
  fileprivate var mPath:[String]
  var merge:NSDictionary = NSDictionary()
  var delete:NSDictionary = NSDictionary()
  
  init (path:[String]) {
    mPath = path
  }
  
  func getPath() -> [String] {
    return mPath
  }
  
  func mergeObjects() -> [NSDictionary] {
    var objects:[NSDictionary] = [NSDictionary]()
    for key in merge.allKeys as! [String] {
      if merge[key] is NSDictionary {
        
      } else {
        objects.append([key:merge[key]!])
      }
    }
    return objects
  }
  
  func deleteFields() -> [String] {
    var fields:[String] = [String]()
    for key in delete.allKeys as! [String] {
      if delete[key] is NSDictionary {
        
      } else {
        fields.append(key)
      }
    }
    return fields
  }
}

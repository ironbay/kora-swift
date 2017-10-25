//
//  DeltaUUID.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/7/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

class DeltaUUID:NSObject {
  
  private static let lockQueue = DispatchQueue(label:"com.inboxtheapp.DeltaUUID.lockQueue")
  
  private static let ASC_CHARS = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".characters)
  private static let DESC_CHARS = Array(ASC_CHARS.reversed())
  private static var lastPushTime: UInt64 = 0
  private static var lastRandChars = Array<Int>(repeating: 0, count: 12)
  
  class func ascending() -> String {
    return generatePushID(ascending: true)
  }
  
  class func descending() -> String {
    return generatePushID(ascending: false)
  }
  
  /// custom unique identifier
  /// @see https://www.firebase.com/blog/2015-02-11-firebase-unique-identifiers.html
  /// @from https://gist.github.com/pgherveou/8e2b3a718bc9e367efa0
  
  private class func generatePushID(ascending: Bool = true) -> String {
    var id:String?
    
    lockQueue.sync() {
      let PUSH_CHARS = ascending ? ASC_CHARS : DESC_CHARS
      var timeStampChars = Array(repeating: PUSH_CHARS.first!, count: 8)
      var now = UInt64(DeltaTime.syncedTime.timeIntervalSince1970MS())
      let duplicateTime = (now == lastPushTime)
      lastPushTime = now
      
      for i in stride(from:7, through: 0, by: -1) {
        timeStampChars[i] = PUSH_CHARS[Int(now % UInt64(ASC_CHARS.count))]
        now = UInt64(floor(Double(now) / Double(ASC_CHARS.count)))
      }
      
      assert(now == 0, "We should have converted the entire timestamp.")
      
      var temp:String = String(timeStampChars)
      
      if !duplicateTime {
        for i in 0..<12 {
          lastRandChars[i] = Int(Double(ASC_CHARS.count) * (Double(arc4random_uniform(UINT32_MAX)) / Double(UINT32_MAX)))
        }
      } else {
        var reached = 0
        for i in stride(from:11, through:0, by:-1) {
          reached = i
          if lastRandChars[i] == ASC_CHARS.count - 1 {
            lastRandChars[i] = 0
          } else {
            break
          }
        }
        lastRandChars[reached] += 1
      }
      
      for i in 0..<12 {
        temp.append(PUSH_CHARS[lastRandChars[i]])
      }
      
      assert(temp.characters.count == 20, "Length should be 20.")
      
      id = temp
    }
    
    return id!
  }
}

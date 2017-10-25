//
//  DeltaTime.swift
//  Inbox
//
//  Created by Hani Shabsigh on 6/1/16.
//  Copyright © 2016 Inbox. All rights reserved.
//
//  What time is it? Delta Time!
//

import Foundation

class DeltaTime:NSObject {
  static let syncedTime:DeltaTime = DeltaTime()
  
  fileprivate var mServerTimeOffsetMS:TimeInterval = 0.0;
  
  fileprivate override init() {
    
  }
  
  /**
   Returns the time interval since 1970 in milliseconds UTC
   
   - Returns: time interval since 1970 in milliseconds UTC
   */
  func timeIntervalSince1970MS() -> TimeInterval {
    return TimeInterval(Date().timeIntervalSince1970 * 1000) + mServerTimeOffsetMS
  }
  
  /**
   Updates internal DeltaTime server offset used to calculate timeIntervalSince1970MS
   
   - Parameter serverTimeOffsetMillis: The offset between local time and server time in milliseconds.
   */
  func updateWithServerTimeOffsetMS(_ serverTimeOffsetMS:Double) {
    self.mServerTimeOffsetMS = serverTimeOffsetMS
  }
}

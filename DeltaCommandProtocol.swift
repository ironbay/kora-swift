//
//  DeltaCommandProtocol.swift
//  Inbox
//
//  Created by Hani Shabsigh on 4/15/16.
//  Copyright © 2016 Inbox. All rights reserved.
//

import Foundation

@objc protocol DeltaCommandProtocol : class {
  
  func getKey() -> String
  
  func getJSON() -> [String:AnyObject]
}

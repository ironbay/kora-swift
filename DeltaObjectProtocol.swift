//
//  DeltaObject.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

@objc protocol DeltaObjectProtocol {
  
  func getId() -> String?
  
  func getObject(_ path:[String]) -> DeltaObjectProtocol?
  
  func getValue(_ path:[String]) -> AnyObject?
  
  
  func getString(_ path:[String]) -> String?
  
  func getInt(_ def:Int , path:[String]) -> Int
  
  
  func getStringPath() -> String?
}

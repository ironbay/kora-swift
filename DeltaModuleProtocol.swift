//
//  DeltaModule.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

@objc protocol DeltaModuleProtocol {
  
  func getObject(_ path:[String]) -> DeltaObjectProtocol?
  
  func getChildren(_ path:[String]) -> [DeltaObjectProtocol]?
  
  func getChildren(_ path:[String], limit:Int) -> [DeltaObjectProtocol]?
  
  func getChildrenIds(_ path:[String]) -> [String]
  
  func getChildrenPaths(_ path:[String]) -> [[String]]
  
  func removeChildren(_ path:[String])
  
  func merge(_ path:[String], objects:[NSDictionary])
  
  func delete(_ path:[String], fields:[String])
  
  func dumpInfo()
  
  func dumpInfo(_ path:[String])
  
  func removeAllObjects()
  
  // MARK: Legacy v0 Mutation/Query Support
  
  func processMutation(_ channel:String?, operation:NSDictionary) -> [Atom]
  
  func saveObject(_ channel:String, object:NSDictionary) -> [Atom]
}

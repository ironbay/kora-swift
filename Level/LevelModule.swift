//
//  LevelModule.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

@objc class LevelModule: NSObject, DeltaModuleProtocol {
  
  func getObject(_ path:[String]) -> DeltaObjectProtocol? {
    if objectExists(path) {
      return LevelObject.init(rootPath: path)
    }
    return nil
  }
  
  func getChildren(_ path:[String]) -> [DeltaObjectProtocol]? {
    if !objectExists(path) {
      return nil
    }
    
    var objects:[DeltaObjectProtocol] = [DeltaObjectProtocol]()
    for rootPath in getChildrenPaths(path) {
      let object:DeltaObjectProtocol = LevelObject(rootPath:rootPath)
      objects.append(object)
    }
    return objects
  }
  
  func getChildren(_ path:[String], limit:Int) -> [DeltaObjectProtocol]? {
    if !objectExists(path) {
      return nil
    }
    
    var objects:[DeltaObjectProtocol] = [DeltaObjectProtocol]()

    for rootPath in getChildrenPaths(path) {
      let object:DeltaObjectProtocol = LevelObject(rootPath:rootPath)
      objects.append(object)
      
      if objects.count == limit {
        break
      }
    }
    return objects
  }
  
  func getChildrenIds(_ path:[String]) -> [String] {
    var ids:[String] = [String]()
    for path in getChildrenPaths(path) {
      if let id = path.last {
        ids.append(id)
      }
    }
    return ids
  }
  
  func getChildrenPaths(_ path:[String]) -> [[String]] {
    let strPath = Delta.convertPathToString(path, root: nil)
    let prefix = strPath + Delta.SEPARATOR
    let keys:[String] = LevelWrapper.getKeys(prefix)
    
    let map:NSMutableDictionary = NSMutableDictionary()
    var rootPaths:[[String]] = [[String]]()
    for key in keys {
      let childPath = key.components(separatedBy: Delta.SEPARATOR)
      if childPath.count > path.count {
        let rootPath:[String] = Array(childPath[0...path.count])
        let string = Delta.convertPathToString(rootPath, root:nil)
        if map[string] == nil {
          rootPaths.append(rootPath)
          map[string] = string
        }
      }
    }
    return rootPaths
  }
  
  func removeChildren(_ path:[String]) {
    if !objectExists(path) {
      return
    }
    
    let strPath = Delta.convertPathToString(path, root: nil)
    let prefix = strPath + Delta.SEPARATOR
    LevelWrapper.removeAllObjectsWithPrefix(prefix)
  }
  
  func merge(_ path:[String], objects:[NSDictionary]) {
    for object in objects {
      if let field = object.allKeys.first as? String {
        var mergePath:[String] = path
        mergePath.append(field)
        LevelWrapper.setObject(object[field]! as AnyObject, key:Delta.convertPathToString(mergePath, root:nil))
      }
    }
  }
  
  func delete(_ path:[String], fields:[String]) {
    for field in fields {
      var deletePath = path
      deletePath.append(field)
      LevelWrapper.removeAllObjectsWithPrefix(Delta.convertPathToString(deletePath, root: nil))
    }
  }
  
  func processMutation(_ channel:String?, operation:NSDictionary) -> [Atom] {
    var currentPath:[String] = [String]()
    if let theChannel = channel {
      currentPath.append(theChannel)
    }
    var atoms:[Atom] = [Atom]()
    recurOnOperations(operation, currentPath:&currentPath, atoms:&atoms)
    return atoms
  }
  
  func saveObject(_ channel:String, object:NSDictionary) -> [Atom] {
    var currentPath:[String] = [String]()
    currentPath.append(channel)
    var outputDeltas:[Atom] = [Atom]()
    if let theObject = object[channel] as? NSDictionary {
      recurOnSave(theObject, currentPath:&currentPath, outputDeltas:&outputDeltas)
    }
    return outputDeltas
  }
  
  func dumpInfo() {
    LevelWrapper.dumpInfo()
  }
  
  func dumpInfo(_ path:[String]) {
    let prefix = Delta.convertPathToString(path, root: nil)
    LevelWrapper.dumpInfo(prefix)
  }
  
  func removeAllObjects() {
    LevelWrapper.removeAllObjects()
  }
  
  // MARK: Private Functions
  
  fileprivate func objectExists(_ path:[String]) -> Bool {
    let key:String = Delta.convertPathToString(path, root: nil)
    return LevelWrapper.objectExistsForKey(key)
  }
  
  fileprivate func recurOnOperations(_ operation:NSDictionary, currentPath:inout [String], atoms:inout [Atom]) {
    if currentPath.isEmpty == false {
      if currentPath.count <= 3 {
        let delta = Atom(path:currentPath);
        let string = Delta.convertPathToString(delta.getPath(), root:nil)
        if string != DeltaEngine.OP_MERGE && string != DeltaEngine.OP_DELETE {
          atoms.append(delta)
        }
      }
      
      let lastSection = currentPath.removeLast()
      currentPath.append(lastSection)
      LevelWrapper.setObject(true as AnyObject, key:Delta.convertPathToString(currentPath, root: nil))
      currentPath.removeLast()
      currentPath.append(lastSection)
    }
    
    if let mergeOp = operation[DeltaEngine.OP_MERGE] as? NSDictionary {
      let rootKeyPath = Delta.convertPathToString(currentPath, root: nil)
      for localKey in mergeOp.allKeys as! [String] {
        let object = mergeOp[localKey]
        if let theObject = object {
          LevelWrapper.setObject(theObject as AnyObject, key:rootKeyPath+Delta.SEPARATOR+localKey)
          if currentPath.count <= 2 {
            currentPath.append(localKey)
            atoms.append(Atom(path:currentPath))
            currentPath.removeLast()
          }
        }
      }
    }
    
    if let deleteOp = operation[DeltaEngine.OP_DELETE] as? [String] {
      let rootKeyPath = Delta.convertPathToString(currentPath, root: nil)
      for index in 0 ..< deleteOp.count {
        let currentKey = rootKeyPath + Delta.SEPARATOR + deleteOp[index]
        LevelWrapper.removeAllObjectsWithPrefix(currentKey)
        
        let objectId = rootKeyPath + Delta.SEPARATOR + deleteOp[index]
        LevelWrapper.removeObjectForKey(objectId)
      }
    }
    
    for key in operation.allKeys as! [String] {
      if key == DeltaEngine.OP_MERGE || key == DeltaEngine.OP_DELETE {
        continue
      }
      currentPath.append(key)
      recurOnOperations(operation[key] as! NSDictionary, currentPath:&currentPath, atoms:&atoms)
      currentPath.removeLast()
    }
  }
  
  fileprivate func recurOnSave(_ object:NSDictionary, currentPath:inout [String], outputDeltas:inout [Atom]) {
    if currentPath.isEmpty == false {
      if currentPath.count <= 3 {
        outputDeltas.append(Atom(path:currentPath))
      }
      
      let lastSection = currentPath.removeLast()
      currentPath.append(lastSection)
      LevelWrapper.setObject(true as AnyObject, key:Delta.convertPathToString(currentPath, root: nil))
      currentPath.removeLast()
      currentPath.append(lastSection)
    }
    
    let rootKeyPath:String = Delta.convertPathToString(currentPath, root:nil)
    for key in object.allKeys as! [String] {
      let value = object[key]
      if let theValue = value as? NSDictionary {
        currentPath.append(key)
        recurOnSave(theValue, currentPath:&currentPath, outputDeltas:&outputDeltas)
        currentPath.removeLast()
      } else if let theValue = value {
        LevelWrapper.setObject(theValue as AnyObject, key:rootKeyPath + Delta.SEPARATOR + key)
        if currentPath.count <= 2 {
          currentPath.append(key)
          outputDeltas.append(Atom(path:currentPath))
          currentPath.removeLast()
        }
      }
    }
  }
}

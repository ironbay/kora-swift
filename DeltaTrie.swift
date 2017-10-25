//
//  DeltaTrie.swift
//  Inbox
//
//  Created by Hani Shabsigh on 7/6/16.
//  Copyright © 2016 Inbox. All rights reserved.
//

import Foundation

class DeltaTrie {
  static let WildCard:String = "+"
  
  fileprivate var root:Trie = Trie()
  
  func addObject(_ object:AnyObject, path:[String]) {
    var currentNode:Trie = root
    for part in path {
      var subNode:Trie? = currentNode.children[part]
      if subNode == nil {
        subNode = Trie(key:part, parent:currentNode)
        currentNode.children[part] = subNode
      }
      currentNode = subNode!
    }
    
    if !currentNode.values.contains(object) {
      currentNode.values.add(object)
    }
  }
  
  func removeObject(_ object:AnyObject, path:[String]) {
    var currentNode:Trie = root
    for part in path {
      let subNode:Trie? = currentNode.children[part]
      if
        subNode == nil {
        return
      }
      currentNode = subNode!
    }
    
    if currentNode.values.contains(object) {
      currentNode.values.remove(object)
    }
  }
  
  func find(_ path:[String]) -> NSArray {
    return aggregateChildValues(path, currentNode:root).copy() as! NSArray
  }
  
  fileprivate func aggregateChildValues(_ path:[String]?, currentNode:Trie?) -> NSMutableArray {
    guard let currentNode = currentNode, var path = path else {
      return NSMutableArray()
    }
    
    if path.count > 0 {
      let aggregatedValues:NSMutableArray = NSMutableArray()
      let part:String = path.removeFirst()
      
      let childNode:Trie? = currentNode.children[part]
      if childNode != nil {
        for object in aggregateChildValues(path, currentNode:childNode) {
          aggregatedValues.add(object)
        }
      }
      
      let wildCardNode = currentNode.children[DeltaTrie.WildCard]
      if (wildCardNode != nil) {
        for object in aggregateChildValues(path, currentNode:wildCardNode) {
          aggregatedValues.add(object)
        }
      }
      
      return aggregatedValues
    }
    
    return currentNode.values
  }
}

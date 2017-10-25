//
//  Trie.swift
//  Inbox
//
//  Created by Hani Shabsigh on 6/24/16.
//  Copyright © 2016 Inbox. All rights reserved.
//

import Foundation

class Trie {
  
  var key:String
  var parent:Trie?
  var children:[String:Trie] = [String:Trie]()
  var values:NSMutableArray = NSMutableArray()
  
  convenience init() {
    self.init(key: "", parent: nil)
  }
  
  init(key:String, parent:Trie?) {
    self.key = key
    self.parent = parent
  }
}

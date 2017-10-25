//
//  Delta.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

class Delta:NSObject {
  
  static let SEPARATOR:String = "."
  
  class func convertPathToString(_ path:[String], root:String?) -> String {
    if let root = root {
      return root + Delta.SEPARATOR + path.joined(separator: Delta.SEPARATOR)
    } else {
      return path.joined(separator: Delta.SEPARATOR)
    }
  }
}

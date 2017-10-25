//
//  DeltaListener.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

@objc protocol DeltaListenerProtocol : class {
  
  @objc optional
  func willApplyAtom(_ atom:Atom)
  func didApplyAtom(_ atom:Atom)
}

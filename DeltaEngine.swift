//
//  DeltaEngine.swift
//  Inbox
//
//  Created by Hani Shabsigh on 12/3/15.
//  Copyright © 2015 Inbox. All rights reserved.
//

import Foundation

@objc class DeltaEngine: NSObject {
  
  static let KEY = "key"
  
  static let ACTION:String = "action"
  static let ACTION_RESPONSE:String = "drs.response"
  static let ACTION_ERROR = "drs.error"
  static let ACTION_EXCEPTION = "drs.exception"
  
  static let VERSION:String = "version"
  
  static let OP:String = "op"
  static let OP_MERGE:String = "$merge"
  static let OP_DELETE:String = "$delete"
  
  static let BODY:String = "body"
  
  fileprivate let KEY_QUEUE:String = "delta:internal:queue"
  
  public let mWriteQueue:DispatchQueue = DispatchQueue(label: "com.inboxtheapp.deltaEngine.writeQueue", attributes: [])
  fileprivate let mReadQueue:DispatchQueue = DispatchQueue(label: "com.inboxtheapp.deltaEngine.readQueue", attributes: DispatchQueue.Attributes.concurrent)
  fileprivate let mOutgoingQueue:DispatchQueue = DispatchQueue(label: "com.inboxtheapp.deltaEngine.outgoingQueue", attributes: [])
  fileprivate let mBroadcastQueue:DispatchQueue = DispatchQueue(label: "com.inboxtheapp.deltaEngine.broadcastQueue", attributes: DispatchQueue.Attributes.concurrent)
  fileprivate var mProcessingOutgoingQueue:Bool = false
  
  fileprivate var mDeltaModule:DeltaModuleProtocol
  fileprivate var mDeltaTransport:DeltaTransportProtocol
  
  fileprivate var mListenerMap:DeltaTrie = DeltaTrie()
  
  fileprivate let mPingQueue:DispatchQueue = DispatchQueue(label: "com.inboxtheapp.deltaEngine.pingQueue", attributes: [])
  fileprivate var mPingTimer:Timer?
  
  // MARK: - Public Functions
  
  // MARK: Init
  
  init (deltaModule:DeltaModuleProtocol, deltaTransport:DeltaTransportProtocol) {
    mDeltaModule = deltaModule
    mDeltaTransport = deltaTransport
    super.init()
    mDeltaTransport.setDeltaEngine(self)
    processOutgoingQueueAsync()
  }
  
  // MARK: Debug Tools
  
  /**
   Prints every key/value stored in Delta to the console
   */
  func dumpInfo() {
    mDeltaModule.dumpInfo()
  }
  
  /**
   Prints every key/value stored in Delta to the console under a specific path prefix
   
   - Parameter path: The path prefix for keys that will be printed to the console
   */
  func dumpInfo(_ path:[String]) {
    mDeltaModule.dumpInfo(path)
  }
  
  // MARK: Command Processing
  
  /**
   Stores Delta Command Dictionary based on version / action combination and broadcasts to DeltaListeners
   
   Delta Command Dictionary always follow the format:
   
   ```
   {
     "key": "[some-uuid]",
     "action": "some.command",
     "version": 0, // Optional, defaults to 0
     "body": {
       "any": {
         "payload": true,
       }
     }
   }
   ```
   
   Further documentation can be found at: https://github.com/InboxAppCo/documentation/blob/master/specs/0-drs.md
   
   - Parameter command: A dictionary that represents the JSON representation of a Delta Command
   - Parameter broadcast: Whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: The queue on which the block should be called. If nil will call on main thread.
   - Parameter block: Block is called on completion
   */
  func processCommandDictionary(_ command:[String:AnyObject], broadcast:Bool, queue: DispatchQueue?, block:(()->())?) {
    mWriteQueue.async {
      self._processCommandDictionary(command, broadcast:broadcast)
      
      if let theBlock = block {
        if let theQueue = queue {
          theQueue.async(execute: theBlock)
        } else {
          DispatchQueue.main.async(execute: theBlock)
        }
      }
    }
  }
  
  /**
   Stores Delta Command Object based on version / action combination and broadcasts to DeltaListeners
   
   - Parameter action: Delta Command Object
   - Parameter broadcast: Whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: The queue on which the block should be called. If nil will call on main thread.
   - Parameter block: Block is called on completion
   */
  func processCommandObject(_ command:DeltaCommandProtocol, broadcast:Bool, queue: DispatchQueue?, block:(()->())?) {
    mWriteQueue.async {
      let json = command.getJSON()
      self._processCommandDictionary(json, broadcast:broadcast)
      
      if let theBlock = block {
        if let theQueue = queue {
          theQueue.async(execute: theBlock)
        } else {
          DispatchQueue.main.async(execute: theBlock)
        }
      }
    }
  }
  
  /**
   Stores Delta Command Object based on version / action combination and broadcasts to DeltaListeners
   Queues changes to be delivered to server
   
   - Parameter action: Delta Command Object
   - Parameter broadcast: Whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: The queue on which the block should be called. If nil will call on main thread.
   - Parameter block: Block is called when object is placed in queue
   */
  func processAndQueueCommandObject(_ command:DeltaCommandProtocol, broadcast:Bool, queue: DispatchQueue?, block:(()->())?) {
    mWriteQueue.async {
      let json = command.getJSON()
      self._processCommandDictionary(json, broadcast:broadcast)
      
      LevelWrapper.setObject(json as AnyObject, key:self.KEY_QUEUE + Delta.SEPARATOR + command.getKey())
      self.processOutgoingQueueAsync()
      
      if let theBlock = block {
        if let theQueue = queue {
          theQueue.async(execute: theBlock)
        } else {
          DispatchQueue.main.async(execute: theBlock)
        }
      }
    }
  }
  
  /**
   Stores Delta Command Object based on version / action combination and broadcasts to DeltaListeners
   Immediately sends object to server instead of placing in queue
   
   - Parameter action: Delta Command Object
   - Parameter broadcast: Whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: The queue on which the block should be called. If nil will call on main thread.
   - Parameter block: Block is called when object object has been successfully sent to server or failed
   */
  
  func processAndSendCommandObjectOverRest(_ command:DeltaCommandProtocol, broadcast:Bool, queue: DispatchQueue?, block:((_ error:NSError?, _ response:[String:AnyObject]?) -> Void)?) {
    mWriteQueue.async {
      let json = command.getJSON()
      self._processCommandDictionary(json, broadcast:broadcast)
      
      self.mDeltaTransport.sendCommandREST(json, broadcast: broadcast, callback: { (error:NSError?, response:[String:AnyObject]?) in
        if let theBlock = block {
          if self.isDictionaryResponse(response) || self.doesDictionaryHaveValidCommandKeys(response) {
            self._processCommandDictionary(response!, broadcast: broadcast)
            if let theQueue = queue {
              theQueue.async {
                theBlock(error, response)
              }
            } else {
              Thread.in_performBlock(onMainThread: {
                theBlock(error, response)
              })
            }
          } else {
            if let theQueue = queue {
              theQueue.async {
                theBlock(NSError(domain:"DeltaEngine", code:401, userInfo:nil), nil)
              }
            } else {
              Thread.in_performBlock(onMainThread: {
                theBlock(NSError(domain:"DeltaEngine", code:401, userInfo:nil), nil)
              })
            }
          }
        }
      })
    }
  }
  
  /**
   Stores Delta Command Object based on version / action combination and broadcasts to DeltaListeners
   Immediately sends object to server instead of placing in queue
   
   - Parameter action: Delta Command Object
   - Parameter broadcast: Whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: The queue on which the block should be called. If nil will call on main thread.
   - Parameter block: Block is called when object object has been successfully sent to server or failed
   */
  func sendCommandObject(_ command:DeltaCommandProtocol, preprocess:Bool, broadcast:Bool, queue: DispatchQueue?, block: ((_ error:NSError?, _ response:[String:AnyObject]?) -> Void)?) {
    mWriteQueue.async {
      let json = command.getJSON()
      
      if preprocess {
        self._processCommandDictionary(json, broadcast:broadcast)
      }
      
      self.mDeltaTransport.sendCommand(json, broadcast: broadcast, callback: { (error:NSError?, response:[String:AnyObject]?) in
        if let theBlock = block {
          if self.isDictionaryResponse(response) || self.doesDictionaryHaveValidCommandKeys(response) {
            self._processCommandDictionary(response!, broadcast: broadcast)
            if let theQueue = queue {
              theQueue.async {
                theBlock(error, response)
              }
            } else {
              Thread.in_performBlock(onMainThread: {
                theBlock(error, response)
              })
            }
          } else {
            if let theQueue = queue {
              theQueue.async {
                theBlock(NSError(domain:"DeltaEngine", code:401, userInfo:nil), nil)
              }
            } else {
              Thread.in_performBlock(onMainThread: {
                theBlock(NSError(domain:"DeltaEngine", code:401, userInfo:nil), nil)
              })
            }
          }
        }
      })
    }
  }
  
  // MARK: Outgoing Queue Processing
  
  /**
   Kicks of queue to deliver commands to server
   */
  func processOutgoingQueueAsync() {
    mOutgoingQueue.async {
      if self.mProcessingOutgoingQueue {
        return
      }
      
      self.mProcessingOutgoingQueue = true
      let keys:[String] = LevelWrapper.getKeys(self.KEY_QUEUE + Delta.SEPARATOR)
      if keys.count == 0 {
        self.mProcessingOutgoingQueue = false
        return
      }
      
      let key:String = keys.first!
      let command = LevelWrapper.getValue(key)
      if let theCommand = command as? [String:AnyObject] {
        self.mDeltaTransport.sendCommand(theCommand, broadcast: true, callback: { (error:NSError?, response:[String:AnyObject]?) in
          self.mOutgoingQueue.async {
            self.mProcessingOutgoingQueue = false
            if error != nil || self.isDictionaryException(response) {
              
            } else {
              LevelWrapper.removeObjectForKey(key)
              DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
                self.processOutgoingQueueAsync()
              }
            }
          }
        })
      }
    }
  }
  
  // MARK: Listeners
  
  /**
   Adds subscriber to a path with wildcards +
   
   Examples:
   
   If you subscribe on "this.+.may" you will be notified when "this.path.may.be.long" is updated
   If you subscribe on "this.+.may.+" you will be notified when "this.path.may.be.long" is updated
   If you subscribe on "this.path.may.be.long" you will be notified when "this.path.may.be.long"
   If you subscribe on "this.path.may.be.long.jello" you will not be notified when "this.path.may.be.long" is updated
   
   - Parameter path: the path to subscribe to. Note: you can use + as a wildcard
   - Parameter listener: Object that adheres to DeltaListenerProtocol that will listen on updates
   */
  func subscribe(_ path:[String], listener:DeltaListenerProtocol) {
    mListenerMap.addObject(listener, path:path)
  }
  
  /**
   Removes subscriber to root path (aka channel)
   
   - Parameter channel: Root of path to unsubscribe from
   - Parameter listener: Object that adheres to DeltaListenerProtocol that will listen on updates
   */
  func unsubscribe(_ path:[String], listener:DeltaListenerProtocol) {
    mListenerMap.removeObject(listener, path:path)
  }
  
  // MARK: Read Data
  
  /**
   Checks if an object exists locally at the specified path
   
   - Parameter path: The path of the object
   - Return Bool: results of the check
   */
  func doesPathExist(_ path:[String]) -> Bool {
   return LevelWrapper.objectExistsForKey(Delta.convertPathToString(path, root: nil))
  }
  
  /**
   Retreives a single Delta Object from the local datastore
   
   - Parameter path: The path of the object
   */
  func getLocalObjectAtPath(_ path:[String]) -> DeltaObjectProtocol? {
    return getLocalObjectsAtPaths([path]).first
  }
  
  /**
   Retreives a single Delta Object from the network
   
   Note: Even if there is a network error the local object is also returned in the block
   
   - Parameter path: the path of the object
   - Parameter broadcast: whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: the queue on which the block should be called. If nil will call on main thread
   - Parameter block: block is called at completion
   */
  func getNetworkObjectAtPath(_ path:[String], broadcast:Bool, queue:DispatchQueue?, block:((_ error:NSError?, _ object:DeltaObjectProtocol?) -> Void)?) {
    getNetworkObjectsAtPaths([path], broadcast:broadcast, queue:queue) { (error, objects) in
      if let theBlock = block {
        theBlock(error, objects.first)
      }
    }
  }
  
  /**
   Retreives a single Delta Object, attempts local datastore first then network if local object had no children
   
   Note: Even if there is a network error the local object is also returned in the block
   
   - Parameter path: the path of the object
   - Parameter broadcast: whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: the queue on which the block should be called. If nil will call on main thread
   - Parameter block: block is called at completion
   */
  func getObjectAtPath(_ path:[String], broadcast:Bool, queue:DispatchQueue?, block:((_ error:NSError?, _ object:DeltaObjectProtocol?) -> Void)?) {
    getObjectsAtPaths([path], broadcast:broadcast, queue:queue) { (error, objects) in
      if let theBlock = block {
        theBlock(error, objects.first)
      }
    }
  }
  
  func getChildKeysAtPrefix(_ prefix:String, startingKey:String, limit:Int, reverse:Bool) -> [String] {
   return LevelWrapper.getKeys(prefix, startingKey: startingKey, limit: limit, reverse: reverse)
  }
  
  /**
   Retreives multiple Delta Objects from the local datastore
   
   - Parameter path: The path of the object
   */
  func getLocalObjectsAtPaths(_ paths:[[String]]) -> [DeltaObjectProtocol] {
    var objects:[DeltaObjectProtocol] = [DeltaObjectProtocol]()
    for path in paths {
      if let object = self.mDeltaModule.getObject(path) {
        objects.append(object)
      }
    }
    return objects
  }
  
  /**
   Retreives multiple Delta Objects from the network
   
   Note: Even if there is a network error the local objects are also returned in the block
   
   - Parameter path: the path of the object
   - Parameter broadcast: whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: the queue on which the block should be called. If nil will call on main thread
   - Parameter block: block is called at completion
   */
  func getNetworkObjectsAtPaths(_ paths:[[String]], broadcast:Bool, queue:DispatchQueue?, block:((_ error:NSError?, _ objects:[DeltaObjectProtocol]) -> Void)?) {
    mReadQueue.async {
      // if we are forced to download the object from the network OR the object is nil than continue to downloading the object from the network
      let deltaQuery:DeltaQuery = DeltaQuery()
      for path in paths {
        deltaQuery.addPath(path)
      }
      self.mDeltaTransport.sendCommand(deltaQuery.getJSON(), broadcast: broadcast, callback: { (error:NSError?, response:[String:AnyObject]?) in
        self.mReadQueue.async {
          
          // attempt to parse the object from the network response, if successful overwrite the local delta object
          if let response = response {
            self._processCommandDictionary(response, broadcast:broadcast)
          }
          
          if let theBlock = block {
            if let theQueue = queue {
              theQueue.async {
                theBlock(error, self.getLocalObjectsAtPaths(paths))
              }
            } else {
              DispatchQueue.main.async {
                theBlock(error, self.getLocalObjectsAtPaths(paths))
              }
            }
          }
        }
      })
    }
  }
  
  /**
   Retreives multiple Delta Objects, attempts local datastore first then network if even a single local object had no children
   
   Note: Even if there is a network error the local objects are also returned in the block
   
   - Parameter path: the path of the object
   - Parameter broadcast: whether resulting Atoms should be broadcast to DeltaListeners
   - Parameter queue: the queue on which the block should be called. If nil will call on main thread
   - Parameter block: block is called at completion
   */
  func getObjectsAtPaths(_ paths:[[String]], broadcast:Bool, queue:DispatchQueue?, block:((_ error:NSError?, _ objects:[DeltaObjectProtocol]) -> Void)?) {
    let objects:[DeltaObjectProtocol] = getLocalObjectsAtPaths(paths)
    if objects.count == paths.count {
      if let theBlock = block {
        if let theQueue = queue {
          theQueue.async {
            theBlock(nil, self.getLocalObjectsAtPaths(paths))
          }
        } else {
          DispatchQueue.main.async {
            theBlock(nil, self.getLocalObjectsAtPaths(paths))
          }
        }
      }
    } else {
      getNetworkObjectsAtPaths(paths, broadcast:broadcast, queue:queue, block:block)
    }
  }
  
  /**
   Retreives direct Children of the prefix path
   
   - Parameter path: The prefix path
   
   - Returns: an array of objects that adhere to DeltaObjectProtocol
   */
  func getChildren(_ path:[String]) -> [DeltaObjectProtocol]? {
    return mDeltaModule.getChildren(path)
  }
  
  /**
   Retreives a limited number of direct Children of the prefix path
   
   - Parameter path: The prefix path
   - Parameter limit: The maximum number of children to retreive
   
   - Returns: an array of objects that adhere to DeltaObjectProtocol
   */
  func getChildren(_ path:[String], limit:Int) -> [DeltaObjectProtocol]? {
    return mDeltaModule.getChildren(path, limit:limit)
  }
  
  /**
   Removed all local objects from datastore
   */
  func removeAllObjectsLocal() {
    self.mWriteQueue.sync {
      self.mDeltaModule.removeAllObjects()
    }
  }
  
  /**
   Retreives direct Children Ids of the prefix path
   
   - Parameter path: The prefix path
   
   - Returns: an array of strings(ids)
   */
  func getChildrenIds(_ path:[String]) -> [String] {
    return mDeltaModule.getChildrenIds(path)
  }
  
  /**
   Retreives direct Children Paths of the prefix path
   
   - Parameter path: The prefix path
   
   - Returns: an array of arrays(paths)
   */
  func getChildrenPaths(_ path:[String]) -> [[String]] {
    return mDeltaModule.getChildrenPaths(path)
  }
  
  /**
   Retreives direct Children Paths of the prefix path
   
   - Parameter path: The prefix path
   
   - Returns: current time in milliseconds adjusted to sync with the server
   */
  func currentTimeMillis() -> Double {
    return Double(Date().timeIntervalSince1970 * 1000)
  }
  
  // MARK: - Private Functions
  
  // MARK: Listeners
  
  /**
   Retreives listeners for a specific root path
   
   - Parameter channel: Root of path to subscribe to
   - Returns: an array of objects that adheres to DeltaListenerProtocol
   */
  fileprivate func getListeners(_ path:[String]) -> NSArray {
    return mListenerMap.find(path)
  }
  
  /**
   Broadcasts Atoms to listeners before being applied to local delta
   
   - Parameter atoms: an array of Atoms
   */
  fileprivate func prebroadcast(_ atoms:[Atom]) {
    for atom in atoms {
      for listener in self.getListeners(atom.getPath()) {
        if (listener as AnyObject).responds(to: #selector(DeltaListenerProtocol.willApplyAtom(_:))) {
          (listener as! DeltaListenerProtocol).willApplyAtom!(atom)
        }
      }
    }
  }
  
  /**
   Broadcasts Atoms to listeners after being applied to local delta
   
   - Parameter atoms: an array of Atoms
   */
  fileprivate func broadcast(_ atoms:[Atom]) {
    mBroadcastQueue.async(execute: { () -> Void in
      for atom in atoms {
        for listener in self.getListeners(atom.getPath()) {
          if (listener as AnyObject).responds(to: #selector(DeltaListenerProtocol.didApplyAtom(_:))) {
            (listener as! DeltaListenerProtocol).didApplyAtom(atom)
          }
        }
      }
    })
  }
  
  // MARK: Delta Command Processing
  
  /**
   Stores Delta Command Dictionary based on version / action combination and broadcasts to DeltaListeners
   
   Delta Command Dictionary always follow the format:
   
   ```
   {
     "key": "[some-uuid]",
     "action": "some.command",
     "version": 0, // Optional, defaults to 0
     "body": {
       "any": {
         "payload": true,
       }
     }
   }
   ```
   
   Further documentation can be found at: https://github.com/InboxAppCo/documentation/blob/master/specs/0-drs.md
   
   - Parameter command: A dictionary that represents the JSON representation of a Delta Command
   - Parameter broadcast: Whether resulting Atoms should be broadcast to DeltaListeners
   */
  fileprivate func _processCommandDictionary(_ command:[String:AnyObject], broadcast:Bool) {
    let version = command[DeltaEngine.VERSION] as? Int
    let action:String? = command[DeltaEngine.ACTION] as? String
    
    if action == DeltaEngine.ACTION_RESPONSE {
      _processCommandDictionaryV1(command, broadcast:broadcast)
      return
    }
    
    if version == 1 || version == nil {
      _processCommandDictionaryV1(command, broadcast:broadcast)
      return
    }
    
    if version == 0 {
      _processCommandDictionaryV0(command, broadcast:broadcast)
      return
    }
  }
  
  /**
   Stores v1 Delta Command Dictionary based on action and broadcasts to DeltaListeners
   
   - Parameter command: A dictionary that represents the JSON representation of a Delta Command
   - Parameter broadcast: Whether resulting Atoms should be broadcast to DeltaListeners
   */
  fileprivate func _processCommandDictionaryV1(_ command:[String:AnyObject], broadcast:Bool) {
    let action:String? = command[DeltaEngine.ACTION] as? String
    if action == DeltaMutation.ACTION_MUTATION || action == DeltaEngine.ACTION_RESPONSE {
      if let body = command[DeltaEngine.BODY] as? [String:AnyObject] {
        let keys = Array(body.keys)
        if keys.contains(DeltaEngine.OP_MERGE) && keys.contains(DeltaEngine.OP_DELETE) {
          let atoms:[Atom] = generateAtomsFromBody(body)
          if (broadcast) {
            self.prebroadcast(atoms);
          }
          for atom in atoms {
            let path = atom.getPath()
            let fields = atom.deleteFields()
            mDeltaModule.delete(path, fields:fields)
          }
          for atom in atoms {
            let path = atom.getPath()
            let objects = atom.mergeObjects()
            mDeltaModule.merge(path, objects:objects)
          }
          if (broadcast) {
            self.broadcast(atoms)
          }
        }
      }
    }
  }
  
  /**
   Stores v0 Delta Command Dictionary based on action and broadcasts to DeltaListeners
   
   - Parameter command: A dictionary that represents the JSON representation of a Delta Command
   - Parameter broadcast: Whether resulting Atoms should be broadcast to DeltaListeners
   */
  fileprivate func _processCommandDictionaryV0(_ command:[String:AnyObject], broadcast:Bool) {
    if let action:String = command[DeltaEngine.ACTION] as? String {
      var atoms = [Atom]()
      
      if action == DeltaMutation.ACTION_MUTATION {
        if let body = command[DeltaEngine.BODY] as? [String:AnyObject] {
          if let op = body[DeltaEngine.OP] as? [String:AnyObject] {
            for key in Array(op.keys) {
              if key == DeltaEngine.OP_DELETE || key == DeltaEngine.OP_MERGE {
                continue
              }
              
              if let x = op[key] as? [String:AnyObject] {
                atoms.append(contentsOf:self.mDeltaModule.processMutation(key, operation:x as NSDictionary))
              }
            }
          }
        }
      } else if action == DeltaQuery.ACTION_QUERY {
        if let body = command[DeltaEngine.BODY] as? [String:AnyObject] {
          for key in Array(body.keys) {
            atoms.append(contentsOf:self.mDeltaModule.saveObject(key, object:body as NSDictionary))
          }
        }
      }
      
      if (broadcast) {
        self.broadcast(atoms)
      }
    }
  }
  
  // MARK: Body to Atom

  /**
   Generates Atoms from Delta Command Body
   
   - Parameter body: Body of Delta Command to be converted into Atoms
   
   - Returns: Array of Atoms
   */
  fileprivate func generateAtomsFromBody(_ body:[String:AnyObject]) -> [Atom] {
    let paths:[[String]] = findUniquePathsFromKeys([DeltaEngine.OP_MERGE, DeltaEngine.OP_DELETE], object:body as NSDictionary)
    return generateAtomsFromBodyWithPaths(body as NSDictionary, paths:paths)
  }
  
  /**
   Finds Unique Paths in Objects
   
   - Parameter keys: The root level keys in the root object that contain the objects that are compared to find the unique paths
   - Parameter object: The root object that contains other objects that will be compared to find unique paths
   
   - Returns: Array of Paths
   */
  fileprivate func findUniquePathsFromKeys(_ keys:[String], object:NSDictionary) -> [[String]] {
    var map:NSMutableDictionary = NSMutableDictionary()
    var paths:[[String]] = [[String]]()
    
    let emptyPath:[String] = [String]()
    paths.append(emptyPath)
    
    for key in keys {
      if let object = object[key] as? NSDictionary {
        self.findUniquePathsFromRootPath([], paths:&paths, object:object, map:&map)
      }
    }
    return paths
  }
  
  /**
   Recursive Function used to find Unique Paths in Object from Root Path
   
   - Parameter root: Root path that was used to create object
   - Parameter inout paths: Pass through array of paths
   - Parameter object: The sub object that contains other objects that will be compared to find unique paths
   
   - Returns: Array of Paths
   */
  fileprivate func findUniquePathsFromRootPath(_ root:[String], paths:inout [[String]], object:NSDictionary, map:inout NSMutableDictionary) {
    let keys = object.allKeys
    for key in keys as! [String] {
      if let sub = object[key] as? NSDictionary {
        var mutRoot = root
        mutRoot.append(key)
        let string = Delta.convertPathToString(mutRoot, root:nil)
        if let _ = map[string] {
          
        } else {
          paths.append(mutRoot)
          map[string] = string
        }
        findUniquePathsFromRootPath(mutRoot, paths:&paths, object:sub, map:&map)
      }
    }
  }
  
  /**
   Generates Atoms from Delta Command Body with Paths
   
   - Parameter object: The root object that contains other objects that will be compared to find unique paths
   - Parameter paths: Paths in Delta Command body
   
   - Returns: Array of Paths
   */
  fileprivate func generateAtomsFromBodyWithPaths(_ object:NSDictionary, paths:[[String]]) -> [Atom] {
    var atoms:[Atom] = [Atom]()
    if let merge = object[DeltaEngine.OP_MERGE] as? NSDictionary, let delete = object[DeltaEngine.OP_DELETE] as? NSDictionary {
      for path in paths {
        let atom:Atom = Atom(path:path)
        
        atom.merge = getObjectAtPath(merge, path:path)
        
        atom.delete = getObjectAtPath(delete, path:path)
        
        atoms.append(atom)
      }
    }
    return atoms
  }
  
  fileprivate func getObjectAtPath(_ object:NSDictionary, path:[String]) -> NSDictionary {
    var sub:NSDictionary? = object
    for part in path {
      sub = sub![part] as? NSDictionary
      if sub == nil {
        break
      }
    }
    
    if sub != nil {
      return sub!
    } else {
      return NSDictionary()
    }
  }
  
  // MARK: Errors & Exceptions
  
  fileprivate func doesDictionaryHaveValidCommandKeys(_ dictionary:[String:AnyObject]?) -> Bool {
    if let dictionary = dictionary {
      if let _ = dictionary[DeltaEngine.KEY] as? String, let _ = dictionary[DeltaEngine.ACTION] as? String, let _ = dictionary[DeltaEngine.BODY] as? [String:AnyObject] {
        return true
      }
    }
    return false
  }
  
  fileprivate func isDictionaryError(_ dictionary:[String:AnyObject]?) -> Bool {
    if let dictionary = dictionary {
      if let action = dictionary[DeltaEngine.ACTION] as? String {
        if action == DeltaEngine.ACTION_ERROR {
          return true
        }
      }
    }
    return false
  }
  
  fileprivate func isDictionaryException(_ dictionary:[String:AnyObject]?) -> Bool {
    if let dictionary = dictionary {
      if let action = dictionary[DeltaEngine.ACTION] as? String {
        if action == DeltaEngine.ACTION_EXCEPTION {
          return true
        }
      }
    }
    return false
  }
  
  fileprivate func isDictionaryResponse(_ dictionary:[String:AnyObject]?) -> Bool {
    if let dictionary = dictionary {
      if let action = dictionary[DeltaEngine.ACTION] as? String {
        if action == DeltaEngine.ACTION_RESPONSE {
          return true
        }
      }
    }
    return false
  }
  
  fileprivate func printErrorOrExceptionCommandBody(_ command:[String:AnyObject]?) {
    if let command = command {
      if let body = command[DeltaEngine.BODY] {
        print(body)
      }
    }
  }
}

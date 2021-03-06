//
//  MPCHandler.swift
//  BattleShip
//
//  Created by Aaron Johnson on 2017-10-30.
//  Copyright © 2017 Aaron Johnson. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import RxSwift

class MPCHandler: NSObject, MCSessionDelegate, PeerManager{
    func setUp(){
        self.setupPeerWithDisplayName(displayName: UIDevice.current.name)
        self.setupSession()
        self.advertiseSelf(advertise: true)
        self.setupSubscribe()
    }
    
    static let sharedInstance = MPCHandler()
    //MARK: Properties
    var peerID:MCPeerID!
    var session:MCSession!
    var browser:MCBrowserViewController!
    var advertiser:MCAdvertiserAssistant? = nil
    
    var state:MCSessionState!
    
    let recievedInstruction = PublishSubject<InstructionAndHashBundle>()
    let outgoingMessages = PublishSubject<InstructionAndHashBundle>()
    let disposeBag = DisposeBag()
    
    //MARK:- Setup
    func setupSubscribe(){
        InstructionManager.subscribeToInstructionsFrom(self.recievedInstruction)
        
        _ = InstructionManager.sharedInstance.broadcastInstructions
            .subscribe(onNext: { self.outgoingMessages.onNext($0) })
        
        
        let bufferRate = 0.25
        let messagesPerSecond = 30.0
        let messagesPerInterval = Int(messagesPerSecond * bufferRate)
        
        outgoingMessages.buffer(timeSpan: bufferRate, count: Int.max, scheduler: MainScheduler.instance)
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { (bundleArray) in
                if bundleArray.isEmpty { return }

                print("\nOutgoing Buffer: \(bundleArray.count)")
                
                if self.state == MCSessionState.connected {
                    for (index, bundle) in bundleArray.enumerated() {
                        if index < messagesPerInterval {
                            
                            print("Send: \(bundle.instruction.stamp)")
                            
                            let newMessage = LineMessage(instruction: bundle.instruction)
                            newMessage.currentHash = bundle.hash
                            self.sendLine(lineMessage: newMessage)
                        } else {
                            self.outgoingMessages.onNext(bundle)
                        }
                    }
                }
            }).disposed(by: self.disposeBag)
    }
    
    func setupPeerWithDisplayName (displayName:String){
        peerID = MCPeerID(displayName: displayName)
    }
    func setupSession(){
        session = MCSession(peer:peerID)
        session.delegate = self
    }
    func setupBrowser(){
        browser = MCBrowserViewController(serviceType:"draw", session: session)
    }
    func advertiseSelf(advertise:Bool){
        if advertise{
            advertiser = MCAdvertiserAssistant(serviceType:"draw", discoveryInfo: nil, session: session)
            advertiser!.start()
        } else {
            advertiser!.stop()
            advertiser = nil
        }
    }
    
    //MARK: - Send message
    //    func sendInstruction(instruction:Instruction){
    //        let messageDict = ["message":message, "player":UIDevice.current.name] as [String : Any]
    //        let messageData = try! JSONSerialization.data(withJSONObject: messageDict, options: JSONSerialization.WritingOptions.prettyPrinted)
    //        try! session.send(messageData, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
    //    }
    func sendLine(lineMessage: LineMessage){
        
        DispatchQueue.global().async {
            let messageData = NSKeyedArchiver.archivedData(withRootObject: lineMessage)
            let data = NSKeyedArchiver.archivedData(withRootObject:["data":messageData, "type": 0])
            try? self.session.send(data,
                                   toPeers: self.session.connectedPeers,
                                   with: MCSessionSendDataMode.unreliable)
        }
        
        
    }
    func sendLabel(labelMessage: LabelMessage){
        let messageData = NSKeyedArchiver.archivedData(withRootObject: labelMessage)
        let data = NSKeyedArchiver.archivedData(withRootObject:["data":messageData, "type": 1])
        try? session.send(data, toPeers: session.connectedPeers, with: MCSessionSendDataMode.unreliable)
    }
    func peerFromUser(user: String) -> [MCPeerID] {
        let conPeers = self.session.connectedPeers
        let userPeerID = conPeers.filter{$0.displayName == user}
        return userPeerID
    }
    
    func requestInstructions(from peer: MCPeerID, for stampsArray: [Stamp], with hash: InstructionStoreHash) {
        if self.state == MCSessionState.connected {
            let stampMessage = StampMessage(stamps: stampsArray)
            stampMessage.currentHash = hash
            self.sendStamps(stampMessage: stampMessage, peer: peer)
        }
    }
    
    
    func sendStamps(stampMessage: StampMessage, peer:MCPeerID){
        let messageData = NSKeyedArchiver.archivedData(withRootObject: stampMessage)
        let data = NSKeyedArchiver.archivedData(withRootObject:["data":messageData, "type": 2])
        try? session.send(data, toPeers: [peer], with: MCSessionSendDataMode.reliable)
    }
    
    //MARK:- MCSessionDelegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == MCSessionState.connected {
            self.state = state
        }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        //data.
        let dic = NSKeyedUnarchiver.unarchiveObject(with: data) as! Dictionary<String, Any>
        let newInstruction: Instruction
        let instructionAndHash: InstructionAndHashBundle
        
        if dic["type"] as! Int == 0 {
            let lineMessage = NSKeyedUnarchiver.unarchiveObject(with: dic["data"] as! Data) as! LineMessage
            newInstruction = lineMessage.toInstruction()
            instructionAndHash = InstructionAndHashBundle(instruction: newInstruction,
                                                          hash: lineMessage.currentHash)
            
            DispatchQueue.main.async {
                self.recievedInstruction.onNext(instructionAndHash)
            }
            
        } else if dic["type"] as! Int == 2 {
            let stampMessage = NSKeyedUnarchiver.unarchiveObject(with: dic["data"] as! Data) as! StampMessage
            
            InstructionManager.sharedInstance.stampsStream
                .onNext(StampsAndSender(stamps: stampMessage.toStamps(),
                                        sender: peerID))
            
        } else {
            let labelMessage = NSKeyedUnarchiver.unarchiveObject(with: dic["data"] as! Data) as! LabelMessage
            newInstruction = labelMessage.toInstruction()
            instructionAndHash = InstructionAndHashBundle(instruction: newInstruction,
                                                          hash: labelMessage.currentHash)
            self.recievedInstruction.onNext(instructionAndHash)
        }
    }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }
    
}


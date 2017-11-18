//
//  InstructionManager.swift
//  Whiteboard
//
//  Created by Andrew on 2017-11-16.
//  Copyright © 2017 hearthedge. All rights reserved.
//

import Foundation
import RxSwift

class InstructionManager {
    
    static let sharedInstance = InstructionManager()
    
    private var instructionStore = [Instruction]()
    let newInstructions = PublishSubject<Instruction>()
    let broadcastInstructions = PublishSubject<Instruction>()
    private let disposeBag = DisposeBag()
    
    
    // MARK: - Methods
    
    class func subscribeToInstructionsFrom(_ newPublishSubject: PublishSubject<Instruction>) {
        newPublishSubject.subscribe(onNext: { instruction in
            InstructionManager.sharedInstance.newInstruction(instruction)
        }).disposed(by: InstructionManager.sharedInstance.disposeBag)
    }
    
    private func newInstruction(_ newInstruction: Instruction) {
        
        if (self.instructionStore.isEmpty ||
            newInstruction.stamp > self.instructionStore.last!.stamp) {
            self.instructionStore.append(newInstruction)
            self.newInstructions.onNext(newInstruction)
            self.broadcastInstructions.onNext(newInstruction)
            return
        } else {
            for (index, currentInstruction) in self.instructionStore.lazy.reversed().enumerated() {
                guard newInstruction.stamp != currentInstruction.stamp else {
                    return
                }
                if newInstruction.stamp > currentInstruction.stamp {
                    self.instructionStore.insert(newInstruction, at: self.instructionStore.count - index)
                    self.broadcastInstructions.onNext(newInstruction)

                    switch newInstruction.element {
                    case .line(_):
                        self.refreshLines()
                    case .emoji(_):
                        return
                    }
                }
            }
        }
    }
    
    private func refreshLines() {
        
    }
    
    
}


// MARK: - Instruction components

struct Instruction {
    let type : InstructionType
    let element : InstructionPayload
    let stamp : Stamp
}

enum InstructionType {
    case new
    case edit(Stamp)
    case delete(Stamp)
}

enum InstructionPayload {
    case line (LineElement)
    case emoji (LabelElement)
}

struct Stamp: Comparable, Hashable {
    var hashValue: Int {
        get {
            let timeHash = self.timestamp.hashValue
            let userHash = self.user.hashValue
            return timeHash ^ userHash &* 16777619
        }
    }
    
    static func <(lhs: Stamp, rhs: Stamp) -> Bool {
        if (lhs.timestamp < rhs.timestamp) {
            return true
        }
        if (lhs.timestamp == rhs.timestamp && lhs.user < rhs.user) {
            return true
        }
        return false
    }
    
    static func ==(lhs: Stamp, rhs: Stamp) -> Bool {
        return ((lhs.user == rhs.user) && (lhs.timestamp == rhs.timestamp))
    }
    
    
    
    let user : String
    let timestamp : Date
    
    
}

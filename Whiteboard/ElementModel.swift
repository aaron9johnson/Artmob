//
//  ElementModel.swift
//  Whiteboard
//
//  Created by Andrew on 2017-11-16.
//  Copyright © 2017 hearthedge. All rights reserved.
//

import Foundation
import UIKit
import RxSwift

class ElementModel {

    static let sharedInstance = ElementModel()

    var lineSubject = PublishSubject<[LineElement]>()
    fileprivate let incomingThrottle = PublishSubject<Instruction>()
    fileprivate var labels = [Stamp: LabelElement]()
    fileprivate let disposeBag = DisposeBag()

    init() {
        self.setupSubscriptions()
    }

    internal func setupSubscriptions() {
        _ = InstructionManager.sharedInstance.newInstructions
            .subscribe { event in
                switch event {
                case .next(let instruction):
                    switch instruction.element {
                    case .line(let lineToDraw):
                        if instruction.isFromSelf() {
                            self.lineSubject.onNext([lineToDraw])
                        } else {
                            self.incomingThrottle.onNext(instruction)
                        }
                    case .label:
                        self.processLabel(instruction)
                    }

                case .error(let error):
                    fatalError(error.localizedDescription)
                case .completed:
                    print("BoardViewModel Lines Subscription ended")

                }
        }
        
        _ = self.incomingThrottle.buffer(timeSpan: 0.1, count: 100, scheduler: MainScheduler.instance)
            .subscribe(onNext: { self.drawMultipleLines(from: $0) })
    }

    public func drawMultipleLines(from lineInstructions: [Instruction]) {
        let lineElements = lineInstructions.map { return $0.element.lineElement! }
        self.lineSubject.onNext(lineElements)
    }

    internal func processLabel(_ labelInstruction: Instruction) {

    }
}

// MARK: - Lines

struct LineElement {
    let line: Line
    let width: CGFloat
    let cap: CGLineCap
    let color: LineColor

    var drawColor: UIColor {
        switch self.color {
        case .black:
            return Colour.black
        case .white:
            return Colour.white
        case .red:
            return Colour.red
        case .orange:
            return Colour.orange
        case .yellow:
            return Colour.yellow
        case .green:
            return Colour.green
        case .blue:
            return Colour.blue
        case .purple:
            return Colour.purple
        }
    }
}

enum LineColor: Int {
    case black
    case white
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    
    var uiColor: UIColor {
        switch self {
        case .black:
            return Colour.black
        case .white:
            return Colour.white
        case .red:
            return Colour.red
        case .orange:
            return Colour.orange
        case .yellow:
            return Colour.yellow
        case .green:
            return Colour.green
        case .blue:
            return Colour.blue
        case .purple:
            return Colour.purple
        }
    }
    
}

struct Line {
    let segments: [LineSegment]

    init() {self.segments = [LineSegment]()}

    init(with line: Line = Line(), and newSegment: LineSegment) {
        self.segments = line.segments + [newSegment]
    }

    static func + (left: Line, right: LineSegment) -> Line {
        return Line(with: left, and: right)
    }
}

extension Line: Equatable {
    static func ==(lhs: Line, rhs: Line) -> Bool {
        if lhs.segments.count != rhs.segments.count {
            return false
        }
        for i in 0..<lhs.segments.count {
            if lhs.segments[i] != rhs.segments[i] {
                return false
            }
        }
        return true
    }
}

struct LineSegment {
    let firstPoint: CGPoint
    let secondPoint: CGPoint
}

extension LineSegment: Equatable {
    static func ==(lhs: LineSegment, rhs: LineSegment) -> Bool {
        return lhs.firstPoint == rhs.firstPoint && lhs.secondPoint == rhs.secondPoint
    }
    
    
}



// MARK: - Labels

struct LabelElement {
    let pos: CGPoint!
    let text: String!
    let size: CGRect!
    let rotation: Float!
}

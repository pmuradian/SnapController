//
//  SnapController.swift
//
//  Created by Paruyr Muradian on 8/13/19.

import Foundation
import UIKit

class Point: NSObject {
    private var p = CGPoint.zero
    
    var x: CGFloat {
        return p.x
    }
    
    var y: CGFloat {
        return p.y
    }
    
    init(_ point: CGPoint) {
        super.init()
        p = point
    }
    
    func toCGPoint() -> CGPoint {
        return p
    }
}

@objc protocol Snapable {
    // set this property if you need snapping behaviour on view's center
    @objc dynamic var nextCenter: Point {get set}
    // set this property if you need snapping behaviour on rotation
    @objc dynamic var angle: CGFloat {get set}
}

class SnapController: NSObject {
    
    private var viewToSnap: UIView!
    @objc private var viewThatSnaps: Snapable?
    private var isHorizontal = false
    private var isVertical = false
    private var isSnapped = false
    private var isRotationSnapped = false
    
    private var moveCount = 0;
    private var maxMoveCount = 5;
    private var unsnapThreshold = CGFloat(10)
    private var unsnapAngleThreshold = CGFloat(0.01)
    private var horizontalLine: CALayer!
    private var verticalLine: CALayer!
    private var lastKnownPosition = CGPoint.zero
    private var centerObserver: NSKeyValueObservation?
    private var rotationObserver: NSKeyValueObservation?
    private var isTimerStarted = false
    
    init<T: UIView & Snapable>(view: T, snapsTo: UIView, horizontally: Bool = true, vertically: Bool = true) {
        super.init()
        
        viewThatSnaps = view
        viewToSnap = snapsTo
        isHorizontal = horizontally
        isVertical = vertically
        
        horizontalLine = createHorizontalLineLayer()
        horizontalLine.isHidden = true
        verticalLine = createVerticalLineLayer()
        verticalLine.isHidden = true
        
        viewToSnap.layer.addSublayer(horizontalLine)
        viewToSnap.layer.addSublayer(verticalLine)
        
        self.observeCenter()
        self.observeRotation()
    }
    
    convenience init<T: UIView & Snapable>(view: T, snapsTo: UIView, horizontally: Bool) {
        self.init(view: view, snapsTo: snapsTo, horizontally: horizontally, vertically: false)
    }
    
    convenience init<T: UIView & Snapable>(view: T, snapsTo: UIView, vertically: Bool) {
        self.init(view: view, snapsTo: snapsTo, horizontally: false, vertically: vertically)
    }
    
    func finalPointReached() {
        self.lastKnownPosition = self.viewThatSnaps!.nextCenter.toCGPoint()
    }
}

// Private methods
extension SnapController {
    private func observeRotation() {
        rotationObserver = observe(\.viewThatSnaps!.angle, options: [.old, .new]) { [unowned self] object, change in
            let newTransform = (self.viewThatSnaps as! UIView).transform.rotated(by: change.newValue!)
            let newAngle = atan2(newTransform.b, newTransform.a)
            
            var clockwiseAngle = CGFloat(0)
            var counterClockwiseAngle = CGFloat(0)
            let increment = CGFloat.pi / 4
            
            if self.isRotationSnapped {
                self.moveCount += 1
            }
            
            if self.moveCount >= self.maxMoveCount {
                (self.viewThatSnaps as! UIView).transform = newTransform
                self.moveCount = 0
                self.isRotationSnapped = false
            }
            
            for _ in 0...4 {
                if newAngle < clockwiseAngle + self.unsnapAngleThreshold && newAngle > clockwiseAngle - self.unsnapAngleThreshold {
                    (self.viewThatSnaps as! UIView).transform = (self.viewThatSnaps as! UIView).transform.rotated(by: (clockwiseAngle - newAngle))
                    self.isRotationSnapped = true
                    return
                }
                if newAngle < counterClockwiseAngle + self.unsnapAngleThreshold && newAngle > counterClockwiseAngle - self.unsnapAngleThreshold {
                    (self.viewThatSnaps as! UIView).transform = (self.viewThatSnaps as! UIView).transform.rotated(by: (counterClockwiseAngle - newAngle))
                    self.isRotationSnapped = true
                    return
                }
                clockwiseAngle += increment
                counterClockwiseAngle -= increment
            }
            
            (self.viewThatSnaps as! UIView).transform = newTransform
        }
    }
    
    private func observeCenter() {
        centerObserver = observe(\.viewThatSnaps!.nextCenter, options: [.old, .new]) { [unowned self] object, change in
            let newCenter = change.newValue!.toCGPoint()
            let (h, v) = self.shouldSnap()
            
            if !self.isTimerStarted {
                self.startTimer(withDuration: 0.5)
            }
            
            if self.isSnapped {
                // if is snapped both horizontally and vertically
                if h && v {
                    // if should unsnap
                    if abs(newCenter.y - self.viewToSnap.bounds.size.height / 2) > self.unsnapThreshold || abs(newCenter.x - self.viewToSnap.bounds.size.width / 2) > self.unsnapThreshold {
                        (self.viewThatSnaps as! UIView).center = newCenter
                        self.isSnapped = false
                    } else {
                        (self.viewThatSnaps as! UIView).center = self.viewToSnap.center
                        self.showHorizontalLine()
                        self.showVerticalLine()
                    }
                    return
                }
                
                if h {
                    // change on Y axis is bigger than unsnapThreshold, should unsnap
                    if abs(newCenter.y - self.viewToSnap.bounds.size.height / 2) > self.unsnapThreshold {
                        self.isSnapped = false
                        (self.viewThatSnaps as! UIView).center = newCenter
                    } else {
                        // move along horizontal line without unsnapping
                        (self.viewThatSnaps as! UIView).center.y = self.viewToSnap.center.y
                        (self.viewThatSnaps as! UIView).center.x = newCenter.x
                        self.showHorizontalLine()
                    }
                    return
                }
                if v {
                    // change on X axis is bigger than unsnapThreshold, should unsnap
                    if abs(newCenter.x - self.viewToSnap.bounds.size.width / 2) > self.unsnapThreshold {
                        self.isSnapped = false
                        (self.viewThatSnaps as! UIView).center = newCenter
                    } else {
                        // move along vertical line without unsnapping
                        (self.viewThatSnaps as! UIView).center.x = self.viewToSnap.center.x
                        (self.viewThatSnaps as! UIView).center.y = newCenter.y
                        self.showVerticalLine()
                    }
                    return
                }
                if !h && !v {
                    (self.viewThatSnaps as! UIView).center = newCenter
                    self.isSnapped = false
                }
                self.lastKnownPosition = self.viewThatSnaps!.nextCenter.toCGPoint()
            } else {
                if h {
                    self.showHorizontalLine()
                    self.snapHorizontal(view: self.viewThatSnaps as! UIView, to: self.viewToSnap)
                    self.isSnapped = true
                }
                if v {
                    self.showVerticalLine()
                    self.snapVertical(view: self.viewThatSnaps as! UIView, to: self.viewToSnap)
                    self.isSnapped = true
                }
                
                if !h && !v {
                    (self.viewThatSnaps as! UIView).center = newCenter
                    self.isSnapped = false
                }
            }
        }
    }
    
    private func startTimer(withDuration: Double) {
        self.isTimerStarted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(floatLiteral: withDuration), execute: {
            // position did not change, should hide snap lines
            if self.lastKnownPosition == self.viewThatSnaps!.nextCenter.toCGPoint() {
                self.hideSnapLines()
            } else {
                // check current location, hide snap line based on the result
                let (h, v) = self.shouldSnap()
                
                if h && !v {
                    self.hideVerticalSnapLine()
                } else if v && !h {
                    self.hideHorizontalSnapLine()
                } else {
                    self.hideSnapLines()
                }
            }
            self.isTimerStarted = false
        })
    }
    
    private func createHorizontalLineLayer() -> CAShapeLayer {
        let startPoint = CGPoint(x: 0, y: viewToSnap.bounds.size.height / 2)
        let endPoint = CGPoint(x: viewToSnap.bounds.size.width, y: viewToSnap.bounds.size.height / 2)
        return createLineLayer(start: startPoint, toPoint: endPoint)
    }
    
    private func createVerticalLineLayer() -> CAShapeLayer {
        let startPoint = CGPoint(x: viewToSnap.bounds.size.width / 2, y: 0)
        let endPoint = CGPoint(x: viewToSnap.bounds.size.width / 2, y: viewToSnap.bounds.size.height)
        return createLineLayer(start: startPoint, toPoint: endPoint)
    }
    
    private func createLineLayer(start : CGPoint, toPoint end:CGPoint) -> CAShapeLayer {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        shapeLayer.lineWidth = 1.0
        
        return shapeLayer
    }
    
    private func showHorizontalLine() {
        self.horizontalLine.isHidden = false
    }
    private func showVerticalLine() {
        self.verticalLine.isHidden = false
    }
    
    private func hideSnapLines() {
        self.verticalLine.isHidden = true
        self.horizontalLine.isHidden = true
    }
    
    private func hideVerticalSnapLine() {
        self.verticalLine.isHidden = true
    }
    
    private func hideHorizontalSnapLine() {
        self.horizontalLine.isHidden = true
    }
    
    // check if viewThatSnaps should snap to viewToSnap vertically (v) and horizontally (h)
    private func shouldSnap() -> (h: Bool, v: Bool) {
        let verticalFrame = CGRect(x: viewToSnap.frame.size.width / 2 - 2.5, y: 0, width: 5, height: viewToSnap.frame.size.height)
        let horizontalFrame = CGRect(x: 0, y: viewToSnap.frame.size.height / 2 - 2.5, width: viewToSnap.frame.size.width, height: 5)
        var h = false
        var v = false
        if let view = viewThatSnaps as? UIView {
            let convertedCenter = viewToSnap.convert(view.center, to: viewToSnap)
            if horizontalFrame.contains(convertedCenter) {
                h = true
            }
            if verticalFrame.contains(convertedCenter) {
                v = true
            }
        }
        return (h, v)
    }
    
    private func snapVertical(view v: UIView, to view: UIView) {
        v.center.x = view.center.x
    }
    private func snapHorizontal(view v: UIView, to view: UIView) {
        v.center.y = view.center.y
    }
}

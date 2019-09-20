# SnapController ##
SnapController is a small controller class that enables horizontal and vertical snap functionality on UIViews.
---
## Setup ##

You have two views, **view1** and **view2**, **view2** is a subview of **view1**, you want **view2** to snap to **view1's** center vertically and horizontally.
---
## Usage ##

@objc protocol Snapable {
    @objc dynamic var nextCenter: Point {get set}
    @objc dynamic var angle: CGFloat {get set}
}
---
Implement **Snappable** protocol on **view2**:
class View2: UIView, SnapController {
    // provide getter and setter for nextCenter
    // provide getter and setter for angle
}
---
Initialize **SnapController** with views:
let snapController = SnapController(view: view2, snapsTo: view1)

Set **nextCenter** property every time you change the position of a **view2**, SnapController uses this property to know if **view2** should snap to **view1**.
Call **finalPointReached()** method of SnapController when **view2** is no more being dragged (PanGestureRecognizer.state == .ended, touchesEnded(...)):

Set **angle** if your **view2** can be rotated, SnapController will use this property to snap **view2** at every k * (pi/4) angle, where k = 1, 2, 3....
---
## Hope you'll find this helpful

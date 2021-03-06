//
//  JZLongPressWeekView.swift
//  JZCalendarWeekView
//
//  Created by Jeff Zhang on 26/4/18.
//  Copyright © 2018 Jeff Zhang. All rights reserved.
//

import UIKit

public protocol JZLongPressViewDelegate: class {
    
    /// When addNew long press gesture ends, this function will be called.
    /// You should handle what should be done after creating a new event.
    /// - Parameters:
    ///   - weekView: current long pressed JZLongPressWeekView
    ///   - startDate: the startDate of the event when gesture ends
    func weekView(_ weekView: JZLongPressWeekView, didEndAddNewFrom startDate: Date, to endDate: Date, pendingEventView: EventView)
    
    /// When Move long press gesture ends, this function will be called.
    /// You should handle what should be done after editing (moving) a existed event.
    /// - Parameters:
    ///   - weekView: current long pressed JZLongPressWeekView
    ///   - editingEvent: the moving (existed, editing) event
    ///   - startDate: the startDate of the event when gesture ends
    func weekView(_ weekView: JZLongPressWeekView, editingEvent: JZBaseEvent, didEndMoveLongPressAt startDate: Date, pendingEventView: EventView)
    
    
    /// When Move long press gesture ends, this function will be called.
    /// You should handle what should be done after editing (moving) a existed event.
    /// - Parameters:
    ///   - weekView: current long pressed JZLongPressWeekView
    ///   - editingEvent: the moving (existed, editing) event
    ///   - startDate: the startDate of the event when gesture ends
    func weekView(_ weekView: JZLongPressWeekView, editingEvent: JZBaseEvent, didEndMoveLongPressAt startDate: Date , didUpdateDuration newDuration: Int, pendingEventView: EventView)
    
    /// Sometimes the longPress will be cancelled because some curtain reason.
    /// Normally this function no need to be implemented.
    /// - Parameters:
    ///   - weekView: current long pressed JZLongPressWeekView
    ///   - longPressType: the long press type when gusture cancels
    ///   - startDate: the startDate of the event when gesture cancels
    func weekView(_ weekView: JZLongPressWeekView, longPressType: JZLongPressWeekView.LongPressType, didCancelLongPressAt startDate: Date)
    func weekView(_ weekView: JZLongPressWeekView,editingEvent: JZBaseEvent, cellCenter: CGPoint, startDate: Date, duration: Int)
    func weekView(_ weekView: JZLongPressWeekView,didEndEditing event: JZBaseEvent)
    func weekView(_ weekView: JZLongPressWeekView,startMovng: JZBaseEvent?)
    func weekView(_ weekView: JZLongPressWeekView,endMovng: JZBaseEvent?)
    func weekView(_ weekView: JZLongPressWeekView,didTapInside: IndexPath, event: JZBaseEvent?)
}

public protocol JZLongPressViewDataSource: class {
    /// Implement this function to customise your own AddNew longPressView
    /// - Parameters:
    ///   - weekView: current long pressed JZLongPressWeekView
    ///   - startDate: the startDate when initialise the longPressView (if you want, you can get the section with startDate)
    /// - Returns: AddNew type of LongPressView (dragging with your finger when move this view)
    func weekView(_ weekView: JZLongPressWeekView, viewForAddNewLongPressAt startDate: Date) -> EventView
    
    /// The default way to get move type longPressView is create a snapshot for the selectedCell.
    /// Implement this function to customise your own Move longPressView
    /// - Parameters:
    ///   - weekView: current long pressed JZLongPressWeekView
    ///   - movingCell: the exsited cell currently is moving
    ///   - startDate: the startDate when initialise the longPressView
    /// - Returns: Move type of LongPressView (dragging with your finger when move event)
    func weekView(_ weekView: JZLongPressWeekView, movingCell: UICollectionViewCell, viewForMoveLongPressAt startDate: Date) -> EventView
}
extension JZLongPressViewDataSource {
    // Default snapshot method
    
    
}
extension JZLongPressViewDelegate {
    // Keep them optional
    public func weekView(_ weekView: JZLongPressWeekView, longPressType: JZLongPressWeekView.LongPressType, didCancelLongPressAt startDate: Date) {}
    public func weekView(_ weekView: JZLongPressWeekView, didEndAddNewLongPressAt startDate: Date) {}
    public func weekView(_ weekView: JZLongPressWeekView, editingEvent: JZBaseEvent, didEndMoveLongPressAt startDate: Date) {}
    func weekView(_ weekView: JZLongPressWeekView, cellCenter: CGPoint, startDate: Date, duration: Int) {}
}

open class JZLongPressWeekView: JZBaseWeekView {
    
    public enum LongPressType {
        /// when long press position is not on a existed event, this type will create a new event view allowing user to move
        case addNew
        /// when long press position is on a existed event, this type will allow user to move the existed event
        case move
    }
    
    /// This structure is used to save editing information before reusing collectionViewCell (Type Move used only)
    private struct CurrentEditingInfo {
        /// The editing event when move type long press(used to be currentMovingCell, it is a reference of cell but item will be reused in CollectionView!!)
        var event: JZBaseEvent!
        
        // in minute
        var eventDuration: Int {Calendar.current.dateComponents([.minute], from: self.event.startDate, to: self.event.endDate).minute ?? 0}
        var isEditable: Bool = true
        /// The editing cell original size, get it from the long press status began
        var cellSize: CGSize!
        /// (REPLACED THIS ONE WITH EVENT ID NOW) Save current indexPath to check whether a cell is the previous one ()
        var indexPath: IndexPath!
        /// Save current all changed opacity cell contentViews to change them back when end or cancel longPress, have to save them because of cell reusage
        var allOpacityContentViews = [UIView]()
    }
    /// When moving the longPress view, if it causes the collectionView scrolling
    private var isScrolling: Bool = false
    private var isLongPressing: Bool = false
    private var currentLongPressType: LongPressType!
    private var longPressView: EventView? {
        didSet {
            longPressView?.textView.font = self.timeLabelBoldFont
            longPressView?.setDefaultShadow()
            longPressView?.layer.shadowColor = longPressView?.descriptor?.backgroundColor.cgColor
        }
    }
    private var currentEditingInfo = CurrentEditingInfo()
    /// Get this value when long press began and save the current relative X and Y value until it ended or cancelled
    private var pressPosition: (xToViewLeft: CGFloat, yToViewTop: CGFloat)?
    
    public weak var longPressDelegate: JZLongPressViewDelegate?
    public weak var longPressDataSource: JZLongPressViewDataSource?
    
    // You can modify these properties below
    public var longPressTypes: [LongPressType] = [LongPressType]()
    /// It is used to identify the minimum time interval(Minute) when dragging the event view (minimum value is 1, maximum is 60)
    public var moveTimeMinInterval: Int = 15
    /// For an addNew event, the event duration mins determine the add new event duration and height
    public var addNewDurationMins: Int = 120
    open var timeLabelBoldFont: UIFont = UIFont.systemFont(ofSize: 12)
    //    /// The longPressTimeLabel along with longPressView, can be customised
    //    open lazy var longPressTimeLabel: UILabel = {
    //        let label = UILabel()
    //        label.font = timeLabelBoldFont
    //        label.textColor = UIColor.black
    //        return label
    //    }()
    /// The moving cell contentView layer opacity (when you move the existing cell, the previous cell will be translucent)
    /// If your cell background alpha below this value, you should decrease this value as well
    public var movingCellOpacity: Float = 0
    
    /// The most top Y in the collectionView that you want longPress gesture enable.
    /// If you customise some decoration and supplementry views on top, **must** override this variable
    open var longPressTopMarginY: CGFloat { return flowLayout.columnHeaderHeight + flowLayout.allDayHeaderHeight }
    /// The most bottom Y in the collectionView that you want longPress gesture enable.
    /// If you customise some decoration and supplementry views on bottom, **must** override this variable
    open var longPressBottomMarginY: CGFloat { return frame.height }
    /// The most left X in the collectionView that you want longPress gesture enable.
    /// If you customise some decoration and supplementry views on left, **must** override this variable
    open var longPressLeftMarginX: CGFloat { return flowLayout.rowHeaderWidth }
    /// The most right X in the collectionView that you want longPress gesture enable.
    /// If you customise some decoration and supplementry views on right, **must** override this variable
    open var longPressRightMarginX: CGFloat { return frame.width }
    private lazy var daysXPosition: [(Int,CGRect)] = {
        return (0...2).map({($0 , CGRect.init(x: self.longPressLeftMarginX + CGFloat($0) * self.flowLayout.sectionWidth, y:0 , width: self.flowLayout.sectionWidth, height: self.collectionView.contentSize.height))})
    }()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupGestures()
    }
    public var longPressToEditGesture: UILongPressGestureRecognizer!
    var tapPressToDismissGesture: UITapGestureRecognizer!
//    var tapPressToAddNew: UITapGestureRecognizer!
    var allDayStatusHeightBeforeDrag: CGFloat = -1
    private func setupGestures() {
        longPressToEditGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPressGesture(_:)))
        longPressToEditGesture.delegate = self
        collectionView.addGestureRecognizer(longPressToEditGesture)
        
        tapPressToDismissGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissEditing))
        tapPressToDismissGesture.delegate = self
        tapPressToDismissGesture.isEnabled = false
        collectionView.addGestureRecognizer(tapPressToDismissGesture)
        
//        tapPressToAddNew = UITapGestureRecognizer(target: self, action: #selector(handleLongPressGesture(_:)))
//        tapPressToAddNew.delegate = self
//        tapPressToAddNew.isEnabled = false
//        collectionView.addGestureRecognizer(tapPressToAddNew)
        
        self.allDayWillUpdate = { [weak self] extraHeight in
            guard let self = self, let longPressView = self.longPressView else {return}
            if self.allDayStatusHeightBeforeDrag == 0 {
                if extraHeight > 0 {
                    longPressView.center.y = self.oldCenter.y + extraHeight
                } else {
                    longPressView.center.y = self.oldCenter.y
                }
            } else {
                if extraHeight > 0 {
                    if extraHeight > self.allDayStatusHeightBeforeDrag {
                        longPressView.center.y = self.oldCenter.y + (extraHeight - self.allDayStatusHeightBeforeDrag)
                    } else if extraHeight < self.allDayStatusHeightBeforeDrag {
                        longPressView.center.y = self.oldCenter.y - (self.allDayStatusHeightBeforeDrag - extraHeight)
                    } else {
                        longPressView.center.y = self.oldCenter.y
                    }
                } else {
                    longPressView.center.y = self.oldCenter.y - self.allDayStatusHeightBeforeDrag
                }
            }
            
            self.updateTimeLabel(start: self.acceptedDateAfterMove, duration: self.currentEditingInfo.eventDuration)
        }
    }
    
    /// Reset everything
    @objc
    public func dismissEditing() {
        isScrolling = false
        longPressToEditGesture.isEnabled = true
        tapPressToDismissGesture.isEnabled = false
//        tapPressToAddNew.isEnabled = true
        self.acceptedDateAfterMove = Date()
        self.oldCenter = .zero
        isLongPressing = false
        firstMovementIsUp = nil
        prevOffset = .zero
        getCurrentMovingCells().forEach {
            $0.contentView.layer.opacity = 1
            currentEditingInfo.allOpacityContentViews.append($0.contentView)
        }
        //        longPressTimeLabel.removeFromSuperview()
        collectionView.isInEditMode = false
        
        self.scrollDirection = nil
        if currentEditingInfo.event != nil {
            notifyDurationChange()
            longPressDelegate?.weekView(self, didEndEditing: currentEditingInfo.event)
        }
        if longPressView != nil  {
            longPressView!.removeFromSuperview()
            longPressView = nil
        }
        currentEditingInfo.event = nil
        currentEditingInfo.isEditable = true
    }
    
    @discardableResult
    private func notifyDurationChange() -> Int {
        let duration = currentEditingInfo.eventDuration // Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!
        longPressDelegate?.weekView(self, editingEvent: currentEditingInfo.event, didEndMoveLongPressAt: currentEditingInfo.event.startDate, didUpdateDuration: duration, pendingEventView: longPressView as! EventView)
        return duration
    }
    
    /// Updating time label in longPressView during dragging
    private func updateTimeLabel(start: Date, duration: Int) {
        let clock = start.getTimeIgnoreSecondsFormat()
        let end = Calendar.current.date(byAdding: .minute, value: duration, to: start)?.getTimeIgnoreSecondsFormat() ?? ""
        self.longPressView!.textView.text = "\(clock) - \(end)"
        
        updateTimeLabelText(time: start)
        //        updateTimeLabelPosition(pointInSelf: pointInSelf)
    }
    
    /// Update time label content, this method can be overridden
    open func updateTimeLabelText(time: Date) {
        
        //        longPressTimeLabel.text = clock
        //        longPressTimeLabel.isHidden = false
        //        longPressTimeLabel.font = clock.contains(":00") ? self.timeLabelRegularFont : self.timeLabelBoldFont
    }
    
    /// Update the position for the time label
    //    private func updateTimeLabelPosition(pointInSelf: CGPoint) {
    //        longPressTimeLabel.frame.origin.y = pointInSelf.y - longPressTimeLabel.frame.height / 2
    //        longPressTimeLabel.sizeToFit()
    //        longPressTimeLabel.frame.origin.x = longPressLeftMarginX - (longPressTimeLabel.frame.width + 15)
    //    }
    
    /// When dragging the longPressView, the collectionView should scroll with the drag point.
    /// - The logic of vertical scroll is top scroll depending on **longPressView top** to longPressTopMarginY, bottom scroll denpending on **finger point** to LongPressBottomMarginY.
    /// - The logic of horizontal scroll is left scroll depending on **finger point** to longPressLeftMarginY, bottom scroll denpending on **finger point** to LongPressRightMarginY.
    private func updateScroll(pointInSelfView: CGPoint, doneScroll: (()->Void)? = nil) {
        if isScrolling { return }
        
        // vertical
        if pointInSelfView.y - pressPosition!.yToViewTop < longPressTopMarginY + 10 {
            isScrolling = true
            scrollingTo(direction: .up, doneScroll:  doneScroll)
            
            return
        } else if pointInSelfView.y > longPressBottomMarginY - 40 {
            isScrolling = true
            scrollingTo(direction: .down, doneScroll:  doneScroll)
            
            return
        }
        // horizontal
        if pointInSelfView.x < longPressLeftMarginX + 10 {
            isScrolling = true
            scrollingTo(direction: .right, doneScroll:  doneScroll)
            
            return
        } else if pointInSelfView.x > longPressRightMarginX - 20 {
            isScrolling = true
            scrollingTo(direction: .left, doneScroll:  doneScroll)
            
            return
        }
    }
    
    var scrollTimer: Timer? = nil {
        didSet {
            self.allDayStatusHeightBeforeDrag = -1
            oldValue?.invalidate()
        }
    }
    
    /*
     NOTICE: Existing issue: In some scenarios, longPress to edge cannot trigger collectionView scrolling
     Generally, it is because isScrolling set true previously but doesn't set false back, which cause cannot scroll next time because isScrolling is true
     1. In section scroll, when keep longPressing and scrolling, sometimes it will become unscrollable. (Should be caused by forceReload async, page scroll got enough time to async reload)
     2. In both scroll types, if you end longPress at the left or right edge when collectionView is scrolling, it might cause isScrolling cannot set back to false either.
     This issue exists before 0.7.0 (not caused by pagination redesign), will be fixed when async forceReload issue has been resolved
     */
    private func scrollingTo(direction: LongPressScrollDirection, doneScroll: (()->Void)? = nil) {
        let currentOffset = collectionView.contentOffset
        let minOffsetY: CGFloat = 0, maxOffsetY = collectionView.contentSize.height - collectionView.bounds.height
        
        if direction == .up || direction == .down {
            let yOffset: CGFloat
            
            if direction == .up {
                yOffset = max(minOffsetY, currentOffset.y - ( snapVerticalSize))
                collectionView.setContentOffset(CGPoint(x: currentOffset.x, y: yOffset), animated: true)
            } else {
                yOffset = min(maxOffsetY, currentOffset.y + ( snapVerticalSize))
                collectionView.setContentOffset(CGPoint(x: currentOffset.x, y: yOffset), animated: true)
            }
            // scrollview didEndAnimation will not set isScrolling, should be set manually
            if yOffset == minOffsetY || yOffset == maxOffsetY {
                isScrolling = false
            }
            
        } else {
            var contentOffsetX: CGFloat
            switch scrollType! {
            case .sectionScroll:
                let scrollSections: CGFloat = direction == .left ? -1 : 1
                contentOffsetX = currentOffset.x - flowLayout.sectionWidth! * scrollSections
            case .pageScroll:
                contentOffsetX = direction == .left ? contentViewWidth * 2 : 0
            }
            // Take the horizontal scrollable edges into account
            let contentOffsetXWithScrollableEdges = min(max(contentOffsetX, scrollableEdges.leftX ?? -1), scrollableEdges.rightX ?? CGFloat.greatestFiniteMagnitude)
            if contentOffsetXWithScrollableEdges == currentOffset.x {
                // scrollViewDidEndScrollingAnimation will not be called
                isScrolling = false
            } else {
                collectionView.setContentOffset(CGPoint(x: contentOffsetXWithScrollableEdges, y: currentOffset.y), animated: true)
            }
        }
        doneScroll?()
    }
    
    /// Calculate the expected start date with timeMinInterval
    func getLongPressStartDate(date: Date, dateInSection: Date, timeMinInterval: Int) -> Date {
        let daysBetween = Date.daysBetween(start: dateInSection, end: date, ignoreHours: true)
        let startDate: Date
        
        if daysBetween == 1 {
            // Below the bottom set as the following day
            startDate = date.startOfDay
        } else if daysBetween == -1 {
            // Beyond the top set as the current day
            startDate = dateInSection.startOfDay
        } else {
            let currentMin = Calendar.current.component(.minute, from: date)
            // Choose previous time interval (currentMin/timeMinInterval = Int)
            let minValue = (currentMin/timeMinInterval) * timeMinInterval
            startDate = date.set(minute: minValue)
        }
        return startDate
    }
    
    /// Initialise the long press view with longPressTimeLabel.
    open func initLongPressView(selectedCell: UICollectionViewCell?, type: LongPressType, startDate: Date) -> EventView {
        
        let longPressView = type == .move ? longPressDataSource!.weekView(self, movingCell: selectedCell!, viewForMoveLongPressAt: startDate) :
            longPressDataSource!.weekView(self, viewForAddNewLongPressAt: startDate)
        longPressView.clipsToBounds = false
        longPressView.layer.cornerRadius = 8
        
        // timeText width will change from 00:00 - 24:00, and for each time the length will be different
        // add 5 to ensure the max width
        //        let labelHeight: CGFloat = 15
        //        let textWidth = UILabel.getLabelWidth(labelHeight, font: longPressTimeLabel.font, text: "23:59") + 5
        //        let timeLabelWidth = max(selectedCell?.bounds.width ?? flowLayout.sectionWidth, textWidth)
        //        longPressTimeLabel.frame = CGRect(x: 0, y: self.center.y, width: timeLabelWidth, height: labelHeight)
        //        longPressView.setDefaultShadow()
        return longPressView
    }
    
    /// Overload for base class with left and right margin check for LongPress
    open func getDateForPointX(xCollectionView: CGFloat, xSelfView: CGFloat) -> Date {
        let date = self.getDateForPointX(xCollectionView)
        // when isScrolling equals true, means it will scroll to previous date
        if xSelfView < longPressLeftMarginX && isScrolling == false {
            // should add one date to put the view inside current page
            return date.add(component: .day, value: 1)
        } else if xSelfView > longPressRightMarginX && isScrolling == false {
            // normally this condition will not enter
            // should substract one date to put the view inside current page
            return date.add(component: .day, value: -1)
        } else {
            return date
        }
    }
    
    /// Overload for base class with modified date for X
    open func getDateForPoint(pointCollectionView: CGPoint, pointSelfView: CGPoint) -> Date {
        let yearMonthDay = getDateForPointX(xCollectionView: pointCollectionView.x, xSelfView: pointSelfView.x)
        let hourMinute = getDateForPointY(pointCollectionView.y)
        return yearMonthDay.set(hour: hourMinute.0, minute: hourMinute.1, second: 0)
    }
    
    // Only being called when setContentOffset ends animition by scrollingTo method
    // scrollViewDidEndScrollingAnimation won't be called in JZBaseWeekView, then should load page here
    open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        // vertical scroll should not load page, handled in loadPage method
        let prePendingView = longPressView?.frame
        
        loadPage()
        if let old = prePendingView {
            longPressView?.frame = old
            
        }
        isScrolling = false
    }
    
    // Following three functions are used to Handle collectionView items reusued
    
    /// when the previous cell is reused, have to find current one
    open func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard isLongPressing == true && currentLongPressType == .move else { return }
        
        let cellContentView = cell.contentView
        
        if isOriginalMovingCell(cell){
            cellContentView.layer.opacity = movingCellOpacity
            if !currentEditingInfo.allOpacityContentViews.contains(cellContentView) {
                currentEditingInfo.allOpacityContentViews.append(cellContentView)
            }
        } else {
            cellContentView.layer.opacity = 1
            if let index = currentEditingInfo.allOpacityContentViews.firstIndex(where: {$0 == cellContentView}) {
                currentEditingInfo.allOpacityContentViews.remove(at: index)
            }
        }
    }
    
    /// Use the event id to check the cell item is the original cell
    private func isOriginalMovingCell(_ cell: UICollectionViewCell) -> Bool {
        if let cell = cell as? JZLongPressEventCell, currentEditingInfo.event != nil {
            return cell.event.id == currentEditingInfo.event.id
        } else {
            return false
        }
    }
    
    /*** Because of reusability, we set some cell contentViews to translucent, then when those views are reused, if you don't scroll back
     the willDisplayCell will not be called, then those reused contentViews will be translucent and cannot be found */
    /// Get the current moving cells to change to alpha (crossing days will have more than one cells)
    private func getCurrentMovingCells() -> [UICollectionViewCell] {
        var movingCells = [UICollectionViewCell]()
        for cell in collectionView.visibleCells {
            if isOriginalMovingCell(cell) {
                movingCells.append(cell)
            }
        }
        return movingCells
    }
    private lazy var snapVerticalSize =  {CGFloat(15) * self.flowLayout.hourHeight / 60}()
    private var prevOffset: CGPoint = .zero
    private var originalNewEventOffset: CGRect = .zero
    private var firstMovementIsUp: Bool? = nil
    
    private var prevScrollOffset: CGPoint = .zero
    let haptic = UIImpactFeedbackGenerator(style: .light)
    private var oldCenter: CGPoint = .zero
    private var oldMovement: CGPoint = .zero
    private var acceptedDateAfterMove: Date = Date()
    
    @objc private func handleResizeHandlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let pendingEvent = longPressView else {return}
        let state = gestureRecognizer.state
        let pointInSelfView: CGPoint
        let pointInCollectionView: CGPoint
        
        if gestureRecognizer.view?.tag == 0 {
            pointInSelfView =  collectionView.convert(pendingEvent.frame.origin, to: self)
            pointInCollectionView = pendingEvent.frame.origin
            
        } else {
            pointInSelfView = collectionView.convert(CGPoint.init(x: pendingEvent.frame.midX ,y:pendingEvent.frame.maxY), to: self)
            pointInCollectionView = .init(x: pendingEvent.frame.midX,y:pendingEvent.frame.maxY + snapVerticalSize)
        }
        
        if state == .began {
            UIView.animate(withDuration: 0.1) {gestureRecognizer.view?.subviews[0].transform = .init(scaleX: 2, y: 2)}
            
            prevScrollOffset = .zero
            getCurrentMovingCells().forEach {
                $0.contentView.layer.opacity = movingCellOpacity
                currentEditingInfo.allOpacityContentViews.append($0.contentView)
            }
            var point = pendingEvent.frame.origin
            point.y += CGFloat(gestureRecognizer.view!.tag == 0 ? 0 : (Int(snapVerticalSize) * Int(round(pendingEvent.frame.size.height / snapVerticalSize))))
            pressPosition = (pointInCollectionView.x - point.x, pointInCollectionView.y - point.y)
            self.longPressDelegate?.weekView(self, startMovng: currentEditingInfo.event)
        }
        
        // pressPosition is nil only when state equals began
        // The startDate of the longPressView (the date of top Y in longPressView)
        let longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: pointInCollectionView, pointInSelfView: pointInSelfView)
        //        print(longPressViewStartDate.getTimeIgnoreSecondsFormat())
        if gestureRecognizer.state == .ended || state == .cancelled {
            //            longPressTimeLabel.isHidden = true
            // startDate
            if gestureRecognizer.view!.tag == 0 {
                currentEditingInfo.event.startDate = longPressViewStartDate
            } else {
                currentEditingInfo.event.endDate = longPressViewStartDate
            }
            notifyDurationChange()
            UIView.animate(withDuration: 0.1) {gestureRecognizer.view?.subviews[0].transform = .identity}
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.longPressDelegate?.weekView(self, endMovng: self.currentEditingInfo.event)
            }
        }
        
        let newCoord = gestureRecognizer.translation(in: pendingEvent)
        if gestureRecognizer.state == .began {
            prevOffset = newCoord
        }
        guard let tag = gestureRecognizer.view?.tag else {
            return
        }
        
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            if gestureRecognizer.view!.tag == 0 {
                currentEditingInfo.event.startDate = longPressViewStartDate
            } else {
                currentEditingInfo.event.endDate = longPressViewStartDate
            }
            
            longPressDelegate?.weekView(self,editingEvent: currentEditingInfo.event, cellCenter: longPressView!.center, startDate: currentEditingInfo.event.startDate, duration: Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!)
            
            updateTimeLabel(start: currentEditingInfo.event.startDate, duration: currentEditingInfo.eventDuration)
            updateScroll(pointInSelfView: pointInSelfView)
        }
        
        var scrollOffset: CGFloat = 0
        if self.isScrolling {
            if prevScrollOffset == .zero {
                prevScrollOffset = self.collectionView.contentOffset
            }
            scrollOffset = abs(prevScrollOffset.y) - abs(self.collectionView.contentOffset.y)
            prevScrollOffset.y = self.collectionView.contentOffset.y
        }
        
        var diff = CGPoint(x: newCoord.x - prevOffset.x,
                           y: (newCoord.y - scrollOffset) - prevOffset.y)
        guard abs(diff.y) >= snapVerticalSize else {return}
        var suggestedEventFrame = pendingEvent.frame
        let padding : CGFloat = 12
        let changeOffset = diff.y > 0  ? snapVerticalSize : -1 * snapVerticalSize
        if tag == 0 { // Top handle
            suggestedEventFrame.origin.y +=  changeOffset
            suggestedEventFrame.size.height -= changeOffset
            if diff.y < 0, suggestedEventFrame.origin.y < longPressTopMarginY + padding {
                suggestedEventFrame = pendingEvent.frame
            }
        } else { // Bottom handle
            suggestedEventFrame.size.height += diff.y > 0  ? snapVerticalSize : -1 * snapVerticalSize
            if diff.y > 0, suggestedEventFrame.maxY > collectionView.contentSize.height - padding / 2 {
                suggestedEventFrame = pendingEvent.frame
            }
        }
        
        let minimumMinutesEventDurationWhileEditing = CGFloat(15)
        let minimumEventHeight = minimumMinutesEventDurationWhileEditing * flowLayout.hourHeight / 60
        let suggestedEventHeight = suggestedEventFrame.size.height
        
        if suggestedEventHeight > minimumEventHeight {
            pendingEvent.frame = suggestedEventFrame
            prevOffset = newCoord
        } else {
            gestureRecognizer.isEnabled = false
            gestureRecognizer.isEnabled = true
        }
        diff.y = 0
        haptic.impactOccurred()
    }
}

// Long press Gesture methods
extension JZLongPressWeekView: UIGestureRecognizerDelegate {
    
    // Override this function to customise gesture begin conditions
    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let pointInSelfView = gestureRecognizer.location(in: self)
        let pointInCollectionView = gestureRecognizer.location(in: collectionView)
        
        if gestureRecognizer.state == .possible {
            // Long press on ouside margin area should not begin
            let isOutsideBeginArea = pointInSelfView.x < longPressLeftMarginX || pointInSelfView.x > longPressRightMarginX ||
                pointInSelfView.y < longPressTopMarginY || pointInSelfView.y > longPressBottomMarginY
            if isOutsideBeginArea {
                return false
            }
        }
        let itemAtPoint = collectionView.indexPathForItem(at: pointInCollectionView)
        let hasItemAtPoint = itemAtPoint != nil
        if let item = (itemAtPoint as? JZLongPressEventCell)?.event, !item.descriptor.isEditable {
            return false
        }
        
        // Long press should not begin if there are events at long press position and move not required
        if hasItemAtPoint && !longPressTypes.contains(LongPressType.move) {
            return false
        }
        
        // Long press should not begin if no events at long press position and addNew not required
        if !hasItemAtPoint && !longPressTypes.contains(LongPressType.addNew) {
            return false
        }
        return true
    }
    
    @objc private func handleLongPressGestureOnPendingView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        currentLongPressType = .move
        let state = gestureRecognizer.state
        if state == .began {
            isLongPressing = false
            isScrolling = false
            self.scrollDirection = nil
        }
        
        handleLongPressGesture(gestureRecognizer)
    }
    
    private func addLongPressGestureToPendingView() {
        let longPressGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handleLongPressGestureOnPendingView(_:)))
        longPressGesture.delegate = self
        longPressView!.addGestureRecognizer(longPressGesture)
    }
    
    @objc func openDetailsView() {
        let point =  longPressView!.superview!.convert(longPressView!.center, to: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else {return}
        self.longPressDelegate?.weekView(self, didTapInside: indexPath, event: currentEditingInfo.event)
    }
    
    private func mapToVerticalSnap(_ number: CGFloat) -> CGFloat{
        CGFloat((Int(snapVerticalSize) * Int(round(number / snapVerticalSize))))
    }
    
    private func acceptMoves(poistion: CGPoint , date: Date ) {
        self.oldCenter = poistion
        self.acceptedDateAfterMove = date
        guard currentEditingInfo.event != nil, let longPressView = longPressView  else {return}
        let duration = currentEditingInfo.eventDuration
        currentEditingInfo.event.startDate = acceptedDateAfterMove
        currentEditingInfo.event.endDate =  Calendar.current.date(byAdding: .minute, value: duration, to: acceptedDateAfterMove)!
        longPressDelegate?.weekView(self,editingEvent: currentEditingInfo.event, cellCenter: longPressView.center, startDate: acceptedDateAfterMove, duration: Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!)
        self.updateTimeLabel(start: self.acceptedDateAfterMove, duration: duration)
    }
    
    private func automaticScroll (pointInSelfView: CGPoint, pointInCollectionView: CGPoint, playgroundBounds: CGRect) {
        if pointInSelfView.x > playgroundBounds.maxX - 30, self.scrollTimer == nil {
            self.scrollTimer?.invalidate()
            self.scrollTimer = nil
            let oldOffset = self.collectionView.contentOffset.x
            let oldY = pointInSelfView.y
            var isAllDayOpen =  self.flowLayout.allDayHeaderHeight > 0
            self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: {[weak self] _ in
                guard let self = self else {return}
                if self.allDayStatusHeightBeforeDrag == -1 {
                    self.allDayStatusHeightBeforeDrag = self.flowLayout.allDayHeaderHeight
                }
                
                self.scrollingTo(direction: .left) {
                    self.acceptMoves(poistion: self.oldCenter, date: Calendar.current.date(byAdding: .day, value: 1, to: self.acceptedDateAfterMove)!)
                }
            })
        } else if pointInSelfView.x < longPressLeftMarginX, self.scrollTimer == nil {
            self.scrollTimer?.invalidate()
            self.scrollTimer = nil
            self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true, block: {[weak self] _ in
                guard let self = self else {return}
                if self.allDayStatusHeightBeforeDrag == -1 {
                    self.allDayStatusHeightBeforeDrag = self.flowLayout.allDayHeaderHeight
                }
                self.scrollingTo(direction: .right) {
                    self.acceptMoves(poistion: self.oldCenter, date: Calendar.current.date(byAdding: .day, value: -1, to: self.acceptedDateAfterMove)!)
                }
            })
        }  else if pointInSelfView.y < longPressTopMarginY + snapVerticalSize, self.scrollTimer == nil {
            self.scrollTimer?.invalidate()
            self.scrollTimer = nil
            self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: {[weak self] _ in
                guard let self = self, self.longPressView != nil, self.convert(self.longPressView!.frame.origin, to: self.collectionView).y > self.longPressTopMarginY + self.snapVerticalSize  else {return}
                //                            self.oldCenter.y -= self.snapVerticalSize
                self.scrollingTo(direction: .up) {[weak self] in
                    guard let self = self, self.longPressView != nil else {return}
                    self.acceptMoves(poistion: self.oldCenter, date: Calendar.current.date(byAdding: .minute, value: -15, to: self.acceptedDateAfterMove)!)
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.3) {
                        self.updateTimeLabel(start: self.acceptedDateAfterMove, duration: self.currentEditingInfo.eventDuration)
                        self.haptic.impactOccurred()
                    }
                }
            })
        } else if pointInSelfView.y > playgroundBounds.maxY, self.scrollTimer == nil {
            self.scrollTimer?.invalidate()
            self.scrollTimer = nil
            self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: {[weak self] _ in
                
                guard let self = self, self.longPressView != nil, self.convert(.init(x:self.longPressView!.frame.maxX, y: self.longPressView!.frame.maxY), to: self.collectionView).y < (self.collectionView.contentSize.height - self.snapVerticalSize) else {return}
                self.scrollingTo(direction: .down) {[weak self] in
                    guard let self = self, self.longPressView != nil else {return}
                    self.acceptMoves(poistion: self.oldCenter, date: Calendar.current.date(byAdding: .minute, value: 15, to: self.acceptedDateAfterMove)!)
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.3) {
                        self.updateTimeLabel(start: self.acceptedDateAfterMove, duration: self.currentEditingInfo.eventDuration)
                        self.longPressView!.center =  self.oldCenter
                        self.haptic.impactOccurred()
                    }
                }
            })
        }
    }
    
    @objc private func handleNewEventLongPressGesture(pointInSelfView: CGPoint, pointInCollectionView: CGPoint) {
        let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
        let height = mapToVerticalSnap(currentEditingInfo.cellSize.height)
        var newCoord = pointInCollectionView
        var diff = CGPoint(x: newCoord.x - prevOffset.x,
                           y: newCoord.y  - prevOffset.y)
        var topHandler: Bool = diff.y < 0
        guard let pendingEvent = longPressView else {return}
        if (firstMovementIsUp == nil && diff.y == 0) {return}
        if firstMovementIsUp == nil || pendingEvent.frame.size.height < self.flowLayout.hourHeight / 2{
            // reset every thing
            pendingEvent.frame = originalNewEventOffset
            firstMovementIsUp = topHandler

            pendingEvent.frame.size.height = pendingEvent.frame.size.height / 2
            currentEditingInfo.event.startDate = getLongPressViewStartDate(pointInCollectionView: .init(x:pendingEvent.frame.origin.x, y: pendingEvent.frame.origin.y + (2 * snapVerticalSize)), pointInSelfView: pointInSelfView)
            currentEditingInfo.event.endDate = getLongPressViewStartDate(pointInCollectionView: .init(x: pendingEvent.frame.midX,y:pendingEvent.frame.maxY + (2 * snapVerticalSize)), pointInSelfView: pointInSelfView)
        }
        let newPointInSelfView: CGPoint
        let newPointInCollectionView: CGPoint
        
        if firstMovementIsUp! {
            newPointInSelfView = collectionView.convert(pendingEvent.frame.origin, to: self)
            newPointInCollectionView = .init(x:pendingEvent.frame.origin.x, y: pendingEvent.frame.origin.y + (2 * snapVerticalSize))
        } else {
            newPointInSelfView = collectionView.convert(CGPoint.init(x: pendingEvent.frame.midX ,y:pendingEvent.frame.maxY), to: self)
            newPointInCollectionView = .init(x: pendingEvent.frame.midX,y:pendingEvent.frame.maxY + (2 * snapVerticalSize))
        }
        
        if pointInSelfView.y > self.frame.height * 0.7 {
            if self.collectionView.contentOffset.y <  floor(abs(self.collectionView.contentSize.height - self.collectionView.bounds.size.height + self.collectionView.contentInset.bottom)) {
                self.collectionView.contentOffset = .init(x: self.collectionView.contentOffset.x, y: self.collectionView.contentOffset.y + (diff.y / 1.7))
            }
        } else if pointInSelfView.y < 200 {
            if self.collectionView.contentOffset.y >  0  {
                self.collectionView.contentOffset = .init(x: self.collectionView.contentOffset.x, y: self.collectionView.contentOffset.y + (diff.y / 1.7))
            }
        }
        
        // pressPosition is nil only when state equals began
        // The startDate of the longPressView (the date of top Y in longPressView)
        let longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: newPointInCollectionView, pointInSelfView: newPointInSelfView)
        if firstMovementIsUp! {
            currentEditingInfo.event.startDate = longPressViewStartDate
        } else {
            currentEditingInfo.event.endDate = longPressViewStartDate
        }

        updateTimeLabel(start: currentEditingInfo.event.startDate, duration: currentEditingInfo.eventDuration)
        var suggestedEventFrame = pendingEvent.frame
        let padding : CGFloat = 12
        let changeOffset = diff.y
        if firstMovementIsUp! { // Top handle
            suggestedEventFrame.origin.y +=  changeOffset
            suggestedEventFrame.size.height -= changeOffset
            if diff.y < 0, suggestedEventFrame.origin.y < longPressTopMarginY + padding {
                suggestedEventFrame = pendingEvent.frame
            }
        } else { // Bottom handle
            suggestedEventFrame.size.height += changeOffset
            if diff.y > 0, suggestedEventFrame.maxY > collectionView.contentSize.height - padding / 2 {
                suggestedEventFrame = pendingEvent.frame
            }
        }
        
        let minimumMinutesEventDurationWhileEditing = CGFloat(15)
        let minimumEventHeight = minimumMinutesEventDurationWhileEditing * flowLayout.hourHeight / 60
        let suggestedEventHeight = suggestedEventFrame.size.height
        if suggestedEventHeight > minimumEventHeight {
            pendingEvent.frame = suggestedEventFrame
            prevOffset = newCoord
        }
        diff.y = 0
        oldCenter = newCoord
    }
    
    public func quickChangeDuration(locationInSelfView: CGPoint, locationInCollectionView: CGPoint) {
        var pointInCollectionView = locationInCollectionView
        var pointInSelfView = locationInSelfView
        
        guard let indexPath = collectionView.indexPathForItem(at: pointInCollectionView), let currentMovingCell = collectionView.cellForItem(at: indexPath) else {return}
        currentLongPressType = .move
        
        currentEditingInfo.cellSize = currentMovingCell.frame.size
        pressPosition = (pointInCollectionView.x - currentMovingCell.frame.origin.x, pointInCollectionView.y - currentMovingCell.frame.origin.y)
        let longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: pointInCollectionView, pointInSelfView: pointInSelfView)
        longPressView = initLongPressView(selectedCell: currentMovingCell, type: currentLongPressType, startDate: longPressViewStartDate)
        
        longPressView!.frame.size = currentEditingInfo.cellSize
        longPressView!.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        if let editable = longPressView?.descriptor?.isEditable, !editable {
            self.currentEditingInfo.isEditable = false
            dismissEditing()
            return
        }
        if let eventView = longPressView, currentLongPressType != .addNew {
            let tapToShowDetails = UITapGestureRecognizer()
            tapToShowDetails.addTarget(self, action: #selector(openDetailsView))
            tapToShowDetails.cancelsTouchesInView = true
            longPressView!.addGestureRecognizer(tapToShowDetails)
            for handle in eventView.eventResizeHandles {
                let panGestureRecognizer = handle.panGestureRecognizer
                panGestureRecognizer.addTarget(self, action: #selector(handleResizeHandlePanGesture(_:)))
                panGestureRecognizer.cancelsTouchesInView = true
                //                    handle.isHidden = true
            }
        }
        addLongPressGestureToPendingView()
        self.addSubview(longPressView!)
        haptic.impactOccurred()
        longPressView!.layer.zPosition = CGFloat(flowLayout.zIndexForElementKind(JZSupplementaryViewKinds.editModeEventView))
        let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
        let center =  self.longPressLeftMarginX + (floor((pointInSelfView.x) / flowLayout.sectionWidth) * flowLayout.sectionWidth)
        longPressView!.center = CGPoint(x: center - (flowLayout.sectionWidth / 2),
                                        y: topYPoint + mapToVerticalSnap(currentEditingInfo.cellSize.height/2))
        longPressView!.center.x = daysXPosition.first(where: {$0.1.contains(.init(x: pointInSelfView.x, y: 0))})?.1.midX ?? longPressLeftMarginX + (flowLayout.sectionWidth / 2)
        acceptMoves(poistion: longPressView!.center, date:  longPressViewStartDate)
        
            currentEditingInfo.event = (currentMovingCell as! JZLongPressEventCell).event
            longPressView!.center = collectionView.convert(currentMovingCell.center, to: self)
            acceptMoves(poistion: longPressView!.center, date:  longPressViewStartDate)
            getCurrentMovingCells().forEach {
                $0.contentView.layer.opacity = movingCellOpacity
                currentEditingInfo.allOpacityContentViews.append($0.contentView)
            }
       
        
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 5, options: .curveEaseOut,
                       animations: { self.longPressView!.transform = CGAffineTransform.identity }, completion: nil)
        self.longPressDelegate?.weekView(self, startMovng: currentEditingInfo.event)

        scrollTimer = nil
        longPressToEditGesture.isEnabled = false
        tapPressToDismissGesture.isEnabled = true
        collectionView.isInEditMode = true
        self.collectionView.addSubview(self.longPressView!)
        longPressDelegate?.weekView(self, editingEvent: currentEditingInfo.event, didEndMoveLongPressAt: acceptedDateAfterMove , pendingEventView: longPressView as! EventView)
        
        updateCurrentEvent(startDate:acceptedDateAfterMove)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard self.longPressView != nil else {return}
            self.acceptMoves(poistion: self.longPressView!.center, date:  self.acceptedDateAfterMove)
            self.scrollDirection = .init(direction: .horizontal, lockedAt: self.collectionView.contentOffset.x)
            self.longPressDelegate?.weekView(self, endMovng: self.currentEditingInfo.event)
        }
        
        pressPosition = nil
    }
    
    /// The basic longPressView position logic is moving with your finger's original position.
    /// - The Move type longPressView will keep the relative position during this longPress, that's how Apple Calendar did.
    /// - The AddNew type longPressView will be created centrally at your finger press position
    @objc private func handleLongPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let widthBound: CGFloat = (flowLayout.sectionWidth / 2) + 1
        var pointInSelfView = gestureRecognizer.location(in: self)
        /// Used for get startDate of longPressView
        var pointInCollectionView = gestureRecognizer.location(in: collectionView)
        var playgroundBounds = CGRect(x: longPressLeftMarginX, y: longPressTopMarginY + snapVerticalSize, width: self.frame.size.width - longPressLeftMarginX - widthBound - snapVerticalSize , height: longPressBottomMarginY - (longPressTopMarginY + snapVerticalSize + snapVerticalSize))
        let xxxxssssxxx = UIView(frame: playgroundBounds)
        xxxxssssxxx.backgroundColor = .red
        
        // bounds point
        if pointInSelfView.x > self.frame.width - widthBound {
            pointInSelfView.x = pointInSelfView.x - widthBound
            pointInCollectionView.x = pointInCollectionView.x - widthBound
        } else if pointInSelfView.x < widthBound{
            pointInSelfView.x = widthBound
            pointInCollectionView.x = pointInCollectionView.x - widthBound
        }
        
        if pointInSelfView.y < longPressTopMarginY - snapVerticalSize {
            pointInSelfView.y = pointInSelfView.y - snapVerticalSize
            pointInCollectionView.y = pointInCollectionView.y - snapVerticalSize
        } else if pointInSelfView.y > longPressBottomMarginY + snapVerticalSize{
            pointInSelfView.y = longPressBottomMarginY
            //            pointInCollectionView.y = pointInCollectionView.y - snapVerticalSize
        }
        let state = gestureRecognizer.state
        if state == .began {
            oldMovement = pointInSelfView
        }
        
        var currentMovingCell: UICollectionViewCell!
        
        if isLongPressing == false {
            
            if let indexPath = collectionView.indexPathForItem(at: pointInCollectionView) {
                // Can add some conditions for allowing only few types of cells can be moved
                currentLongPressType = .move
                currentMovingCell = collectionView.cellForItem(at: indexPath)
//                if gestureRecognizer == tapPressToAddNew {
//                    self.collectionView.delegate?.collectionView?(self.collectionView, didSelectItemAt: indexPath)
//                    return
//                }
            } else {
                currentLongPressType = .addNew
            }
            isLongPressing = true
        }
        var diff = CGPoint(x: pointInSelfView.x - oldMovement.x,
                           y: pointInSelfView.y  - oldMovement.y)
        // The startDate of the longPressView (the date of top Y in longPressView)
        var longPressViewStartDate: Date!
        
        // pressPosition is nil only when state equals began
        if pressPosition != nil {
            longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: .init(x:pointInCollectionView.x + (diff.x > 0 ? 0 : -50) , y:pointInCollectionView.y), pointInSelfView: pointInSelfView)
            
        }
        
        if state == .began
            
//            || gestureRecognizer == tapPressToAddNew
        {
            guard longPressView == nil else {
                if currentMovingCell == nil {return}
                pressPosition = (pointInCollectionView.x - longPressView!.frame.origin.x, pointInCollectionView.y - longPressView!.frame.origin.y)
                currentEditingInfo.cellSize = currentMovingCell.frame.size
                self.addSubview(self.longPressView!)
                
                let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
                longPressView!.center = CGPoint(x: pointInSelfView.x - pressPosition!.xToViewLeft + currentEditingInfo.cellSize.width/2,
                                                y: topYPoint + currentEditingInfo.cellSize.height/2)
                self.layoutIfNeeded()
                UIView.animate(withDuration: 0.1, animations: {
                    self.longPressView!.transform = .identity
                })
                self.longPressDelegate?.weekView(self, startMovng: currentEditingInfo.event)
                acceptMoves(poistion: longPressView!.center, date:  currentEditingInfo.event.startDate)
                
                return
            }
            
            currentEditingInfo.cellSize = currentLongPressType == .move ? currentMovingCell.frame.size : CGSize(width: flowLayout.sectionWidth, height: flowLayout.hourHeight * CGFloat(addNewDurationMins)/60)
            pressPosition = currentLongPressType == .move ? (pointInCollectionView.x - currentMovingCell.frame.origin.x, pointInCollectionView.y - currentMovingCell.frame.origin.y) :
                (currentEditingInfo.cellSize.width/2, currentEditingInfo.cellSize.height/2)
            longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: pointInCollectionView, pointInSelfView: pointInSelfView)
            longPressView = initLongPressView(selectedCell: currentMovingCell, type: currentLongPressType, startDate: longPressViewStartDate)
            
            longPressView!.frame.size = currentEditingInfo.cellSize
            longPressView!.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            if let editable = longPressView?.descriptor?.isEditable, !editable {
                self.currentEditingInfo.isEditable = false
                gestureRecognizer.isEnabled = false
                gestureRecognizer.isEnabled = true
                dismissEditing()
                return
            }
            if let eventView = longPressView, currentLongPressType != .addNew {
                let tapToShowDetails = UITapGestureRecognizer()
                tapToShowDetails.addTarget(self, action: #selector(openDetailsView))
                tapToShowDetails.cancelsTouchesInView = true
                longPressView!.addGestureRecognizer(tapToShowDetails)
                for handle in eventView.eventResizeHandles {
                    let panGestureRecognizer = handle.panGestureRecognizer
                    panGestureRecognizer.addTarget(self, action: #selector(handleResizeHandlePanGesture(_:)))
                    panGestureRecognizer.cancelsTouchesInView = true
                    //                    handle.isHidden = true
                }
            } else {
                for handle in longPressView!.eventResizeHandles {
                     handle.isHidden = true
                }
            }
            addLongPressGestureToPendingView()
            
            //            self.addSubview(longPressTimeLabel)
            //            longPressTimeLabel.layer.zPosition = CGFloat(flowLayout.zIndexForElementKind(JZSupplementaryViewKinds.timeLabelIndicator))
            
            self.addSubview(longPressView!)
            haptic.impactOccurred()
            longPressView!.layer.zPosition = CGFloat(flowLayout.zIndexForElementKind(JZSupplementaryViewKinds.editModeEventView))
            let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
            let center =  self.longPressLeftMarginX + (floor((pointInSelfView.x) / flowLayout.sectionWidth) * flowLayout.sectionWidth)
            longPressView!.center = CGPoint(x: center - (flowLayout.sectionWidth / 2),
                                            y: topYPoint + mapToVerticalSnap(currentEditingInfo.cellSize.height/2))
            longPressView!.center.x = daysXPosition.first(where: {$0.1.contains(.init(x: pointInSelfView.x, y: 0))})?.1.midX ?? longPressLeftMarginX + (flowLayout.sectionWidth / 2)
            acceptMoves(poistion: longPressView!.center, date:  longPressViewStartDate)
            
            if currentLongPressType == .move {
                currentEditingInfo.event = (currentMovingCell as! JZLongPressEventCell).event
                longPressView!.center = collectionView.convert(currentMovingCell.center, to: self)
                acceptMoves(poistion: longPressView!.center, date:  longPressViewStartDate)
                getCurrentMovingCells().forEach {
                    $0.contentView.layer.opacity = movingCellOpacity
                    currentEditingInfo.allOpacityContentViews.append($0.contentView)
                }
            } else {
                currentEditingInfo.event = .init(id: "-----", startDate: longPressViewStartDate, endDate: Calendar.current.date(byAdding: .hour, value: 1, to: longPressViewStartDate)!, descriptor: (longPressView as! EventView).descriptor!)
                
                let midHeight = (pointInCollectionView.y + longPressView!.frame.size.height / 2)
                if let item = collectionView.visibleSupplementaryViews(ofKind: JZSupplementaryViewKinds.rowHeader).first(where: {$0.frame.minY <= midHeight && $0.frame.maxY > midHeight}) {
                    var y = item.frame.minY
                    while y < item.frame.maxY {
                        if y <= midHeight && (y + snapVerticalSize) >  midHeight {
                            if midHeight - y > snapVerticalSize / 2 {
                                longPressView!.center.y = collectionView.convert(.init(x:pointInSelfView.x,y:y + snapVerticalSize), to: self).y
                            } else {
                                longPressView!.center.y = collectionView.convert(.init(x:pointInSelfView.x,y:y), to: self).y
                            }
                            
                            longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: longPressView!.superview!.convert(.init(x:longPressView!.frame.origin.x, y: longPressView!.frame.origin.y + 5), to: collectionView), pointInSelfView: .init(x:longPressView!.frame.origin.x, y: longPressView!.frame.origin.y))
                            
                            acceptMoves(poistion: longPressView!.center, date:  longPressViewStartDate)
                            
                        }
                        y += snapVerticalSize
                    }
                }
            }
            
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 5, options: .curveEaseOut,
                           animations: { self.longPressView!.transform = CGAffineTransform.identity }, completion: nil)
            self.longPressDelegate?.weekView(self, startMovng: currentEditingInfo.event)
//
//            if gestureRecognizer == tapPressToAddNew {
//
//                let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
//                let newCoord = CGPoint(x: pointInSelfView.x - pressPosition!.xToViewLeft + currentEditingInfo.cellSize.width/2,
//                                       y: topYPoint + currentEditingInfo.cellSize.height/2)
//                longPressView!.center = newCoord
//                acceptMoves(poistion: longPressView!.center, date:  longPressViewStartDate)
//                if currentEditingInfo.event != nil {
//                    longPressDelegate?.weekView(self,editingEvent: currentEditingInfo.event, cellCenter: longPressView!.center, startDate: longPressViewStartDate, duration: Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!)
//                }
//            }
        }
        
        if state == .changed {
            
            guard currentLongPressType != .addNew else{
                if prevOffset == .zero {
                    prevOffset = pointInCollectionView
                    let center = self.convert(longPressView!.center, to: collectionView)
                    self.collectionView.addSubview(longPressView!)
                    longPressView?.center = center
                    originalNewEventOffset = longPressView!.frame
                }
                
                handleNewEventLongPressGesture(pointInSelfView: pointInSelfView, pointInCollectionView: pointInCollectionView)
                return
            }
            automaticScroll(pointInSelfView: pointInSelfView, pointInCollectionView: pointInCollectionView, playgroundBounds: playgroundBounds)
            if self.scrollTimer != nil, playgroundBounds.contains(pointInSelfView) {
                self.scrollTimer?.invalidate()
                self.scrollTimer = nil
            }
            
            guard pressPosition != nil, self.scrollTimer == nil, self.longPressView != nil else {
                return
            }
            
            let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
            let height = mapToVerticalSnap(currentEditingInfo.cellSize.height)
            var newCoord = CGPoint(x: pointInSelfView.x - pressPosition!.xToViewLeft + currentEditingInfo.cellSize.width/2,
                                   y: topYPoint + height / 2)
            var diff = CGPoint(x: newCoord.x - oldCenter.x,
                               y: newCoord.y  - oldCenter.y)
            var snapToNextDay = diff.x > 0 ? abs(diff.x) > flowLayout.sectionWidth / 2 : abs(diff.x) > flowLayout.sectionWidth
            // just put a -2 when event is moving up to have some margin
            if abs(diff.y) < snapVerticalSize + (diff.y < 0 ? -2 : 0) && !snapToNextDay {
                return
            }
            if snapToNextDay  {
                newCoord.x =  self.longPressLeftMarginX + (ceil((pointInSelfView.x) / flowLayout.sectionWidth) * flowLayout.sectionWidth)
                newCoord.x -= (flowLayout.sectionWidth / 2)
                newCoord.y = oldCenter.y
                
                diff.x = 0
                
            } else {
                newCoord.x = currentMovingCell?.frame.midX ?? oldCenter.x
                newCoord.y = diff.y > 0 ? oldCenter.y + snapVerticalSize : oldCenter.y - snapVerticalSize
                
            }
            
            longPressView!.center = newCoord
            
            if currentEditingInfo.event != nil {
                longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: pointInCollectionView, pointInSelfView: pointInSelfView)
                if snapToNextDay {
                    let time = Calendar.current.dateComponents([.hour,.minute], from: acceptedDateAfterMove)
                    longPressViewStartDate = Calendar.current.date(bySettingHour: time.hour!, minute: time.minute!, second: 0, of: longPressViewStartDate)
                }
                longPressDelegate?.weekView(self,editingEvent: currentEditingInfo.event, cellCenter: longPressView!.center, startDate: longPressViewStartDate, duration: Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!)
            }
            oldCenter = newCoord
            acceptMoves(poistion: oldCenter, date:  longPressViewStartDate)
            snapToNextDay = false
            diff.y = 0
            
            
        } else if state == .ended {
            guard pressPosition != nil else {
                gestureRecognizer.isEnabled = false
                gestureRecognizer.isEnabled = true
                return
            }
            
            let endBoundedDate = getLongPressViewStartDate(pointInCollectionView: self.convert(.init(x: self.frame.width - widthBound  , y: pointInSelfView.y), to: collectionView), pointInSelfView: .init(x: self.frame.width - widthBound , y: pointInSelfView.y))
            let startBoundedDate = getLongPressViewStartDate(pointInCollectionView: self.convert(.init(x: longPressLeftMarginX , y: pointInSelfView.y), to: collectionView), pointInSelfView: .init(x: longPressLeftMarginX , y: pointInSelfView.y))
            
            if Calendar.current.compare(endBoundedDate, to: acceptedDateAfterMove, toGranularity: .day) == .orderedAscending  {
                longPressViewStartDate = endBoundedDate
            } else if Calendar.current.compare(acceptedDateAfterMove, to: startBoundedDate, toGranularity: .day) == .orderedAscending {
                longPressViewStartDate = startBoundedDate
            }
            if currentLongPressType == .addNew {
                guard longPressView != nil else {
                    gestureRecognizer.isEnabled = false
                    gestureRecognizer.isEnabled = true
                    dismissEditing()
                    return
                }
                self.longPressDelegate?.weekView(self, didEndAddNewFrom: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate, pendingEventView: longPressView!)
                dismissEditing()
                return
            } else if currentLongPressType == .move {
                
                guard longPressViewStartDate != nil, longPressView != nil, currentEditingInfo.event != nil  else {
                    gestureRecognizer.isEnabled = false
                    gestureRecognizer.isEnabled = true
                    dismissEditing()
                    return
                }
                
                longPressDelegate?.weekView(self, editingEvent: currentEditingInfo.event, didEndMoveLongPressAt: acceptedDateAfterMove , pendingEventView: longPressView as! EventView)
                
                updateCurrentEvent(startDate:acceptedDateAfterMove)
            }
        }
        guard self.longPressView != nil else {
            gestureRecognizer.isEnabled = false
            gestureRecognizer.isEnabled = true
            return
        }
        //        if state == .began || state == .changed  {
        //            updateTimeLabel(start: longPressViewStartDate, duration: self.currentEditingInfo.eventDuration)
        //        }
        if (state == .ended || state == .cancelled)  && longPressView != nil{
            collectionView.addSubview(longPressView!)
            longPressView!.center = self.convert(oldCenter, to: collectionView)
        }
        if state == .ended || state == .cancelled {
            if currentLongPressType == .addNew {
                
            }
            scrollTimer = nil
            longPressToEditGesture.isEnabled = false
            tapPressToDismissGesture.isEnabled = true
//            tapPressToAddNew.isEnabled = false
            //            longPressTimeLabel.isHidden = true
            collectionView.isInEditMode = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard self.longPressView != nil else {return}
                self.acceptMoves(poistion: self.longPressView!.center, date:  self.acceptedDateAfterMove)
                self.scrollDirection = .init(direction: .horizontal, lockedAt: self.collectionView.contentOffset.x)
                self.longPressDelegate?.weekView(self, endMovng: self.currentEditingInfo.event)
            }
            
            pressPosition = nil
            return
        }
    }
    
    private func updateCurrentEvent(startDate:Date) {
        let duration = Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!
        currentEditingInfo.event.startDate = startDate
        currentEditingInfo.event.endDate = startDate.add(component: .minute, value: duration)
    }
    /// used by handleLongPressGesture only
    private func getLongPressViewStartDate(pointInCollectionView: CGPoint, pointInSelfView: CGPoint) -> Date {
        
        let longPressViewTopDate = getDateForPoint(pointCollectionView: CGPoint(x: pointInCollectionView.x, y: pointInCollectionView.y - pressPosition!.yToViewTop), pointSelfView: pointInSelfView)
        let longPressViewStartDate = getLongPressStartDate(date: longPressViewTopDate, dateInSection: getDateForPointX(xCollectionView: pointInCollectionView.x, xSelfView: pointInSelfView.x), timeMinInterval: moveTimeMinInterval)
        return longPressViewStartDate
    }
    
}

extension JZLongPressWeekView {
    
    /// For indicating which direction should collectionView scroll to in LongPressWeekView
    enum LongPressScrollDirection {
        case up
        case down
        case left
        case right
    }
    
}
extension UIView {
    func applyTransform(withScale scale: CGFloat, anchorPoint: CGPoint) {
        layer.anchorPoint = anchorPoint
        let scale = scale != 0 ? scale : CGFloat.leastNonzeroMagnitude
        let xPadding = 1/scale * (anchorPoint.x - 0.5)*bounds.width
        let yPadding = 1/scale * (anchorPoint.y - 0.5)*bounds.height
        transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xPadding, y: yPadding)
    }
}

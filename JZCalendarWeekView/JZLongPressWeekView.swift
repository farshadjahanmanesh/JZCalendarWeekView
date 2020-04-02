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
    func weekView(_ weekView: JZLongPressWeekView, didEndAddNewLongPressAt startDate: Date, pendingEventView: EventView) -> JZBaseEvent
    
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
}

public protocol JZLongPressViewDataSource: class {
    /// Implement this function to customise your own AddNew longPressView
    /// - Parameters:
    ///   - weekView: current long pressed JZLongPressWeekView
    ///   - startDate: the startDate when initialise the longPressView (if you want, you can get the section with startDate)
    /// - Returns: AddNew type of LongPressView (dragging with your finger when move this view)
    func weekView(_ weekView: JZLongPressWeekView, viewForAddNewLongPressAt startDate: Date) -> UIView
    
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
    private var longPressView: UIView!
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
    /// The longPressTimeLabel along with longPressView, can be customised
    open var longPressTimeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textColor = UIColor.black
        return label
    }()
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
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupGestures()
    }
    var longPressToEditGesture: UILongPressGestureRecognizer!
    var tapPressToDismissGesture: UITapGestureRecognizer!
    var tapPressToAddNew: UITapGestureRecognizer!
    private func setupGestures() {
        longPressToEditGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPressGesture(_:)))
        longPressToEditGesture.delegate = self
        collectionView.addGestureRecognizer(longPressToEditGesture)
        
        tapPressToDismissGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissEditing))
        tapPressToDismissGesture.delegate = self
        tapPressToDismissGesture.isEnabled = false
        collectionView.addGestureRecognizer(tapPressToDismissGesture)
        
        tapPressToAddNew = UITapGestureRecognizer(target: self, action: #selector(handleLongPressGesture(_:)))
        tapPressToAddNew.delegate = self
        tapPressToAddNew.isEnabled = true
        collectionView.addGestureRecognizer(tapPressToAddNew)
    }
    
    /// Reset everything
    @objc
    public func dismissEditing() {
        isScrolling = false
        longPressToEditGesture.isEnabled = true
        tapPressToDismissGesture.isEnabled = false
        tapPressToAddNew.isEnabled = true
       
        isLongPressing = false
        getCurrentMovingCells().forEach {
            $0.contentView.layer.opacity = 1
            currentEditingInfo.allOpacityContentViews.append($0.contentView)
        }
        longPressTimeLabel.removeFromSuperview()
        collectionView.isInEditMode = false
        
        self.scrollDirection = nil
        if currentEditingInfo.event != nil {
            notifyDurationChange()
            longPressDelegate?.weekView(self, didEndEditing: currentEditingInfo.event)
        }
        if longPressView != nil  {
               longPressView.removeFromSuperview()
               longPressView = nil
        }
    }
    
    @discardableResult
    private func notifyDurationChange() -> Int {
        let duration = Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!
        longPressDelegate?.weekView(self, editingEvent: currentEditingInfo.event, didEndMoveLongPressAt: currentEditingInfo.event.startDate, didUpdateDuration: duration, pendingEventView: longPressView as! EventView)
        return duration
    }
    
    /// Updating time label in longPressView during dragging
    private func updateTimeLabel(time: Date, pointInSelf: CGPoint) {
        updateTimeLabelText(time: time)
        updateTimeLabelPosition(pointInSelf: pointInSelf)
    }
    
    /// Update time label content, this method can be overridden
    open func updateTimeLabelText(time: Date) {
        let clock = time.getTimeIgnoreSecondsFormat()
        longPressTimeLabel.text = clock
        longPressTimeLabel.isHidden = clock.contains(":00")
    }
    
    /// Update the position for the time label
    private func updateTimeLabelPosition(pointInSelf: CGPoint) {
        longPressTimeLabel.frame.origin.y = pointInSelf.y - longPressTimeLabel.frame.height / 2
        longPressTimeLabel.sizeToFit()
        longPressTimeLabel.frame.origin.x = longPressLeftMarginX - (longPressTimeLabel.frame.width + 15)
    }
    
    /// When dragging the longPressView, the collectionView should scroll with the drag point.
    /// - The logic of vertical scroll is top scroll depending on **longPressView top** to longPressTopMarginY, bottom scroll denpending on **finger point** to LongPressBottomMarginY.
    /// - The logic of horizontal scroll is left scroll depending on **finger point** to longPressLeftMarginY, bottom scroll denpending on **finger point** to LongPressRightMarginY.
    private func updateScroll(pointInSelfView: CGPoint) {
        if isScrolling { return }
        
        // vertical
        if pointInSelfView.y - pressPosition!.yToViewTop < longPressTopMarginY + 10 {
            isScrolling = true
            scrollingTo(direction: .up)
            return
        } else if pointInSelfView.y > longPressBottomMarginY - 40 {
            isScrolling = true
            scrollingTo(direction: .down)
            return
        }
        // horizontal
        if pointInSelfView.x < longPressLeftMarginX + 10 {
            isScrolling = true
            scrollingTo(direction: .right)
            return
        } else if pointInSelfView.x > longPressRightMarginX - 20 {
            isScrolling = true
            scrollingTo(direction: .left)
            return
        }
    }
    
    var scrollTimer: Timer? = nil {
        didSet {
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
    private func scrollingTo(direction: LongPressScrollDirection) {
        let currentOffset = collectionView.contentOffset
        let minOffsetY: CGFloat = 0, maxOffsetY = collectionView.contentSize.height - collectionView.bounds.height
        
        if direction == .up || direction == .down {
            let yOffset: CGFloat
            
            if direction == .up {
                yOffset = max(minOffsetY, currentOffset.y - 50)
                collectionView.setContentOffset(CGPoint(x: currentOffset.x, y: yOffset), animated: true)
            } else {
                yOffset = min(maxOffsetY, currentOffset.y + 50)
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
    open func initLongPressView(selectedCell: UICollectionViewCell?, type: LongPressType, startDate: Date) -> UIView {
        
        let longPressView = type == .move ? longPressDataSource!.weekView(self, movingCell: selectedCell!, viewForMoveLongPressAt: startDate) :
            longPressDataSource!.weekView(self, viewForAddNewLongPressAt: startDate)
        longPressView.clipsToBounds = false
        longPressView.layer.cornerRadius = 8
        
        // timeText width will change from 00:00 - 24:00, and for each time the length will be different
        // add 5 to ensure the max width
        let labelHeight: CGFloat = 15
        let textWidth = UILabel.getLabelWidth(labelHeight, font: longPressTimeLabel.font, text: "23:59") + 5
        let timeLabelWidth = max(selectedCell?.bounds.width ?? flowLayout.sectionWidth, textWidth)
        longPressTimeLabel.frame = CGRect(x: 0, y: self.center.y, width: timeLabelWidth, height: labelHeight)
        longPressView.setDefaultShadow()
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
    private var prevScrollOffset: CGPoint = .zero
    let haptic = UIImpactFeedbackGenerator(style: .light)
    private var oldCenter: CGPoint = .zero
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
            pointInCollectionView = .init(x: pendingEvent.frame.midX,y:pendingEvent.frame.minY + CGFloat((20 * Int(round(pendingEvent.frame.size.height / 20)))))
        }
        
        if state == .began {
            UIView.animate(withDuration: 0.1) {gestureRecognizer.view?.subviews[0].transform = .init(scaleX: 2, y: 2)}
            
            prevScrollOffset = .zero
            longPressTimeLabel.isHidden = false
            getCurrentMovingCells().forEach {
                $0.contentView.layer.opacity = movingCellOpacity
                currentEditingInfo.allOpacityContentViews.append($0.contentView)
            }
            var point = pendingEvent.frame.origin
            point.y += CGFloat(gestureRecognizer.view!.tag == 0 ? 0 : (20 * Int(round(pendingEvent.frame.size.height / 20))))
            pressPosition = (pointInCollectionView.x - point.x, pointInCollectionView.y - point.y)
            self.longPressDelegate?.weekView(self, startMovng: currentEditingInfo.event)
        }
        
        // pressPosition is nil only when state equals began
        // The startDate of the longPressView (the date of top Y in longPressView)
        let longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: pointInCollectionView, pointInSelfView: pointInSelfView)
//        print(longPressViewStartDate.getTimeIgnoreSecondsFormat())
        if gestureRecognizer.state == .ended || state == .cancelled {
            longPressTimeLabel.isHidden = true
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
            longPressDelegate?.weekView(self,editingEvent: currentEditingInfo.event, cellCenter: longPressView.center, startDate: currentEditingInfo.event.startDate, duration: Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!)
            print("beforeTimeShow:",longPressViewStartDate.getTimeIgnoreSecondsFormat())

            updateTimeLabel(time: longPressViewStartDate, pointInSelf: pointInSelfView)
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
        if tag == 0 { // Top handle
            suggestedEventFrame.origin.y +=  diff.y
            suggestedEventFrame.size.height -= diff.y
            if diff.y < 0, suggestedEventFrame.origin.y < longPressTopMarginY + padding {
                suggestedEventFrame = pendingEvent.frame
            }
        } else { // Bottom handle
            suggestedEventFrame.size.height += diff.y > 0  ? snapVerticalSize : -1 * snapVerticalSize
            if diff.y > 0, suggestedEventFrame.maxY > collectionView.contentSize.height - padding / 2 {
                suggestedEventFrame = pendingEvent.frame
            }
        }
        
        let minimumMinutesEventDurationWhileEditing = CGFloat(30)
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
        longPressView.addGestureRecognizer(longPressGesture)
    }
    
    /// The basic longPressView position logic is moving with your finger's original position.
    /// - The Move type longPressView will keep the relative position during this longPress, that's how Apple Calendar did.
    /// - The AddNew type longPressView will be created centrally at your finger press position
    @objc private func handleLongPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
    
        let pointInSelfView = gestureRecognizer.location(in: self)
        /// Used for get startDate of longPressView
        let pointInCollectionView = gestureRecognizer.location(in: collectionView)
        
        let state = gestureRecognizer.state
        
        var currentMovingCell: UICollectionViewCell!
        
        if isLongPressing == false {
            
            if let indexPath = collectionView.indexPathForItem(at: pointInCollectionView) {
                // Can add some conditions for allowing only few types of cells can be moved
                currentLongPressType = .move
                currentMovingCell = collectionView.cellForItem(at: indexPath)
                if gestureRecognizer == tapPressToAddNew {
                    self.collectionView.delegate?.collectionView?(self.collectionView, didSelectItemAt: indexPath)
                    return
                }
            } else {
                currentLongPressType = .addNew
            }
            isLongPressing = true
        }
        
        // The startDate of the longPressView (the date of top Y in longPressView)
        var longPressViewStartDate: Date!
        
        // pressPosition is nil only when state equals began
        if pressPosition != nil {
            longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: pointInCollectionView, pointInSelfView: pointInSelfView)
        }
        
        if state == .began || gestureRecognizer == tapPressToAddNew{
            guard longPressView == nil else {
                if currentMovingCell == nil {return}
                pressPosition = (pointInCollectionView.x - currentMovingCell.frame.origin.x, pointInCollectionView.y - currentMovingCell.frame.origin.y)
                currentEditingInfo.cellSize = currentMovingCell.frame.size
                self.addSubview(self.longPressView)
                let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
                longPressView.center = CGPoint(x: pointInSelfView.x - pressPosition!.xToViewLeft + currentEditingInfo.cellSize.width/2,
                                               y: topYPoint + currentEditingInfo.cellSize.height/2)
                self.layoutIfNeeded()
                UIView.animate(withDuration: 0.1, animations: {
                    self.longPressView.transform = .identity
                })
                self.longPressDelegate?.weekView(self, startMovng: currentEditingInfo.event)
                return
            }
            currentEditingInfo.cellSize = currentLongPressType == .move ? currentMovingCell.frame.size : CGSize(width: flowLayout.sectionWidth, height: flowLayout.hourHeight * CGFloat(addNewDurationMins)/60)
            pressPosition = currentLongPressType == .move ? (pointInCollectionView.x - currentMovingCell.frame.origin.x, pointInCollectionView.y - currentMovingCell.frame.origin.y) :
                (currentEditingInfo.cellSize.width/2, currentEditingInfo.cellSize.height/2)
            longPressViewStartDate = getLongPressViewStartDate(pointInCollectionView: pointInCollectionView, pointInSelfView: pointInSelfView)
            longPressView = initLongPressView(selectedCell: currentMovingCell, type: currentLongPressType, startDate: longPressViewStartDate)
            longPressView.frame.size = currentEditingInfo.cellSize
            longPressView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            if let editable = (longPressView as? EventView)?.descriptor?.isEditable, !editable {
                self.currentEditingInfo.isEditable = false
                return
            }
            if let eventView = longPressView as? EventView {
                
                for handle in eventView.eventResizeHandles {
                    let panGestureRecognizer = handle.panGestureRecognizer
                    panGestureRecognizer.addTarget(self, action: #selector(handleResizeHandlePanGesture(_:)))
                    panGestureRecognizer.cancelsTouchesInView = true
                    //                    handle.isHidden = true
                }
            }
            addLongPressGestureToPendingView()
            
            self.addSubview(longPressTimeLabel)
            longPressTimeLabel.layer.zPosition = CGFloat(flowLayout.zIndexForElementKind(JZSupplementaryViewKinds.timeLabelIndicator))
            
            self.addSubview(longPressView)
            longPressView.layer.zPosition = CGFloat(flowLayout.zIndexForElementKind(JZSupplementaryViewKinds.editModeEventView))
            longPressView.center = CGPoint(x: pointInSelfView.x - pressPosition!.xToViewLeft + currentEditingInfo.cellSize.width/2,
                                           y: pointInSelfView.y - pressPosition!.yToViewTop + currentEditingInfo.cellSize.height/2)
            if currentLongPressType == .move {
                currentEditingInfo.event = (currentMovingCell as! JZLongPressEventCell).event
                getCurrentMovingCells().forEach {
                    $0.contentView.layer.opacity = movingCellOpacity
                    currentEditingInfo.allOpacityContentViews.append($0.contentView)
                }
            } else {
                currentEditingInfo.event = .init(id: "-----", startDate: longPressViewStartDate, endDate: Calendar.current.date(byAdding: .hour, value: 1, to: longPressViewStartDate)!, descriptor: (longPressView as! EventView).descriptor!)
            }
            
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 5, options: .curveEaseOut,
                           animations: { self.longPressView.transform = CGAffineTransform.identity }, completion: nil)
            self.longPressDelegate?.weekView(self, startMovng: currentEditingInfo.event)
            
            if gestureRecognizer == tapPressToAddNew {
                
                let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
                let newCoord = CGPoint(x: pointInSelfView.x - pressPosition!.xToViewLeft + currentEditingInfo.cellSize.width/2,
                                       y: topYPoint + currentEditingInfo.cellSize.height/2)
                oldCenter = newCoord
                longPressView.center = newCoord
                if currentEditingInfo.event != nil {
                    longPressDelegate?.weekView(self,editingEvent: currentEditingInfo.event, cellCenter: longPressView.center, startDate: longPressViewStartDate, duration: Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!)
                }
            }
        }
        
        if state == .changed {
            if pointInSelfView.x > self.frame.size.width - 30, self.scrollTimer == nil {
                self.scrollTimer?.invalidate()
                self.scrollTimer = nil
                self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true, block: {[weak self] _ in
                    self?.scrollingTo(direction: .left)
                })
            } else if (pointInSelfView.x > longPressLeftMarginX && pointInSelfView.x < self.frame.size.width - 30), self.scrollTimer != nil {
                self.scrollTimer?.invalidate()
                self.scrollTimer = nil
            } else if pointInSelfView.x < longPressLeftMarginX, self.scrollTimer == nil {
                self.scrollTimer?.invalidate()
                self.scrollTimer = nil
                self.scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true, block: {[weak self] _ in
                    self?.scrollingTo(direction: .right)
                })
            }
            guard pressPosition != nil else {
                longPressToEditGesture.isEnabled = false
                longPressToEditGesture.isEnabled = true
                return
            }
            
            let topYPoint = max(pointInSelfView.y - pressPosition!.yToViewTop, longPressTopMarginY)
            var newCoord = CGPoint(x: pointInSelfView.x - pressPosition!.xToViewLeft + currentEditingInfo.cellSize.width/2,
                                   y: topYPoint + currentEditingInfo.cellSize.height / 2)
           
            var diff = CGPoint(x: newCoord.x - oldCenter.x,
                               y: newCoord.y  - oldCenter.y)
            if oldCenter == .zero {
                oldCenter = newCoord
            }
            var snapToNextDay = abs(diff.x) > flowLayout.sectionWidth / 2
            
            if abs(diff.y) <= snapVerticalSize && !snapToNextDay {
                return
            }
            if snapToNextDay  {
                newCoord.x = CGFloat(Int(((pointInCollectionView.x - longPressLeftMarginX) / flowLayout.sectionWidth) - 1) * Int(flowLayout.sectionWidth)) - (flowLayout.sectionWidth / 2) - 4
                newCoord.y = oldCenter.y
            } else {
                newCoord.x = currentMovingCell?.frame.midX ?? oldCenter.x
                newCoord.y = snapVerticalSize * round(newCoord.y / snapVerticalSize)
            }

            longPressView.center = newCoord

            if currentEditingInfo.event != nil {
                longPressDelegate?.weekView(self,editingEvent: currentEditingInfo.event, cellCenter: longPressView.center, startDate: longPressViewStartDate, duration: Calendar.current.dateComponents([.minute], from: currentEditingInfo.event.startDate, to: currentEditingInfo.event.endDate).minute!)
            }
            oldCenter = newCoord
            snapToNextDay = false
            diff.y = 0
        } else if state == .cancelled {
//            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: {
//                self.longPressView.alpha = 0
//            }, completion: { _ in
//                self.longPressView.removeFromSuperview()
//            })
//            longPressDelegate?.weekView(self, longPressType: currentLongPressType, didCancelLongPressAt: longPressViewStartDate)
//            updateCurrentEvent(startDate:longPressViewStartDate)
        } else if state == .ended {
            if currentLongPressType == .addNew {
                guard longPressView != nil else {
                    gestureRecognizer.isEnabled = false
                    gestureRecognizer.isEnabled = true
                    return
                }
                let event = longPressDelegate?.weekView(self, didEndAddNewLongPressAt: longPressViewStartDate, pendingEventView: longPressView as! EventView)
                self.currentEditingInfo.event = event
                
                
            } else if currentLongPressType == .move {
                guard longPressViewStartDate != nil else {
                    gestureRecognizer.isEnabled = false
                    gestureRecognizer.isEnabled = true
                    return
                }
                longPressDelegate?.weekView(self, editingEvent: currentEditingInfo.event, didEndMoveLongPressAt: longPressViewStartDate, pendingEventView: longPressView as! EventView)
                updateCurrentEvent(startDate:longPressViewStartDate)
            }
        }
        
        if state == .began || state == .changed  {
            updateTimeLabel(time: longPressViewStartDate, pointInSelf: self.longPressView.frame.origin)
            updateScroll(pointInSelfView: pointInSelfView)
        }
        if (state == .ended || state == .cancelled)  && longPressView != nil{
            collectionView.addSubview(longPressView)
        }
        if state == .ended || state == .cancelled {
            scrollTimer = nil
            longPressToEditGesture.isEnabled = false
            tapPressToDismissGesture.isEnabled = true
            tapPressToAddNew.isEnabled = false
            longPressTimeLabel.isHidden = true
            collectionView.isInEditMode = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.oldCenter = self.longPressView.center
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

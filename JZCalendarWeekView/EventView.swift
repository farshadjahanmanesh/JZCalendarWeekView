//
//  EventView.swift
//  JZCalendarWeekView
//
//  Created by Farshad Jahanmanesh on 3/2/20.
//  Copyright © 2020 Jeff Zhang. All rights reserved.
//

import UIKit
public protocol EventViewDelegate: AnyObject {
	func eventViewDidTap(_ eventView: EventView)
	func eventViewDidLongPress(_ eventview: EventView)
}

open class EventView: UIView {
	var descriptor: EventDescriptor?
	
	weak var delegate: EventViewDelegate?
	//  public var descriptor: EventDescriptor?
	
	public var color = UIColor.lightGray
	
	var contentHeight: CGFloat {
		return textView.frame.height
	}
	
	lazy var textView: UITextView = {
		let view = UITextView()
		view.isUserInteractionEnabled = false
		view.backgroundColor = .clear
		view.isScrollEnabled = false
		return view
	}()
	
	lazy var tapGestureRecognizer = UITapGestureRecognizer(target: self,
														   action: #selector(tap))
	
	lazy var longPressGestureRecognizer = UILongPressGestureRecognizer(target: self,
																	   action: #selector(longPress))
	
	/// Resize Handle views showing up when editing the event.
	/// The top handle has a tag of `0` and the bottom has a tag of `1`
	public lazy var eventResizeHandles = [EventResizeHandleView(), EventResizeHandleView()]
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		configure()
	}
	
	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		configure()
	}
	lazy var backgroundView = UIView(frame: .zero)
	func configure() {
		clipsToBounds = true
		[tapGestureRecognizer, longPressGestureRecognizer].forEach {addGestureRecognizer($0)}
		color = tintColor
		addSubview(textView)
		
		for (idx, handle) in eventResizeHandles.enumerated() {
			handle.tag = idx
			addSubview(handle)
		}
		
	
		self.insertSubview(backgroundView, at: 0)
		backgroundView.setAnchorConstraintsFullSizeTo(view: self)
		backgroundView.layer.cornerRadius = 8
		backgroundView.clipsToBounds = true
	}
	
	open func updateWithDescriptor(event: EventDescriptor) {
		if let attributedText = event.attributedText {
			textView.attributedText = attributedText
		} else {
			textView.text = event.text
			textView.textColor = event.textColor
			textView.font = event.font
		}
		descriptor = event
		backgroundView.backgroundColor = event.backgroundColor
		backgroundColor = .clear
		color = event.color
		setNeedsDisplay()
		setNeedsLayout()
	}
	
	@objc func tap() {
		delegate?.eventViewDidTap(self)
	}
	
	@objc func longPress(_ sender: UILongPressGestureRecognizer) {
		if sender.state == .began {
			delegate?.eventViewDidLongPress(self)
		}
	}
	
	/**
	Custom implementation of the hitTest method is needed for the tap gesture recognizers
	located in the ResizeHandleView to work.
	Since the ResizeHandleView could be outside of the EventView's bounds, the touches to the ResizeHandleView
	are ignored.
	In the custom implementation the method is recursively invoked for all of the subviews,
	regardless of their position in relation to the Timeline's bounds.
	*/
	public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		for resizeHandle in eventResizeHandles {
			if let subSubView = resizeHandle.hitTest(convert(point, to: resizeHandle), with: event) {
				return subSubView
			}
		}
		return super.hitTest(point, with: event)
	}
	

	
	private var drawsShadow = false
	
	override open func layoutSubviews() {
		super.layoutSubviews()
		textView.fillSuperview()
		let first = eventResizeHandles.first
		let last = eventResizeHandles.last
		let radius: CGFloat = 40
		let yPad: CGFloat =  -radius / 2
		first?.anchorInCorner(.topRight,
							  xPad: layoutMargins.right * 2,
							  yPad: yPad,
							  width: radius,
							  height: radius)
		last?.anchorInCorner(.bottomLeft,
							 xPad: layoutMargins.left * 2,
							 yPad: yPad,
							 width: radius,
							 height: radius)
		
	}
	
	public func animateCreation() {
		transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
		func scaleAnimation() {
			transform = .identity
		}
		UIView.animate(withDuration: 0.2,
					   delay: 0,
					   usingSpringWithDamping: 0.2,
					   initialSpringVelocity: 10,
					   options: [],
					   animations: scaleAnimation,
					   completion: nil)
	}
}

public class EventResizeHandleView: UIView {
	public lazy var panGestureRecognizer = UIPanGestureRecognizer()
	public lazy var dotView = EventResizeHandleDotView()
	
	public var borderColor: UIColor? {
		get {
			return dotView.borderColor
		}
		set(value) {
			dotView.borderColor = value
		}
	}
	
	public override init(frame: CGRect) {
		super.init(frame: frame)
		configure()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func configure() {
		addSubview(dotView)
		clipsToBounds = false
		backgroundColor = .clear
		addGestureRecognizer(panGestureRecognizer)
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		let radius: CGFloat = 10
		let centerD = (self.frame.width - radius) / 2
		let origin = CGPoint(x: centerD, y: centerD)
		let dotSize = CGSize(width: radius, height: radius)
		dotView.frame = CGRect(origin: origin, size: dotSize)
	}
}
public class EventResizeHandleDotView: UIView {
	public var borderColor: UIColor? {
		get {
			guard let cgColor = layer.borderColor else {return nil}
			return UIColor(cgColor: cgColor)
		}
		set(value) {
			layer.borderColor = value?.cgColor
		}
	}
	
	public override init(frame: CGRect) {
		super.init(frame: frame)
		configure()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func configure() {
		clipsToBounds = true
		backgroundColor = .white
		layer.borderWidth = 2
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		layer.cornerRadius = bounds.height / 2
	}
}

extension UIView {
	public var superFrame: CGRect {
		  guard let superview = superview else {
			  return CGRect.zero
		  }

		  return superview.frame
	  }

	public func fillSuperview(left: CGFloat = 0, right: CGFloat = 0, top: CGFloat = 0, bottom: CGFloat = 0) {
		   let width : CGFloat = superFrame.width - (left + right)
		   let height : CGFloat = superFrame.height - (top + bottom)

		   frame = CGRect(x: left, y: top, width: width, height: height)
	   }
	
	
    /// Anchor a view in one of the four corners of its superview.
    ///
    /// - parameters:
    ///   - corner: The `CornerType` value used to specify in which corner the view will be anchored.
    ///
    ///   - xPad: The *horizontal* padding applied to the view inside its superview, which can be applied
    /// to the left or right side of the view, depending upon the `CornerType` specified.
    ///
    ///   - yPad: The *vertical* padding applied to the view inside its supeview, which will either be on
    /// the top or bottom of the view, depending upon the `CornerType` specified.
    ///
    ///   - width: The width of the view.
    ///
    ///   - height: The height of the view.
    ///
    public func anchorInCorner(_ corner: Corner, xPad: CGFloat, yPad: CGFloat, width: CGFloat, height: CGFloat) {
        var xOrigin : CGFloat = 0.0
        var yOrigin : CGFloat = 0.0

        switch corner {
        case .topLeft:
            xOrigin = xPad
            yOrigin = yPad

        case .bottomLeft:
            xOrigin = xPad
            yOrigin = superFrame.height - height - yPad

        case .topRight:
            xOrigin = superFrame.width - width - xPad
            yOrigin = yPad

        case .bottomRight:
            xOrigin = superFrame.width - width - xPad
            yOrigin = superFrame.height - height - yPad
        }

        frame = CGRect(x: xOrigin, y: yOrigin, width: width, height: height)

        if height == AutoHeight {
            self.setDimensionAutomatically()
			self.anchorInCorner(corner, xPad: xPad, yPad: yPad, width: width, height: self.frame.height)
        }

        if width == AutoWidth {
            self.setDimensionAutomatically()
			self.anchorInCorner(corner, xPad: xPad, yPad: yPad, width: self.frame.width, height: height)
        }

    }
	public func setDimensionAutomatically() {
		  #if os(iOS)
			  self.sizeToFit()
		  #else
			  self.autoresizesSubviews = true
			  self.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
		  #endif
	  }
}

// MARK: Corner
//
///
/// Specifies a corner of a frame.
///
/// **topLeft**: The upper-left corner of the frame.
///
/// **topRight**: The upper-right corner of the frame.
///
/// **bottomLeft**: The bottom-left corner of the frame.
///
/// **bottomRight**: The upper-right corner of the frame.
///
public enum Corner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

public let AutoHeight : CGFloat = -1
public let AutoWidth : CGFloat = -1

//
//  JZCurrentTimelineSection.swift
//  JZCalendarWeekView
//
//  Created by Jeff Zhang on 28/3/18.
//  Copyright © 2018 Jeff Zhang. All rights reserved.
//

import Foundation

open class JZCurrentTimelineSection: UICollectionReusableView {

    public var halfBallView = UIView()
    public var lineView = UIView()
    let halfBallSize: CGFloat = 15

    public override init(frame: CGRect) {
        super.init(frame: .zero)

        setupUI()
    }

    open func setupUI() {
        self.addSubviews([halfBallView, lineView])
        halfBallView.setAnchorCenterVerticallyTo(view: self, widthAnchor: halfBallSize, heightAnchor: halfBallSize, leadingAnchor: (leadingAnchor, 0))
        lineView.setAnchorCenterVerticallyTo(view: self, heightAnchor: 1, leadingAnchor: (halfBallView.trailingAnchor, 0), trailingAnchor: (trailingAnchor, 0))
		halfBallView.layer.borderColor = UIColor.white.cgColor
		halfBallView.layer.borderWidth = 2
		halfBallView.backgroundColor = .black
        halfBallView.layer.cornerRadius = halfBallSize/2
		lineView.backgroundColor = .black
        self.clipsToBounds = false
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

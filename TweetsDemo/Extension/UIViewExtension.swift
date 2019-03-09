//
//  UIViewExtension.swift
//  TweetsDemo
//
//  Created by Ying Zhang on 5/18/15.
//  Copyright © 2019 Ying Zhang. All rights reserved.
//

import UIKit

public enum AnchorItem: String {
	case top = "topAnchor"
	case bottom = "bottomAnchor"
	case left = "leftAnchor"
	case leading = "leadingAnchor"
	case right = "rightAnchor"
	case trailing = "trailingAnchor"
	case centerX = "centerXAnchor"
	case centerY = "centerYAnchor"
	case width = "widthAnchor"
	case height = "heightAnchor"
	case firstBaseline = "firstBaselineAnchor"
	case lastBaseline = "lastBaselineAnchor"
}

extension UIView {
	
	//MARK: Private methods
	
	private func disableTranslatesAutoresizingMaskIntoConstraints() {
		if self.translatesAutoresizingMaskIntoConstraints {
			self.translatesAutoresizingMaskIntoConstraints = false
		}
	}
	
	// MARK: Public methods
	
	@discardableResult
	public func anchorItem<T>(_ item: NSLayoutAnchor<T>, toItem: NSLayoutAnchor<T>?, constant: CGFloat = 0.0, activate: Bool = true) -> NSLayoutConstraint {
		guard let parentItem = toItem else { return NSLayoutConstraint() }
		
		self.disableTranslatesAutoresizingMaskIntoConstraints()
		
		let constraint = item.constraint(equalTo: parentItem, constant: constant)
		
		if activate {
			NSLayoutConstraint.activate([constraint])
		}
		
		return constraint
	}
	
	@discardableResult
	public func anchorEdgesToView(_ anchorView: UIView, inset: UIEdgeInsets = .zero) -> (topConstraint: NSLayoutConstraint, bottomConstraint: NSLayoutConstraint, leadingConstraint: NSLayoutConstraint, trailingConstraint: NSLayoutConstraint) {
		let topConstraint = self.anchorItem(self.topAnchor, toItem: anchorView.topAnchor, constant: inset.top)
		let bottomConstraint = self.anchorItem(self.bottomAnchor, toItem: anchorView.bottomAnchor, constant: -inset.bottom)
		let leadingConstraint = self.anchorItem(self.leadingAnchor, toItem: anchorView.leadingAnchor, constant: inset.left)
		let trailingConstraint = self.anchorItem(self.trailingAnchor, toItem: anchorView.trailingAnchor, constant: -inset.right)
		NSLayoutConstraint.activate([topConstraint, bottomConstraint, leadingConstraint, trailingConstraint])
		
		return (topConstraint: topConstraint, bottomConstraint: bottomConstraint, leadingConstraint: leadingConstraint, trailingConstraint: trailingConstraint)
	}
	
	public func anchorToView(_ view: UIView?, anchors: [AnchorItem], insets: [String: CGFloat]? = nil) {
		guard let anchorView = view else { return }
		
		for anchorItem in anchors {
			let constantValue = insets?[anchorItem.rawValue] ?? 0.0
			
			switch anchorItem {
			case .top:
				self.anchorItem(self.topAnchor, toItem: anchorView.topAnchor, constant: constantValue)
				
			case .bottom:
				self.anchorItem(self.bottomAnchor, toItem: anchorView.bottomAnchor, constant: constantValue)
				
			case .left:
				self.anchorItem(self.leftAnchor, toItem: anchorView.leftAnchor, constant: constantValue)
				
			case .leading:
				self.anchorItem(self.leadingAnchor, toItem: anchorView.leadingAnchor, constant: constantValue)
				
			case .right:
				self.anchorItem(self.rightAnchor, toItem: anchorView.rightAnchor, constant: constantValue)
				
			case .trailing:
				self.anchorItem(self.trailingAnchor, toItem: anchorView.trailingAnchor, constant: constantValue)
				
			case .centerX:
				self.anchorItem(self.centerXAnchor, toItem: anchorView.centerXAnchor, constant: constantValue)
				
			case .centerY:
				self.anchorItem(self.centerYAnchor, toItem: anchorView.centerYAnchor, constant: constantValue)
				
			case .width:
				self.anchorItem(self.widthAnchor, toItem: anchorView.widthAnchor, constant: constantValue)
				
			case .height:
				self.anchorItem(self.heightAnchor, toItem: anchorView.heightAnchor, constant: constantValue)
				
			case .firstBaseline:
				self.anchorItem(self.firstBaselineAnchor, toItem: anchorView.firstBaselineAnchor, constant: constantValue)
				
			case .lastBaseline:
				self.anchorItem(self.lastBaselineAnchor, toItem: anchorView.lastBaselineAnchor, constant: constantValue)
			}
		}
	}

	@discardableResult
	public func setHeightConstraint(_ height: CGFloat, activate: Bool = true) -> NSLayoutConstraint {
		self.disableTranslatesAutoresizingMaskIntoConstraints()
		
		let constraint = self.heightAnchor.constraint(equalToConstant: height)
		
		if activate {
			NSLayoutConstraint.activate([constraint])
		}
		
		return constraint
	}
}


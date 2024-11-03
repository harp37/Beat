//
//  BeatNotepadView.swift
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 15.8.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

import UIKit
import BeatCore
import BeatDynamicColor

class BeatNotepadView:BeatNotepad, UITextViewDelegate {
	
	@IBOutlet var colorButtons:[UIButton] = []
		
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		defaultColor = DynamicColor(lightColor: UIColor(white: 0, alpha: 1), darkColor: UIColor(white: 0.9, alpha: 1))!

		contentInset = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
		
		if UIDevice.current.userInterfaceIdiom == .phone {
			baseFontSize = 15.0
		}
		
		self.delegate = self
		self.currentColor = defaultColor
	}
	
	func textViewDidChange(_ textView: UITextView) {
		self.didChangeText()
	}

	@objc func selectColor(name:String) {
		self.setColor(name)
		
		if self.selectedRange.length > 0 {
			// If a range was selected, add the color to the range
			let attrStr = self.attributedString.attributedSubstring(from: self.selectedRange)
			self.textStorage.beginEditing()
			self.textStorage.addAttribute(.foregroundColor, value: self.currentColor, range: self.selectedRange)
			self.textStorage.endEditing()
			self.saveToDocument()
		}
		
		self.typingAttributes = [.foregroundColor: self.currentColor]
		self.selectedRange = NSMakeRange(NSMaxRange(self.selectedRange), 0)
	}
	
}

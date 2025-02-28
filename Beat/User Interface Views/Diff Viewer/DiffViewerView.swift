//
//  DiffViewerView.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 21.2.2025.
//  Copyright © 2025 Lauri-Matti Parppei. All rights reserved.
//

import BeatCore

private enum DiffViewMode: Int {
	case compare = 0
	case fullText = 1
}


class DiffViewerViewController: NSViewController {
	
	weak var delegate: BeatEditorDelegate?
	
	private var vc: BeatVersionControl?
	private var viewMode: DiffViewMode = .compare {
		didSet {
			currentVersionMenu?.isHidden = viewMode != .compare
			refreshContent()
		}
	}
	
	private var originalText: String?
	private var modifiedText: String?
	
	private var originalTimestamp: String = "base" {
		didSet {
			otherVersionMenu?.selectCommit(originalTimestamp)
		}
	}
	
	private var modifiedTimestamp: String = "current" {
		didSet {
			currentVersionMenu?.selectCommit(modifiedTimestamp)
		}
	}
	
	// MARK: UI outlets
	
	@IBOutlet private weak var textView: DiffViewerTextView?
	@IBOutlet private weak var currentVersionMenu: DiffTimestampMenu?
	@IBOutlet private weak var otherVersionMenu: DiffTimestampMenu?
	@IBOutlet private weak var statusView: DiffViewerStatusView?
	@IBOutlet private weak var commitButton: NSButton?
	
	// MARK: Lifecycle
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		guard let delegate = delegate else { return }
		
		self.vc = BeatVersionControl(delegate: delegate)

		setupTextView()
		updateCommitStatus()

		_ = compareToLatestCommit()
		populateVersions()
	}
	
	// MARK: - Setup
	
	private func setupTextView() {
		guard let delegate = delegate, let textView = textView else { return }

		textView.setup(editorDelegate: delegate)
		textView.backgroundColor = ThemeManager.shared().backgroundColor.effectiveColor()
		
		// Set up custom scroller
		if let scrollView = textView.enclosingScrollView {
			let customScroller = DiffScrollerView()
			customScroller.controlSize = .regular
			customScroller.scrollerStyle = .overlay
			scrollView.verticalScroller = customScroller
			scrollView.hasVerticalScroller = true
		}
	}
	
	// MARK: - Version control actions
	
	@IBAction func commit(_ sender: Any?) {
		guard let delegate = delegate,
			  let button = sender as? NSButton else { return }
		
		// Show a popover
		let popover = NSPopover()
		popover.behavior = .transient
		
		let popoverVC = CommitMessagePopover { [weak self] message in
			popover.close()
			
			// Create version control and add commit with message
			let vc = BeatVersionControl(delegate: delegate)
			vc.addCommit(withMessage: message)
			self?.updateCommitStatus()
			
			// After committing, select the latest commit to be displayed
			if let latest = vc.latestTimestamp() {
				self?.originalTimestamp = latest
			}
			
			self?.populateVersions()
			self?.refreshContent()
		}
		
		popover.contentViewController = popoverVC
		
		// Show the popover
		popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
	}
	
	private func updateCommitStatus() {
		let uncommitted = vc?.hasUncommittedChanges() ?? false
		
		statusView?.update(uncommitedChanges: uncommitted)
		commitButton?.isEnabled = uncommitted
	}
	
	
	// MARK: - Version selection
	
	private func populateVersions() {
		guard let vc = vc else { return }
		
		addTimestampMenuItems(menu: currentVersionMenu, versionControl: vc)
		addTimestampMenuItems(menu: otherVersionMenu, versionControl: vc)
		
		currentVersionMenu?.selectCommit(modifiedTimestamp)
		otherVersionMenu?.selectCommit(originalTimestamp)
	}
	
	private func addTimestampMenuItems(menu: DiffTimestampMenu?, versionControl: BeatVersionControl) {
		guard let menu = menu else { return }
		
		menu.removeAllItems()
		
		// Add base item
		let baseItem = DiffTimestampMenuItem(title: formatTimestamp("base"), action: nil, keyEquivalent: "")
		baseItem.timestamp = "base"
		menu.menu?.addItem(baseItem)
		
		// Add versioned items
		for commit in versionControl.commits() {
			guard let timestamp = commit["timestamp"] as? String else { return }
			let item = DiffTimestampMenuItem(title: formatTimestamp(timestamp), action: nil, keyEquivalent: "")
			item.timestamp = timestamp
			
			if #available(macOS 14.4, *) {
				if let message = commit["message"] as? String {
					item.subtitle = message
				}
			}
			
			menu.menu?.addItem(item)
		}
		
		// Add item for current version
		let currentItem = DiffTimestampMenuItem(title: formatTimestamp("current"), action: nil, keyEquivalent: "")
		currentItem.timestamp = "current"
		menu.menu?.addItem(currentItem)
	}
	
	private func formatTimestamp(_ timestamp: String) -> String {
		// Special timestamps need to be localized
		if timestamp == "base" || timestamp == "current" {
			return BeatLocalization.localizedString(forKey: "versionControl." + timestamp)
		}
		
		// Timestamps are stored in shortened ISO format
		let inputFormatter = DateFormatter()
		inputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
		
		// Output formatter for user-friendly display
		let outputFormatter = DateFormatter()
		outputFormatter.dateStyle = .medium
		outputFormatter.timeStyle = .short
		outputFormatter.doesRelativeDateFormatting = true
		
		if let date = inputFormatter.date(from: timestamp) {
			return outputFormatter.string(from: date)
		}
		
		// Fallback to the original timestamp if parsing fails
		return timestamp
	}
	
	@IBAction func selectVersion(_ sender: NSPopUpButton?) {
		guard let button = sender,
			  let menuItem = button.selectedItem as? DiffTimestampMenuItem,
			  let timestamp = menuItem.timestamp.isEmpty ? button.selectedItem?.title : menuItem.timestamp
		else { return }
		
		if sender == currentVersionMenu {
			modifiedTimestamp = timestamp
		} else {
			originalTimestamp = timestamp
		}
		
		refreshContent()
	}
	
	/// Helper method to quickly select the latest commit at startup
	func compareToLatestCommit() -> Bool {
		guard let vc = vc, let latest = vc.latestTimestamp() else { print("Nope"); return false }
		
		modifiedTimestamp = "current"
		originalTimestamp = latest
		
		refreshContent()
		
		return true
	}
	
	// MARK: - Content Loading
	
	private func refreshContent() {
		// Update both texts
		updateTexts()
		
		if viewMode == .compare {
			loadDiff()
		} else {
			loadText()
		}
		
		updateScrollerWithDiffMarkers()
	}
	
	private func updateTexts() {
		// Build texts for version controls
		originalText = getText(timestamp: originalTimestamp)
		modifiedText = getText(timestamp: modifiedTimestamp)
	}
	
	private func getText(timestamp: String) -> String? {
		guard let delegate, let vc else {
			print("Error fetching commit text")
			return nil
		}
		
		if timestamp == "current" {
			return delegate.text()
		} else {
			return vc.text(at: timestamp)
		}
	}
	
	func loadDiff() {
		guard let originalText = originalText, let modifiedText = modifiedText else { return }
		
		let dmp = DiffMatchPatch()
		guard let diffs = dmp.diff_main(ofOldString: originalText, andNewString: modifiedText) else { return }
		
		dmp.diff_cleanupSemantic(diffs)
		
		// Convert NSMutableArray to [Diff]
		var diffValues: [Diff] = []
		for d in diffs {
			if let diff = d as? Diff {
				diffValues.append(diff)
			}
		}
		
		let text = formatDiffedText(diffValues, isOriginal: false)
		textView?.textStorage?.setAttributedString(text)
	}
	
	func loadText() {
		guard let text = originalText else { return }
		
		let attributedString = formatFountain(text)
		textView?.textStorage?.setAttributedString(attributedString)
	}
	
	
	// MARK: - Text Formatting
	
	private func formatDiffedText(_ diffs: [Diff], isOriginal: Bool) -> NSAttributedString {
		let string = NSMutableString()
		
		let redColor = BeatColors.color("red").withAlphaComponent(0.2)
		let greenColor = BeatColors.color("green").withAlphaComponent(0.2)
		
		let indices: [String: NSMutableIndexSet] = [
			"delete": NSMutableIndexSet(),
			"insert": NSMutableIndexSet()
		]
		
		// Create an attributed string from diffs
		for diff in diffs {
			let text = diff.text ?? ""
			let range = NSMakeRange(string.length, text.count)
					
			switch diff.operation.rawValue {
			case 1: // Delete
				indices["delete"]?.add(in: range)
			case 2: // Insert
				indices["insert"]?.add(in: range)
			default: // Equal
				break
			}

			string.append(text)
		}
		
		// Create a string, parse content and load document settings
		let attributedString = formatFountain(string as String)
		
		// Apply diff colors
		indices["delete"]?.enumerateRanges(using: { range, stop in
			attributedString.addAttribute(.backgroundColor, value: redColor, range: range)
			attributedString.addAttribute(.strikethroughColor, value: NSColor.red, range: range)
			attributedString.addAttribute(.strikethroughStyle, value: 1, range: range)
			attributedString.addAttribute(NSAttributedString.Key("DIFF"), value: "delete", range: range)
		})
		indices["insert"]?.enumerateRanges(using: { range, stop in
			attributedString.addAttribute(.backgroundColor, value: greenColor, range: range)
			attributedString.addAttribute(NSAttributedString.Key("DIFF"), value: "add", range: range)
		})
		
		return attributedString
	}
	
	private func formatFountain(_ string: String) -> NSMutableAttributedString {
		let attributedString = NSMutableAttributedString(string: string)
		let formatting = BeatEditorFormatting(textStorage: attributedString)
		let documentSettings = delegate?.documentSettings
				
		formatting.staticParser = ContinuousFountainParser(staticParsingWith: attributedString.string, settings: documentSettings)
		formatting.formatAllLines()
		
		return attributedString
	}
	
	
	// Call this after the text is set in textView
	func updateScrollerWithDiffMarkers() {
		guard let textView = textView,
			  let textStorage = textView.textStorage,
			  let scrollView = textView.enclosingScrollView,
			  let scroller = scrollView.verticalScroller as? DiffScrollerView else { return }
		
		var insertRanges: [NSRange] = []
		var deleteRanges: [NSRange] = []
		
		// Scan through the entire text storage to find diff markers
		textStorage.enumerateAttribute(NSAttributedString.Key("DIFF"), in: textStorage.range) { value, range, stop in
			guard let attr = value as? String else { return }
			if attr == "delete" {
				deleteRanges.append(range)
			} else {
				insertRanges.append(range)
			}
		}
				
		// Update the scroller with the found ranges
		scroller.updateDiffRanges(
			insertRanges: insertRanges,
			deleteRanges: deleteRanges,
			totalLength: textStorage.length
		)
	}
	
	// MARK: - View mode control
	
	@IBAction func switchMode(_ sender: NSSegmentedControl) {
		if let mode = DiffViewMode(rawValue: sender.selectedSegment) {
			viewMode = mode
		}
	}
	
	// MARK: - Window actions
	
	@IBAction func close(_ sender: Any?) {
		view.window?.close()
	}
	
	override func cancelOperation(_ sender: Any?) {
		close(sender)
	}
	
	func showVersion(originalTimestamp: String) {
		self.originalTimestamp = originalTimestamp
		otherVersionMenu?.selectCommit(originalTimestamp)
		loadText()
	}
}


// MARK: - Supporting Classes

class DiffViewerTextView: NSTextView {
	weak var editor: BeatEditorDelegate?
	var magnification = 1.3
	
	override var frame: NSRect {
		didSet {
			updateTextLayout()
		}
	}
	
	func setup(editorDelegate: BeatEditorDelegate) {
		editor = editorDelegate
		
		textContainer?.widthTracksTextView = false
		scaleUnitSquare(to: CGSize(width: magnification, height: magnification))
		textContainer?.lineFragmentPadding = BeatTextView.linePadding()
		updateTextLayout()
	}
	
	private func updateTextLayout() {
		guard let editor = editor else { return }
		
		let scrollWidth = enclosingScrollView?.frame.size.width ?? 0.0
		let documentWidth = editor.documentWidth
		
		let insetWidth = (scrollWidth / 2 - documentWidth * magnification / 2) / magnification
		
		textContainerInset = CGSize(width: insetWidth, height: 10.0)
		textContainer?.containerSize = CGSize(width: documentWidth, height: .greatestFiniteMagnitude)
	}
}

class DiffViewerStatusView: NSView {
	@IBOutlet weak var icon: NSImageView?
	@IBOutlet weak var text: NSTextField?
	
	func update(uncommitedChanges: Bool) {
		if uncommitedChanges {
			if #available(macOS 11.0, *) {
				icon?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
				icon?.contentTintColor = .systemYellow
			}
			
			text?.stringValue = "You have uncommitted changes"
		} else {
			if #available(macOS 11.0, *) {
				icon?.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
				icon?.contentTintColor = .systemGreen
			}
			
			text?.stringValue = "Up to date"
		}
	}
}

class DiffTimestampMenu: NSPopUpButton {
	func selectCommit(_ timestamp: String) {
		guard let menu = menu else { return }
		
		for item in menu.items {
			if let timestampItem = item as? DiffTimestampMenuItem,
			   timestampItem.timestamp == timestamp {
				select(item)
				break
			}
		}
	}
}

class DiffTimestampMenuItem: NSMenuItem {
	var timestamp: String = ""
}


// MARK: - Custom Diff Scrollbar

class DiffScrollerView: NSScroller {
	private var insertRanges: [NSRange] = []
	private var deleteRanges: [NSRange] = []
	private var totalLength: CGFloat = 1.0
	
	func updateDiffRanges(insertRanges: [NSRange], deleteRanges: [NSRange], totalLength: Int) {
		self.insertRanges = insertRanges
		self.deleteRanges = deleteRanges
		self.totalLength = CGFloat(max(totalLength, 1))
		self.needsDisplay = true
	}
	
	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)
		drawDiffIndicators()
	}
	
	private func drawDiffIndicators() {
		// Set up colors
		let insertColor = NSColor.systemGreen.withAlphaComponent(0.6)
		let deleteColor = NSColor.systemRed.withAlphaComponent(0.6)
		
		let slotRect = self.rect(for: .knobSlot)
		let indicatorWidth: CGFloat = self.frame.width
		
		// Draw insert indicators
		drawIndicators(ranges: insertRanges, color: insertColor, slotRect: slotRect, indicatorWidth: indicatorWidth)
		
		// Draw delete indicators
		drawIndicators(ranges: deleteRanges, color: deleteColor, slotRect: slotRect, indicatorWidth: indicatorWidth)
	}
	
	private func drawIndicators(ranges: [NSRange], color: NSColor, slotRect: NSRect, indicatorWidth: CGFloat) {
		color.setFill()
		
		for range in ranges {
			let rangeStart = CGFloat(range.location) / totalLength
			let rangeEnd = CGFloat(range.location + range.length) / totalLength
			
			// Calculate position in scrollbar
			let yStart = slotRect.origin.y + slotRect.size.height * rangeStart
			let height = max(2.0, slotRect.size.height * (rangeEnd - rangeStart))
			
			// Draw indicator
			let indicatorRect = NSRect(
				x: slotRect.origin.x,
				y: yStart,
				width: indicatorWidth,
				height: height
			)
			
			let path = NSBezierPath(roundedRect: indicatorRect, xRadius: 1.0, yRadius: 1.0)
			path.fill()
		}
	}
}

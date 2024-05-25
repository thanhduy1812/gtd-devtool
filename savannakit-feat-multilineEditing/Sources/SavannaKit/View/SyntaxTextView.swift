//
//  SyntaxTextView.swift
//  SavannaKit
//
//  Created by Louis D'hauwe on 23/01/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation
import CoreGraphics
import AppKit

public protocol SyntaxTextViewDelegate: AnyObject {
	
	func didChangeText(_ syntaxTextView: SyntaxTextView)

	func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange)
	
	func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView)
	
	func lexerForSource(_ source: String) -> Lexer
    
    func theme(for appearance: NSAppearance) -> SyntaxColorTheme
    
    func didUpdateSelectionRanges(_ syntaxTextView: SyntaxTextView)
}

// Provide default empty implementations of methods that are optional.
public extension SyntaxTextViewDelegate {
    
    func didChangeText(_ syntaxTextView: SyntaxTextView) { }
	
    func didChangeSelectedRange(_ syntaxTextView: SyntaxTextView, selectedRange: NSRange) { }
	
    func textViewDidBeginEditing(_ syntaxTextView: SyntaxTextView) { }
    
    func didUpdateSelectionRanges(_ syntaxTextView: SyntaxTextView) { }

}

struct ThemeInfo {
	
	let theme: SyntaxColorTheme
	
	/// Width of a space character in the theme's font.
	/// Useful for calculating tab indent size.
	let spaceWidth: CGFloat
	
}

//@IBDesignable
open class SyntaxTextView: View {

	var previousSelectedRange: NSRange?
	
	private var textViewSelectedRangeObserver: NSKeyValueObservation?

	let textView: InnerTextView
    var rulerView: LineRulerView? {
        didSet {
            rulerView?.clipsToBounds = true
        }
    }
    
	
	public var contentTextView: TextView {
		return textView
	}
	
	public weak var delegate: SyntaxTextViewDelegate? {
		didSet {
			didUpdateText()
            self.theme = delegate?.theme(for: self.effectiveAppearance)
		}
	}
	
	var ignoreSelectionChange = false
	
	public var tintColor: NSColor! {
		set {
			textView.tintColor = newValue
		}
		get {
			return textView.tintColor
		}
	}
    
    public override init(frame: CGRect) {
        textView = SyntaxTextView.createInnerTextView()
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        textView = SyntaxTextView.createInnerTextView()
        super.init(coder: aDecoder)
        setup()
    }
	
    private static func createInnerTextView() -> InnerTextView {
        let textStorage = NSTextStorage()
        let layoutManager = SyntaxTextViewLayoutManager()

        let containerSize = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
				
        let textContainer = NSTextContainer(size: containerSize)
        
        textContainer.widthTracksTextView = true
		
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        return InnerTextView(frame: .zero, textContainer: textContainer)
    }


    public let scrollView = NSScrollView()
	
	private func setup() {
        
        
        
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        scrollView.contentView.backgroundColor = .clear
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        
        scrollView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerKnobStyle = .light
        
        scrollView.documentView = textView
    
        scrollView.contentView.postsFrameChangedNotifications = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(renewLines(_:)), name: NSView.frameDidChangeNotification, object: scrollView.contentView)
        
        
        textView.minSize = NSSize(width: 0.0, height: self.bounds.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        
       
        textView.textContainer?.containerSize = NSSize(width: self.bounds.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
		
		textView.innerDelegate = self
		textView.delegate = self
        
        if let scrollView = textView.enclosingScrollView {
            
            rulerView = LineRulerView(textView: textView)
            scrollView.verticalRulerView = rulerView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            
            scrollView.contentView.postsBoundsChangedNotifications = true
            
            NotificationCenter.default.addObserver(self,
                selector: #selector(scrollViewDidResize(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView)
        }
        
		textView.text = ""
	}
    
    @objc public func scrollViewDidResize(_ notification: NSNotification) {
        textView.scrollViewDidResize(scrollView)
    }

    
    @objc func renewLines(_ notification: Notification) {
        self.textView.invalidateCachedParagraphs()
        rulerView?.needsDisplay = true
    }
    
    @available(OSXApplicationExtension 10.14, *)
    open override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        
        self.theme = delegate?.theme(for: self.effectiveAppearance)
    }

	// MARK: -
	
//	@IBInspectable
	public var text: String {
		get {
            return textView.string
		}
		set {
            textView.layer?.isOpaque = true

            textView.string = newValue
            
            self.didUpdateText()
		}
	}
	
	// MARK: -


	public var theme: SyntaxColorTheme? {
		didSet {
			
			guard let theme = theme else {
				return
			}
			
			cachedThemeInfo = nil
            textView.backgroundColor = theme.backgroundColor
            textView.theme = theme
			textView.font = theme.font
            cachedThemeInfo = nil
			
			didUpdateText()
		}
	}
	
	var cachedThemeInfo: ThemeInfo?
	
	var themeInfo: ThemeInfo? {
		
		if let cached = cachedThemeInfo {
			return cached
		}
		
		guard let theme = theme else {
			return nil
		}
		
		let spaceAttrString = NSAttributedString(string: " ", attributes: [.font: theme.font])
		let spaceWidth = spaceAttrString.size().width
		
		let info = ThemeInfo(theme: theme, spaceWidth: spaceWidth)
		
		cachedThemeInfo = info
		
		return info
	}
	
	var cachedTokens: [CachedToken]?
	
	func invalidateCachedTokens() {
		cachedTokens = nil
	}
	
	func colorTextView(lexerForSource: (String) -> Lexer) {
		
		guard let source = textView.text else {
			return
		}
		
		let textStorage: NSTextStorage
				
        textStorage = textView.textStorage!
				
        var tokens: [Token]
		
		if let cachedTokens = cachedTokens {
			
			updateAttributes(textStorage: textStorage, cachedTokens: cachedTokens, source: source)
			
		} else {
			
			guard let theme = self.theme else {
				return
			}
			
			guard let themeInfo = self.themeInfo else {
				return
			}
			
			textView.font = theme.font
            
            

			let lexer = lexerForSource(source)
			tokens = lexer.getSavannaTokens(input: source)
            
            
            toggleTokens(tokens: tokens)
			
			let cachedTokens: [CachedToken] = tokens.map {

                return CachedToken(token: $0, nsRange: $0.range)
			}

			self.cachedTokens = cachedTokens
			
			createAttributes(theme: theme, themeInfo: themeInfo, textStorage: textStorage, cachedTokens: cachedTokens, source: source)
			
		}
		
	}
    
    func toggleTokens(tokens: [Token]) {
        let sortedTokens = tokens.sorted { (left, right) -> Bool in
            left.range.lowerBound < right.range.lowerBound
        }

        guard let first = sortedTokens.first else {
            // No token found.
            return
        }
        
        var currentToken = first
        
        var firstLoop = true

        for var token in sortedTokens {

            if currentToken.isGreedy,
                currentToken.range.contains(token.range.location),
                !firstLoop {
                token.isActive = false
            } else {
                firstLoop = false
                currentToken = token
            }
        }
    }

	func updateAttributes(textStorage: NSTextStorage, cachedTokens: [CachedToken], source: String) {

		let selectedRange = textView.selectedRange
		
		let fullRange = NSRange(location: 0, length: (source as NSString).length)
		
		var rangesToUpdate = [(NSRange, EditorPlaceholderState)]()
		
		textStorage.enumerateAttribute(.editorPlaceholder, in: fullRange, options: []) { (value, range, stop) in
			
			if let state = value as? EditorPlaceholderState {
				
				var newState: EditorPlaceholderState = .inactive
				
				if isEditorPlaceholderSelected(selectedRange: selectedRange, tokenRange: range) {
					newState = .active
				}
				
				if newState != state {					
					rangesToUpdate.append((range, newState))
				}
				
			}
		
		}
		
		var didBeginEditing = false
		
		if !rangesToUpdate.isEmpty {
			textStorage.beginEditing()
			didBeginEditing = true
		}
		
		for (range, state) in rangesToUpdate {
			
			var attr = [NSAttributedString.Key: Any]()
			attr[.editorPlaceholder] = state

			textStorage.addAttributes(attr, range: range)

		}
		
		if didBeginEditing {
			textStorage.endEditing()
		}

	}
	
	func createAttributes(theme: SyntaxColorTheme, themeInfo: ThemeInfo, textStorage: NSTextStorage, cachedTokens: [CachedToken], source: String) {
		
		textStorage.beginEditing()

		var attributes = [NSAttributedString.Key: Any]()
		
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.paragraphSpacing = 2.0
		paragraphStyle.defaultTabInterval = themeInfo.spaceWidth * 4
		paragraphStyle.tabStops = []
		
		let wholeRange = NSRange(location: 0, length: (source as NSString).length)
		
		attributes[.paragraphStyle] = paragraphStyle
		
		for (attr, value) in theme.globalAttributes() {
			
			attributes[attr] = value

		}
		
		textStorage.setAttributes(attributes, range: wholeRange)
		
		let selectedRange = textView.selectedRange
		
		for cachedToken in cachedTokens {
			
			let token = cachedToken.token
			
			if token.isPlain {
				continue
			}
            
            guard token.isActive else {
                continue
            }
			
			let range = cachedToken.nsRange

			if token.isEditorPlaceholder {
				
				let startRange = NSRange(location: range.lowerBound, length: 2)
				let endRange = NSRange(location: range.upperBound - 2, length: 2)
				
				let contentRange = NSRange(location: range.lowerBound + 2, length: range.length - 4)
				
				var attr = [NSAttributedString.Key: Any]()
				
				var state: EditorPlaceholderState = .inactive
				
				if isEditorPlaceholderSelected(selectedRange: selectedRange, tokenRange: range) {
					state = .active
				}
				
				attr[.editorPlaceholder] = state
				
				textStorage.addAttributes(theme.attributes(for: token), range: contentRange)
				
				textStorage.addAttributes([.foregroundColor: Color.clear, .font: Font.systemFont(ofSize: 0.01)], range: startRange)
				textStorage.addAttributes([.foregroundColor: Color.clear, .font: Font.systemFont(ofSize: 0.01)], range: endRange)
				
				textStorage.addAttributes(attr, range: range)
				continue
			}
			
			textStorage.addAttributes(theme.attributes(for: token), range: range)
		}
        
        // Taken from brunophilipe/savannakit
        // Cleanup attributes. Good practice after applying many attributes at once.
        textStorage.fixAttributes(in: wholeRange)
		
		textStorage.endEditing()
		
	}
    
    public func highlight(line: Int, column: Int = 0, color: NSColor, message: String? = nil) {
    
        DispatchQueue.main.sync {
        
            guard let text = self.contentTextView.textStorage?.string as NSString? else { return assertionFailure() }
            
            var lineIndex = 1
            var index = 0
            let stringLength = self.text.count
            
            while index < stringLength {
                
                let oldIndex = index
                index = NSMaxRange(text.lineRange(for: NSMakeRange(index, 0)))
                
                if lineIndex == line {
                    let highlightedRange = text.lineRange(for: NSMakeRange(oldIndex, 0))
                    let columnHighlightRange = NSMakeRange(highlightedRange.location + column - 1, highlightedRange.length - column + 1)
                    self.contentTextView.textStorage?.addAttribute(.backgroundColor, value: color, range: columnHighlightRange)
                    if let message = message {
                        self.contentTextView.textStorage?.addAttribute(.toolTip, value: message, range: columnHighlightRange)
                    }
                    
                }
                lineIndex += 1
            }
        }
    }
}

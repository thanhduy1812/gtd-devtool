//
//  SyntaxTextStorage.swift
//  SavannaKit macOS
//
//  Created by Nguyen Thanh Duy on 25/05/2024.
//  Copyright © 2024 Silver Fox. All rights reserved.
//

import Foundation
import AppKit

class SyntaxTextStorage: NSTextStorage {

    private var storage: NSTextStorage

    override var string: String {
        return storage.string
    }

    override init() {
        self.storage = NSTextStorage(string: "")
        super.init()
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        self.storage = NSTextStorage(string: "")
        super.init(pasteboardPropertyList: propertyList, ofType: type)
    }
    
    required init?(coder: NSCoder) {
        self.storage = NSTextStorage(string: "")
        super.init(coder: coder)
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return storage.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        storage.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        storage.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

}

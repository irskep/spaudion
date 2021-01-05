//
//  AudionWindow.swift
//  Audion
//
//  Created by Buckley on 5/14/20.
//  Copyright © 2020 Panic. All rights reserved.
//

import Cocoa

class AudionWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool {
        get {
            return true
        }
    }
}

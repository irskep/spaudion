//
//  OpenStreamViewController.swift
//  Audion
//
//  Created by Buckley on 8/7/20.
//  Copyright © 2020 Panic. All rights reserved.
//

import Cocoa

class OpenStreamViewController: NSViewController, NSTextFieldDelegate {

    @IBOutlet private var textField: NSTextField? = nil
    @IBOutlet private var okButton: NSButton? = nil

    public var callback: ((String) -> ())?

    @IBAction func ok(_ sender: Any?) {
        if let callback = self.callback {
            callback(self.textField?.stringValue ?? "")
        }
        
        self.view.window?.close()
    }

    @IBAction func cancel(_ sender: Any?) {
        self.view.window?.close()
    }

    func controlTextDidChange(_ obj: Notification) {
        self.okButton?.isEnabled = (self.textField?.stringValue ?? "").count > 0
    }
}

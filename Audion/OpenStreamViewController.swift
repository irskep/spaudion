/*
Copyright 2020-2021 Panic Inc.

This file is part of Audion.

Audion is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Audion is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Audion.  If not, see <https://www.gnu.org/licenses/>.
*/

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

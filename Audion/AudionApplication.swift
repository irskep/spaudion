//
//  AudionApplication.swift
//  Spaudion
//
//  Created by Stephen Landey on 1/10/21.
//  Copyright © 2021 Panic. All rights reserved.
//

import AppKit

@objc (AudionApplication)
class AudionApplication: NSApplication {
  override var nextResponder: NSResponder? {
    get {
      if self.mainWindow?.contentViewController as? ViewController != nil {
        return super.nextResponder
      }
      else {
        for window in NSApp.windows {
          if let viewController = window.contentViewController as? ViewController {
            return viewController
          }
        }

        return super.nextResponder
      }
    }
    set {
      super.nextResponder = newValue
    }
  }

  override func orderFrontStandardAboutPanel(options optionsDictionary: [NSApplication.AboutPanelOptionKey : Any] = [:]) {
    if ( NSEvent.modifierFlags.contains(.option) )
    {
      let year = Calendar.current.component(.year, from: Date())
      let alert = NSAlert()
      alert.messageText = "Were you really expecting an Easter egg in " + String(year) + "?"
      alert.informativeText = "I mean, this is open source, so it's not like I can hide it."

      alert.addButton(withTitle: "Of course I was!")
      alert.addButton(withTitle: "Not really…")

      let result = alert.runModal()

      if result == .alertFirstButtonReturn {
        let subalert = NSAlert()
        subalert.messageText = "You're right, software should be more fun."
        subalert.informativeText = "I thought really hard about what kinds of easter eggs I should add, but it just didn't feel appropriate given the state of the world right now. Fortunately, Audion itself is already plenty fun."

        subalert.addButton(withTitle: "😢")

        subalert.runModal()
      } else {
        super.orderFrontStandardAboutPanel(options: optionsDictionary)
      }
    } else {
      super.orderFrontStandardAboutPanel(options: optionsDictionary)
    }
  }
}

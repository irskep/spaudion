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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  var preferencesWindowController: NSWindowController? = nil

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleURLEvent),
      forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL))
  }

  @objc func handleURLEvent(event: NSAppleEventDescriptor,
                            replyEvent: NSAppleEventDescriptor) {
    if  let descriptor = event.paramDescriptor(forKeyword: keyDirectObject),
        let urlString  = descriptor.stringValue,
        let url        = URL(string: urlString) {
      NotificationCenter.default.post(name: NSNotification.Name(rawValue: "url"), object: nil, userInfo: ["url": url])
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    UserDefaults.standard.register(defaults: [Constants.audionVolumePrefKey: 0.5])
  }

  public var appSupportDirectory: URL? {
    get {
      let fileManager = FileManager.default
      let appSupportURLs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      if appSupportURLs.count > 0 {
        let appSupportURL = appSupportURLs[0]
        let facesURL = appSupportURL.appendingPathComponent("Audion").appendingPathComponent("Faces")

        do {
          if !fileManager.fileExists(atPath: facesURL.path) {
            try fileManager.createDirectory(at: facesURL, withIntermediateDirectories: true, attributes: nil)
          }
        } catch {
          return nil
        }

        return facesURL
      }

      return nil
    }
  }

  @IBAction func openFacesFolder(_ sender: Any?) {
    if let appSupportDirectory = self.appSupportDirectory {
      NSWorkspace.shared.open(appSupportDirectory)
    }
  }

  @IBAction func showPrefs(_ sender: Any?) {
    if self.preferencesWindowController == nil {
      if let viewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("AppearancePrefPane")) as? AppearancePrefsViewController {
        viewController.view.translatesAutoresizingMaskIntoConstraints = false

        let window = NSWindow(contentRect: NSRect.zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
        window.title = "Preferences"
        window.contentViewController = viewController
        preferencesWindowController = NSWindowController(window: window)

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: OperationQueue.main) { _ in
          self.preferencesWindowController = nil
        }

        window.center()
      }
    }

    self.preferencesWindowController?.window?.makeKeyAndOrderFront(self)
  }
}


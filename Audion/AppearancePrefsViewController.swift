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

import FaceKit
import Cocoa

public let AudionFacePrefsKey = "faceURL"
public let AudionHuePrefsKey = "hue"

extension UserDefaults {
    @objc dynamic var faceURL: URL? {
        return self.url(forKey: AudionFacePrefsKey)
    }

    @objc dynamic var hue: Double {
        return self.double(forKey: AudionHuePrefsKey)
    }
}

class AppearancePrefsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    struct FaceInfo: Decodable {
        let description1: String
        let description2: String
        let url: URL?
        let urlString: String

        private enum CodingKeys: String, CodingKey {
            case faceInfo
        }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            let faceInfo = try values.decode([String].self, forKey: CodingKeys.faceInfo)

            if faceInfo.count == 3 {
                let description = faceInfo[0]
                let components = description.split(separator: "\n")

                if components.count == 2 {
                    self.description1 = String(components[0])
                    self.description2 = String(components[1])
                } else {
                    self.description1 = ""
                    self.description2 = ""
                }

                if faceInfo[1].count > 0, let url = URL(string: faceInfo[1]) {
                    self.url = url
                    self.urlString = faceInfo[2]
                } else if faceInfo[2].count > 0, let url = URL(string:faceInfo[2]) {
                    self.url = url
                    self.urlString = faceInfo[1]
                } else {
                    self.url = nil
                    self.urlString = faceInfo[2]
                }

            } else {
                self.description1 = ""
                self.description2 = ""
                self.urlString = ""
                self.url = nil
            }
        }
    }

    private var faces: [URL] = []

    @IBOutlet private weak var aboutImageView: NSImageView? = nil
    @IBOutlet private weak var descriptionLabel1: NSTextField? = nil
    @IBOutlet private weak var descriptionLabel2: NSTextField? = nil
    @IBOutlet private weak var urlField: NSTextField? = nil
    @IBOutlet private weak var tableView: NSTableView? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let fileManager = FileManager.default

        if let bundle = Bundle(identifier: "com.panic.FaceKit"), let defaultURL = bundle.url(forResource: "Smoothface 2", withExtension: nil) {
            self.faces.append(defaultURL)
        }

        if let appDelegate = NSApp.delegate as? AppDelegate, let appSupportURL = appDelegate.appSupportDirectory {
            do {
                let contents = try fileManager.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants)
                for url in contents {
                    if url.lastPathComponent == "Smoothface 2" {
                        continue
                    }

                    let indexURL = url.appendingPathComponent("index.json")
                    if fileManager.fileExists(atPath: indexURL.path) {
                        self.faces.append(url)
                    }
                }
            } catch {
                fatalError()
            }
        }

        self.faces.sort() { a, b in
            return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
        }
    }

    override func viewWillAppear() {
        let selectedURL: URL?

        if let url = UserDefaults.standard.url(forKey: AudionFacePrefsKey) {
            selectedURL = url
        } else if let bundle = Bundle(identifier: "com.panic.FaceKit"), let defaultURL = bundle.url(forResource: "Smoothface 2", withExtension: nil) {
            selectedURL = defaultURL
        } else {
            selectedURL = nil
        }

        self.tableView?.reloadData()
        if let selectedURL = selectedURL, let index = self.faces.firstIndex(of: selectedURL) {
            self.tableView?.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            self.tableView?.scrollRowToVisible(index)
        }
    }

    // MARK: - NSTableViewDataSource Methods

    func numberOfRows(in tableView: NSTableView) -> Int {
        self.faces.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = notification.object as? NSTableView {
            let selectedRow = tableView.selectedRow

            if selectedRow < 0 || selectedRow >= self.faces.count {
                return
            }

            do {
                let url = self.faces[tableView.selectedRow]
                let indexURL = url.appendingPathComponent("index.json")
                let imageURL = url.appendingPathComponent("about.png")
                let decoder = JSONDecoder()
                let data = try Data(contentsOf: indexURL)
                let faceInfo = try decoder.decode(FaceInfo.self, from: data)

                self.aboutImageView?.image = NSImage(contentsOf: imageURL)
                self.descriptionLabel1?.stringValue = faceInfo.description1
                self.descriptionLabel2?.stringValue = faceInfo.description2

                if faceInfo.urlString.count > 0 {
                    if let faceInfoURL = faceInfo.url {
                        let attributedString = NSAttributedString(string: faceInfo.urlString, attributes: [ NSAttributedString.Key.link: faceInfoURL, NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue, NSAttributedString.Key.foregroundColor: NSColor.blue, NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize) ])

                        self.urlField?.attributedStringValue = attributedString
                    } else {
                        self.urlField?.stringValue = faceInfo.urlString
                    }
                } else {
                    self.urlField?.stringValue = ""
                }

                self.urlField?.resetCursorRects()

                UserDefaults.standard.set(url, forKey: AudionFacePrefsKey)
            } catch {
                fatalError()
            }
        }
    }

    // MARK: - NSTableViewDelegate Methods

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "FaceRow"), owner: nil) as? NSTableCellView {
            view.textField?.stringValue = self.faces[row].lastPathComponent
            return view
        }
        return nil
    }
}

class ClickableTextField: NSTextField {

    var trackingArea: NSTrackingArea? = nil

    override var stringValue: String {
        didSet {
            if let trackingArea = self.trackingArea {
                self.removeTrackingArea(trackingArea)
            }
        }
    }

    override var attributedStringValue: NSAttributedString {
        didSet {
            if let trackingArea = self.trackingArea {
                self.removeTrackingArea(trackingArea)
            }

            let size = self.attributedStringValue.boundingRect(with: NSSize(width: self.frame.size.width, height: self.frame.size.height), options: .truncatesLastVisibleLine)
            self.trackingArea = NSTrackingArea(rect: NSRect(x: 0, y: 0, width: size.width, height: self.frame.size.height), options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: self, userInfo: nil)

            self.addTrackingArea(self.trackingArea!)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        if self.attributedStringValue.length > 0 && self.attributedStringValue.attributes(at: 0, effectiveRange: nil).keys.contains(NSAttributedString.Key.link) {
            self.addCursorRect(self.bounds, cursor: .pointingHand)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if self.attributedStringValue.length > 0 && self.attributedStringValue.attributes(at: 0, effectiveRange: nil).keys.contains(NSAttributedString.Key.link) {
            NSCursor.pointingHand.set()
        }
    }
}

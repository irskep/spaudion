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

import AVFoundation
import Cocoa
import FaceKit

let AudionVolumePrefKey = "volume"

class Player: NSObject, AudionFaceViewDelegate {
    let supportsStop = true
    let supportsRewind = true
    let supportsFastForward = true

    private var avPlayer: AVPlayer? = nil {
        willSet {
            if let avPlayer = self.avPlayer {
                avPlayer.removeObserver(self, forKeyPath: "rate")
                avPlayer.removeObserver(self, forKeyPath: "status")
                avPlayer.removeObserver(self, forKeyPath: "timeControlStatus")
            }
        }
        didSet {
            if let avPlayer = self.avPlayer {
                avPlayer.addObserver(self, forKeyPath: "rate", options: .new, context: nil)
                avPlayer.addObserver(self, forKeyPath: "status", options: .new, context: nil)
                avPlayer.addObserver(self, forKeyPath: "timeControlStatus", options: .new, context: nil)
            }
        }
    }

    var faceView: AudionFaceView? = nil
    private var filename: String? = nil
    private var streaming = false
    private var startedStream = false

    func open(url: URL) -> Bool {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        self.avPlayer = AVPlayer(playerItem: playerItem)
        self.avPlayer?.volume = UserDefaults.standard.float(forKey: AudionVolumePrefKey)
        self.avPlayer?.automaticallyWaitsToMinimizeStalling = true
        self.faceView?.stop()

        let duration = self.avPlayer?.currentItem?.asset.duration.seconds ?? 0.0

        if duration.isFinite {
            self.faceView?.durationInSeconds = Int(duration)
        } else {
            self.faceView?.durationInSeconds = -1
        }

        if url.isFileURL {
            self.filename = url.lastPathComponent
        } else {
            self.filename = url.absoluteString
        }

        if ( url.scheme != "file" ) {
            self.streaming = true
            self.faceView?.animationType = .connecting
        }

        let assetLength = Float(asset.duration.value) / Float(asset.duration.timescale)
        return (assetLength > 0)
    }

    var isPlaying: Bool {
        get {
            return self.faceView?.isPlaying ?? false
        }
    }

    var isScrubbing = false

    func play() {
        if let avPlayer = self.avPlayer {
            avPlayer.play()

            if !self.isScrubbing {
                self.faceView?.play()
            }
        } else {
            NSApp.sendAction(NSSelectorFromString("openDocument:"), to: nil, from: self)
        }
    }

    func pause() {
        self.avPlayer?.pause()

        if !self.isScrubbing {
            self.faceView?.pause()
        }
    }

    func stop() {
        self.avPlayer?.pause()

        if !self.isScrubbing {
            self.faceView?.stop()
        }

        self.startedStream = false
        self.streaming = false
        self.avPlayer = nil
    }

    func togglePlayPause() {
        if self.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }

    private(set) var isMuted = false
    private var preMuteVolume: Double = 0.0

    func mute() {
        self.preMuteVolume = self.faceView?.volume ?? 0.0
        self.isMuted = true
        self.faceView?.volume = 0.0
        self.avPlayer?.volume = 0.0
    }

    func unMute() {
        self.isMuted = false
        self.faceView?.volume = self.preMuteVolume
        self.avPlayer?.volume = Float(self.preMuteVolume)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if (self.avPlayer?.rate ?? 0) == 0 {
                if !self.isScrubbing {
                    self.faceView?.pause()
                }
            } else {
                if !self.isScrubbing {
                    self.faceView?.play()
                }
            }
        } else if keyPath == "status" {
            let status = self.avPlayer?.status ?? .unknown
            if status == .readyToPlay {
                self.updateMetadata()
            }
        } else if keyPath == "timeControlStatus" {
            if self.streaming {
                if self.avPlayer?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                    if self.startedStream {
                        self.faceView?.animationType = .lag
                    } else {
                        self.faceView?.animationType = .connecting
                    }
                } else {
                    self.startedStream = true
                    self.faceView?.animationType = .streaming
                }
            }
        }
    }

    private func updateMetadata() {
        let duration = self.avPlayer?.currentItem?.asset.duration.seconds ?? 0.0

        if duration.isFinite {
            if self.streaming && duration == 0 {
                self.stop(self.faceView!)
                let alert = NSAlert()
                alert.messageText = "Connection failed"
                alert.informativeText = "Could not connect, or connection was refused by server."
                alert.runModal()
            } else {
                self.faceView?.durationInSeconds = Int(duration)
            }
        } else {
            self.faceView?.durationInSeconds = -1
            self.play()
        }

        var artist = ""
        var album = ""
        var format = ""

        self.faceView?.artistText = nil

        for datum in self.avPlayer?.currentItem?.asset.commonMetadata ?? [] {
            if datum.commonKey == AVMetadataKey.commonKeyTitle, let title = datum.value as? String {
                self.faceView?.artistText = title
            } else if datum.commonKey == AVMetadataKey.commonKeyArtist, let value = datum.value as? String {
                artist = value
            } else if datum.commonKey == AVMetadataKey.commonKeyAlbumName, let value = datum.value as? String {
                album = value
            } else if datum.commonKey == AVMetadataKey.commonKeyFormat, let value = datum.value as? String {
                format = value
            }
        }

        if (self.faceView?.artistText ?? nil) == nil {
            self.faceView?.artistText = self.filename
        }

        let albumText = [artist, album, format].filter() { $0.count > 0 }.joined(separator: "—")
        if albumText.count > 0 {
            self.faceView?.albumText = albumText
        } else {
            self.faceView?.albumText = nil
        }

        self.avPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main) { time in
            if self.avPlayer != nil {
                self.faceView?.timeInSeconds = Int(time.seconds)
            }
        }
    }

    // MARK: - faceViewDelegate Methods

    func play(_ sender: AudionFaceView) {
        if let avPlayer = self.avPlayer {
            avPlayer.play()
        } else {
            NSApp.sendAction(NSSelectorFromString("openDocument:"), to: nil, from: self)
        }
    }

    func pause(_ sender: AudionFaceView) {
        self.avPlayer?.pause()
    }

    func stop(_ sender: AudionFaceView) {
        self.stop()
    }

    func rewind(_ sender: AudionFaceView) {}

    func fastForward(_ sender: AudionFaceView) {}

    func volumeChanged(to volume: Double, sender: AudionFaceView) {
        if volume > 0 {
            self.isMuted = false
        }

        self.avPlayer?.volume = Float(volume)
        UserDefaults.standard.set(Float(volume), forKey: AudionVolumePrefKey)
    }

    func playTimeChanged(to time: Double, sender: AudionFaceView) {
        self.avPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }

    func pauseBeforeScrubbing(_ sender: AudionFaceView) {
        self.isScrubbing = true
        self.avPlayer?.pause()
    }

    func playAfterScrubbing(_ sender: AudionFaceView) {
        self.isScrubbing = false
        self.avPlayer?.play()
    }
}

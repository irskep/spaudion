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

import SpotifyWebAPI
import KeychainSwift
import Combine
import Cocoa
import FaceKit
import Security

class Services {
  static let shared = Services()

  lazy var spotify = SpotifyAPI(
    authorizationManager: AuthorizationCodeFlowManager(
      clientId: SpotifyCredentials.clientId,
      clientSecret: SpotifyCredentials.clientSecret))

  let keychain = KeychainSwift(keyPrefix: "com.steveasleep.Avdion")
}

class PlaybackState {
  @Published
  var itemURI: SpotifyURIConvertible? = nil

  @Published
  var isPlaying = false

  @Published
  var songName = ""

  @Published
  var songArtist = ""

  @Published
  var songAlbum = ""

  @Published
  var volume: Double = 0

  @Published
  var duration: Double = 0

  @Published
  var progress: Double = 0

  @Published
  var isAuthorized = false
}

enum AvdiumError: Error {
  case meaningless
}

extension Track {
  var artistNames: String? { artists?.map { $0.name}.joined(separator: ", ") }
}

class SpotifyPlayer: NSObject, AudionFaceViewDelegate {
  let supportsStop = false
  let supportsRewind = true
  let supportsFastForward = true

  var faceView: AudionFaceView? = nil

  var isPlaying: Bool { playbackState.isPlaying }
  var isScrubbing = false

  private var cancellables = Set<AnyCancellable>()

  var playbackState = PlaybackState()

  lazy var timer = Timer(timeInterval: 1, repeats: true, block: { [weak self] _ in
    self?.refresh()
  })

  private var spotify: SpotifyAPI<AuthorizationCodeFlowManager> { Services.shared.spotify }
  private var keychain: KeychainSwift { Services.shared.keychain }

  lazy var trackPublisher: AnyPublisher<AnyPublisher<Track?, Error>, Never> = { self.playbackState.$itemURI
    .removeDuplicates(by: { $0?.uri == $1?.uri })
    .map { [weak self] (maybeURI: SpotifyURIConvertible?) -> AnyPublisher<Track?, Error> in
      guard let self = self, let uri = maybeURI else {
        return Just<Track?>(nil).mapError({ _ in AvdiumError.meaningless }).eraseToAnyPublisher()
      }
      return self.spotify.track(uri).map({ $0 }).eraseToAnyPublisher()
    }
    .receive(on: RunLoop.main)
    .eraseToAnyPublisher() }()

  override init() {
    super.init()
    print("Setting event handler")
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name(rawValue: "url"),
      object: nil,
      queue: OperationQueue.main,
      using: { [weak self] n in
        if let url = n.userInfo?["url"] as? URL {
          self?.handleURL(url)
        }
      })

  }

  func start() {
    // MARK: Read playback state

    trackPublisher
      .sink { [weak self] in
        guard let self = self else { return }
        $0
          .receive(on: RunLoop.main)
          .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] track in
            guard let self = self else { return }
            self.playbackState.songName = track?.name ?? ""
            self.playbackState.songArtist = track?.artistNames ?? ""
            self.playbackState.songAlbum = track?.album?.name ?? ""
            print(self.playbackState.songName, "-", self.playbackState.songAlbum)
          })
          .store(in: &self.cancellables)
      }
      .store(in: &cancellables)

    playbackState.$isPlaying
      .sink {
        [weak self] (isPlaying: Bool) -> Void in
        if isPlaying { self?.faceView?.play() } else { self?.faceView?.pause() }
        return
      }
      .store(in: &cancellables)

    playbackState.$songName.combineLatest(playbackState.$songAlbum)
      .map { (songName: String, songAlbum: String) -> String in
        switch (songName.isEmpty, songAlbum.isEmpty) {
        case (false, true): return songName
        case (true, false): return songAlbum
        case (true, true): return ""
        case (false, false): return "\(songName)—\(songAlbum)"
        }
      }
      .sink { [weak self] text in
        self?.faceView?.albumText = text
      }
      .store(in: &cancellables)
    playbackState.$songArtist
      .sink { [weak self] in self?.faceView?.artistText = $0 }
      .store(in: &cancellables)
    playbackState.$volume
      .sink { [weak self] in self?.faceView?.volume = $0 / 100 }
      .store(in: &cancellables)
    playbackState.$duration
      .sink { [weak self] in self?.faceView?.durationInSeconds = Int($0) }
      .store(in: &cancellables)
    playbackState.$progress
      .sink { [weak self] in self?.faceView?.timeInSeconds = Int($0) }
      .store(in: &cancellables)
    playbackState.$isAuthorized
      .sink { [weak self] in self?.faceView?.animationType = $0 ? .none : .connecting }
      .store(in: &cancellables)

    // MARK: Auth

    print("Subscribing to auth updates")
    spotify.authorizationManagerDidChange
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        print("Auth updated")
        guard let self = self else { return }
        self.playbackState.isAuthorized = self.spotify.authorizationManager.isAuthorized()

        do {
          // Encode the authorization information to data.
          let authManagerData = try JSONEncoder().encode(
            self.spotify.authorizationManager
          )

          // Save the data to the keychain.
          self.keychain.set(authManagerData, forKey: "auth")

          self.refresh()
        } catch {
          print(error)
        }
      }
      .store(in: &cancellables)

    print("Subscribing to deauth updates")
    spotify.authorizationManagerDidDeauthorize
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        guard let self = self else { return }
        self.playbackState.isAuthorized = false
        self.keychain.delete("auth")
      }
      .store(in: &cancellables)

    print("Trying to load auth data")
    if let authManagerData = keychain.getData("auth") {
      do {
        // Try to decode the data.
        let authorizationManager = try JSONDecoder().decode(
          AuthorizationCodeFlowManager.self,
          from: authManagerData
        )
        print("found authorization information in keychain")

        spotify.authorizationManager = authorizationManager

      } catch {
        print(error)
      }
    } else {
      print("Logging in via browser")
      let url = spotify.authorizationManager.makeAuthorizationURL(
        redirectURI: URL(string: "com.steveasleep.avdion://callback")!,
        showDialog: false,
        scopes: [
          //        .appRemoteControl,
          .userReadPlaybackState,
          .userModifyPlaybackState,
          .userReadPlaybackPosition,
        ])!
      NSWorkspace.shared.open(url)
    }

    RunLoop.main.add(timer, forMode: .default)
  }

  private func handleURL(_ url: URL) {
    print("Handling URL", url)
    spotify.authorizationManager.requestAccessAndRefreshTokens(redirectURIWithQuery: url)
      .receive(on: RunLoop.main)
      .sink(
        receiveCompletion: { error in
          print(error)
        },
        receiveValue: { })
      .store(in: &cancellables)
  }

  func fallbackBehavior() {

  }

  func refresh() {
    print("Start refresh")
    spotify.currentPlayback()
      .receive(on: RunLoop.main)
      .sink(receiveCompletion: { _ in }, receiveValue: {
        self.playbackState.isPlaying = $0?.isPlaying == true
        let item = $0?.item
        self.playbackState.songName = item?.name ?? ""
        self.playbackState.duration = Double(item?.durationMS ?? 0) / 1000
        self.playbackState.volume = Double($0?.device.volumePercent ?? 100)
        self.playbackState.itemURI = item?.uri
        self.playbackState.progress = Double($0?.progressMS ?? 0) / 1000
      })
      .store(in: &cancellables)
  }

  func play() {
    if playbackState.isAuthorized {
      spotify.resumePlayback().sink(receiveCompletion: { _ in }).store(in: &cancellables)
      playbackState.isPlaying = true

      if !isScrubbing {
        faceView?.play()
      }
    } else {
      fallbackBehavior()
    }
  }

  func pause() {
    spotify.pausePlayback().sink(receiveCompletion: { _ in }).store(in: &cancellables)
    playbackState.isPlaying = false

    if !isScrubbing {
      faceView?.pause()
    }
  }

  func stop() {
    spotify.pausePlayback().sink(receiveCompletion: { _ in }).store(in: &cancellables)
    playbackState.isPlaying = false

    if !isScrubbing {
      faceView?.stop()
    }
  }

  func togglePlayPause() {
    if isPlaying {
      pause()
    } else {
      play()
    }
  }

  private(set) var isMuted = false
  private var preMuteVolume: Double = 0.0

  func mute() {
    preMuteVolume = faceView?.volume ?? 0.0
    isMuted = true
    faceView?.volume = 0.0
    spotify.setVolume(to: 0).sink(receiveCompletion: { _ in }).store(in: &cancellables)
  }

  func unMute() {
    isMuted = false
    faceView?.volume = preMuteVolume
    spotify.setVolume(to: Int(preMuteVolume)).sink(receiveCompletion: { _ in }).store(in: &cancellables)
  }

  // MARK: - faceViewDelegate Methods

  func play(_ sender: AudionFaceView) {
    play()
  }

  func pause(_ sender: AudionFaceView) {
    pause()
  }

  func stop(_ sender: AudionFaceView) {
    stop()
  }

  func rewind(_ sender: AudionFaceView) {
    playbackState.songName = ""
    playbackState.songArtist = ""
    playbackState.songAlbum = ""
    spotify.skipToPrevious().sink(receiveCompletion: { _ in }).store(in: &cancellables)
  }

  func fastForward(_ sender: AudionFaceView) {
    playbackState.songName = ""
    playbackState.songArtist = ""
    playbackState.songAlbum = ""
    spotify.skipToNext().sink(receiveCompletion: { _ in }).store(in: &cancellables)
  }

  func volumeChanged(to volume: Double, sender: AudionFaceView) {
    if volume > 0 {
      isMuted = false
    }

    spotify.setVolume(to: Int(volume * 100)).sink(receiveCompletion: { _ in }).store(in: &cancellables)
    UserDefaults.standard.set(Float(volume * 100), forKey: AudionVolumePrefKey)
  }

  func playTimeChanged(to time: Double, sender: AudionFaceView) {
    spotify.seekToPosition(Int(time * 1000)).sink(receiveCompletion: { _ in }).store(in: &cancellables)
  }

  func pauseBeforeScrubbing(_ sender: AudionFaceView) {
    isScrubbing = true
    pause()
  }

  func playAfterScrubbing(_ sender: AudionFaceView) {
    isScrubbing = false
    play()
  }
}

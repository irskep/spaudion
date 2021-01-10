//
//  PlaybackState.swift
//  Spaudion
//
//  Created by Stephen Landey on 1/10/21.
//  Copyright © 2021 Panic. All rights reserved.
//

import Foundation
import SpotifyWebAPI
import Combine

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

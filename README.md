# Spaudion

This is a fork of [Audion](https://dev.panic.com/panic/audion) that replaces the file player with a very basic Spotify controllers. It supports pause, play, skip forward/back, and volume control. Right now it's just a one-day hack, so it probably doesn't use the Spotify API very responsibly.

The app reports its name as Avdion because I renamed the project 5 minutes before publishing this git repo. Send me a PR and fix it? 😅

To run, create `Audion/SpotifyCredentials.swift` like this:

```swift
struct SpotifyCredentials {
  static let clientId = "xyzzy"
  static let clientSecret = "updownupdownleftrightleftrightbastart"
}
```

You'll probably also need to change the development team on FaceKit.

Don't forget to `git submodule init && git pull`.

## Original README

This repository contains the source code to a lite version of Audion that can view faces on modern Macs.

### Latest Build

The latest build can be doanloaded from https://download.panic.com/audion-viewer/Audion.app.zip

### License

This code is licensed under the GPLv3, in order to prevent it from being used on the App Store.

If you wish to license it for commercial purposes, get in touch.

### Intalling Faces

This version of Audion only supports faces that had been converted to a modern format. You can download the faces from https://download.panic.com/audion-viewer. Once downloaded, unzip them, launch Audion, select `Open Faces Folder` from the `File` menu. A new empty Finder window will open. Select all the face folders and drag them into this empty window.

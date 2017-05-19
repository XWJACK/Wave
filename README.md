# Wave

![Xcode 8.3+](https://img.shields.io/badge/Xcode-8.3%2B-blue.svg)
![iOS 8.0+](https://img.shields.io/badge/iOS-8.0%2B-blue.svg)
![macOS 10.9+](https://img.shields.io/badge/macOS-10.9%2B-blue.svg)
![Swift 3.1+](https://img.shields.io/badge/Swift-3.0%2B-orange.svg)
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg)
![pod](https://img.shields.io/badge/pod-v0.1.0-brightgreen.svg)

## Overview

Simple stream audio player

## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org/) is a dependency manager for Cocoa projects.

Specify Wave into your project's Podfile:

```ruby
platform :ios, '8.0'
use_frameworks!

target '<Your App Target>' do
  pod 'Wave', :git => 'git@github.com:XWJACK/Wave.git'
end
```

Then run the following command:

```sh
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a simple, decentralized
dependency manager for Cocoa.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Wave into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "XWJACK/Wave" ~> 0.1.0
```

Run `carthage update` to build the framework and drag the built `Wave.framework` into your Xcode project.

## How to use

1. Create StreamAudioPlayer

```swift
let player = StreamAudioPlayer()
```

2. Then response data from network or local

```swift
player.response(with: data)
```

3. Set Delegate to Self

```swift
player.delegate = self
```

4. Control

```swift
player?.play()
player?.pause()
player?.stop()
player?.seek(toTime: 1024)
```

## Flow Diagram for StreamAudioPlayer

![AudioToolBox StreamAudioPlayer](http://o9omj1fgd.bkt.clouddn.com/blog/Music/images/AudioToolBox_StreamAudioPlayer.png)


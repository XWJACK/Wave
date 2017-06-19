# Wave

![Xcode 8.3+](https://img.shields.io/badge/Xcode-8.3%2B-blue.svg)
![iOS 8.0+](https://img.shields.io/badge/iOS-8.0%2B-blue.svg)
![macOS 10.9+](https://img.shields.io/badge/macOS-10.9%2B-blue.svg)
![Swift 3.0+](https://img.shields.io/badge/Swift-3.0%2B-orange.svg)
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg)
![pod](https://img.shields.io/badge/pod-v0.2.2-brightgreen.svg)

## Overview

Simple stream audio player.

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
github "XWJACK/Wave" ~> 0.2.2
```

Run `carthage update` to build the framework and drag the built `Wave.framework` into your Xcode project.

## Usage

1. Create StreamAudioPlayer

```swift
let player = StreamAudioPlayer()
```

2. Response data from network or local

```swift
player.response(with: data)
/// player will auto play when parsed audio data.
```

3. Custom set property

At least `leastPlayPackets` packets to start playing.

```swift
player?.leastPlayPackets = 100
```

4. Set Delegate to Self

```swift
player.delegate = self

    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedProgress progress: Progress) {
        DispatchQueue.main.async {
            /// Display progress.
        }
    }

    func streamAudioPlayerCompletedParsedAudioInfo(_ player: StreamAudioPlayer) {
        DispatchQueue.main.async {
            /// Audio info has been parsed that you can seek.
        }
    }
    
    func streamAudioPlayer(_ player: StreamAudioPlayer, didCompletedPlayFromTime time: TimeInterval) {
        DispatchQueue.main.async {
            /// Dismiss buffer indicator.
            /// Seek to time successful or resume play when data has been parsed.
            self.player?.play()
        }
    }
    
    func streamAudioPlayer(_ player: StreamAudioPlayer, didCompletedPlayAudio isEnd: Bool) {
        DispatchQueue.main.async {
            if isEnd {
                /// Next music
            } else {
                /// Showing buffer indicator.
            }
        }
    }
```

5. Control

```swift
player?.play()
player?.pause()
player?.stop()
/// Return true if time is already can be seek, or this time is out of range between 0 to duration.
/// Otherwise you can using delegate to listen if data is not full parsed.
player?.seek(toTime: 1024)
```

> You should not during seek by UISlider with valueChanged, you can using like this.

```swift
/// Add valueChanged target to timeSliderValueChange
timeSlider.addTarget(self, action: #selector(timeSliderValueChange(_:)), for: .valueChanged)

/// Add touchUpInside and touchUpOutside target to timeSliderSeek
timeSlider.addTarget(self, action: #selector(timeSliderSeek(_:)), for: .touchUpInside)
timeSlider.addTarget(self, action: #selector(timeSliderSeek(_:)), for: .touchUpOutside)
        
@objc fileprivate func timeSliderValueChange(_ sender: MusicPlayerSlider) {
}
    
@objc fileprivate func timeSliderSeek(_ sender: MusicPlayerSlider) {
    if player?.seek(toTime: TimeInterval(sender.value)) == true {
        player?.play()
    } else {
        /// Show buffer indicator
    }
}
```

## Flow Diagram for StreamAudioPlayer

![AudioToolBox StreamAudioPlayer](http://o9omj1fgd.bkt.clouddn.com/blog/Music/images/AudioToolBox_StreamAudioPlayer.png)

## Demo

The best demo is my graduation project: [Music](https://github.com/XWJACK/Music)

## License

Wave is released under the MIT license. [See LICENSE](https://github.com/XWJACK/Wave/blob/master/LICENSE) for details.



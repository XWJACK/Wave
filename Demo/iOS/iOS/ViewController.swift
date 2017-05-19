//
//  ViewController.swift
//  iOS
//
//  Created by Jack on 4/27/17.
//  Copyright © 2017 Jack. All rights reserved.
//

import UIKit
import Wave

class ViewController: UIViewController {

    @IBOutlet weak var indicator: UIActivityIndicatorView!
    @IBOutlet weak var slide: UISlider!
    @IBOutlet weak var switchView: UISwitch!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    var player = StreamAudioPlayer()
    var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        player?.delegate = self
        
        if let url = Bundle.main.url(forResource: "allLife", withExtension: "mp3"),
            let fileHandle = try? FileHandle(forReadingFrom: url) {
            timer = Timer(timeInterval: 1, target: self, selector: #selector(updateCurrentTime), userInfo: nil, repeats: true)
            RunLoop.main.add(timer!, forMode: .commonModes)
            player?.respond(with: fileHandle.readDataToEndOfFile())
        }
        
        slide.addTarget(self, action: #selector(seek(_:)), for: .touchUpInside)
        slide.addTarget(self, action: #selector(seek(_:)), for: .touchUpOutside)
        
    }
    
    @IBAction func seek(_ sender: UISlider) {
        guard let player = player else { return }
        print("seek to: \(sender.value)")
        player.seek(toTime: TimeInterval(sender.value))
        switchView.isOn = true
        self.switch(switchView)
    }
    
    @IBAction func `switch`(_ sender: UISwitch) {
        if sender.isOn {
            player?.play()
        } else {
            player?.pause()
        }
    }
    
    func updateCurrentTime() {
        guard let player = player else { timer?.invalidate(); return }
        currentTimeLabel.text = player.currentTime.timeFormater
        slide.value = Float(player.currentTime)
    }
}

extension ViewController: StreamAudioPlayerDelegate {
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDuration duration: TimeInterval?) {
        guard let duration = duration else { return }
        slide.maximumValue = Float(duration)
        durationLabel.text = duration.timeFormater
    }
}

extension TimeInterval {
    var timeFormater: String {
        let date = Date(timeIntervalSinceReferenceDate: self)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss"
        return dateFormatter.string(from: date)
    }
}

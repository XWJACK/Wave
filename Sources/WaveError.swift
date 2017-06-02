//
//  WaveError.swift
//  Wave
//
//  Created by Jack on 5/18/17.
//
//

import Foundation

/// Wave error
public enum WaveError: Error {
    
    public enum StreamAudioPlayerError {
        
        public enum AudioFileStreamError {
            case open(OSStatus)
            case close(OSStatus)
            case perseBytes(OSStatus)
        }
        
        public enum AudioQueueError {
            case start(OSStatus)
            case pause(OSStatus)
            case stop(OSStatus)
            
            case getCurrentTime(OSStatus)
            case newOutput(OSStatus)
            case allocateBuffer(OSStatus)
            case enqueueBuffer(OSStatus)
        }
        
        case audioFileStream(AudioFileStreamError)
        case audioQueue(AudioQueueError)
    }
    
    case streamAudioPlayer(StreamAudioPlayerError)
}

//
//  WaveError.swift
//
//  Copyright (c) 2017 Jack
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

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

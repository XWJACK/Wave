//
//  WAudioOutputQueue.swift
//  Wave
//
//  Created by Jack on 4/26/17.
//
//

import Foundation
import AudioToolbox

open class WAudioOutputQueue {
    
    open var audioQueue: AudioQueueRef? = nil
    open var audioStreamDescription: AudioStreamBasicDescription
    open var audioBuffer: WAudioBuffer
    
    open var status: OSStatus = noErr
    open var isStarted: Bool = false
    open var isRunning: Bool = false
    
    private var selfInstance: UnsafeMutableRawPointer?
    
    /// Init Audio Output Queue to play Stream Audio
    ///
    /// - Parameters:
    ///   - audioStreamDescription: AudioStreamBasicDescription
    ///   - runloop: The event loop on which the callback function pointed to by the inCallbackProc parameter is to be called. 
    ///              If you specify NULL, the callback is invoked on one of the audio queue’s internal threads.
    ///   - runloopModel: The run loop mode in which to invoke the callback function specified in the inCallbackProc parameter. 
    ///                   Typically, you pass kCFRunLoopCommonModes or use nil, which is equivalent. 
    ///                   You can choose to create your own thread with your own run loops.
    public init?(audioStreamDescription: AudioStreamBasicDescription = AudioStreamBasicDescription(),
                 runloop: CFRunLoop? = nil,
                 runloopModel: CFString? = nil,
                 audioBuffer: WAudioBuffer = .default) {
        
        self.audioStreamDescription = audioStreamDescription
        self.audioBuffer = audioBuffer
        
        selfInstance = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        
        /// Create new output queue
        status = AudioQueueNewOutput(&self.audioStreamDescription,
                                     AudioQueueOutputCallback,
                                     selfInstance,
                                     runloop,
                                     runloopModel,
                                     0,
                                     &audioQueue)
        if status != noErr { return nil }
        
        /// Create listener when property is change
        status = AudioQueueAddPropertyListener(audioQueue!,
                                               kAudioQueueProperty_IsRunning,
                                               AudioQueuePropertyListenerProc,
                                               selfInstance)
        if status != noErr { return nil }
        
        /// Allocate buffer for audio queue
        status = audioBuffer.allocate(forAudioQueue: audioQueue!)
        
        if status != noErr { return nil }
    }
    
//    @available(iOS 10.0, *)
//    public init(audioStreamDescription: AudioStreamBasicDescription = AudioStreamBasicDescription(),
//                dispatchQueue: DispatchQueue = .main) {
//        AudioQueueNewOutputWithDispatchQueue(&audioQueue,
//                                             &self.audioStreamDescription,
//                                             0,
//                                             dispatchQueue,
//                                             AudioQueueOutputCallback)
//        
//    }
    
    deinit {
        if let audioQueue = audioQueue {
            AudioQueueDispose(audioQueue, true)
        }
    }
    
    @discardableResult
    open func start() -> Bool {
        guard let audioQueue = audioQueue else { return false }
        status = AudioQueueStart(audioQueue, nil)
        isStarted = status == noErr
        return isStarted
    }
    
    @discardableResult
    open func pause() -> Bool {
        guard let audioQueue = audioQueue else { return false }
        status = AudioQueuePause(audioQueue)
        isStarted = false
        return status == noErr
    }
    
    @discardableResult
    open func stop(immediate: Bool = true) -> Bool {
        guard let audioQueue = audioQueue else { return false }
        status = AudioQueueStop(audioQueue, immediate)
        isStarted = false
        return status == noErr
    }
    
    @discardableResult
    open func flush() -> Bool {
        guard let audioQueue = audioQueue else { return false }
        status = AudioQueueFlush(audioQueue)
        return status == noErr
    }
    
    @discardableResult
    open func reset() -> Bool {
        guard let audioQueue = audioQueue else { return false }
        status = AudioQueueReset(audioQueue)
        return status == noErr
    }
    
    @discardableResult
    open func filling(data: Data) -> Bool {
        guard UInt32(data.count) > audioBuffer.bufferByteSize else { return false }
        return status == noErr
    }
}

private func AudioQueueOutputCallback(inUserData: UnsafeMutableRawPointer?,
                                      inAQ: AudioQueueRef,
                                      inBuffer: AudioQueueBufferRef) {
    let mySelf: WAudioBuffer = converInstance(by: inUserData!)
}

private func AudioQueuePropertyListenerProc(inUserData: UnsafeMutableRawPointer?,
                                            inAQ: AudioQueueRef,
                                            inID: AudioQueuePropertyID) {
    guard inID == kAudioQueueProperty_IsRunning else { return }
    let mySelf: WAudioOutputQueue = converInstance(by: inUserData!)
    
    var dataSize: UInt32 = 0
    var running: UInt32 = 0
    mySelf.status = AudioQueueGetPropertySize(inAQ, inID, &dataSize)
    mySelf.status = AudioQueueGetProperty(inAQ, inID, &running, &dataSize)
    mySelf.isRunning = running != 0
}

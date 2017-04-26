//
//  WAudioBuffer.swift
//  Wave
//
//  Created by Jack on 4/26/17.
//
//

import Foundation
import AudioToolbox

open class WAudioBuffer {
    
    open let bufferContainerCount: Int
    open let bufferByteSize: UInt32
    open var reuseBuffer: [AudioQueueBufferRef?] = []
    open var status: OSStatus = noErr
    
    open static var `default`: WAudioBuffer { return WAudioBuffer() }
    
    public init(bufferContainerCount: Int = 2,
                bufferByteSize: UInt32 = 1024_00) {
        self.bufferContainerCount = bufferContainerCount
        self.bufferByteSize = bufferByteSize
    }
    
    /// Allocate buffer for audio queue
    ///
    /// - Parameter audioQueue: AudioQueueRef
    /// - Returns: Status
    @discardableResult
    open func allocate(forAudioQueue audioQueue: AudioQueueRef) -> OSStatus {
        var buffer: AudioQueueBufferRef? = nil
        status = AudioQueueAllocateBuffer(audioQueue, bufferByteSize, &buffer)
        if status == noErr { reuseBuffer.append(buffer) }
        return status
    }
}

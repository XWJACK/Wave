//
//  StreamAudioPlayer.swift
//  AudioPlayer
//
//  Created by Jack on 4/19/17.
//  Copyright © 2017 Jack. All rights reserved.
//

import Foundation
import AudioToolbox

public enum StreamAudioQueueStatus {
    case playing
    case paused
    case stop
}

/// Conver instance to self
///
/// - Parameter pointee: Instance
/// - Returns: Self
func converInstance<T: AnyObject>(by pointee: UnsafeMutableRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(pointee).takeUnretainedValue()
}

// MARK: - Extension OSStatus to check is success
extension OSStatus {
    var isSuccess: Bool { return self == noErr }
}

/// Stream audio player delegate
public protocol StreamAudioPlayerDelegate: class {
    
    /// Ask when parsed duration
    ///
    /// - Parameters:
    ///   - player: StreamAudioPlayer
    ///   - duration: Total duration, this duration is optional value, nil if not parased bitRate. You can assigned bitRate before parse audio.
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDuration duration: TimeInterval?)
    
    /// Ask when parsed packet count, you can assigned `packetPerLoad` in this.
    ///
    /// - Parameters:
    ///   - player: StreamAuidoPlayer
    ///   - dataPacketCount: Total packet count
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDataPacketCount dataPacketCount: UInt64)
    
    /// Ask parsed progress only effective if parsed `dataPacketCount`
    ///
    /// - Parameters:
    ///   - player: StreamAudioPlayer
    ///   - progress: Progress for parse audio data
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedProgress progress: Progress)
    
    /// Ask seek to time success
    ///
    /// - Parameters:
    ///   - player: StreamAudioPlayer
    ///   - time: Play from time, contain seek
    func streamAudioPlayer(_ player: StreamAudioPlayer, didCompletedPlayFromTime time: TimeInterval)
    
    /// Ask completed parsed audio infomation
    ///
    /// - Parameter player: StreamAudioPlayer
    func streamAudioPlayerCompletedParsedAudioInfo(_ player: StreamAudioPlayer)
    
    /// Ask completed play audio
    ///
    /// - Parameters:
    ///   - player: StreamAudioPlayer
    ///   - isEnd: Is end to audio file,
    ///            true: End of audio file
    ///            false: Have no audio file can be play.
    func streamAudioPlayer(_ player: StreamAudioPlayer, didCompletedPlayAudio isEnd: Bool)
    
    /// Ask when Queue status change
    ///
    /// - Parameters:
    ///   - player: StreamAudioPlayer
    ///   - status: StreamAudioQueueStatus
    //    func streamAudioPlayer(_ player: StreamAudioPlayer, queueStatusChange status: StreamAudioQueueStatus)
    
    /// Ask
    ///
    /// - Parameters:
    ///   - player: StreamAudioPlayer
    ///   - anErrorOccur: WaveError
    func streamAudioPlayer(_ player: StreamAudioPlayer, anErrorOccur error: WaveError)
}

// MARK: - Extension with default
public extension StreamAudioPlayerDelegate {
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDuration duration: TimeInterval?){}
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDataPacketCount dataPacketCount: UInt64) {}
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedProgress progress: Progress){}
    func streamAudioPlayer(_ player: StreamAudioPlayer, didCompletedPlayFromTime time: TimeInterval){}
    func streamAudioPlayerCompletedParsedAudioInfo(_ player: StreamAudioPlayer){}
    //    func streamAudioPlayer(_ player: StreamAudioPlayer, queueStatusChange status: StreamAudioQueueStatus){}
    func streamAudioPlayer(_ player: StreamAudioPlayer, anErrorOccur error: WaveError){}
    func streamAudioPlayer(_ player: StreamAudioPlayer, didCompletedPlayAudio isEnd: Bool){}
}

/// Stream audio player
open class StreamAudioPlayer {
    
    //MARK: - public property
    
    /// Stream audio player delegate
    open weak var delegate: StreamAudioPlayerDelegate?
    /// Least packets for play audio
    open var leastPlayPackets: Int = 50
    /// Audio bit rate
    public private(set) var bitRate: UInt32 = 0
    /// Number of audio data bytes
    public private(set) var dataByteCount: UInt64 = 0
    /// Number of audio data packets
    public private(set) var dataPacketCount: UInt64 = 0
    /// Duration
    public private(set) var duration: TimeInterval = 0
    /// Current time
    public var currentTime: TimeInterval { return playedTime() + timeOffset }
    /// Audio queue is running
    public private(set) var isRunning: Bool = false
    
    //MARK: - private property
    
    /// Current packet offset
    private var currentOffset: Int = 0
    /// Time offset
    private var timeOffset: TimeInterval = 0
    /// Audio file Stream identifier, define union audio file stream
    private var audioFileStreamID: AudioFileStreamID? = nil
    /// Audio file stream description for audio
    private var audioStreamDescription: AudioStreamBasicDescription = AudioStreamBasicDescription()
    /// Audio queue refrence
    private var audioQueue: AudioQueueRef? = nil
    /// All packets for audio
    private var packets: [Data] = []
    /// Status code
    private var status: OSStatus = noErr
    /// Self instance
    private var selfInstance: UnsafeMutableRawPointer? = nil
    /// Is first playing audio
    private var isFirstPlaying: Bool = true
    /// Temp offSet for seek or pause because of no audio data
    private var tempOffset: Int? = 0
    
    /// Init stream audio player
    ///
    /// - Parameter type: AudioFileTypeID, default is mp3 type.
    public init?(_ type: AudioFileTypeID = kAudioFileMP3Type) {
        
        selfInstance = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        
        /// Create and open an audio file stream
        status = AudioFileStreamOpen(selfInstance, { (inClientData, inAudioFileStream, inPropertyID, ioFlags) in
            /// Call back for parse audio info.
            
            let mySelf: StreamAudioPlayer = converInstance(by: inClientData)
            /// Property size
            var propertySize: UInt32 = 0
            /// On output, true if the property can be written. Currently, there are no writable audio file stream properties.
            /// (I have no idea about this property.)
            var writable: DarwinBoolean = false
            
            /// Get property size
            AudioFileStreamGetPropertyInfo(inAudioFileStream, inPropertyID, &propertySize, &writable)
            
            switch inPropertyID {
            case kAudioFileStreamProperty_BitRate:/// (128000,320000,....)
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.bitRate)
                
            case kAudioFileStreamProperty_AudioDataByteCount:
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.dataByteCount)
                
            case kAudioFileStreamProperty_AudioDataPacketCount:
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.dataPacketCount)
                
                /// Assigned `packets` capacity to keep `append` thread-safe
                mySelf.packets.reserveCapacity(Int(mySelf.dataPacketCount))
                mySelf.delegate?.streamAudioPlayer(mySelf, parsedDataPacketCount: mySelf.dataPacketCount)
                
            case kAudioFileStreamProperty_DataFormat:
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.audioStreamDescription)
                
            case kAudioFileStreamProperty_ReadyToProducePackets: /// Completed perase audio infomation
                if mySelf.bitRate > 0 {
                    /// Calculate duration
                    mySelf.duration = (Double(mySelf.dataByteCount) * 8 ) / Double(mySelf.bitRate)
                    mySelf.delegate?.streamAudioPlayer(mySelf, parsedDuration: mySelf.duration)
                } else {
                    mySelf.delegate?.streamAudioPlayer(mySelf, parsedDuration: nil)
                }
                
                mySelf.delegate?.streamAudioPlayerCompletedParsedAudioInfo(mySelf)
                
                mySelf.createAudioQueue()
                
            default: break
            }
        }, { (inClientData, inNumberBytes, inNumberPackets, inInputData, inPacketDescriptions) in
            
            guard inNumberBytes != 0 && inNumberPackets != 0 else { return }
            let mySelf: StreamAudioPlayer = converInstance(by: inClientData)
            
            /// Save packet
            for i in 0..<Int(inNumberPackets) {
                let paketOffset = inPacketDescriptions[i].mStartOffset
                let paketSize = inPacketDescriptions[i].mDataByteSize
                let packetData = NSData(bytes: inInputData.advanced(by: Int(paketOffset)), length: Int(paketSize)) as Data
                mySelf.packets.append(packetData)//(packetData, inPacketDescriptions.pointee))
                //如果这里去保存每一帧的信息，其中mStartOffset都是0，但是在队列中播放的时候是连续的帧偏移。
            }
            
            if mySelf.dataPacketCount > 0 {
                let progress = Progress(totalUnitCount: Int64(mySelf.dataPacketCount))
                progress.completedUnitCount = Int64(mySelf.packets.count)
                mySelf.delegate?.streamAudioPlayer(mySelf, parsedProgress: progress)
            }
            
            if let offSet = mySelf.tempOffset,
                offSet <= mySelf.packets.count + mySelf.leastPlayPackets {
                mySelf.tempOffset = nil
                mySelf.delegate?.streamAudioPlayer(mySelf, didCompletedPlayFromTime: Double(offSet) * mySelf.duration / Double(mySelf.dataPacketCount))
            }
            
        }, type, &audioFileStreamID)
        
        if !status.isSuccess {
            delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioFileStream(.open(status))))
            return nil
        }
    }
    
    deinit {
        selfInstance = nil
        if let audioFileStreamID = audioFileStreamID {
            status = AudioFileStreamClose(audioFileStreamID)
            if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioFileStream(.close(status)))) }
        }
        if let audioQueue = audioQueue {
            AudioQueueDispose(audioQueue, true)
        }
    }
    
    //MARK: - Control
    
    /// Play or resume play from last
    open func play() {
        guard let audioQueue = audioQueue, !isRunning else { return }
        isRunning = true
        if isFirstPlaying {/// Need to enter packets to audio queue when first play
            isFirstPlaying = false
            enAudioQueue()
        }
        status = AudioQueueStart(audioQueue, nil)
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.start(status)))) }
    }
    
    /// Pause
    open func pause() {
        guard let audioQueue = audioQueue, isRunning else { return }
        isRunning = false
        status = AudioQueuePause(audioQueue)
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.pause(status)))) }
    }
    
    /// Stop
    open func stop() {
        guard let audioQueue = audioQueue else { return }
        isRunning = false
        isFirstPlaying = true
        timeOffset = 0
        currentOffset = 0
        status = AudioQueueStop(audioQueue, true)
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.stop(status)))) }
    }
    
    /// Seek to time
    ///
    /// - Parameter time: TimeInterval
    /// - Returns: Is success
    @discardableResult
    open func seek(toTime time: TimeInterval) -> Bool {
        stop()
        
        currentOffset = Int(Double(dataPacketCount) * time / duration)
        timeOffset = time - playedTime()
        
        if currentOffset > packets.count {
            tempOffset = currentOffset
            return false
        }
        
        delegate?.streamAudioPlayer(self, didCompletedPlayFromTime: time)
        return true
    }
    
    //    open func reset() {
    //        guard let audioQueue = audioQueue else { return }
    //        status = AudioQueueReset(audioQueue)
    //        assert(noErr == status)
    //    }
    
    //MARK: - public function
    
    /// Response audio data
    ///
    /// - Parameter data: Data
    open func respond(with data: Data) {
        parse(data: data)
    }
    
    /// AudioQueue has been running time, not current play time
    ///
    /// - Returns: TimeInterval
    public final func playedTime() -> TimeInterval {
        guard let audioQueue = audioQueue,
            audioStreamDescription.mSampleRate != 0 else { return 0 }
        
        var time: AudioTimeStamp = AudioTimeStamp()
        /// 这里获取的是播放时间， 第一个需要注意的时这个播放时间是指实际播放的时间和一般理解上的播放进度是有区别的。
        /// 举个例子，开始播放8秒后用户操作slider把播放进度seek到了第20秒之后又播放了3秒钟，此时通常意义上播放时间应该是23秒，即播放进度；
        /// 而用GetCurrentTime方法中获得的时间为11秒，即实际播放时间。所以每次seek时都必须保存seek的timingOffset：
        status = AudioQueueGetCurrentTime(audioQueue, nil, &time, nil)
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.getCurrentTime(status)))) }
        return status.isSuccess ? time.mSampleTime / audioStreamDescription.mSampleRate : 0
    }
    
    //MARK: - private function
    
    /// Create new output audio queue
    private func createAudioQueue() {
        /// New output audio queue
        status = AudioQueueNewOutput(&audioStreamDescription, { (inUserData, inAQ, inBuffer) in
            /// 每次播放器需要播放音频数据的时候就会调用，一般这个时候inBuffer已经播放完成了，可以从队列中移除了。
            /// 这里采用没次都创建一定capacity的Buffer
            
            let mySelf: StreamAudioPlayer = converInstance(by: inUserData!)
            guard !mySelf.isFirstPlaying else { return }
            /// Free aleardy played buffer, it can been reused.
            AudioQueueFreeBuffer(inAQ, inBuffer)
            
            mySelf.enAudioQueue()
        }, selfInstance, nil, nil, 0, &audioQueue)/// The event loop on which the callback function pointed to by the inCallbackProc parameter is to be called. If you specify NULL, the callback is invoked on one of the audio queue’s internal threads.
        
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.newOutput(status)))) }
        
        /// Add listent property
        //        status = AudioQueueAddPropertyListener(audioQueue!, kAudioQueueProperty_IsRunning, { (inUserData, inAQ, inID) in
        //            ///控制播放器的状态
        //            let mySelf: StreamAudioPlayer = converInstance(by: inUserData!)
        //
        //            var dataSize: UInt32 = 0
        //            var running: UInt32 = 0
        //            mySelf.status = AudioQueueGetPropertySize(inAQ, inID, &dataSize)
        //            mySelf.status = AudioQueueGetProperty(inAQ, inID, &running, &dataSize)
        //            mySelf.delegate?.streamAudioPlayer(mySelf, queueStatusChange: running != 0)
        //        }, selfInstance)
        //
        //        assert(noErr == status)
        
        //        /// 解析音频数据 - 解析所有进入队列的数据 -（实际解析多少数据）--------默认解析
        //        status = AudioQueuePrime(audioQueue!, 0, nil)
        //        assert(noErr == status)
    }
    
    /// Enter buffer into audio queue
    private func enAudioQueue() {
        
        guard currentOffset < packets.count else {
            /// All audio datas were play completed
            if UInt64(currentOffset) >= dataPacketCount { delegate?.streamAudioPlayer(self, didCompletedPlayAudio: true) }
                /// Waitting for data to resume play
            else {
                tempOffset = currentOffset
                isFirstPlaying = true
                delegate?.streamAudioPlayer(self, didCompletedPlayAudio: false)
            }
            return
        }
        
        let endOffset = packets.count
        
        /// New buffer
        var newAudioQueueBuffer: AudioQueueBufferRef? = nil
        /// How many data need to enter queue
        var inQueueDatas: ArraySlice<Data> = packets[currentOffset..<endOffset]
        var inQueueDescriptions: [AudioStreamPacketDescription] = []
        /// Total data size
        let totalSize = inQueueDatas.reduce(0, { $0 + $1.count })
        
        /// Allocate buffer
        status = AudioQueueAllocateBuffer(audioQueue!,
                                          UInt32(totalSize),
                                          &newAudioQueueBuffer)
        
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.allocateBuffer(status)))) }
        
        
        newAudioQueueBuffer?.pointee.mAudioDataByteSize = UInt32(totalSize)
        newAudioQueueBuffer?.pointee.mUserData = selfInstance
        
        var copiedSize = 0
        for i in currentOffset..<endOffset {
            let packetData = inQueueDatas[i]
            /// Copy data to buffer
            memcpy(newAudioQueueBuffer?.pointee.mAudioData.advanced(by: copiedSize),
                   (packetData as NSData).bytes,
                   packetData.count)
            let description = AudioStreamPacketDescription(mStartOffset: Int64(copiedSize),
                                                           mVariableFramesInPacket: 0,
                                                           mDataByteSize: UInt32(packetData.count))
            inQueueDescriptions.append(description)
            copiedSize += packetData.count
        }
        
        /// Enter buffer to audio queue
        status = AudioQueueEnqueueBuffer(audioQueue!,
                                         newAudioQueueBuffer!,
                                         UInt32(inQueueDescriptions.count),
                                         inQueueDescriptions)
        //TODO: 持续移动的时候会报 kAudioQueueErr_EnqueueDuringReset❌，暂时不知道如何处理
        
        
        currentOffset = endOffset
        
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.enqueueBuffer(status)))) }
    }
    
    /// Parse audio
    ///
    /// - Parameter data: Data
    private func parse(data: Data) {
        /// Tell audio file stream to parse data.
        status = AudioFileStreamParseBytes(audioFileStreamID!,
                                           UInt32(data.count),
                                           (data as NSData).bytes,
                                           AudioFileStreamParseFlags(rawValue: 0))//.discontinuity
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioFileStream(.perseBytes(status)))) }
    }
}

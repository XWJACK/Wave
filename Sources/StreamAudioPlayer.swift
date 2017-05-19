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
    ///   - time: seek to time
    func streamAudioPlayer(_ player: StreamAudioPlayer, didCompletedSeekToTime time: TimeInterval)
    
    /// Ask completed parsed audio infomation
    ///
    /// - Parameter player: StreamAudioPlayer
    func streamAudioPlayerCompletedParsedAudioInfo(_ player: StreamAudioPlayer)
    
    /// Ask when Queue status change
    ///
    /// - Parameters:
    ///   - player: StreamAudioPlayer
    ///   - status: StreamAudioQueueStatus
    func streamAudioPlayer(_ player: StreamAudioPlayer, queueStatusChange status: StreamAudioQueueStatus)
    
    /// Ask
    ///
    /// - Parameters:
    ///   - player: StreamAudioPlayer
    ///   - anErrorOccur: WaveError
    func streamAudioPlayer(_ player: StreamAudioPlayer, anErrorOccur error: WaveError)
}

public extension StreamAudioPlayerDelegate {
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDuration duration: TimeInterval?){}
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDataPacketCount dataPacketCount: UInt64) {}
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedProgress progress: Progress){
        if progress.fractionCompleted > 0.001 { player.play() }
    }
    func streamAudioPlayer(_ player: StreamAudioPlayer, didCompletedSeekToTime time: TimeInterval){}
    func streamAudioPlayerCompletedParsedAudioInfo(_ player: StreamAudioPlayer){}
    func streamAudioPlayer(_ player: StreamAudioPlayer, queueStatusChange status: StreamAudioQueueStatus){}
    func streamAudioPlayer(_ player: StreamAudioPlayer, anErrorOccur error: WaveError){}
}

open class StreamAudioPlayer {
    
    open weak var delegate: StreamAudioPlayerDelegate?
    /// 每次载入多少帧的数据
    open var packetPerLoad: Int = 500
    /// 音频的码率
    public private(set) var bitRate: UInt32 = 0
    /// 音频数据总量
    public private(set) var dataByteCount: UInt64 = 0
    /// 音频帧总量
    public private(set) var dataPacketCount: UInt64 = 0
    /// 总时长
    public private(set) var duration: TimeInterval = 0
    /// 当前播放的时间
    public var currentTime: TimeInterval { return playedTime() + timeOffset }
    /// 音频队列是否在运行
    public private(set) var isRunning: Bool = false
    
    /// 当前帧偏移量
    private var currentOffset: Int = 0
    /// 时间偏移量
    private var timeOffset: TimeInterval = 0
    /// 音频流处理器ID
    private var audioFileStreamID: AudioFileStreamID? = nil
    /// 音频文件信息
    private var audioStreamDescription: AudioStreamBasicDescription = AudioStreamBasicDescription()
    /// 音频队列
    private var audioQueue: AudioQueueRef? = nil
    /// 所有的帧
    private var packets: [Data] = []//[(packet: Data, description: AudioStreamPacketDescription)] = []
    /// 返回码
    private var status: OSStatus = noErr
    /// 自身实例
    private var selfInstance: UnsafeMutableRawPointer? = nil
    /// 是否是第一次播放
    private var isFirstPlaying: Bool = true
    /// seek 到哪一帧
    private var seekToTime: TimeInterval?
    
    public init?(_ type: AudioFileTypeID = kAudioFileMP3Type) {
        
        selfInstance = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        
        /// 创建并打开一个音频文件流处理对象：
        /// 成功：得到音频流处理器ID
        status = AudioFileStreamOpen(selfInstance, { (inClientData, inAudioFileStream, inPropertyID, ioFlags) in
            /// 歌曲信息解析的回调
            
            let mySelf: StreamAudioPlayer = converInstance(by: inClientData)
            /// 属性大小
            var propertySize: UInt32 = 0
            /// On output, true if the property can be written. Currently, there are no writable audio file stream properties.（暂时不知道什么意思）
            var writable: DarwinBoolean = false
            
            /// 获取属性大小
            AudioFileStreamGetPropertyInfo(inAudioFileStream, inPropertyID, &propertySize, &writable)
            
            switch inPropertyID {
            case kAudioFileStreamProperty_BitRate:// 解析到码率：常用有(128000,320000)
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.bitRate)
                
            case kAudioFileStreamProperty_AudioDataByteCount: //解析到音频文件中音频数据的总量
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.dataByteCount)
                
            case kAudioFileStreamProperty_AudioDataPacketCount: //解析到音频文件中帧数量
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.dataPacketCount)
                
                /// Assigned `packets` capacity to keep `append` thread-safe
                mySelf.packets.reserveCapacity(Int(mySelf.dataPacketCount))
                mySelf.delegate?.streamAudioPlayer(mySelf, parsedDataPacketCount: mySelf.dataPacketCount)
            case kAudioFileStreamProperty_DataFormat: //解析到音频文件结构信息
                
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.audioStreamDescription)
                
            case kAudioFileStreamProperty_ReadyToProducePackets: //解析属性完成，接下来进行帧分离
                
                //                if mySelf.bitRate <= 0 {
                //                    mySelf.delegate?.streamAudioPlayer(mySelf, parsedDuration: nil)
                //                } else {
                /// 计算总时长
                mySelf.duration = (Double(mySelf.dataByteCount) * 8 ) / Double(mySelf.bitRate)
                mySelf.delegate?.streamAudioPlayer(mySelf, parsedDuration: mySelf.duration)
                //                }
                
                mySelf.delegate?.streamAudioPlayerCompletedParsedAudioInfo(mySelf)
                
                /// Need to keep create audio queue in main thread.
                DispatchQueue.main.async {
                    mySelf.createAudioQueue()
                }
            default: break
            }
        }, { (inClientData, inNumberBytes, inNumberPackets, inInputData, inPacketDescriptions) in
            
            /// 分离帧的回调
            
            guard inNumberBytes != 0 && inNumberPackets != 0 else { return }
            let mySelf: StreamAudioPlayer = converInstance(by: inClientData)
            
            /// 手动分离的帧，并将帧保存起来，用于播放
            for i in 0..<Int(inNumberPackets) {
                let paketOffset = inPacketDescriptions[i].mStartOffset
                let paketSize = inPacketDescriptions[i].mDataByteSize
                let packetData = NSData(bytes: inInputData.advanced(by: Int(paketOffset)), length: Int(paketSize)) as Data
                mySelf.packets.append(packetData)//(packetData, inPacketDescriptions.pointee))//如果这里去保存每一帧的信息，其中mStartOffset都是0，但是在队列中播放的时候是连续的帧偏移。
            }
            
            if mySelf.dataPacketCount > 0 {
                let progress = Progress(totalUnitCount: Int64(mySelf.dataPacketCount))
                progress.completedUnitCount = Int64(mySelf.packets.count)
                mySelf.delegate?.streamAudioPlayer(mySelf, parsedProgress: progress)
            }
            
            if let time = mySelf.seekToTime,
                time * Double(mySelf.dataPacketCount) < mySelf.duration * Double(mySelf.packets.count) {
                mySelf.seekToTime = nil
                mySelf.delegate?.streamAudioPlayer(mySelf, didCompletedSeekToTime: time)
            }
        }, type, &audioFileStreamID)
        
        if !status.isSuccess {
            delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioFileStream(.open(status))))
            return nil
        }
    }
    
    open func play() {
        guard let audioQueue = audioQueue, !isRunning else { return }
        isRunning = true
        if isFirstPlaying {/// 第一次播放的时候队列中没有数据，需要将数据压入队列中。
            isFirstPlaying = false
            enAudioQueue()
        }
        status = AudioQueueStart(audioQueue, nil)
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.start(status)))) }
    }
    
    open func pause() {
        guard let audioQueue = audioQueue, isRunning else { return }
        isRunning = false
        status = AudioQueuePause(audioQueue)
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.pause(status)))) }
    }
    
    open func stop() {
        guard let audioQueue = audioQueue, isRunning else { return }
        isRunning = false
        isFirstPlaying = true
        timeOffset = 0
        currentOffset = 0
        status = AudioQueueStop(audioQueue, true)
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.stop(status)))) }
    }
    
    @discardableResult
    open func seek(toTime time: TimeInterval) -> Bool {
        stop()
        
        currentOffset = Int(Double(dataPacketCount) * time / duration)
        timeOffset = time - playedTime()
        
        if currentOffset > packets.count {
            seekToTime = time
            return false
        }
        
        delegate?.streamAudioPlayer(self, didCompletedSeekToTime: time)
        return true
    }
    
    //    open func reset() {
    //        guard let audioQueue = audioQueue else { return }
    //        status = AudioQueueReset(audioQueue)
    //        assert(noErr == status)
    //    }
    
    open func respond(with data: Data) {
        parse(data: data)
    }
    
    deinit {
        selfInstance = nil
        if let audioFileStreamID = audioFileStreamID {
            status = AudioFileStreamClose(audioFileStreamID)
            if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioFileStream(.close(status)))) }
        }
    }
    
    /// 播放的总时间
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
    
    private func createAudioQueue() {
        
        /// 新建音频输出队列
        status = AudioQueueNewOutput(&audioStreamDescription, { (inUserData, inAQ, inBuffer) in
            /// 每次播放器需要播放音频数据的时候就会调用，一般这个时候inBuffer已经播放完成了，可以从队列中移除了。
            /// 这里采用没次都创建一定capacity的Buffer
            
            let mySelf: StreamAudioPlayer = converInstance(by: inUserData!)
            guard !mySelf.isFirstPlaying else { return }
            /// 清除队列中已经播放完成的缓存
            AudioQueueFreeBuffer(inAQ, inBuffer)
            
            mySelf.enAudioQueue()
        }, selfInstance, CFRunLoopGetMain(), nil, 0, &audioQueue)
        
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.newOutput(status)))) }
        
        /// 添加属性监听事件 - 是否正在运行
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
    
    private func enAudioQueue() {
        /// 填充音频数据到队列中
        guard currentOffset < packets.count else { return }//播放队列中没有数据可以播放（可能数据断了，还没有过来，或者数据已经全部播放完成）
        var endOffset = currentOffset + packetPerLoad
        if endOffset >= packets.count { endOffset = packets.count }
        
        
        /// 创建新的Buffer
        var newAudioQueueBuffer: AudioQueueBufferRef? = nil
        /// ⚠️这里的类型是ArraySlice
        var inQueueDatas: ArraySlice<Data> = packets[currentOffset..<endOffset]
        var inQueueDescriptions: [AudioStreamPacketDescription] = []
        /// 进入队列中总数据大小
        let totalSize = inQueueDatas.reduce(0, { $0 + $1.count })
        
        /// 分配空间
        status = AudioQueueAllocateBuffer(audioQueue!,
                                          UInt32(totalSize),
                                          &newAudioQueueBuffer)
        
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.allocateBuffer(status)))) }
        
        
        newAudioQueueBuffer?.pointee.mAudioDataByteSize = UInt32(totalSize)
        newAudioQueueBuffer?.pointee.mUserData = selfInstance
        
        var copiedSize = 0
        for i in currentOffset..<endOffset {
            let packetData = inQueueDatas[i]
            /// 填充音频数据
            memcpy(newAudioQueueBuffer?.pointee.mAudioData.advanced(by: copiedSize),
                   (packetData as NSData).bytes,
                   packetData.count)
            let description = AudioStreamPacketDescription(mStartOffset: Int64(copiedSize),
                                                           mVariableFramesInPacket: 0,
                                                           mDataByteSize: UInt32(packetData.count))
            inQueueDescriptions.append(description)
            copiedSize += packetData.count
        }
        
        /// 将音频加入到队列
        status = AudioQueueEnqueueBuffer(audioQueue!,
                                         newAudioQueueBuffer!,
                                         UInt32(inQueueDescriptions.count),
                                         inQueueDescriptions)
        //TODO: 持续移动的时候会报 kAudioQueueErr_EnqueueDuringReset❌，暂时不知道如何处理
        
        
        currentOffset = endOffset
        
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioQueue(.enqueueBuffer(status)))) }
    }
    
    private func parse(data: Data) {
        /// 向指定的流处理器中添加需要解析的数据
        status = AudioFileStreamParseBytes(audioFileStreamID!,
                                           UInt32(data.count),
                                           (data as NSData).bytes,
                                           AudioFileStreamParseFlags(rawValue: 0))//.discontinuity
        if !status.isSuccess { delegate?.streamAudioPlayer(self, anErrorOccur: .streamAudioPlayer(.audioFileStream(.perseBytes(status)))) }
    }
}

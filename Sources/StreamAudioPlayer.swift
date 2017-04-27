//
//  StreamAudioPlayer.swift
//  AudioPlayer
//
//  Created by Jack on 4/19/17.
//  Copyright © 2017 Jack. All rights reserved.
//

import Foundation
import AudioToolbox

public protocol StreamAudioPlayerDelegate: class {
    /// 成功解析到总时长
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDuration duration: TimeInterval)
    /// 成功解析到帧总量，可以在这个回调中设置`packetPerLoad`
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDataPacketCount dataPacketCount: UInt64)
}

public extension StreamAudioPlayerDelegate {
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDuration duration: TimeInterval) {}
    func streamAudioPlayer(_ player: StreamAudioPlayer, parsedDataPacketCount dataPacketCount: UInt64) {}
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
    public var currentTime: TimeInterval {
        guard let audioQueue = audioQueue,
            audioStreamDescription.mSampleRate != 0 else { return 0 }
        
        var time: AudioTimeStamp = AudioTimeStamp()
        /// 这里获取的是播放时间
        status = AudioQueueGetCurrentTime(audioQueue, nil, &time, nil)
        guard status == noErr else { return 0 }
        return time.mSampleTime / audioStreamDescription.mSampleRate
    }
    /// 队列是否在运行
    public private(set) var isRunning: Bool = false
    
    /// 当前帧偏移量
    private var currentOffset: Int = 0
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
            case kAudioFileStreamProperty_BitRate:// 解析到码率
                
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.bitRate)
                
            case kAudioFileStreamProperty_AudioDataByteCount: //解析到音频文件中音频数据的总量
                
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.dataByteCount)
                
            case kAudioFileStreamProperty_AudioDataPacketCount: //解析到音频文件中帧数量
                
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.dataPacketCount)
                
                /// 在这里设置数组的Capacity来保证线程安全
                mySelf.packets.reserveCapacity(Int(mySelf.dataPacketCount))
                mySelf.delegate?.streamAudioPlayer(mySelf, parsedDataPacketCount: mySelf.dataPacketCount)
            case kAudioFileStreamProperty_DataFormat: //解析到音频文件结构信息
                
                AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &propertySize, &mySelf.audioStreamDescription)
                /// 主线中创建音频队列
                // TODO: 不知道是否的确需要。
                DispatchQueue.main.async {
                    mySelf.createAudioQueue()
                }
                
            case kAudioFileStreamProperty_ReadyToProducePackets: //解析属性完成，接下来进行帧分离
                
                /// 计算总时长
                mySelf.duration = (Double(mySelf.dataByteCount) * 8 ) / Double(mySelf.bitRate)
                mySelf.delegate?.streamAudioPlayer(mySelf, parsedDuration: mySelf.duration)
                
                return
            default: return
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
            
        }, type, &audioFileStreamID)
        
        assert(noErr == status)
        if status != noErr { return nil }
        //        if status != noErr { throw AudioPlayerError.streamAudioPlayerError(.AudioFileStreamOpenError(status)) }
    }
    
    open func play() {
        guard let audioQueue = audioQueue else { return }
        if isFirstPlaying {/// 第一次播放的时候队列中没有数据，需要将数据压入队列中。
            enAudioQueue()
            isFirstPlaying = false
        }
        status = AudioQueueStart(audioQueue, nil)
        assert(noErr == status)
    }
    
    open func pause() {
        guard let audioQueue = audioQueue else { return }
        status = AudioQueuePause(audioQueue)
        assert(noErr == status)
    }
    
    open func stop() {
        guard let audioQueue = audioQueue else { return }
        status = AudioQueueStop(audioQueue, true)
        assert(noErr == status)
    }
    
    open func respond(with data: Data) {
        parse(data: data)
    }
    
    deinit {
        selfInstance = nil
        if let audioFileStreamID = audioFileStreamID {
            status = AudioFileStreamClose(audioFileStreamID)
            assert(noErr == status)
        }
    }
    
    private func createAudioQueue() {
        
        /// 新建音频输出队列
        status = AudioQueueNewOutput(&audioStreamDescription, { (inUserData, inAQ, inBuffer) in
            /// 每次播放器需要播放音频数据的时候就会调用，一般这个时候inBuffer已经播放完成了，可以从队列中移除了。
            /// 这里采用没次都创建一定capacity的Buffer
            
            /// 清除队列中已经播放完成的缓存
            AudioQueueFreeBuffer(inAQ, inBuffer)
            
            let mySelf: StreamAudioPlayer = converInstance(by: inUserData!)
            mySelf.enAudioQueue()
        }, selfInstance, CFRunLoopGetCurrent(), nil, 0, &audioQueue)
        
        assert(noErr == status)
        
        /// 添加属性监听事件 - 是否正在运行
        status = AudioQueueAddPropertyListener(audioQueue!, kAudioQueueProperty_IsRunning, { (inUserData, inAQ, inID) in
            ///控制播放器的状态
            let mySelf: StreamAudioPlayer = converInstance(by: inUserData!)
            
            var dataSize: UInt32 = 0
            var running: UInt32 = 0
            mySelf.status = AudioQueueGetPropertySize(inAQ, inID, &dataSize)
            mySelf.status = AudioQueueGetProperty(inAQ, inID, &running, &dataSize)
            mySelf.isRunning = running != 0
        }, selfInstance)
        
        assert(noErr == status)
        
//        /// 解析音频数据 - 解析所有进入队列的数据 -（实际解析多少数据）--------默认解析
//        status = AudioQueuePrime(audioQueue!, 0, nil)
//        assert(noErr == status)
    }
    
    private func enAudioQueue() {
        /// 填充音频数据到队列中
        guard currentOffset < packets.count else { return }//播放完成
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
        assert(noErr == status)
        
        
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
        
        status = AudioQueueEnqueueBuffer(audioQueue!,
                                         newAudioQueueBuffer!,
                                         UInt32(inQueueDescriptions.count),
                                         inQueueDescriptions)
        assert(noErr == status)
        print("enter\(currentOffset) - \(endOffset)")
        currentOffset = endOffset
    }
    
    private func parse(data: Data) {
        /// 向指定的流处理器中添加需要解析的数据
        status = AudioFileStreamParseBytes(audioFileStreamID!,
                                           UInt32(data.count),
                                           (data as NSData).bytes,
                                           AudioFileStreamParseFlags(rawValue: 0))//.discontinuity
        assert(noErr == status)
        //        return status == noErr ? nil : AudioPlayerError.streamAudioPlayerError(.AudioFileStreamParseBytes(status))
    }
}

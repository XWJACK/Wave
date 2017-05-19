//
//  Wave.swift
//  Wave
//
//  Created by Jack on 4/26/17.
//
//

import Foundation

public func converInstance<T: AnyObject>(by pointee: UnsafeMutableRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(pointee).takeUnretainedValue()
}

extension OSStatus {
    var isSuccess: Bool { return self == noErr }
}

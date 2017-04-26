//
//  Wave.swift
//  Wave
//
//  Created by Jack on 4/26/17.
//
//

import Foundation

func converInstance<T: AnyObject>(by pointee: UnsafeMutableRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(pointee).takeUnretainedValue()
}

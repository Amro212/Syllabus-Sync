//
//  AppLog.swift
//  Syllabus Sync
//

import Foundation

enum AppLog {
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }
}

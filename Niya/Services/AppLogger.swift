import os

enum AppLogger {
    static let audio = Logger(subsystem: "com.niya.mobile", category: "audio")
    static let data = Logger(subsystem: "com.niya.mobile", category: "data")
    static let network = Logger(subsystem: "com.niya.mobile", category: "network")
    static let store = Logger(subsystem: "com.niya.mobile", category: "store")
}

//
//  Color+Hex.swift
//  ios-native-minimal
//

import SwiftUI

public extension Color {

    /// 十六进制整数：Color(hex: 0xF2F2F7)
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// 字符串："#F2F2F7" / "F2F2F7" / "fff"
    init(hexString: String, opacity: Double = 1) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let value = UInt32(s, radix: 16) ?? 0x000000
        self.init(hex: value, opacity: opacity)
    }
}

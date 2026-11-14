//
//  LineIcon.swift
//  ios-native-minimal
//
//  细线、空心、圆头图标。整套界面只用这一种图标语言。
//

import SwiftUI

public struct LineIcon: View {

    public let name: String
    public var size: CGFloat
    public var weight: Font.Weight
    public var color: Color

    public init(
        _ name: String,
        size: CGFloat = NativeUI.Metric.icon,
        weight: Font.Weight = .light,
        color: Color = NativeUI.ink
    ) {
        self.name = name
        self.size = size
        self.weight = weight
        self.color = color
    }

    public var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .frame(width: size + 4, height: size + 4)
            .accessibilityHidden(true)
    }
}

/// 推荐图标清单。全部是空心线稿（SF Symbols 里名字不带 `.fill` 的变体）。
public enum NativeIcons {

    // 主 Tab
    public static let chat = "bubble.left.and.bubble.right"
    public static let settings = "slider.horizontal.3"
    public static let person = "person"

    // 列表 / 设置
    public static let devices = "rectangle.on.rectangle"        // 或 "laptopcomputer.and.iphone"
    public static let wallet = "creditcard"
    public static let shield = "shield"                        // 隐私
    public static let bell = "bell"
    public static let globe = "globe"
    public static let lock = "lock"
    public static let key = "key"
    public static let info = "info.circle"
    public static let doc = "doc.text"
    public static let help = "questionmark.circle"
    public static let sparkle = "sparkles"
    public static let plus = "plus"
    public static let search = "magnifyingglass"
    public static let menu = "line.3.horizontal"

    // 动作
    public static let back = "chevron.left"
    public static let chevron = "chevron.right"
    public static let close = "xmark"
    public static let send = "arrow.up"
    public static let mic = "mic"
    public static let more = "ellipsis"
    public static let edit = "square.and.pencil"
    public static let trash = "trash"
}

/// 状态圆点（唯一允许的实心圆）
public struct StatusDot: View {
    public var color: Color
    public var size: CGFloat

    public init(color: Color = NativeUI.success, size: CGFloat = 7) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

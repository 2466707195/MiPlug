//
//  CardList.swift
//  ios-native-minimal
//
//  卡片式列表：外层 20pt 白卡，内层行 14pt 高亮，行间 0.5pt 内缩细线。
//  不要用 List / Form 的默认样式 —— 那会带来整屏分隔线，风格立刻垮掉。
//

import SwiftUI

// MARK: - 卡片组

public struct NativeCard<Content: View>: View {

    private let content: Content
    private let showsBorder: Bool

    public init(showsBorder: Bool = false, @ViewBuilder content: () -> Content) {
        self.showsBorder = showsBorder
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) { content }
            .nativeCard()
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: NativeUI.Radius.outer, style: .continuous)
                        .strokeBorder(NativeUI.hairline, lineWidth: 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: NativeUI.Radius.outer, style: .continuous))
    }
}

// MARK: - 细线

public struct NativeDivider: View {

    /// 左内缩，默认对齐文字起始位置（16 + 22 + 12）
    public var leadingInset: CGFloat
    public var trailingInset: CGFloat

    public init(
        leadingInset: CGFloat = NativeUI.Metric.dividerInset,
        trailingInset: CGFloat = 0
    ) {
        self.leadingInset = leadingInset
        self.trailingInset = trailingInset
    }

    public var body: some View {
        Rectangle()
            .fill(NativeUI.hairline)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .allowsHitTesting(false)
    }
}

// MARK: - 行

public struct NativeRow: View {

    public var icon: String
    public var title: String
    public var subtitle: String?
    public var detail: String?
    public var showsChevron: Bool
    public var iconColor: Color
    public var titleColor: Color
    public var action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        showsChevron: Bool = true,
        iconColor: Color = NativeUI.ink,
        titleColor: Color = NativeUI.ink,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.showsChevron = showsChevron
        self.iconColor = iconColor
        self.titleColor = titleColor
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { label }
                .buttonStyle(NativeRowButtonStyle())
                .accessibilityElement(children: .combine)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: NativeUI.Metric.iconGap) {
            LineIcon(icon, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NativeUI.Fonts.body)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .font(NativeUI.Fonts.secondary)
                        .foregroundStyle(NativeUI.secondary)
                }
            }

            Spacer(minLength: 8)

            if let detail {
                Text(detail)
                    .font(NativeUI.Fonts.secondary)
                    .foregroundStyle(NativeUI.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            if showsChevron {
                LineIcon(NativeIcons.chevron, size: 13, weight: .semibold, color: NativeUI.tertiary)
                    .frame(width: 8)
            }
        }
        .padding(.horizontal, NativeUI.Metric.rowInset)
        .frame(minHeight: NativeUI.Metric.rowHeight)
        .contentShape(Rectangle())
    }
}

/// 行按下态：14pt 圆角的浅灰块，左右各内缩 6 —— 这就是「内层圆角」的落点。
public struct NativeRowButtonStyle: ButtonStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: NativeUI.Radius.inner, style: .continuous)
                    .fill(NativeUI.fill)
                    .opacity(configuration.isPressed ? 1 : 0)
                    .padding(.horizontal, 6)
            }
            .animation(NativeUI.Motion.fade, value: configuration.isPressed)
    }
}

// MARK: - 分区（标题 + 卡片 + 脚注）

public struct NativeSection<Content: View>: View {

    private let title: String?
    private let footer: String?
    private let content: Content

    public init(
        _ title: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(NativeUI.Fonts.section)
                    .foregroundStyle(NativeUI.secondary)
            }

            NativeCard { content }

            if let footer {
                Text(footer)
                    .font(NativeUI.Fonts.caption)
                    .foregroundStyle(NativeUI.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, NativeUI.Metric.page)
        .padding(.bottom, NativeUI.Metric.cardGap)
    }
}

// MARK: - 卡片组行序列（自动插细线，首尾不加）

public struct NativeRowList<Content: View>: View {

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) { content }
    }
}

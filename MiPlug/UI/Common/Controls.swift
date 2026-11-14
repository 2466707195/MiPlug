//
//  Controls.swift
//  ios-native-minimal
//
//  胶囊分段、圆形返回钮、次按钮（浅灰底 + 蓝字）、开关行、状态标签。
//

import SwiftUI

// MARK: - 按下反馈（全站统一：0.97 缩放 + 轻微透明）

public struct PressScaleStyle: ButtonStyle {

    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 胶囊分段（Connectable / Connected）

public struct SegmentedPill<Item: Hashable>: View {

    @Binding private var selection: Item
    private let items: [Item]
    private let title: (Item) -> String

    @Namespace private var namespace

    public init(
        selection: Binding<Item>,
        items: [Item],
        title: @escaping (Item) -> String
    ) {
        self._selection = selection
        self.items = items
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(NativeUI.Motion.control) { selection = item }
                } label: {
                    Text(title(item))
                        .font(.system(size: 14, weight: selection == item ? .semibold : .medium))
                        .foregroundStyle(selection == item ? NativeUI.ink : NativeUI.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            if selection == item {
                                Capsule(style: .continuous)
                                    .fill(NativeUI.card)
                                    .matchedGeometryEffect(id: "pill.selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(NativeUI.fill, in: Capsule(style: .continuous))
    }
}

// MARK: - 圆形返回钮（子页左上，44pt，浅灰底）

public struct CircleBackButton: View {

    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(NativeUI.fill)
                LineIcon(NativeIcons.back, size: 15, weight: .semibold, color: NativeUI.ink)
                    .offset(x: -0.5)
            }
            .frame(width: NativeUI.Metric.circleButton, height: NativeUI.Metric.circleButton)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("返回")
    }
}

// MARK: - 同款圆形图标钮（右上更多/编辑）

public struct CircleIconButton: View {

    private let icon: String
    private let action: () -> Void

    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(NativeUI.fill)
                LineIcon(icon, size: 16, weight: .regular, color: NativeUI.ink)
            }
            .frame(width: NativeUI.Metric.circleButton, height: NativeUI.Metric.circleButton)
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - 次按钮：浅灰底 + 蓝字

public struct SecondaryButton: View {

    private let title: String
    private let icon: String?
    private let action: () -> Void

    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    LineIcon(icon, size: 16, weight: .regular, color: NativeUI.accent)
                }
                Text(title)
                    .font(NativeUI.Fonts.button)
                    .foregroundStyle(NativeUI.accent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .nativeFillBackground(radius: NativeUI.Radius.inner)
            .contentShape(RoundedRectangle(cornerRadius: NativeUI.Radius.inner, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - 主按钮（整屏只放一个）

public struct PrimaryButton: View {

    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(NativeUI.Fonts.button)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    NativeUI.accent,
                    in: RoundedRectangle(cornerRadius: NativeUI.Radius.inner, style: .continuous)
                )
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - 蓝色文字链

public struct TextLink: View {

    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(NativeUI.Fonts.body)
                .foregroundStyle(NativeUI.accent)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 开关行（标准 iOS Toggle）

public struct NativeToggleRow: View {

    private let icon: String
    private let title: String
    private let subtitle: String?
    @Binding private var isOn: Bool

    public init(icon: String, title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        HStack(spacing: NativeUI.Metric.iconGap) {
            LineIcon(icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NativeUI.Fonts.body)
                    .foregroundStyle(NativeUI.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(NativeUI.Fonts.secondary)
                        .foregroundStyle(NativeUI.secondary)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(NativeUI.success)
                .accessibilityLabel(title)
        }
        .padding(.horizontal, NativeUI.Metric.rowInset)
        .frame(minHeight: NativeUI.Metric.rowHeight)
    }
}

// MARK: - 小胶囊状态标签

public struct PillTag: View {

    private let text: String
    private let color: Color
    private let background: Color

    public init(_ text: String, color: Color = NativeUI.secondary, background: Color = NativeUI.fill) {
        self.text = text
        self.color = color
        self.background = background
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule(style: .continuous))
    }
}

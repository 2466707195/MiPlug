//
//  Headers.swift
//  ios-native-minimal
//
//  标题只有两种：主页大标题（左对齐 34 bold）和子页标题（居中 17 semibold + 44 圆钮返回）。
//

import SwiftUI

// MARK: - 大标题（主页 / 抽屉）

public struct LargeTitleHeader<Trailing: View>: View {

    private let eyebrow: String?
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    public init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(NativeUI.Fonts.section)
                        .foregroundStyle(NativeUI.secondary)
                }

                Text(title)
                    .font(NativeUI.Fonts.largeTitle)
                    .foregroundStyle(NativeUI.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(NativeUI.Fonts.secondary)
                        .foregroundStyle(NativeUI.secondary)
                }
            }

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal, NativeUI.Metric.page)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

public extension LargeTitleHeader where Trailing == EmptyView {

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

// MARK: - 子页导航（居中标题 + 左上圆钮返回）

public struct SubPageHeader<Trailing: View>: View {

    private let title: String
    private let onBack: () -> Void
    private let trailing: Trailing

    public init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing()
    }

    public var body: some View {
        ZStack {
            Text(title)
                .font(NativeUI.Fonts.navTitle)
                .foregroundStyle(NativeUI.ink)
                .lineLimit(1)
                .padding(.horizontal, 64)

            HStack(spacing: 8) {
                CircleBackButton(action: onBack)
                Spacer(minLength: 0)
                trailing
            }
        }
        .frame(height: 44)
        .padding(.horizontal, NativeUI.Metric.page)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

public extension SubPageHeader where Trailing == EmptyView {

    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}

// MARK: - 分区小标题

public struct SectionHeader: View {

    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(NativeUI.Fonts.section)
            .foregroundStyle(NativeUI.secondary)
            .padding(.horizontal, NativeUI.Metric.page)
            .padding(.bottom, 8)
    }
}

//
//  ControlScreen.swift
//  MiPlug
//
//  控制主页：大标题 + 通道分段 + 状态大卡 + 开关主按钮。
//  极简风：灰底白卡、零装饰、彩色只有系统蓝。
//

import SwiftUI

struct ControlScreen: View {

    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            NativeUI.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                LargeTitleHeader(
                    eyebrow: model.device.model,
                    title: model.device.name,
                    subtitle: channelSubtitle
                )

                // 通道切换
                SegmentedPill(
                    selection: $model.channel,
                    items: PlugChannel.allCases,
                    title: { $0.title }
                )
                .padding(.horizontal, NativeUI.Metric.page)
                .padding(.bottom, NativeUI.Metric.cardGap)
                .onChange(of: model.channel) { _ in
                    model.refresh()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: NativeUI.Metric.cardGap) {
                        stateCard
                        controlCard
                        errorCard
                    }
                    .padding(.horizontal, NativeUI.Metric.page)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var channelSubtitle: String {
        switch model.channel {
        case .local:
            switch model.localStatus {
            case .available: return "局域网直连 · 在线"
            case .unavailable: return "局域网不可达 · 自动转云端"
            default: return "同一 Wi-Fi 下直连设备"
            }
        case .cloud:
            switch model.cloudStatus {
            case .available: return "云端中转 · 在线"
            case .unavailable: return "云端不可达"
            default: return "经小米云中转，随时随地"
            }
        }
    }

    // MARK: - 状态卡

    private var stateCard: some View {
        NativeCard {
            VStack(spacing: 18) {
                // 电源图标
                ZStack {
                    Circle()
                        .fill(iconBg)
                        .frame(width: 92, height: 92)
                    Image(systemName: "power")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(iconTint)
                }
                .padding(.top, 28)

                Text(model.state.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(NativeUI.ink)

                Text(subtitleText)
                    .font(NativeUI.Fonts.secondary)
                    .foregroundStyle(NativeUI.secondary)
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var iconBg: Color {
        if model.state == .on { return NativeUI.accent.opacity(0.12) }
        return NativeUI.fill
    }

    private var iconTint: Color {
        if model.state == .on { return NativeUI.accent }
        return NativeUI.secondary
    }

    private var subtitleText: String {
        if model.busy && model.state == .checking { return "正在查询…" }
        if let err = model.lastError { return err }
        switch model.channel {
        case .local: return "通过局域网 miIO 直连"
        case .cloud: return "通过小米云 API 中转"
        }
    }

    // MARK: - 控制卡

    private var controlCard: some View {
        NativeCard {
            VStack(spacing: 0) {
                // 开按钮
                actionRow(
                    icon: "power",
                    title: "打开插座",
                    subtitle: "接通输出",
                    accent: NativeUI.accent,
                    disabled: model.busy || model.state == .on
                ) {
                    model.setPower(true)
                }

                NativeDivider(leadingInset: NativeUI.Metric.rowInset, trailingInset: NativeUI.Metric.rowInset)

                // 关按钮
                actionRow(
                    icon: "power",
                    title: "关闭插座",
                    subtitle: "断开输出",
                    accent: NativeUI.ink,
                    disabled: model.busy || model.state == .off
                ) {
                    model.setPower(false)
                }

                NativeDivider(leadingInset: NativeUI.Metric.rowInset, trailingInset: NativeUI.Metric.rowInset)

                // 刷新
                actionRow(
                    icon: "arrow.clockwise",
                    title: "刷新状态",
                    subtitle: "重新查询当前开关",
                    accent: NativeUI.ink,
                    disabled: model.busy
                ) {
                    model.refresh()
                }
            }
        }
    }

    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: NativeUI.Metric.iconGap) {
                LineIcon(icon, color: accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(NativeUI.Fonts.body)
                        .foregroundStyle(disabled ? NativeUI.tertiary : NativeUI.ink)
                    Text(subtitle)
                        .font(NativeUI.Fonts.secondary)
                        .foregroundStyle(NativeUI.secondary)
                }

                Spacer(minLength: 8)

                if model.busy {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, NativeUI.Metric.rowInset)
            .frame(minHeight: NativeUI.Metric.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(NativeRowButtonStyle())
        .disabled(disabled)
    }

    // MARK: - 错误卡

    @ViewBuilder
    private var errorCard: some View {
        if let err = model.lastError {
            NativeCard {
                HStack(spacing: NativeUI.Metric.iconGap) {
                    LineIcon("exclamationmark.triangle", color: NativeUI.danger)
                    Text(err)
                        .font(NativeUI.Fonts.secondary)
                        .foregroundStyle(NativeUI.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, NativeUI.Metric.rowInset)
                .padding(.vertical, 14)
            }
        }
    }
}

//
//  TimerScreen.swift
//  MiPlug
//
//  本地定时（设备固件执行，断网也能触发）：
//  设备 spec siid=7/piid=1，单条规则：开关 + 时间 + 重复日 + 动作。
//

import SwiftUI

struct TimerScreen: View {

    @EnvironmentObject private var model: AppModel

    @State private var draft: LocalTimer?
    @State private var loaded = false

    var body: some View {
        ZStack {
            NativeUI.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                LargeTitleHeader(
                    eyebrow: "插座固件本地计时",
                    title: "定时"
                )

                if let t = draft {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: NativeUI.Metric.cardGap) {
                            statusCard(t)
                            timeCard(t)
                            weekdayCard(t)
                            actionCard(t)
                            saveButton(t)
                            footer
                        }
                        .padding(.horizontal, NativeUI.Metric.page)
                        .padding(.bottom, 32)
                    }
                } else if model.timerLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    Spacer()
                    Text("暂时读不到设备的定时信息")
                        .font(NativeUI.Fonts.secondary)
                        .foregroundStyle(NativeUI.secondary)
                    Spacer()
                }
            }
        }
        .onAppear {
            if !loaded {
                loaded = true
                model.loadTimer()
            }
        }
        .onChange(of: model.timer) { newTimer in
            // 首次载入 / 外部刷新时同步草稿
            if draft == nil, let t = newTimer {
                draft = t
            }
        }
    }

    // MARK: - 状态卡

    private func statusCard(_ t: LocalTimer) -> some View {
        NativeCard {
            HStack(spacing: NativeUI.Metric.iconGap) {
                LineIcon("clock", color: t.enabled ? NativeUI.accent : NativeUI.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("定时开关")
                        .font(NativeUI.Fonts.body)
                        .foregroundStyle(NativeUI.ink)
                    Text(t.enabled ? "设备到点自动执行（固件本地计时）" : "已停用")
                        .font(NativeUI.Fonts.secondary)
                        .foregroundStyle(NativeUI.secondary)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { t.enabled },
                    set: { v in draft?.enabled = v }
                ))
                .labelsHidden()
                .tint(NativeUI.success)
            }
            .padding(.horizontal, NativeUI.Metric.rowInset)
            .frame(minHeight: NativeUI.Metric.rowHeight)
        }
    }

    // MARK: - 时间卡

    private func timeCard(_ t: LocalTimer) -> some View {
        NativeCard {
            HStack {
                Text("触发时间")
                    .font(NativeUI.Fonts.body)
                    .foregroundStyle(NativeUI.ink)
                Spacer()
                DatePicker("", selection: Binding(
                    get: { Self.date(from: t) },
                    set: { d in
                        var c = Calendar(identifier: .gregorian)
                        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
                        draft?.hour = c.component(.hour, from: d)
                        draft?.minute = c.component(.minute, from: d)
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
            }
            .padding(.horizontal, NativeUI.Metric.rowInset)
            .frame(minHeight: NativeUI.Metric.rowHeight)
        }
    }

    // MARK: - 重复日卡

    private func weekdayCard(_ t: LocalTimer) -> some View {
        NativeCard {
            VStack(spacing: 0) {
                HStack {
                    Text("重复")
                        .font(NativeUI.Fonts.body)
                        .foregroundStyle(NativeUI.ink)
                    Spacer()
                    Text(t.weekTitle)
                        .font(NativeUI.Fonts.secondary)
                        .foregroundStyle(NativeUI.secondary)
                }
                .padding(.horizontal, NativeUI.Metric.rowInset)
                .frame(minHeight: NativeUI.Metric.rowHeight)

                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { idx in
                        let names = ["一", "二", "三", "四", "五", "六", "日"]
                        let isOn = t.weekdays.contains(idx)
                        Button {
                            if isOn { draft?.weekdays.remove(idx) }
                            else { draft?.weekdays.insert(idx) }
                        } label: {
                            Text(names[idx])
                                .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                                .foregroundStyle(isOn ? .white : NativeUI.secondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    isOn ? NativeUI.accent : NativeUI.fill,
                                    in: Circle()
                                )
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, NativeUI.Metric.rowInset - 4)
                .padding(.bottom, 14)
            }
        }
    }

    // MARK: - 动作卡

    private func actionCard(_ t: LocalTimer) -> some View {
        NativeCard {
            HStack {
                Text("到点执行")
                    .font(NativeUI.Fonts.body)
                    .foregroundStyle(NativeUI.ink)
                Spacer()
                SegmentedPill(
                    selection: Binding(
                        get: { t.turnsOn },
                        set: { v in draft?.turnsOn = v }
                    ),
                    items: [false, true],
                    title: { v in v ? "打开插座" : "关闭插座" }
                )
                .frame(width: 200)
            }
            .padding(.horizontal, NativeUI.Metric.rowInset)
            .frame(minHeight: NativeUI.Metric.rowHeight)
        }
    }

    // MARK: - 保存

    private func saveButton(_ t: LocalTimer) -> some View {
        Button {
            if let d = draft {
                model.saveTimer(d)
            }
        } label: {
            HStack(spacing: 8) {
                if model.timerLoading {
                    ProgressView().tint(.white)
                }
                Text("保存到设备")
                    .font(NativeUI.Fonts.button)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                NativeUI.accent,
                in: RoundedRectangle(cornerRadius: NativeUI.Radius.inner, style: .continuous)
            )
        }
        .buttonStyle(PressScaleStyle())
        .disabled(model.timerLoading)
    }

    private var footer: some View {
        Text("定时由插座固件本地计时执行，家里断网也会准时触发。当前设备支持 1 条规则。")
            .font(NativeUI.Fonts.caption)
            .foregroundStyle(NativeUI.tertiary)
            .padding(.horizontal, 4)
    }

    private static func date(from t: LocalTimer) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date()
    }
}

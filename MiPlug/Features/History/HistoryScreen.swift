//
//  HistoryScreen.swift
//  MiPlug
//
//  历史记录：米家云端设备消息（插座开关事件等）。
//

import SwiftUI

struct HistoryScreen: View {

    @EnvironmentObject private var model: AppModel
    @State private var loaded = false

    var body: some View {
        ZStack {
            NativeUI.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    LargeTitleHeader(
                        title: "历史记录",
                        subtitle: "米家记录的插座动态"
                    )

                    if model.messagesLoading && model.messages.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 60)
                            Spacer()
                        }
                    } else if model.messages.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                LineIcon("doc.text", size: 34, color: NativeUI.tertiary)
                                Text("暂无记录")
                                    .font(NativeUI.Fonts.body)
                                    .foregroundStyle(NativeUI.secondary)
                                Text("米家云端还没有这台插座的动态消息")
                                    .font(NativeUI.Fonts.secondary)
                                    .foregroundStyle(NativeUI.tertiary)
                            }
                            .padding(.vertical, 50)
                            Spacer()
                        }
                    } else {
                        NativeSection {
                            NativeRowList {
                                ForEach(Array(model.messages.enumerated()), id: \.element.id) { idx, msg in
                                    if idx > 0 { NativeDivider() }
                                    messageRow(msg)
                                }
                            }
                        } footer: {
                            Text("记录保存在米家云端，与米家 App 看到的一致。")
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .onAppear {
            if !loaded {
                loaded = true
                model.loadMessages()
            }
        }
        .refreshable {
            model.loadMessages()
        }
    }

    private func messageRow(_ msg: MiMessage) -> some View {
        HStack(spacing: NativeUI.Metric.iconGap) {
            LineIcon(iconFor(msg.text), color: NativeUI.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(msg.text)
                    .font(NativeUI.Fonts.body)
                    .foregroundStyle(NativeUI.ink)
                Text(Self.timeText(msg.timestamp))
                    .font(NativeUI.Fonts.caption)
                    .foregroundStyle(NativeUI.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, NativeUI.Metric.rowInset)
        .frame(minHeight: NativeUI.Metric.rowHeight)
    }

    private func iconFor(_ text: String) -> String {
        if text.contains("开") { return "power" }
        if text.contains("关") { return "powerplug" }
        return "info.circle"
    }

    private static func timeText(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }
}

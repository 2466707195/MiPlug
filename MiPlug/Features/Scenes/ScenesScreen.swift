//
//  ScenesScreen.swift
//  MiPlug
//
//  智能场景：拉取米家云端手动场景列表，一键执行。
//

import SwiftUI

struct ScenesScreen: View {

    @EnvironmentObject private var model: AppModel
    @State private var loaded = false

    var body: some View {
        ZStack {
            NativeUI.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    LargeTitleHeader(
                        title: "智能场景",
                        subtitle: "米家里创建的手动场景，点一下就执行"
                    )

                    if model.scenesLoading && model.scenes.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 60)
                            Spacer()
                        }
                    } else if model.scenes.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                LineIcon("sparkles", size: 34, color: NativeUI.tertiary)
                                Text("还没有场景")
                                    .font(NativeUI.Fonts.body)
                                    .foregroundStyle(NativeUI.secondary)
                                Text("在米家 App 里创建手动场景后，这里就能一键执行")
                                    .font(NativeUI.Fonts.secondary)
                                    .foregroundStyle(NativeUI.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 50)
                            Spacer()
                        }
                    } else {
                        NativeSection {
                            NativeRowList {
                                ForEach(Array(model.scenes.enumerated()), id: \.element.id) { idx, scene in
                                    if idx > 0 { NativeDivider() }
                                    sceneRow(scene)
                                }
                            }
                        } footer: {
                            Text("场景由米家云端执行，需要插座在线。")
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .onAppear {
            if !loaded {
                loaded = true
                model.loadScenes()
            }
        }
        .refreshable {
            model.loadScenes()
        }
    }

    private func sceneRow(_ scene: MiScene) -> some View {
        Button {
            model.runScene(scene)
        } label: {
            HStack(spacing: NativeUI.Metric.iconGap) {
                ZStack {
                    Circle()
                        .fill(NativeUI.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    LineIcon("sparkles", size: 18, color: NativeUI.accent)
                }

                Text(scene.name)
                    .font(NativeUI.Fonts.body)
                    .foregroundStyle(NativeUI.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if model.runningScene == scene.id {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Text("执行")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NativeUI.accent)
                }
            }
            .padding(.horizontal, NativeUI.Metric.rowInset)
            .frame(minHeight: NativeUI.Metric.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(NativeRowButtonStyle())
        .disabled(model.runningScene != nil)
    }
}

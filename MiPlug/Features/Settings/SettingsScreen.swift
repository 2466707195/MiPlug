//
//  SettingsScreen.swift
//  MiPlug
//
//  设置页：设备信息卡（只读数据行）+ 通道说明卡。
//

import SwiftUI

struct SettingsScreen: View {

    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            NativeUI.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    LargeTitleHeader(title: "设置")

                    NativeSection("设备", footer: "设备参数来自米家云端设备列表。") {
                        NativeRowList {
                            NativeRow(
                                icon: "powerplug",
                                title: "名称",
                                detail: model.device.name,
                                showsChevron: false
                            )
                            NativeDivider()
                            NativeRow(
                                icon: "info.circle",
                                title: "型号",
                                detail: model.device.model,
                                showsChevron: false
                            )
                            NativeDivider()
                            NativeRow(
                                icon: "wifi",
                                title: "局域网地址",
                                detail: model.device.localIP,
                                showsChevron: false
                            )
                            NativeDivider()
                            NativeRow(
                                icon: "number",
                                title: "设备 ID",
                                detail: model.device.deviceIDHex,
                                showsChevron: false
                            )
                        }
                    }
                    .padding(.top, 4)

                    NativeSection("通道", footer: "局域网不可达时，控制指令会自动走云端通道重试一次；反之亦然。") {
                        NativeRowList {
                            NativeRow(
                                icon: "wifi",
                                title: "局域网 miIO",
                                subtitle: "UDP 54321 · AES-CBC 直连设备",
                                detail: statusText(model.localStatus),
                                showsChevron: false
                            )
                            NativeDivider()
                            NativeRow(
                                icon: "icloud",
                                title: "小米云 API",
                                subtitle: "miotspec/prop · RC4 加密",
                                detail: statusText(model.cloudStatus),
                                showsChevron: false
                            )
                        }
                    }

                    NativeSection("关于") {
                        NativeRowList {
                            NativeRow(
                                icon: "lock",
                                title: "数据去向",
                                subtitle: "凭证仅保存在本机 App 内，不经过任何第三方服务器",
                                showsChevron: false
                            )
                            NativeDivider()
                            NativeRow(
                                icon: "info.circle",
                                title: "版本",
                                detail: "0.1.0",
                                showsChevron: false
                            )
                        }
                    }
                }
            }
        }
    }

    private func statusText(_ status: AppModel.ChannelStatus) -> String {
        switch status {
        case .available: return "在线"
        case .unavailable: return "不可达"
        case .busy: return "探测中"
        case .idle: return "未探测"
        }
    }
}

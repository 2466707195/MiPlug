import Foundation

// MARK: - 设备

/// 卧室插座（设备参数来自云端设备列表，token 经扫码获取）
struct PlugDevice: Hashable {
    let name: String
    let model: String
    let cloudDID: String      // 云端设备 ID（数字串）
    let localIP: String       // 局域网 IP
    let localToken: String    // 32 位 hex，本地 miIO 用
    let deviceIDHex: String   // 8 位 hex（本地 miIO 包头用）

    /// miIO 本地端口
    static let miioPort: UInt16 = 54321

    static let bedroom = PlugDevice(
        name: "卧室插座",
        model: "yutai.plug.socn1",
        cloudDID: "2053096533",
        localIP: "192.168.10.9",
        localToken: "4eaf452e7d8d83cd23dd8b34a405a48b",
        deviceIDHex: "7A5FC455"
    )
}

// MARK: - 通道

/// 控制通道：局域网 miIO 直连 or 小米云 API
enum PlugChannel: String, CaseIterable, Identifiable {
    case local
    case cloud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: return "局域网"
        case .cloud: return "云端"
        }
    }

    var subtitle: String {
        switch self {
        case .local: return "同一 Wi-Fi 下直连设备，毫秒级"
        case .cloud: return "经小米云中转，随时随地可用"
        }
    }

    var icon: String {
        switch self {
        case .local: return "wifi"
        case .cloud: return "icloud"
        }
    }
}

// MARK: - 开关状态

enum PlugState: Equatable {
    case on
    case off
    case unknown
    case checking

    var title: String {
        switch self {
        case .on: return "已开启"
        case .off: return "已关闭"
        case .unknown: return "状态未知"
        case .checking: return "查询中…"
        }
    }
}

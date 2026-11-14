//
//  MiCredentials.swift
//  MiPlug
//
//  敏感凭证不进源码：
//  - 本地开发：这个文件被 build 时由 CI 从 Secrets 注入的 MiCredentials.generated.swift 覆盖
//  - CI 构建：GitHub Actions 把 secrets 写成 MiPlug/Core/Model/MiCredentials.generated.swift
//  仓库里只保留这份空模板，构建脚本会用真实值替换。
//

import Foundation

/// 凭证占位。CI 会用模板变量替换这个文件的实现。
enum MiCredentials {
    static let userID = "__MI_USER_ID__"
    static let ssecurity = "__MI_SSECURITY__"
    static let serviceToken = "__MI_SERVICE_TOKEN__"
    static let cloudDID = "__MI_CLOUD_DID__"
    static let localIP = "__MI_LOCAL_IP__"
    static let localToken = "__MI_LOCAL_TOKEN__"
    static let deviceIDHex = "__MI_DEVICE_ID_HEX__"
}

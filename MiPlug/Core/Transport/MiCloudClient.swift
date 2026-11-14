//
//  MiCloudClient.swift
//  MiPlug
//
//  小米云 API 通道：POST https://api.io.mi.com/app/miotspec/prop/get|set
//  加密流程（与 token_extractor / mijia-api 一致，已用 Python 实测验证）：
//    nonce = random8 + minutestamp4
//    signedNonce = SHA256(ssecurity_b64 + nonce)          （b64）
//    请求体：data 明文 → rc4_hash__ 签名 → RC4 加密 → signature 签名
//    签名串 = "POST&/<path>&k=v...&signedNonce"，SHA1
//    响应体：RC4 解密后为 JSON
//

import Foundation
import CommonCrypto

enum MiCloudError: Error, LocalizedError {
    case badResponse
    case http(Int, String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .badResponse: return "云端响应格式异常"
        case .http(let code, let msg): return "云端 HTTP \(code): \(msg)"
        case .api(let m): return m
        }
    }
}

struct MiCloudClient {

    let userID: String
    let ssecurity: String      // base64
    let serviceToken: String

    private static let apiBase = "https://api.io.mi.com"

    init(userID: String, ssecurity: String, serviceToken: String) {
        self.userID = userID
        self.ssecurity = ssecurity
        self.serviceToken = serviceToken
    }

    // MARK: - RC4

    private static func rc4(_ key: [UInt8], _ input: [UInt8]) -> [UInt8] {
        var s = Array(0..<256)
        var j: Int = 0
        for i in 0..<256 {
            j = (j + Int(s[i]) + Int(key[i % key.count])) & 0xFF
            s.swapAt(i, j)
        }
        var out: [UInt8] = []
        out.reserveCapacity(input.count)
        var i: Int = 0
        j = 0
        for byte in input {
            i = (i + 1) & 0xFF
            j = (j + Int(s[i])) & 0xFF
            s.swapAt(i, j)
            out.append(byte ^ UInt8(s[(Int(s[i]) + Int(s[j])) & 0xFF]))
        }
        return out
    }

    /// 与官方实现一致：先空转 1024 字节
    private static func rc4Primed(_ key: [UInt8], _ input: [UInt8]) -> [UInt8] {
        _ = rc4(key, [UInt8](repeating: 0, count: 1024))
        return rc4(key, input)
    }

    // MARK: - 编解码辅助

    private static func b64decode(_ s: String) -> [UInt8] {
        Array(Data(base64Encoded: s) ?? Data())
    }

    private static func b64encode(_ d: [UInt8]) -> String {
        Data(d).base64EncodedString()
    }

    private static func sha1(_ s: String) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        let bytes = Array(s.utf8)
        bytes.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                _ = CC_SHA1(src.baseAddress, CC_LONG(bytes.count), dst.baseAddress)
            }
        }
        return out
    }

    private static func sha256(_ d: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        d.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                _ = CC_SHA256(src.baseAddress, CC_LONG(d.count), dst.baseAddress)
            }
        }
        return out
    }

    /// 签名串：method & path & k=v...（保持传入顺序）& signedNonce
    private static func signString(_ method: String, _ path: String, _ sn: String, _ params: [(String, String)]) -> String {
        var parts = [method.uppercased(), path.replacingOccurrences(of: "/app/", with: "/")]
        for (k, v) in params { parts.append("\(k)=\(v)") }
        parts.append(sn)
        return parts.joined(separator: "&")
    }

    /// application/x-www-form-urlencoded 严格编码（+ → %2B，空格 → %20）
    private static func formEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    // MARK: - 请求

    /// path 形如 "/app/miotspec/prop/get"，dataObj 为请求 JSON
    func call(path: String, dataObj: JSONValue) throws -> JSONValue {
        guard let url = URL(string: Self.apiBase + path) else { throw MiCloudError.badResponse }

        // nonce / signedNonce
        // Python 实测版: os.urandom(8) + int(millis/60000) 即「分钟」时间戳，big-endian 4 字节
        var nonceBytes: [UInt8] = (0..<8).map { _ in UInt8.random(in: 0...255) }
        let minutes = UInt32(Date().timeIntervalSince1970 / 60)  // 秒/60 = 分钟（与 Python 毫秒/60000 一致）
        withUnsafeBytes(of: minutes.bigEndian) { nonceBytes += Array($0) }
        let nonce = Self.b64encode(nonceBytes)
        let snBytes = Self.sha256(Self.b64decode(ssecurity) + nonceBytes)
        let sn = Self.b64encode(snBytes)

        // data 明文
        guard let dataPlain = try? JSONSerialization.data(withJSONObject: JSONValue.jsonAny(dataObj)),
              let dataStr = String(data: dataPlain, encoding: .utf8) else {
            throw MiCloudError.badResponse
        }

        // 第一轮签名：rc4_hash__（对明文 params 签）
        // 注意：签名串的参数顺序必须与最终表单顺序一致，用有序数组而非字典（Swift 字典遍历无序 → 签名随机失败）
        let plainParams: [(String, String)] = [("data", dataStr)]
        let rc4Hash = Self.b64encode(Self.sha1(Self.signString("POST", path, sn, plainParams)))

        // RC4 加密
        let key = Self.b64decode(sn)
        let dataEnc = Self.b64encode(Self.rc4Primed(key, Array(dataStr.utf8)))
        let rc4HashEnc = Self.b64encode(Self.rc4Primed(key, Array(rc4Hash.utf8)))

        // 第二轮签名：signature（对密文 params 签，顺序 = 表单顺序）
        let encParams: [(String, String)] = [("data", dataEnc), ("rc4_hash__", rc4HashEnc)]
        let signature = Self.b64encode(Self.sha1(Self.signString("POST", path, sn, encParams)))

        // 组表单。
        // 关键：base64 里的 + / = 必须百分号编码。URLComponents 会保留 '+'，
        // 服务端把 '+' 解析成空格 → 密文被破坏 → invalid signature（Python requests 无此问题）。
        let pairs: [String] = [
            ("data", dataEnc),
            ("rc4_hash__", rc4HashEnc),
            ("signature", signature),
            ("ssecurity", ssecurity),
            ("_nonce", nonce),
        ].map { "\($0.0)=\(Self.formEncode($0.1))" }
        let body = pairs.joined(separator: "&")

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.httpBody = body.data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("PROTOCAL-HTTP2", forHTTPHeaderField: "x-xiaomi-protocal-flag-cli")
        req.setValue("ENCRYPT-RC4", forHTTPHeaderField: "MIOT-ENCRYPT-ALGORITHM")
        req.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        req.setValue("Android-30-xiaowa-6.5.302", forHTTPHeaderField: "User-Agent")

        // cookies
        let cookie = [
            "userId=\(userID)",
            "serviceToken=\(serviceToken)",
            "yetAnotherServiceToken=\(serviceToken)",
            "locale=zh_CN",
            "timezone=GMT+08:00",
            "is_daylight=0",
            "dst_offset=0",
            "channel=MI_APP_STORE",
        ].joined(separator: "; ")
        req.setValue(cookie, forHTTPHeaderField: "Cookie")

        // 同步请求（调用方放后台线程）
        let semaphore = DispatchSemaphore(value: 0)
        var outResponse: JSONValue?
        var outError: Error?
        let task = URLSession.shared.dataTask(with: req) { data, resp, err in
            defer { semaphore.signal() }
            if let err { outError = err; return }
            guard let http = resp as? HTTPURLResponse, let data else {
                outError = MiCloudError.badResponse; return
            }
            guard http.statusCode == 200 else {
                outError = MiCloudError.http(http.statusCode, String(data: data.prefix(200), encoding: .utf8) ?? "")
                return
            }
            // RC4 解密响应：响应体是 b64 文本，先解码再 RC4（与官方 decrypt_rc4 一致）
            guard let text = String(data: data, encoding: .utf8),
                  let cipher = Data(base64Encoded: text) else {
                outError = MiCloudError.badResponse; return
            }
            let plain = Self.rc4Primed(key, Array(cipher))
            outResponse = JSONValue.parse(Data(plain))
        }
        task.resume()
        semaphore.wait()

        if let outError { throw outError }
        guard let resp = outResponse else { throw MiCloudError.badResponse }
        return resp
    }

    // MARK: - 业务便捷

    /// 读插座开关
    func readPower(device: PlugDevice) throws -> Bool {
        let params: JSONValue = .object(["params": .array([.object([
            "did": .string(device.cloudDID),
            "siid": .int(2),
            "piid": .int(1),
        ])])])
        let resp = try call(path: "/app/miotspec/prop/get", dataObj: params)
        if let value = Self.extractValue(resp) { return value }
        if let msg = Self.extractError(resp) { throw MiCloudError.api(msg) }
        throw MiCloudError.badResponse
    }

    /// 写插座开关
    func writePower(_ on: Bool, device: PlugDevice) throws {
        let params: JSONValue = .object(["params": .array([.object([
            "did": .string(device.cloudDID),
            "siid": .int(2),
            "piid": .int(1),
            "value": .bool(on),
        ])])])
        let resp = try call(path: "/app/miotspec/prop/set", dataObj: params)
        if let msg = Self.extractError(resp) { throw MiCloudError.api(msg) }
    }

    // MARK: - 本地定时（设备固件执行，siid=7 piid=1）

    /// 读取当前本地定时
    func readLocalTimer(device: PlugDevice) throws -> LocalTimer? {
        let params: JSONValue = .object(["params": .array([.object([
            "did": .string(device.cloudDID),
            "siid": .int(7),
            "piid": .int(1),
        ])])])
        let resp = try call(path: "/app/miotspec/prop/get", dataObj: params)
        guard case .object(let root) = resp,
              case .array(let items)? = root["result"],
              case .object(let first)? = items.first,
              case .int(let code)? = first["code"], code == 0,
              case .string(let hex)? = first["value"], hex.hasPrefix("aa") else {
            return nil
        }
        return LocalTimer.parse(hex: hex)
    }

    /// 写入本地定时
    func writeLocalTimer(_ timer: LocalTimer, device: PlugDevice) throws {
        let params: JSONValue = .object(["params": .array([.object([
            "did": .string(device.cloudDID),
            "siid": .int(7),
            "piid": .int(1),
            "value": .string(timer.encoded),
        ])])])
        let resp = try call(path: "/app/miotspec/prop/set", dataObj: params)
        if let msg = Self.extractError(resp) { throw MiCloudError.api(msg) }
    }

    /// 读上电默认状态（0=断电记忆 1=上电关闭 2=上电开启）
    func readPowerOnState(device: PlugDevice) throws -> Int {
        let params: JSONValue = .object(["params": .array([.object([
            "did": .string(device.cloudDID),
            "siid": .int(2),
            "piid": .int(2),
        ])])])
        let resp = try call(path: "/app/miotspec/prop/get", dataObj: params)
        guard case .object(let root) = resp,
              case .array(let items)? = root["result"],
              case .object(let first)? = items.first,
              case .int(let code)? = first["code"], code == 0,
              case .int(let v)? = first["value"] else {
            throw MiCloudError.badResponse
        }
        return v
    }

    /// 写上电默认状态
    func writePowerOnState(_ value: Int, device: PlugDevice) throws {
        let params: JSONValue = .object(["params": .array([.object([
            "did": .string(device.cloudDID),
            "siid": .int(2),
            "piid": .int(2),
            "value": .int(value),
        ])])])
        let resp = try call(path: "/app/miotspec/prop/set", dataObj: params)
        if let msg = Self.extractError(resp) { throw MiCloudError.api(msg) }
    }

    // MARK: - 智能场景（云端手动场景）

    /// 拉取手动场景列表
    func listScenes(homeID: String) throws -> [MiScene] {
        let body: JSONValue = .object([
            "app_version": .int(12),
            "get_type": .int(2),
            "home_id": .string(homeID),
            "owner_uid": .int(Int(userID) ?? 0),
        ])
        let resp = try call(path: "/app/appgateway/miot/appsceneservice/AppSceneService/GetSimpleSceneList", dataObj: body)
        guard case .object(let root) = resp,
              case .object(let result)? = root["result"],
              case .array(let list)? = result["manual_scene_info_list"] else {
            return []
        }
        return list.compactMap { item in
            guard case .object(let d) = item,
                  case .string(let id)? = d["scene_id"],
                  case .string(let name)? = d["name"] else { return nil }
            return MiScene(id: id, name: name)
        }
    }

    /// 执行手动场景
    func runScene(sceneID: String) throws {
        let body: JSONValue = .object([
            "scene_id": .string(sceneID),
            "trigger_key": .string("user.click"),
        ])
        let resp = try call(path: "/app/appgateway/miot/appsceneservice/AppSceneService/RunScene", dataObj: body)
        if let msg = Self.extractError(resp) { throw MiCloudError.api(msg) }
    }

    // MARK: - 设备消息（历史记录）

    func fetchMessages(homeID: String, device: PlugDevice, limit: Int = 20) throws -> [MiMessage] {
        let body: JSONValue = .object([
            "home_id": .string(homeID),
            "did": .string(device.cloudDID),
            "limit": .int(limit),
        ])
        let resp = try call(path: "/app/v2/message/list", dataObj: body)
        guard case .object(let root) = resp,
              case .object(let result)? = root["result"],
              case .array(let list)? = result["messages"] else {
            return []
        }
        return list.compactMap { item in
            guard case .object(let d) = item,
                  case .string(let msg)? = d["message"] else { return nil }
            let ts: Int64
            if case .string(let t)? = d["timestamp"], let v = Int64(t) { ts = v }
            else if case .int(let t)? = d["timestamp"] { ts = Int64(t) }
            else { ts = 0 }
            return MiMessage(text: msg, timestamp: ts)
        }
    }

    // MARK: - 响应解析

    /// 从 {"result":[{"value":...,"code":0}]} 提取 value
    private static func extractValue(_ resp: JSONValue) -> Bool? {
        guard case .object(let root) = resp,
              case .array(let items)? = root["result"],
              case .object(let first)? = items.first else { return nil }
        guard case .int(let code)? = first["code"], code == 0 else { return nil }
        switch first["value"] {
        case .bool(let b): return b
        case .int(let i): return i != 0
        case .double(let d): return d != 0
        default: return nil
        }
    }

    /// 提取失败信息（顶层 message != ok 或 item code != 0）
    private static func extractError(_ resp: JSONValue) -> String? {
        guard case .object(let root) = resp else { return nil }
        if case .string(let msg)? = root["message"], msg != "ok" {
            return msg
        }
        if case .array(let items)? = root["result"], let first = items.first,
           case .object(let dict) = first,
           case .int(let code)? = dict["code"], code != 0 {
            return "设备错误码 \(code)"
        }
        return nil
    }
}

// MARK: - 本地定时 0xAA 二进制协议（已实测破解）

/// 设备固件本地定时（siid=7 piid=1）：
/// `AA 06 [en(1) week(1) hour(1) min(1) action(1) checksum(1)]`
/// checksum = (前 5 字节之和 + 0x06) & 0xFF
/// week: bit 掩码 bit0=周一 … bit6=周日（0x7F=每天）
/// action: 0=关 1=开
struct LocalTimer: Equatable {
    var enabled: Bool
    var weekdays: Set<Int>   // 0=周一 … 6=周日
    var hour: Int
    var minute: Int
    var turnsOn: Bool

    static func parse(hex: String) -> LocalTimer? {
        let b = Self.bytes(hex: hex)
        guard b.count >= 8, b[0] == 0xAA, b[1] == 0x06 else { return nil }
        let en = b[2], week = b[3], hh = b[4], mm = b[5], act = b[6]
        guard hh < 24, mm < 60 else { return nil }
        var days = Set<Int>()
        for i in 0..<7 where week & (1 << i) != 0 { days.insert(i) }
        return LocalTimer(
            enabled: en != 0,
            weekdays: days,
            hour: Int(hh),
            minute: Int(mm),
            turnsOn: act != 0
        )
    }

    var encoded: String {
        var week: UInt8 = 0
        for d in weekdays { week |= UInt8(1 << d) }
        let body: [UInt8] = [
            enabled ? 1 : 0,
            week,
            UInt8(hour),
            UInt8(minute),
            turnsOn ? 1 : 0,
        ]
        let cs = (body.reduce(0, +) + 6) & 0xFF
        let all: [UInt8] = [0xAA, 0x06] + body + [UInt8(cs)]
        return all.map { String(format: "%02x", $0) }.joined()
    }

    private static func bytes(hex: String) -> [UInt8] {
        var out: [UInt8] = []
        var i = hex.startIndex
        while i < hex.endIndex, let next = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) {
            if let b = UInt8(hex[i..<next], radix: 16) { out.append(b) }
            i = next
        }
        return out
    }

    var weekTitle: String {
        let names = ["一", "二", "三", "四", "五", "六", "日"]
        if weekdays.count == 7 { return "每天" }
        if weekdays == Set([0, 1, 2, 3, 4]) { return "工作日" }
        if weekdays == Set([5, 6]) { return "周末" }
        if weekdays.isEmpty { return "仅一次" }
        return weekdays.sorted().map { names[$0] }.joined(separator: " ")
    }

    var timeTitle: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - 场景与消息模型

struct MiScene: Identifiable, Hashable {
    let id: String
    let name: String
}

struct MiMessage: Identifiable, Hashable {
    let text: String
    let timestamp: Int64
    var id: String { "\(timestamp)-\(text)" }
}

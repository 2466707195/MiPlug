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

    private static func signString(_ method: String, _ path: String, _ sn: String, _ params: [String: String]) -> String {
        var parts = [method.uppercased(), path.replacingOccurrences(of: "/app/", with: "/")]
        for (k, v) in params { parts.append("\(k)=\(v)") }
        parts.append(sn)
        return parts.joined(separator: "&")
    }

    // MARK: - 请求

    /// path 形如 "/app/miotspec/prop/get"，dataObj 为请求 JSON
    func call(path: String, dataObj: JSONValue) throws -> JSONValue {
        guard let url = URL(string: Self.apiBase + path) else { throw MiCloudError.badResponse }

        // nonce / signedNonce
        var nonceBytes: [UInt8] = (0..<8).map { _ in UInt8.random(in: 0...255) }
        let minutes = UInt32(Date().timeIntervalSince1970 / 600)
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
        let plainParams = ["data": dataStr]
        let rc4Hash = Self.b64encode(Self.sha1(Self.signString("POST", path, sn, plainParams)))

        // RC4 加密
        let key = Self.b64decode(sn)
        let dataEnc = Self.b64encode(Self.rc4Primed(key, Array(dataStr.utf8)))
        let rc4HashEnc = Self.b64encode(Self.rc4Primed(key, Array(rc4Hash.utf8)))

        // 第二轮签名：signature（对密文 params 签）
        let encParams = ["data": dataEnc, "rc4_hash__": rc4HashEnc]
        let signature = Self.b64encode(Self.sha1(Self.signString("POST", path, sn, encParams)))

        // 组表单
        let form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "data", value: dataEnc),
            URLQueryItem(name: "rc4_hash__", value: rc4HashEnc),
            URLQueryItem(name: "signature", value: signature),
            URLQueryItem(name: "ssecurity", value: ssecurity),
            URLQueryItem(name: "_nonce", value: nonce),
        ]

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.httpBody = form.percentEncodedQuery?.data(using: .utf8)
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

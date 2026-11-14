//
//  MiIOLocalClient.swift
//  MiPlug
//
//  miIO 本地协议（UDP :54321），加密实现严格对应 python-miio protocol.py：
//  AES-128-CBC，key = MD5(token)，iv = MD5(key + token)，payload 末尾补 0x00，
//  校验和 = MD5(header + token + encrypted)。
//

import Foundation
import CommonCrypto

enum MiIOError: Error, LocalizedError {
    case handshakeFailed
    case timeout
    case decryptFailed
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .handshakeFailed: return "设备无响应（不在局域网内？）"
        case .timeout: return "设备超时未响应"
        case .decryptFailed: return "数据解密失败（token 不对？）"
        case .apiError(let m): return m
        }
    }
}

struct MiIOLocalClient {

    let host: String
    let token: [UInt8]     // 16 字节
    let deviceID: [UInt8]  // 4 字节

    init(device: PlugDevice) {
        self.host = device.localIP
        self.token = Self.hexBytes(device.localToken)
        self.deviceID = Self.hexBytes(device.deviceIDHex)
    }

    private static func hexBytes(_ hex: String) -> [UInt8] {
        var out: [UInt8] = []
        var i = hex.startIndex
        while i < hex.endIndex, let next = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) {
            if let b = UInt8(hex[i..<next], radix: 16) { out.append(b) }
            i = next
        }
        // 奇数长度兜底
        if i < hex.endIndex, let b = UInt8(String(hex[i]), radix: 16) { out.append(b) }
        return out
    }

    // MARK: - 加密（AES-128-CBC + PKCS7）

    private static func md5(_ data: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                _ = CC_MD5(src.baseAddress, CC_LONG(data.count), dst.baseAddress)
            }
        }
        return out
    }

    /// 明文 = JSON + 0x00，PKCS7 由本函数补齐（与 python-miio 的 padder 语义一致）
    private func encryptPayload(_ plaintext: [UInt8]) throws -> [UInt8] {
        let key = Self.md5(token)
        let iv = Self.md5(key + token)
        var padded = plaintext
        let padLen = 16 - (padded.count % 16)
        padded += [UInt8](repeating: UInt8(padLen), count: padLen)
        return try Self.cbc(padded, key: key, iv: iv, encrypt: true)
    }

    private func decryptPayload(_ ciphertext: [UInt8]) throws -> [UInt8] {
        let key = Self.md5(token)
        let iv = Self.md5(key + token)
        guard ciphertext.count % 16 == 0, !ciphertext.isEmpty else { throw MiIOError.decryptFailed }
        let raw = try Self.cbc(ciphertext, key: key, iv: iv, encrypt: false)
        guard let last = raw.last, last > 0, Int(last) <= 16 else { return raw }
        return Array(raw.dropLast(Int(last)))
    }

    private static func cbc(_ input: [UInt8], key: [UInt8], iv: [UInt8], encrypt: Bool) throws -> [UInt8] {
        var out = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var moved: Int = 0
        let status = CCCrypt(
            encrypt ? CCOperation(kCCEncrypt) : CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(0),  // CBC，无 PKCS7（自己 pad）
            key, key.count,
            iv,
            input, input.count,
            &out, out.count, &moved
        )
        guard status == kCCSuccess else { throw MiIOError.decryptFailed }
        return Array(out[0..<moved])
    }

    // MARK: - 包构造

    /// hello: magic(2) + len=32(2) + unknown=0(4) + devid(4) + ts(4) + 其余全FF
    private static let hello: [UInt8] = {
        var p: [UInt8] = [0x21, 0x31, 0x00, 0x20]
        p += [UInt8](repeating: 0, count: 8)
        p += [UInt8](repeating: 0xFF, count: 24)
        return p
    }()

    private func buildCommand(plaintext: [UInt8], ts: UInt32) throws -> [UInt8] {
        let enc = try encryptPayload(plaintext)
        var header: [UInt8] = [0x21, 0x31]
        let total = UInt16(32 + enc.count).bigEndian
        withUnsafeBytes(of: total) { header += Array($0) }
        header += [UInt8](repeating: 0, count: 4)          // unknown
        header += deviceID
        withUnsafeBytes(of: (ts &+ 1).bigEndian) { header += Array($0) }
        let checksum = Self.md5(header + token + enc)
        return header + enc + checksum
    }

    // MARK: - 通信

    private func udpRound(_ packet: [UInt8], timeout: TimeInterval = 3) throws -> [UInt8] {
        let sock = try DatagramSocket()
        defer { sock.close() }
        try sock.send(packet, to: host, port: PlugDevice.miioPort)
        return try sock.receive(timeout: timeout)
    }

    /// 握手：返回设备时间戳（秒）
    func handshake() throws -> UInt32 {
        let resp = try udpRound(Self.hello)
        guard resp.count >= 16, resp[0] == 0x21, resp[1] == 0x31 else {
            throw MiIOError.handshakeFailed
        }
        return UInt32(resp[12]) << 24 | UInt32(resp[13]) << 16 | UInt32(resp[14]) << 8 | UInt32(resp[15])
    }

    /// 发送一条 miIO 指令，返回解析后的 JSON
    func send(method: String, params: JSONValue, deviceTS: UInt32) throws -> JSONValue {
        let request: JSONValue = .object([
            "id": .int(1),
            "method": .string(method),
            "params": params
        ])
        var body = try JSONValue.minified(request)
        body.append(0x00)  // 官方实现明文末尾补 0x00

        let packet = try buildCommand(plaintext: body, ts: deviceTS)
        let resp = try udpRound(packet)
        guard resp.count > 32 else { throw MiIOError.timeout }
        let cipher = Array(resp[16..<(resp.count - 16)])
        var plain = try decryptPayload(cipher)
        while plain.last == 0x00 { plain = Array(plain.dropLast()) }
        guard let obj = JSONValue.parse(Data(plain)) else {
            throw MiIOError.decryptFailed
        }
        return obj
    }

    /// 便捷：读开关属性 siid=2 piid=1
    func readPower(deviceTS: UInt32) throws -> Bool {
        let prop: JSONValue = .array([.object([
            "did": .string("2_1"),
            "siid": .int(2),
            "piid": .int(1)
        ])])
        let resp = try send(method: "get_properties", params: prop, deviceTS: deviceTS)
        if case .array(let items) = resp, let first = items.first,
           case .object(let dict) = first,
           let v = dict["value"] {
            switch v {
            case .bool(let b): return b
            case .int(let i): return i != 0
            case .double(let d): return d != 0
            default: return false
            }
        }
        if case .object(let err) = resp, err["error"] != nil {
            throw MiIOError.apiError(String(describing: err["error"]))
        }
        throw MiIOError.decryptFailed
    }

    /// 便捷：写开关属性 siid=2 piid=1
    func writePower(_ on: Bool, deviceTS: UInt32) throws {
        let prop: JSONValue = .array([.object([
            "did": .string("2_1"),
            "siid": .int(2),
            "piid": .int(1),
            "value": .bool(on)
        ])])
        let resp = try send(method: "set_properties", params: prop, deviceTS: deviceTS)
        if case .object(let err) = resp, err["error"] != nil {
            throw MiIOError.apiError(String(describing: err["error"]))
        }
    }
}

// MARK: - 极简 JSON 值

enum JSONValue {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    static func parse(_ data: Data) -> JSONValue? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return fromAny(obj)
    }

    static func fromAny(_ any: Any) -> JSONValue {
        switch any {
        case is NSNull: return .null
        case let b as Bool: return .bool(b)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .bool(n.boolValue) }
            if n.doubleValue.truncatingRemainder(dividingBy: 1) == 0 && abs(n.doubleValue) < 1e15 {
                return .int(n.intValue)
            }
            return .double(n.doubleValue)
        case let s as String: return .string(s)
        case let a as [Any]: return .array(a.map(fromAny))
        case let o as [String: Any]:
            var dict: [String: JSONValue] = [:]
            for (k, v) in o { dict[k] = fromAny(v) }
            return .object(dict)
        default: return .null
        }
    }

    static func minified(_ v: JSONValue) throws -> [UInt8] {
        let data = try JSONSerialization.data(withJSONObject: anyFrom(v))
        return Array(data)
    }

    static func jsonAny(_ v: JSONValue) -> Any {
        return anyFrom(v)
    }

    static func anyFrom(_ v: JSONValue) -> Any {
        switch v {
        case .null: return NSNull()
        case .bool(let b): return b
        case .int(let i): return i
        case .double(let d): return d
        case .string(let s): return s
        case .array(let a): return a.map(anyFrom)
        case .object(let o):
            var dict: [String: Any] = [:]
            for (k, v) in o { dict[k] = anyFrom(v) }
            return dict
        }
    }
}

// MARK: - 同步 UDP socket（POSIX，select 超时）

final class DatagramSocket {
    private let fd: Int32

    init() throws {
        fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw MiIOError.handshakeFailed }
    }

    func close() {
        Darwin.close(fd)
    }

    deinit {
        Darwin.close(fd)
    }

    func send(_ data: [UInt8], to host: String, port: UInt16) throws {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            throw MiIOError.handshakeFailed
        }
        let sent = withUnsafePointer(to: &addr) { ptr -> Int in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                data.withUnsafeBufferPointer { buf in
                    sendto(fd, buf.baseAddress, data.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == data.count else { throw MiIOError.handshakeFailed }
    }

    func receive(timeout: TimeInterval) throws -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: 4096)
        var n: Int = 0
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var readSet = fd_set()
            __darwin_fd_zero(&readSet)
            __darwin_fd_set(fd, &readSet)
            var remaining = deadline.timeIntervalSinceNow
            var tv = timeval(tv_sec: Int(remaining), tv_usec: Int32((remaining.truncatingRemainder(dividingBy: 1)) * 1_000_000))
            let ready = select(fd + 1, &readSet, nil, nil, &tv)
            if ready <= 0 { continue }
            n = recv(fd, &buf, buf.count, 0)
            if n > 0 { break }
        }
        guard n > 0 else { throw MiIOError.timeout }
        return Array(buf[0..<n])
    }
}

// fd_set 操作（Darwin 的 fd_set 是元组，没法直接下标，用内存操作实现）
private func __darwin_fd_zero(_ set: inout fd_set) {
    withUnsafeMutableBytes(of: &set) { $0.initializeMemory(as: UInt8.self, repeating: 0) }
}

private func __darwin_fd_set(_ fd: Int32, _ set: inout fd_set) {
    withUnsafeMutableBytes(of: &set) { raw in
        let byteIdx = Int(fd / 8)
        guard byteIdx < raw.count else { return }
        raw[byteIdx] |= UInt8(1 << (fd % 8))
    }
}

//
//  AppModel.swift
//  MiPlug
//
//  全局状态机：通道选择 / 开关状态 / 操作反馈。
//

import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {

    // MARK: - 状态

    enum ChannelStatus: Equatable {
        case idle          // 未探测
        case available     // 可用
        case unavailable   // 不可达
        case busy          // 正在请求
    }

    @Published var state: PlugState = .checking
    @Published var channel: PlugChannel = .local
    @Published var localStatus: ChannelStatus = .idle
    @Published var cloudStatus: ChannelStatus = .idle
    @Published var lastError: String?
    @Published var busy = false

    // 定时 / 场景 / 记录
    @Published var timer: LocalTimer?
    @Published var timerLoading = false
    @Published var scenes: [MiScene] = []
    @Published var scenesLoading = false
    @Published var runningScene: String?
    @Published var messages: [MiMessage] = []
    @Published var messagesLoading = false

    let device = PlugDevice.bedroom
    let homeID = "97001615862"

    private let local = MiIOLocalClient(device: PlugDevice.bedroom)
    private let cloud = MiCloudClient(
        userID: MiCredentials.userID,
        ssecurity: MiCredentials.ssecurity,
        serviceToken: MiCredentials.serviceToken
    )

    // MARK: - 查询

    /// 刷新当前通道的状态；顺带探测另一条通道的可用性
    func refresh() {
        guard !busy else { return }
        busy = true
        lastError = nil
        state = .checking

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let current = await MainActor.run { self.channel }

            // 当前通道查询状态
            var readError: String?
            var power: Bool?
            switch current {
            case .local:
                do {
                    let ts = try self.local.handshake()
                    power = try self.local.readPower(deviceTS: ts)
                    await MainActor.run { self.localStatus = .available }
                } catch {
                    readError = error.localizedDescription
                    await MainActor.run { self.localStatus = .unavailable }
                }
            case .cloud:
                do {
                    power = try self.cloud.readPower(device: self.device)
                    await MainActor.run { self.cloudStatus = .available }
                } catch {
                    readError = error.localizedDescription
                    await MainActor.run { self.cloudStatus = .unavailable }
                }
            }

            // 另一条通道只探测可用性（本地握手很快；云端一次轻查询太贵，跳过）
            switch current {
            case .local:
                do {
                    _ = try self.local.handshake()
                } catch { }
            case .cloud:
                break
            }

            let err = readError
            let p = power
            await MainActor.run {
                self.busy = false
                if let p {
                    self.state = p ? .on : .off
                } else {
                    self.state = .unknown
                    self.lastError = err
                    // 本地失败自动切云端重试一次
                    if current == .local {
                        self.channel = .cloud
                        self.refresh()
                    }
                }
            }
        }
    }

    // MARK: - 开关

    func setPower(_ on: Bool) {
        guard !busy else { return }
        busy = true
        lastError = nil

        // 乐观更新
        state = on ? .on : .off

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let current = await MainActor.run { self.channel }

            do {
                switch current {
                case .local:
                    let ts = try self.local.handshake()
                    try self.local.writePower(on, deviceTS: ts)
                    let p = try self.local.readPower(deviceTS: ts &+ 1)
                    await MainActor.run {
                        self.localStatus = .available
                        self.state = p ? .on : .off
                        self.busy = false
                    }
                case .cloud:
                    try self.cloud.writePower(on, device: self.device)
                    let p = try self.cloud.readPower(device: self.device)
                    await MainActor.run {
                        self.cloudStatus = .available
                        self.state = p ? .on : .off
                        self.busy = false
                    }
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self.busy = false
                    self.lastError = msg
                    // 当前通道失败：切通道并重试一次
                    let fallback: PlugChannel = (current == .local) ? .cloud : .local
                    self.channel = fallback
                    self.setPowerRetry(on, via: fallback)
                }
            }
        }
    }

    private func setPowerRetry(_ on: Bool, via: PlugChannel) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                switch via {
                case .local:
                    let ts = try self.local.handshake()
                    try self.local.writePower(on, deviceTS: ts)
                    let p = try self.local.readPower(deviceTS: ts &+ 1)
                    await MainActor.run {
                        self.localStatus = .available
                        self.state = p ? .on : .off
                    }
                case .cloud:
                    try self.cloud.writePower(on, device: self.device)
                    let p = try self.cloud.readPower(device: self.device)
                    await MainActor.run {
                        self.cloudStatus = .available
                        self.state = p ? .on : .off
                    }
                }
            } catch {
                let msg = error.localizedDescription
                let failed: PlugChannel = via
                await MainActor.run {
                    self.state = .unknown
                    self.lastError = "两条通道都失败了：\(msg)"
                    if failed == .local {
                        self.localStatus = .unavailable
                    } else {
                        self.cloudStatus = .unavailable
                    }
                }
            }
        }
    }

    /// 首次进入页面刷新
    func refreshOnLaunch() {
        refresh()
    }

    // MARK: - 定时

    func loadTimer() {
        guard !timerLoading else { return }
        timerLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let t = try self.cloud.readLocalTimer(device: self.device)
                await MainActor.run {
                    self.timer = t
                    self.timerLoading = false
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self.timer = nil
                    self.timerLoading = false
                    self.lastError = "读取定时失败：\(msg)"
                }
            }
        }
    }

    func saveTimer(_ t: LocalTimer) {
        timerLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try self.cloud.writeLocalTimer(t, device: self.device)
                let confirmed = try self.cloud.readLocalTimer(device: self.device)
                await MainActor.run {
                    self.timer = confirmed ?? t
                    self.timerLoading = false
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self.timerLoading = false
                    self.lastError = "保存定时失败：\(msg)"
                }
            }
        }
    }

    // MARK: - 场景

    func loadScenes() {
        guard !scenesLoading else { return }
        scenesLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let list = try self.cloud.listScenes(homeID: self.homeID)
                await MainActor.run {
                    self.scenes = list
                    self.scenesLoading = false
                }
            } catch {
                await MainActor.run {
                    self.scenesLoading = false
                }
            }
        }
    }

    func runScene(_ scene: MiScene) {
        guard runningScene == nil else { return }
        runningScene = scene.id
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try self.cloud.runScene(sceneID: scene.id)
                await MainActor.run {
                    self.runningScene = nil
                    self.toastText = "已执行「\(scene.name)」"
                }
            } catch {
                let msg = error.localizedDescription
                await MainActor.run {
                    self.runningScene = nil
                    self.lastError = "执行失败：\(msg)"
                }
            }
        }
    }

    // MARK: - 记录

    func loadMessages() {
        guard !messagesLoading else { return }
        messagesLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let list = try self.cloud.fetchMessages(homeID: self.homeID, device: self.device)
                await MainActor.run {
                    self.messages = list
                    self.messagesLoading = false
                }
            } catch {
                await MainActor.run {
                    self.messagesLoading = false
                }
            }
        }
    }

    @Published var toastText: String?
}

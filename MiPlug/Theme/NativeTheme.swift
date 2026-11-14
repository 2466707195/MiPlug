//
//  NativeTheme.swift
//  ios-native-minimal
//
//  iOS Native Minimal 设计 token。所有页面只从这里取值，禁止在页面里写十六进制。
//  对应文档：references/tokens.md
//

import SwiftUI

public enum NativeUI {

    // MARK: - 颜色

    /// 全屏浅灰底 #F2F2F7
    public static let bg = Color(hex: 0xF2F2F7)
    /// 卡片 / 悬浮输入胶囊 / AI 气泡
    public static let card = Color.white
    /// 主文字
    public static let ink = Color.black
    /// 次要文字 #666666
    public static let secondary = Color(hex: 0x666666)
    /// 占位符、未选中图标
    public static let tertiary = Color(hex: 0x9A9AA0)
    /// 链接与动作 #007AFF
    public static let accent = Color(hex: 0x007AFF)
    /// 0.5pt 细线
    public static let hairline = Color(hex: 0xE9E9EE)
    /// 浅灰底控件（圆钮、次按钮、胶囊槽）
    public static let fill = Color(hex: 0xE9E9EE)
    /// 更深一档的灰底（按下态）
    public static let fillStrong = Color(hex: 0xDFDFE5)
    /// 用户气泡 #FCE8F0
    public static let userBubble = Color(hex: 0xFCE8F0)
    /// 删除类文字
    public static let danger = Color(hex: 0xFF3B30)
    /// 仅用于在线状态圆点
    public static let success = Color(hex: 0x34C759)

    // MARK: - 节奏

    public enum Metric {
        /// 页面左右边距（输入胶囊同值）
        public static let page: CGFloat = 16
        /// 卡片组之间的垂直间距
        public static let cardGap: CGFloat = 16
        /// 标准行高
        public static let rowHeight: CGFloat = 56
        /// 行内左右内边距
        public static let rowInset: CGFloat = 16
        /// 行内图标边长
        public static let icon: CGFloat = 22
        /// 图标 ↔ 文字
        public static let iconGap: CGFloat = 12
        /// 悬浮输入胶囊 ↔ 系统底栏上沿
        public static let composerGap: CGFloat = 12
        /// 悬浮输入胶囊内边距
        public static let composerInset: CGFloat = 8
        /// 最小点击区
        public static let minTap: CGFloat = 44
        /// 圆形返回钮直径
        public static let circleButton: CGFloat = 44
        /// 输入框高度
        public static let fieldHeight: CGFloat = 44

        /// 细线左内缩：对齐文字起始位置（16 + 26 + 12 = 54）
        public static var dividerInset: CGFloat { rowInset + icon + 4 + iconGap }
    }

    // MARK: - 圆角（只有两档在跑）

    public enum Radius {
        /// 卡片组 / 输入胶囊 / 大容器
        public static let outer: CGFloat = 20
        /// 卡片内单行 / 输入框 / 图片块
        public static let inner: CGFloat = 14
        /// 气泡
        public static let bubble: CGFloat = 20
        /// 气泡贴边那一角
        public static let bubbleTail: CGFloat = 6
    }

    // MARK: - 字阶（SF Pro，.system 自动取 Text / Display）

    public enum Fonts {
        /// 34 bold —— 主页 / 抽屉大标题，左对齐
        public static let largeTitle = SwiftUI.Font.system(size: 34, weight: .bold)
        /// 17 semibold —— 子页居中标题
        public static let navTitle = SwiftUI.Font.system(size: 17, weight: .semibold)
        /// 13 semibold —— 分区小标题
        public static let section = SwiftUI.Font.system(size: 13, weight: .semibold)
        /// 16 regular —— 正文 / 行标题 / 气泡 / 输入
        public static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        /// 16 semibold —— 行标题里的强调（不要拿颜色强调）
        public static let bodyEmph = SwiftUI.Font.system(size: 16, weight: .semibold)
        /// 14 regular —— 说明 / 行右侧详情
        public static let secondary = SwiftUI.Font.system(size: 14, weight: .regular)
        /// 12 regular —— 时间戳 / 脚注
        public static let caption = SwiftUI.Font.system(size: 12, weight: .regular)
        /// 16 medium —— 按钮
        public static let button = SwiftUI.Font.system(size: 16, weight: .medium)
    }

    /// 正文行距
    public static let lineSpacingBody: CGFloat = 3
    /// 次要文字行距
    public static let lineSpacingSecondary: CGFloat = 2

    // MARK: - 阴影（全屏唯一一处：悬浮输入胶囊）

    public static let composerShadowColor = Color.black.opacity(0.06)
    public static let composerShadowRadius: CGFloat = 18
    public static let composerShadowY: CGFloat = 8

    // MARK: - 动效

    public enum Motion {
        /// Tab / 胶囊切换
        public static let control = Animation.spring(response: 0.32, dampingFraction: 0.86)
        /// 气泡出现
        public static let bubble = Animation.spring(response: 0.42, dampingFraction: 0.8)
        /// 抽屉推拉
        public static let drawer = Animation.spring(response: 0.38, dampingFraction: 0.88)
        /// 通用淡入淡出
        public static let fade = Animation.easeInOut(duration: 0.18)
    }
}

// MARK: - 常用修饰器

public extension View {

    /// 白卡：20pt 连续圆角，无阴影无描边。
    func nativeCard(radius: CGFloat = NativeUI.Radius.outer) -> some View {
        background(
            NativeUI.card,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }

    /// 悬浮输入胶囊唯一允许的阴影。
    func nativeComposerShadow() -> some View {
        shadow(
            color: NativeUI.composerShadowColor,
            radius: NativeUI.composerShadowRadius,
            x: 0,
            y: NativeUI.composerShadowY
        )
    }

    /// 页面底色。TabView 的背景归系统，所以每个 Tab 的内容都要自己铺 #F2F2F7。
    func nativePageBackground() -> some View {
        background(NativeUI.bg.ignoresSafeArea())
    }

    /// 浅灰圆形/胶囊底（返回钮、次按钮、图标按钮）。
    func nativeFillBackground(radius: CGFloat) -> some View {
        background(
            NativeUI.fill,
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
    }

    /// 让某个视图吃掉空白处的点击（自绘浮层需要，系统底栏不需要）。
    func swallowTaps() -> some View {
        contentShape(Rectangle()).onTapGesture { }
    }
}

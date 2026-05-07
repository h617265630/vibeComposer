import SwiftUI

// MARK: - 引导页面

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部进度条
            progressBar

            // 内容区域
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                step1Page.tag(1)
                step2Page.tag(2)
                step3Page.tag(3)
                step4Page.tag(4)
                summaryPage.tag(5)
            }
            .tabViewStyle(.automatic)
            .background(Color.white)

            Divider()

            // 底部控制
            bottomControls
        }
        .frame(width: 850, height: 620)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: 15)
    }

    // MARK: - 进度条
    private var progressBar: some View {
        let steps = ["开始", "打开项目", "记录生成", "对齐检查", "验收确认", "完成"]
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    VStack(spacing: 6) {
                        ZStack {
                            if index <= currentPage {
                                Circle()
                                    .fill(VibeTheme.accent)
                                    .frame(width: 24, height: 24)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                            if index < currentPage {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else if index == currentPage {
                                Text("\(index)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(index)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.gray)
                            }
                        }
                        Text(steps[index])
                            .font(.system(size: 10))
                            .foregroundStyle(index <= currentPage ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentPage ? VibeTheme.accent : Color.gray.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
    }

    // MARK: - 底部控制
    private var bottomControls: some View {
        HStack {
            if currentPage > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage -= 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一步")
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if currentPage < 5 {
                Button("跳过") {
                    onComplete()
                }
                .font(.system(size: 13))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentPage == 0 ? "开始引导" : "下一步")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(VibeTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onComplete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rocket.fill")
                        Text("开始使用")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(VibeTheme.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
    }

    // MARK: - 页面内容

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            // Logo 和标题
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [VibeTheme.accent, VibeTheme.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: VibeTheme.accent.opacity(0.4), radius: 15, x: 0, y: 8)

                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text("vibeComposer")
                    .font(.system(size: 32, weight: .bold))

                Text("让 Vibe Coding 可控、可追踪、可验收")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }

            // 核心价值
            HStack(spacing: 20) {
                valueCard(icon: "doc.badge.plus", title: "记录", desc: "LLM 生成了什么")
                valueCard(icon: "arrow.left.arrow.right", title: "检查", desc: "是否符合需求")
                valueCard(icon: "checkmark.shield", title: "验收", desc: "确认实现成果")
            }

            Spacer()
        }
        .padding(32)
        .background(Color.white)
    }

    private func valueCard(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(VibeTheme.accent)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(width: 130, height: 90)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var step1Page: some View {
        VStack(spacing: 0) {
            stepHeader(
                number: "1",
                title: "打开你的项目",
                subtitle: "选择一个本地项目文件夹，vibeComposer 会自动扫描项目结构"
            )

            Spacer()

            // 操作示意
            HStack(spacing: 30) {
                // 左侧：操作步骤
                VStack(alignment: .leading, spacing: 14) {
                    stepItem(number: "1.1", text: "点击右上角「打开项目」按钮", highlight: true)
                    stepItem(number: "1.2", text: "选择你的项目根目录", highlight: false)
                    stepItem(number: "1.3", text: "等待扫描完成（约 3-10 秒）", highlight: false)

                    Divider()
                        .frame(width: 240)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("支持的项目类型：")
                            .font(.system(size: 11, weight: .medium))
                        HStack(spacing: 6) {
                            typeBadge("React/Vue")
                            typeBadge("Next.js")
                            typeBadge("Python")
                        }
                        HStack(spacing: 6) {
                            typeBadge("iOS/macOS")
                            typeBadge("Go")
                            typeBadge("Rust")
                        }
                    }
                }
                .frame(width: 280)

                // 右侧：截图示意
                screenshotPlaceholder(
                    title: "项目概览",
                    items: ["前端页面: 12 个", "后端 API: 8 个", "数据库表: 5 个", "AI 逻辑: 3 个"]
                )
            }

            Spacer()
        }
        .padding(28)
        .background(Color.white)
    }

    private var step2Page: some View {
        VStack(spacing: 0) {
            stepHeader(
                number: "2",
                title: "记录 LLM 生成内容",
                subtitle: "每次让 LLM 生成代码后，在这里记录下来"
            )

            Spacer()

            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 14) {
                    stepItem(number: "2.1", text: "切换到「生成记录」标签页", highlight: true)
                    stepItem(number: "2.2", text: "点击「记录新生成」按钮", highlight: true)
                    stepItem(number: "2.3", text: "填写：Prompt、响应摘要、文件路径", highlight: false)
                    stepItem(number: "2.4", text: "选择生成类型（页面/API/数据库）", highlight: false)

                    Divider()
                        .frame(width: 240)

                    tipBox(text: "💡 也可以让 vibeComposer 自动推断新生成的文件")
                }
                .frame(width: 280)

                screenshotPlaceholder(
                    title: "生成记录",
                    items: ["记录 1: 用户登录页面", "记录 2: 订单 API", "记录 3: 用户表结构", "+ 添加新记录"]
                )
            }

            Spacer()
        }
        .padding(28)
        .background(Color.white)
    }

    private var step3Page: some View {
        VStack(spacing: 0) {
            stepHeader(
                number: "3",
                title: "检查需求-实现对齐",
                subtitle: "查看每个需求是否都有对应的实现"
            )

            Spacer()

            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 14) {
                    stepItem(number: "3.1", text: "切换到「对齐分析」标签页", highlight: true)
                    stepItem(number: "3.2", text: "查看需求列表和匹配结果", highlight: false)
                    stepItem(number: "3.3", text: "关注「缺失」和「风险」标记", highlight: true)
                    stepItem(number: "3.4", text: "点击「生成 AI 检查 Prompt」", highlight: false)

                    Divider()
                        .frame(width: 240)

                    tipBox(text: "⚠️ 红色风险标记表示可能遗漏的实现")
                }
                .frame(width: 280)

                screenshotPlaceholder(
                    title: "对齐分析",
                    items: ["✅ 用户登录 → LoginPage, AuthAPI", "✅ 订单管理 → OrderPage, OrderAPI", "⚠️ 支付功能 → [缺失]", "✅ 用户表 → users table"]
                )
            }

            Spacer()
        }
        .padding(28)
        .background(Color.white)
    }

    private var step4Page: some View {
        VStack(spacing: 0) {
            stepHeader(
                number: "4",
                title: "验收并确认",
                subtitle: "逐项检查实现成果，决定通过、重做或跳过"
            )

            Spacer()

            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 14) {
                    stepItem(number: "4.1", text: "切换到「控制中心」标签页", highlight: true)
                    stepItem(number: "4.2", text: "点击「开始验收会话」", highlight: true)
                    stepItem(number: "4.3", text: "逐项检查，选择：通过/重做/跳过", highlight: false)
                    stepItem(number: "4.4", text: "验收完成后更新基线", highlight: false)

                    Divider()
                        .frame(width: 240)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("验收选项说明：")
                            .font(.system(size: 11, weight: .medium))
                        Text("✅ 通过 - 实现正确，可以继续")
                            .font(.system(size: 11))
                        Text("🔄 重做 - 需要重新让 LLM 生成")
                            .font(.system(size: 11))
                        Text("⏭️ 跳过 - 暂时跳过，稍后处理")
                            .font(.system(size: 11))
                    }
                }
                .frame(width: 280)

                screenshotPlaceholder(
                    title: "控制中心",
                    items: ["待验收: 5 项", "已通过: 3 项", "需重做: 1 项", "当前轮次: 第 2 轮"]
                )
            }

            Spacer()
        }
        .padding(28)
        .background(Color.white)
    }

    private var summaryPage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 50))
                .foregroundStyle(VibeTheme.green)

            Text("准备就绪！")
                .font(.system(size: 24, weight: .bold))

            Text("完整工作流程")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            // 流程图
            HStack(spacing: 10) {
                flowStep(icon: "1.circle.fill", title: "打开项目", desc: "扫描结构")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                flowStep(icon: "2.circle.fill", title: "记录生成", desc: "LLM 输出")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                flowStep(icon: "3.circle.fill", title: "对齐检查", desc: "需求匹配")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                flowStep(icon: "4.circle.fill", title: "验收确认", desc: "通过/重做")
            }
            .padding(.vertical, 12)

            // 快捷键提示
            VStack(spacing: 8) {
                Text("快捷键")
                    .font(.system(size: 11, weight: .medium))

                HStack(spacing: 16) {
                    shortcutBadge(key: "⌘O", action: "打开项目")
                    shortcutBadge(key: "⌘R", action: "刷新扫描")
                    shortcutBadge(key: "⇧⌘G", action: "生成 Harness")
                }
            }

            Spacer()
        }
        .padding(24)
        .background(Color.white)
    }

    private func flowStep(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(VibeTheme.accent)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Text(desc)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(width: 75)
    }

    private func shortcutBadge(key: String, action: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(red: 0.9, green: 0.9, blue: 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(action)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 辅助组件

    private func stepHeader(number: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(number)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(VibeTheme.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 12)
    }

    private func stepItem(number: String, text: String, highlight: Bool) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(highlight ? VibeTheme.accent : .secondary)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(highlight ? .primary : .secondary)

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(highlight ? VibeTheme.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func typeBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(VibeTheme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func tipBox(text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 11))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.95, green: 0.97, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func screenshotPlaceholder(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.bottom, 2)

            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    if item.hasPrefix("+") {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(VibeTheme.accent)
                    } else if item.hasPrefix("✅") {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(VibeTheme.green)
                    } else if item.hasPrefix("⚠️") {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(VibeTheme.amber)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Text(item.replacingOccurrences(of: "✅ ", with: "").replacingOccurrences(of: "⚠️ ", with: ""))
                        .font(.system(size: 11))
                }
            }
        }
        .padding(14)
        .frame(width: 260, height: 200, alignment: .top)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
# vibeComposer

A macOS native desktop application for AI-assisted development workflow management and project composition.

## 功能定位

vibeComposer 是一个 **macOS 原生桌面应用**，专为管理 AI 辅助开发工作流而设计。它帮助开发者追踪和管理 AI 生成的代码变更，提供完整的项目分析和审查能力。

### 核心功能

1. **项目管理与扫描**
   - 打开本地项目文件夹
   - 扫描 Git 仓库、文件变更、项目结构
   - 分析前端页面、后端 API、数据库结构
   - 识别 AI Logic 和 .vibe harness 配置

2. **AI 工作追踪**
   - 追踪 AI 生成的代码和变更记录
   - 查看生成历史和代码对齐度
   - 管理开发轮次和审查流程

3. **Vibe Harness 生成**
   - 为 AI 辅助工具生成项目配置文件
   - 自动分析项目结构并生成 harness
   - 支持 Claude Code 等 AI 开发工具

4. **控制中心**
   - 管理开发轮次（Rounds）
   - 审查 AI 生成的代码变更
   - 追踪项目进度和状态

5. **多维度视图**
   - **概览视图** - 项目整体状态和进度
   - **看板视图** - 任务和问题管理
   - **AI 工作视图** - AI 生成内容追踪
   - **控制中心** - 轮次管理和审查
   - **生成记录** - 历史生成内容查看
   - **对齐分析** - 代码与目标对齐度分析
   - **技术详情** - 项目技术栈和结构详情

6. **用户体验**
   - 多主题支持（黑色/白色/深灰色主题）
   - 原生 macOS 界面设计
   - 实时刷新和状态更新
   - 完整的引导教程

## Features

- **Project Management** - Scan and manage development projects
- **AI Workflow Integration** - Work with Claude Code and AI development tools
- **Vibe Harness Generation** - Generate project harnesses for AI assistance
- **Review System** - Track and review AI-generated code changes
- **Progress Tracking** - Monitor development progress and activities
- **Theme Support** - Multiple theme options for comfortable coding

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 6.1 or later

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/h617265630/vibeComposer.git
cd vibeComposer

# Build the project
swift build

# Run the application
swift run vibeComposer
```

### Open in Xcode

```bash
open Package.swift
```

## Usage

1. **Open Project** - Use `⌘O` to open a project folder
2. **Refresh Scan** - Use `⌘R` to refresh project scan
3. **Generate Harness** - Use `⌘⇧G` to generate vibe harness
4. **Change Theme** - Access theme options from the menu bar

## Project Structure

```
vibeComposer/
├── Sources/vibeComposer/
│   ├── App/              # Application entry point
│   ├── Models/           # Data models
│   ├── Services/         # Business logic services
│   ├── Stores/           # State management
│   ├── Views/            # SwiftUI views
│   └── Support/          # Helper utilities
├── Tests/                # Unit tests
├── Resources/            # App resources
└── Package.swift         # Swift package manifest
```

## Architecture

- **SwiftUI** - Modern declarative UI framework
- **MVVM Pattern** - Model-View-ViewModel architecture
- **Combine** - Reactive programming for state management
- **Store Pattern** - Centralized state management with ProjectStore

## Development

### Run Tests

```bash
swift test
```

### Build Release

```bash
swift build -c release
```

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

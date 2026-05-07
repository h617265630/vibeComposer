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

## 支持的项目类型

vibeComposer 支持分析多种类型的项目，包括 Web 应用和原生 App：

### Web 前端项目
- **React** / **Next.js** - 组件、路由、Hooks 分析
- **Vue** / **Nuxt.js** - 页面、组件、模块检测
- **Angular** - 组件、服务、模块结构
- **Svelte** - 组件和路由分析
- 支持 TypeScript / JavaScript

### Web 后端项目
- **Python** (FastAPI, Flask, Django) - API 路由、服务层、数据库模型
- **Node.js** - Express、NestJS 等 API 端点
- 数据库表结构扫描（SQL、ORM 模型）
- AI Logic 检测（LangChain、OpenAI 等）

### Apple 平台项目（原生 App）
- **iOS** / **macOS** / **watchOS** / **tvOS**
- **SwiftUI Views** - 作为"页面"进行追踪
- **UIKit ViewControllers** - 视图控制器分析
- **Swift 数据模型** - 作为"数据库表"展示
- 支持 Xcode 项目和 Swift Package Manager

### 其他语言项目
- **Rust** (Cargo.toml) - 模块和结构分析
- **Go** (go.mod) - 包和模块检测
- **Java/Kotlin** (Maven/Gradle) - 类和依赖分析
- **Ruby** (Gemfile) - Rails 项目支持
- **PHP** (composer.json) - Laravel/Symfony 项目

### 扫描能力

**Web 项目：**
- 前端页面、组件、路由、状态管理
- 后端 API 端点、中间件、服务层
- 数据库表、关系、迁移文件
- AI Logic、Prompt、Agent 检测

**App 项目：**
- SwiftUI Views 和 UIKit ViewControllers
- Swift 数据模型和 Core Data 实体
- 网络服务、API 调用、Combine 发布者
- 平台检测（iOS/macOS/watchOS/tvOS）

## Features

- **Project Management** - Scan and manage development projects
- **AI Workflow Integration** - Work with Claude Code and AI development tools
- **Vibe Harness Generation** - Generate project harnesses for AI assistance
- **Review System** - Track and review AI-generated code changes
- **Progress Tracking** - Monitor development progress and activities
- **Theme Support** - Multiple theme options for comfortable coding
- **Multi-Project Support** - Web apps, native apps, and various languages

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

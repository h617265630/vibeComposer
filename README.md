# vibeComposer

A macOS SwiftUI application for AI-assisted development workflow management and project composition.

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

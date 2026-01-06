# SQLCipher Multi-Platform Build

自动构建 SQLCipher 静态库和头文件，支持多平台多架构。

## 支持的平台和架构

- **macOS**:  x86_64, arm64 (Apple Silicon)
- **Linux**: x86_64, arm64, armv7
- **Windows**: x86, x64

## 构建产物

每次构建会生成以下文件：
- `libsqlcipher.a` (macOS/Linux) 或 `sqlcipher.lib` (Windows)
- `sqlite3.h`
- `sqlcipher.h`

## 使用方法

1. Fork 本仓库
2. 推送代码或创建 Release 触发构建
3. 从 Actions Artifacts 或 Release Assets 下载构建产物

## 本地构建

### macOS/Linux
```bash
./build.sh
```

### Windows
```powershell
.\build.ps1
```

## License

本项目遵循 SQLCipher 的许可证。
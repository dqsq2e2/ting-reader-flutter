# Ting Reader Flutter

Ting Reader Flutter 是听悦的跨平台客户端，用于连接 Ting Reader 服务端，提供书架、书单、下载、本地离线播放和沉浸式播放体验。

## 平台能力

| 平台 | 播放 | 后台/系统媒体控制 | 本地下载 | 说明 |
| --- | --- | --- | --- | --- |
| Android | 支持 | 支持通知栏和锁屏媒体控制 | 支持 | 已配置通知权限、前台播放服务和 HTTP 局域网访问。 |
| iOS | 支持 | 支持系统 Now Playing/锁屏控制 | 支持 | 需要正常签名，并启用 Background Modes: Audio。 |
| macOS | 支持 | 支持系统媒体集成 | 支持 | 已启用 audio background 和网络客户端 entitlement。 |
| Windows | 支持 | 当前未接入系统媒体通知 | 支持 | 播放由 `just_audio_windows` 提供；系统媒体控制需要后续专门实现。 |
| Linux | 支持 | 当前未接入 MPRIS | 支持 | 播放由 `just_audio_media_kit` + `media_kit_libs_linux` 提供。 |
| Web | 支持 | 受浏览器后台策略限制 | 浏览器能力受限 | 适合预览和桌面浏览器使用。 |

## 本地开发

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Android 调试：

```powershell
flutter run -d android
flutter build apk --release
```

Windows 构建：

```powershell
flutter build windows --release
```

Linux 构建需要系统依赖：

```bash
sudo apt-get update
sudo apt-get install -y ninja-build libgtk-3-dev
flutter build linux --release
```

## 发布产物

GitHub Actions 会在推送 `v*` tag 或手动触发时构建以下产物：

- `ting-reader-flutter-android.apk`
- `ting-reader-flutter-android.aab`
- `TingReader-windows-x64.zip`
- `TingReader-linux-x64.tar.gz`
- `TingReader-macos.zip`
- `TingReader-ios-nosign.zip`

官网客户端下载接口会读取 `dqsq2e2/ting-reader-flutter` 的最新 Release，并使用这些固定文件名生成下载链接。

## 平台注意事项

- Android 13+ 首次启动会主动请求通知权限，避免通知栏播放器不可用。
- Windows 和 Linux 当前只保证应用内播放；系统级媒体通知/锁屏控制未接入。
- Linux 播放走 media_kit native libs；如果发行版改为系统 libmpv，需要同步调整打包依赖。
- iOS/macOS 的系统媒体能力需要真实设备和签名环境验证。

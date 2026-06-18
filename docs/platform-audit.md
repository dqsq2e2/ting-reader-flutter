# 平台依赖审计

审计日期：2026-06-18

## 播放器

- Android/iOS/macOS/Web：`just_audio` 提供播放内核。
- Windows：`just_audio_windows` 提供播放内核。
- Linux：`just_audio_media_kit` + `media_kit_libs_linux` 提供播放内核。

## 后台播放和系统媒体控制

- Android：`audio_service` + `just_audio_background`，Manifest 已配置前台媒体服务、媒体按键接收器、通知权限和唤醒锁。
- iOS：`audio_service` + `just_audio_background`，Info.plist 已配置 `UIBackgroundModes/audio`。
- macOS：`audio_service` + `just_audio_background`，Info.plist 已配置 audio background，entitlements 已补 `network.client`。
- Web：`audio_service_web` 可用，但后台行为由浏览器策略决定。
- Windows：当前依赖集中没有 `audio_service` Windows 实现，仅支持应用内播放。
- Linux：当前依赖集中没有 MPRIS 实现，仅支持应用内播放。

## 文件与本地状态

- Android/iOS/macOS/Windows/Linux/Web 都有 `path_provider` 和 `shared_preferences` 对应平台实现。
- `file_picker` 声明支持 Android/iOS/Web/macOS/Windows/Linux；桌面端文件选择不一定会在生成依赖摘要里单独列出，需要在 Windows/macOS/Linux 发布包中做缓存目录选择 smoke test。

## 发布验证建议

- Windows：CI 构建后至少验证登录、播放、下载目录读写。
- Linux：CI 构建环境安装 Flutter Linux 所需的 GTK/Ninja 依赖，播放 native libs 由 `media_kit_libs_linux` 提供。
- iOS/macOS：CI 只做 unsigned 构建，正式分发需要开发者证书和签名配置。

# AI 智能日记

基于 Flutter 的智能日记 App，集成 DeepSeek AI 云端分析，构建为无签名 iOS IPA。

## 功能

- **日记管理**：创建、编辑、删除日记，支持标签分类和心情记录
- **Markdown 编辑**：支持 Markdown 格式，编辑/预览切换
- **AI 心情分析**：自动分析日记情感，生成情绪曲线
- **AI 智能标签**：自动提取关键词作为标签
- **AI 日记总结**：生成周报/月报摘要
- **AI 写作灵感**：根据上下文生成日记写作引导
- **AI 对话**：向 AI 提问关于你日记的问题
- **年度报告**：生成个性化的年度回顾
- **本地存储**：SQLite 本地数据库，隐私安全
- **暗色模式**：跟随系统主题自动切换

## AI 配置

使用 DeepSeek API，兼容 OpenAI 格式的 API：

1. 访问 [platform.deepseek.com](https://platform.deepseek.com) 注册
2. 创建 API Key
3. 在 App 设置中填入 Key

## 构建 iOS IPA（无签名）

### 方法一：GitHub Actions（推荐，无需 Mac）

1. 将代码推送到 GitHub
2. GitHub Actions 自动构建（或手动触发）
3. 从 Artifacts 下载 `AIDiary-Unsigned-iOS-IPA.zip`

```bash
git init
git add -A
git commit -m "Initial commit"
gh repo create ai-diary --public --source=. --remote=origin --push
```

### 方法二：手动构建（需要 macOS + Xcode + Flutter）

```bash
flutter pub get
flutter build ios --release --no-codesign
cd build/ios/iphoneos
mkdir Payload
cp -r Runner.app Payload/
zip -r AIDiary-unsigned.ipa Payload/
```

## IPA 安装方式

| 方式 | 说明 |
|------|------|
| AltStore / Sideloadly | 免费 Apple ID 侧载 |
| 越狱设备 | 直接安装 |
| 模拟器 | `flutter run` 直接运行 |
| App Store 上架 | 需要 Apple Developer 账号 ($99/年) 重新签名 |

## 技术栈

- Flutter 3.2+
- SQLite (sqflite)
- Provider 状态管理
- HTTP 客户端
- DeepSeek API (OpenAI 兼容格式)

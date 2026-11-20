# 鲸鱼日记（Whale Diary）

一个**全本地**的 Android 日记 App：按天记录文字／照片／视频／语音，日历回看，周月年报告由 DeepSeek 生成。数据只存在手机上，只有「生成报告」这一步需要联网。

> 本项目由 **DeepSeek** 支持制作（AI 协助编码与设计）。Built with support from DeepSeek AI.

- 版本：1.1.0（versionCode 2）
- 平台：Android 6.0+（minSdk 23），当前正式包为 arm64
- 技术：Flutter 3.29 / Dart 3.7；SQLite；Vosk 离线语音

---

## 功能

| 模块 | 说明 |
|---|---|
| 首页七日栏 | 明天／今天／昨天＋4 个日期，选中行放大、整格高亮；有记录的日子打点 |
| 发布 | 文字／照片／视频任意组合；今天＝记录、明天＝计划、更远＝寄语；过去的日期只能评论 |
| 记录页 | 内容只读，可追加评论（带年月日时间）；照片可全屏缩放，视频可播放 |
| 计划 | 只在今天（及更早未确认的）能标完成／未完成；未确认会在消息里提醒 |
| 日历 | 月视图、中国节日与纪念日、点日期跳转、跨月「回到今天」 |
| 报告 | 日报贴当天末尾；周报／月报／年报在独立报告页；按状态显示「查看／补生成／无／还没到」；可按日期区间导出 zip（年/月/周/日 分目录） |
| 语音 | Vosk 离线转写，模型由用户导入，不联网 |
| 备份 | 导出 zip（data.json＋照片）并可整体恢复 |
| 设置 | 字号、背景照片与明暗、API（KeyStore 存储）、模型导入、备份导出／恢复 |

---

## 构建

环境：Flutter 3.29+、JDK 21、Android SDK（platform 35/36）。

```bash
cd app
flutter pub get
flutter build apk --release --target-platform android-arm64
# 产物：app/build/app/outputs/flutter-apk/app-release.apk
```

签名：在 `app/android/key.properties` 里提供 `storePassword` / `keyPassword` / `keyAlias` / `storeFile`；不提供时回退 debug 签名。**keystore 与 key.properties 不入库。**

## 语音模型（不打包进 APK）

需要 Vosk 中文模型 `vosk-model-cn-0.22`（约 1.3GB，Apache-2.0）：

- 官方：<https://alphacephei.com/vosk/models>
- 下载后放进手机，打开 App → 设置 → 语音模型 → 导入（解压约 2GB 空间）

## 隐私

- 记录、照片、视频默认只在本机；应用内拍摄的媒体进 App 私有目录（`.nomedia`，系统图库不可见）。
- 报告生成直接请求 DeepSeek 官方 API（`https://api.deepseek.com`），不经过任何自有服务器；默认只附带 512px 缩略图，可关闭。
- API Key 存在 Android KeyStore，不写日志、不进备份。

## 目录

```
app/            Flutter 工程
docs/           需求文档与工作报告
scripts/        构建脚本
```

## 许可

GPL-3.0，见 [LICENSE](LICENSE)。

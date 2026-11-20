# 鲸鱼日记 · 产品需求文档（PRD）

> 版本 v0.1 · 2026-11-19 · 作者：肥鱼 · 状态：待评审
> 一句话：一个全本地、黑底白字、按天记录的安卓日记 App（APK），能记文字／照片／视频／语音，自动生成日报／周报／月报／年报。

---

## 0. 结论

| 项 | 决定 |
|---|---|
| 平台 | Android（Redmi K90，Android 16，minSdk 24，targetSdk 36） |
| 技术栈 | Flutter 3.x（一套代码，全离线） |
| 存储 | SQLite ＋ App 私有目录存媒体 |
| AI | DeepSeek API，只做日报／周报／月报／年报；语音转写不接 AI |
| 交付 | debug 试用 APK → release 签名 APK |

## 1. 范围

**做**：首页七日栏、发布页、记录页＋评论、计划标记、日历、往年今日、四类报告、备份导出、设置（字号／背景／API 状态）。
**不做**：云同步、多用户、手写 OCR、自动分类、图片编辑、推送通知。

## 2. 数据模型（SQLite）

```sql
entries(
  id INTEGER PRIMARY KEY,
  day TEXT,              -- 'YYYY-MM-DD'
  created_at INTEGER,    -- 毫秒时间戳
  type TEXT,             -- 'entry' | 'plan'
  body TEXT,
  plan_state TEXT,       -- NULL | 'done' | 'undone'
  plan_marked_at INTEGER
)
media(
  id INTEGER PRIMARY KEY,
  entry_id INTEGER,
  kind TEXT,             -- 'photo' | 'video'
  path TEXT,             -- files/media/...
  thumb_path TEXT,
  width INTEGER, height INTEGER, duration_ms INTEGER,
  added_at INTEGER
)
comments(
  id INTEGER PRIMARY KEY,
  entry_id INTEGER,
  created_at INTEGER,
  body TEXT,
  media_path TEXT,       -- 可空
  media_kind TEXT        -- 'photo' | NULL
)
reports(
  id INTEGER PRIMARY KEY,
  kind TEXT,             -- 'daily' | 'weekly' | 'monthly' | 'yearly'
  period_start TEXT, period_end TEXT,
  generated_at INTEGER,
  body TEXT,
  model TEXT,
  status TEXT            -- 'ok' | 'failed'
)
settings(key TEXT PRIMARY KEY, value TEXT)
```

索引：`entries(day)`、`media(entry_id)`、`comments(entry_id)`、`reports(kind, period_start)`。

## 3. 四屏线框

```
【首页】
┌──────┬────────────────────────┐
│ 🗓 ⚙ │ 11月19日 周四           │
│ 明天 │ ┌────────────────────┐  │
│ 今天●│ │ [图] 17:21 晚饭：面 │  │
│ 昨天 │ └────────────────────┘  │
│11月16│ ┌────────────────────┐  │
│11月15│ │ 文字…           展开 │  │
│11月14│ └────────────────────┘  │
│11月13│                        │
│──────│                        │
│往年今日│                    [＋]│
└──────┴────────────────────────┘

【发布页】            【记录页】
[照片][视频][语音]    ┌──────────┐
┌────────────────┐   │ 媒体网格  │
│ 文本区          │   ├──────────┤
└────────────────┘   │ 正文(只读)│
时间 17:21          │ 评论列表  │
           [发布✓]   ├──────────┤
                     │[图][语音]│
                     └──────────┘

【日历页】
  11月  < >
一 二 三 四 五 六 日
            1  2  3
 4  5  6  7  8  9 10
11 12 13 14 15 16 17
18 19 20 21 22 23 24   ← 有记录=小圆点
25 26 27 28 29 30
```

## 4. 交互细则

1. **七日栏**：明天／今天／昨天 ＋ 按「X月X日」的 4 天，共 7 行，不滚动；今天高亮。
2. **计划**：在「明天」行发布 → `type='plan'`。次日该行变「今天」，卡片右滑弹出［✓完成］［✗未完成］，结果记入 `plan_state`，显示在当日顶部横幅。
3. **展开**：卡片默认缩略（最多 2 行文字＋首图），点「展开」进记录页。
4. **发布**：图／文／视频任意组合；时间默认当前、可改；发布后回首页该日。
5. **语音**：长按录音 → Vosk 离线转写 → 插入光标处；失败给提示，不做 AI 纠错。
6. **记录页**：正文只读；评论可带图，带时间戳。
7. **往年今日**：左栏底部，与七行隔一条线；先出汇总卡（每年条数／图数／一句话），点开按年列明细。
8. **日历**：农历节日小字；有记录的日子加小圆点；点日期回首页该日。
9. **设置入口**：左上角 🗓 ⚙ 并排。
10. **动效**：只做不挡事的小动效——卡片进记录页用 Hero 展开（200ms）、发布后卡片淡入（180ms）、左栏选中态底色过渡（150ms）、日历有记录的小圆点淡入、录音时麦克风按钮呼吸灯。全部遵守系统「减少动画」设置；设置里加「减少动画」开关，开了就只留淡入淡出。

## 5. 报告系统

| 报告 | 生成时机 | 覆盖周期 |
|---|---|---|
| 日报 | 次日 01:05 | 当天 00:00–23:59 |
| 周报 | 周一 01:05 | 上周一–周日 |
| 月报 | 次月 1 号 01:05 | 当月 |
| 年报 | 12-31 23:30 | 当年 |

**调度**：打开 App 时检查「上次生成到哪」，补生成所有遗漏周期。日报追加到当天记录末尾（特殊样式，可折叠）；周报／月报／年报存库，设置里可看；日报不回看。

**内容**：
- 日报：统计（条数／媒体数／首末记录时间）＋ 观察 ＋ 最多 1 条动作；默认附当天照片的 512px 缩略图（设置可关）。
- 周报／月报／年报：统计 ＋ 辩证定性——先列推进项与断档项，再定性这段「在积累还是在空转」，据此决定主旋律是表扬为主还是批评为主，最后给 1–2 个动作。

**API**：DeepSeek API；key 用 `flutter_secure_storage` 存在 Android KeyStore；base_url 与模型名可改；失败重试 2 次，仍失败记 `failed`，不阻塞使用。

**提示词骨架（周报示例）**：
```
[系统] 你是肥鱼，蓝色鲸鱼娘女仆。先看事实，再抓主要矛盾，落判断，不和稀泥。
[用户] 以下是本周记录：{逐条：时间/类型/文字/图片数}
要求：①列事实 ②指出在推进的项和断档的项 ③定性这段是积累还是空转
④决定主旋律是表扬为主还是批评为主 ⑤给 1–2 个动作。不超过 400 字。
```

## 6. 备份格式

`鲸鱼日记-YYYYMMDD.zip`：
```
data.json       -- entries/media/comments/reports/settings（不含 api_key）
media/          -- 原图与视频，按 id 命名
README.txt      -- 版本号与恢复说明
```

导出：系统文件选择器 → `Documents/鲸鱼日记/`；可一键分享到电脑。恢复：导入同格式 zip，校验 schema 版本。

## 7. 设置项

字号（14／16／18）、背景照片（可调暗遮罩）、日报附图开关、API 状态页（已连／未连、上次调用、延迟、模型名）、key 输入、备份导出／导入、关于。

## 8. 隐私与安全

- 媒体存 App 私有目录 `files/media/`，目录内置 `.nomedia`；应用内拍摄不经系统相册；相册导入只复制不引用（原图本来在相册，藏不了）。
- API key 加密存 KeyStore，不写日志、不进备份。
- 报告外发默认只发当天 512px JPEG 缩略图，设置可关；发送前在日志记「本日 N 张」。
- 权限：相机、麦克风、App 目录存储；不申请通讯录、定位、通知。

## 9. 技术栈与依赖（装环境后验证）

Flutter 3.x；候选包：`sqflite`、`camera`、`video_player`、`image_picker`（相册导入）、`flutter_secure_storage`、`file_picker`、`path_provider`、`archive`、`intl`、`lunar`（农历节日）、状态管理用 `provider`。
Vosk：官方 Android 库 ＋ MethodChannel 封装；备选 whisper.cpp／sherpa-onnx。

**判据**：`flutter build apk` 通过；K90 上三屏不崩；10 秒语音转写 ≤2 秒；中文短句准确率 ≥85%。

## 10. 构建与签名

`flutter create` → `flutter build apk --debug` 试装 → release 用自签 keystore。签名密钥不进仓库、不进备份。

## 11. 验收判据

- [ ] 装机能开，三屏无崩
- [ ] 发一条图文，关掉重开数据还在
- [ ] 明天写计划，次日右滑标记，当日顶部显示结果
- [ ] 评论带图，时间戳正确
- [ ] 日历点日期跳转正确；有记录的日子有圆点
- [ ] 报告：改系统时钟模拟 01:05，补生成日报／周报
- [ ] 备份：导出 zip，电脑能解压出 data.json ＋ media
- [ ] 隐私：应用内拍的照片在系统图库搜索不到

## 12. 里程碑

M0 环境（JDK 21 ＋ Android SDK ＋ Flutter ＋ adb）→ M1 数据层＋首页＋发布＋记录 → M2 计划标记＋日历＋往年今日 → M3 语音 → M4 报告＋备份 → M5 试用 7 天修 bug。

## 13. 安全审查清单

- 只用官方源：flutter.dev、pub.dev、developer.android.com；被墙用官方镜像 `storage.flutter-io.cn`／`pub.flutter-io.cn`。
- 安装包对官方发布页校验 SHA256。
- 依赖锁 `pubspec.lock`；新增包前查 pub.dev 维护状态。
- 不运行来路不明的 exe，不装「破解版」。
- gradle wrapper 与镜像地址只用官方文档列出的。
- 每个安装包落地后火绒全盘扫一次再装。

# iOS 通知本地修复 · 2026-10-22

本轮只修改 iOS；未部署或修改后端、未请求生产通知/AI 接口，不能据此确认线上摘要服务已经恢复。

## 行为

- `AnnouncementStore` 是首页与悬浮工具栏的共同数据源。前台每 60 秒重新读取通知；返回前台立即核对一次，进入后台停止轮询。列表失败后等待 30 秒，不把错误响应当成空列表。
- `AnnouncementItem.isActive(at:)` 使用与本地 PHP 相同的闭区间：`startTime <= now <= endTime`，null 表示该方向不限时间。接收列表时与本地计时器均过滤有效期；到期通知约 1 秒内移除，同时作废旧摘要。撤回/编辑依赖下一次成功读取服务端权威列表，客户端不猜测撤回状态。
- 列表缓存与摘要成功状态分开。摘要失败后等待 5 秒、再等待 30 秒，最多自动请求 3 次；成功且来源内容未变时不重复生成。返回前台允许新一轮重试，但距上次摘要请求至少 30 秒。通知集合/正文变化会作废旧摘要并重新尝试；持续失败仍显示原来的“摘要不可用”。
- 摘要在返回后再次核对来源与有效期；暂停、切账号、任务取消的迟到响应均不写入界面。原网络请求可能已经到达服务器，客户端丢弃响应不代表服务器没有执行该请求。
- 首页及顶部红色入口均列出全部仍有效的 Markdown 通知，按创建时间倒序、编号倒序稳定排序。保留原来的 Markdown 主题、字体、日期、完成按钮与弹窗高度，仅增加逐条排列、分隔线和空状态。其他页面布局未改动。
- 共享日期解析在原 `API/` 文件夹下的 `APIDate.swift`：无时区 SQL 日期按 `Asia/Shanghai`，带 Z/偏移的 ISO 8601 保留其绝对时间。`String.toDate()` 委托给它；广告已有的独立正确解析器未改动。

## 摘要契约未改

`GET /api/OnlyAI/announcement_summary.php`，携带学生 Bearer Token；保留 `{code,message,data}`。成功时 `code=200`、`data.summary` 为非空文本、`data.isAI=true`、`data.sourceIDs` 为非空整数数组，且所有来源都属于当前有效列表。解析失败或来源不符不显示摘要，不拿数量替代摘要。列表与摘要请求均绕过客户端 HTTP 缓存。

## 离线验证

从 iOS 仓库根目录运行，不需要账号、密钥、网络或 AI 额度：

```sh
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -module-cache-path /private/tmp/campura-announcement-diagnostic-cache \
  CampuraOne/API/APIDate.swift \
  CampuraOne/DataStructure/Data-Announce.swift \
  CampuraOne/ViewModels/AnnounceModels/AnnouncementStore.swift \
  Tests/AnnouncementStoreChecks.swift -o /private/tmp/campura-announcement-checks
/private/tmp/campura-announcement-checks
```

测试直接编译生产模型、日期解析器和 Store，注入固定时钟和模拟 loader。覆盖时区/非法日期、有效期边界、Markdown 集合、摘要重试与次数上限、前台冷却、空列表/失败缓存、内容变更/撤回、过期、并发请求、账号切换及取消后的迟到响应；不验证线上响应或实际 SwiftUI 渲染。

2026-10-22 实际执行：50 项离线断言全部通过；最终 arm64 iOS Simulator 无签名整包编译通过。构建日志：`/private/tmp/campura-ios-notices-build.log`。首次构建受沙箱的系统缓存/模拟器访问限制，授权后使用已有依赖完成构建；没有修改后端或真实通知数据。

模拟器编译（无需签名）：

```sh
xcodebuild -project CampuraOne.xcodeproj -scheme CampuraOne \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/campura-ios-notices-20261022 \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64 build
```

仍需人工验收：多条 Markdown 内容上下滚动；弹窗打开期间通知过期后列表与数字一致；后端短暂失败恢复后摘要出现；广告、天气、搜索及其他既有 UI 保持原样。后端首次摘要失败的实际原因仍由后端会话核查。

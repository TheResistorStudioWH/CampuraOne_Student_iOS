# iOS 广告加载与会话恢复 · 2026-10-06

## 设计与兼容

- 大小广告只消费 `AdvertisementStore.shared`，由 `AppRootView` 按登录身份/前台状态启动。两种广告位共用 `AdvertisementPhotoStack`：图片叠放、横滑预览、轻点全屏逐张浏览或切换网格；大广告保留 3:1 排版。头像、商品图片缓存不受影响。
- 每次回到前台先联网核对完整生效清单；不直接恢复磁盘中的广告列表。前台约每 30 秒核对一次，失败后约每 6 秒重试。请求期间独立每秒检查到期，距离最后成功核对超过 60 秒就停止展示旧清单。后台不轮询。
- 完整清单在本地计算新增、变更、移除，无需新增两套 Server 端点。成功的空数组表示全部撤下；网络失败或无效数据不能当成空数组清库。
- 临时撤下在下一次成功核对时移除 UI、取消下载并丢弃对应内存快照。离线无法知道服务端发生了什么，所以只停止展示，不把连接失败伪装成撤下。这不是即时推送；在线撤下检测通常为 30 秒加请求时间。
- 学生响应仍是 `{code,message,data:[...]}`，使用 `adID/saleID/startTime/endTime/type/img/updatedAt`，没有改为破坏旧客户端的 delta 格式。Server 本地学校审核版会过滤撤下/非批准广告，但其生产部署状态需单独核实。
- 无时区 MySQL DATETIME 依据当前 Server 的 `Asia/Shanghai` 配置解析；带时区 ISO 时间按实际瞬间解析。不要复用旧 UTC 默认日期解析器，否则投放时段会偏移 8 小时。
- 若以后改为增量 API，必须同时设计游标、删除墓碑保留期、游标过期后的全量重置；仅有“新增”和“删除”两个数组不足以应对长期离线和清缓存后的客户端。

## 会话内图片快照

- `AdvertisementStore` 按账号、广告 ID、图片 URL、`updatedAt` 与投放时段持有已解码的 UIImage；翻页只读同步内存快照，不启动图片任务。原 URL 换图必须更新 `updatedAt`；缺失版本字段时按天更换快照键。
- 成功核对权威清单时，沿用未变更版本的图片，取消撤下/换图的进行中请求并移除对应快照；投放到期也立即失效。迟到下载不能复活撤下图片。
- 图片请求使用无 URLCache 的临时会话，不携带学生 Bearer；允许 JPEG/PNG/WebP，最多 8 MB，解码最长边 1600 px。不写入广告图片磁盘缓存。`AdvertisementAssets` 是旧实现，现已不被运行路径使用。
- 后台暂停不展示旧清单、取消请求，但同一登录会话可暂存内存图片；回到前台必须先联网核对，匹配的版本才重新显示。退出登录或切换账号清空快照。离线冷启动需要重新获取图片。
- 下载/解码失败显示可重试占位。前台同步预载当前有效清单的图片，避免翻页时才发请求。

## 恢复登录品牌页

`Views/AuthAccount/AuthSession.swift` 中 `SessionLaunchScreen` 是应用内恢复状态页，不是开屏广告。暂用 `square.stack.3d.up.fill` 和 Campura One 字样；有效保存会话恢复时至少显示约 0.5 秒，随后沿用已有主界面过渡（支持减弱动态效果）。无保存会话不人为拖延登录页。未来美工交付后只替换中央 symbol。

## 本地检查

旧磁盘缓存实现的离线检查仍保留在 `Tests/AdvertisementCacheChecks.swift`，但它不覆盖当前展示路径；日期解析可单独复用该测试。当前改动已通过 iOS Simulator 无签名构建，仍需按下方清单做真机/隔离接口验收。

旧检查命令（只验证未接入的历史实现，不作为当前验收结果）：

```sh
swiftc -parse-as-library -module-cache-path /private/tmp/campura-swift-module-cache \
  CampuraOne/Advertisements/AdvertisementAssets.swift \
  CampuraOne/Advertisements/AdvertisementDate.swift \
  Tests/AdvertisementCacheChecks.swift -o /private/tmp/campura-ad-cache-checks
/private/tmp/campura-ad-cache-checks
```

覆盖：并发去重、磁盘命中、前后台后复用、版本变化、账号 key 隔离、撤下删除、过期拒绝、撤下时取消、重新投放、北京时间/ISO 对齐、非法日期。测试创建自己的临时目录并仅清理该目录。

```sh
xcodebuild -project CampuraOne.xcodeproj -scheme CampuraOne \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/campura-ios-ad-validation CODE_SIGNING_ALLOWED=NO build
```

2026-10-06 历史磁盘缓存/日期检查曾通过；当前会话快照实现尚无独立自动化测试。没有对线上广告做撤下写入，也未执行真机视觉验收。

## 仍需真机/隔离接口验收

1. 保存会话后杀进程再启动：品牌页→主界面；无凭据→登录；401→登录。
2. 交替查看大小广告，翻页不触发下载，同 URL/版本在同一会话中不重复下载；同 URL 更新版本重新加载。
3. 本地测试服务器撤下一条/全部广告：下一次核对移除内存快照；错误响应不当成撤下。
4. 弱网下越过投放结束时刻，UI 仍按秒级检查消失；完全断网超过验证租期不继续展示旧广告。
5. 切账号、后台恢复、下载中撤下、选中最后一张后清单缩短均不串数据、不越界。
6. 检查大小广告的叠放、横滑首尾边界、轻点全屏及网格，以及圆点天气在不同屏幕倍率下的外观；其他原有 UI 保持不变。

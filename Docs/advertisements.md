# iOS 广告加载与会话恢复 · 2026-10-06

## 设计与兼容

- 大小广告只消费 `AdvertisementStore.shared`，由 `AppRootView` 按登录身份/前台状态启动。原大广告 3:1 排版、小广告叠放和横向手势保留；头像、商品图片缓存不受影响。
- 每次回到前台先联网核对完整生效清单；不直接恢复磁盘中的广告列表。前台约每 30 秒核对一次，失败后约每 6 秒重试。请求期间独立每秒检查到期，距离最后成功核对超过 60 秒就停止展示旧清单。后台不轮询。
- 完整清单在本地计算新增、变更、移除，无需新增两套 Server 端点。成功的空数组表示全部撤下；网络失败或无效数据不能当成空数组清库。
- 临时撤下在下一次成功核对时移除 UI、取消下载、删除对应磁盘和内存缓存。离线无法知道服务端发生了什么，所以只停止展示，不把连接失败伪装成撤下。这不是即时推送；在线撤下检测通常为 30 秒加请求时间。
- 学生响应仍是 `{code,message,data:[...]}`，使用 `adID/saleID/startTime/endTime/type/img/updatedAt`，没有改为破坏旧客户端的 delta 格式。Server 本地学校审核版会过滤撤下/非批准广告，但其生产部署状态需单独核实。
- 无时区 MySQL DATETIME 依据当前 Server 的 `Asia/Shanghai` 配置解析；带时区 ISO 时间按实际瞬间解析。不要复用旧 UTC 默认日期解析器，否则投放时段会偏移 8 小时。
- 若以后改为增量 API，必须同时设计游标、删除墓碑保留期、游标过期后的全量重置；仅有“新增”和“删除”两个数组不足以应对长期离线和清缓存后的客户端。

## 图片缓存

- `AdvertisementAssets` actor 负责文件、下载去重、取消与授权清单；`AdvertisementStore` 负责解码后的 UIImage 内存缓存、状态和图片视图。
- key = 账号 + 广告 ID + 图片 URL + `updatedAt` + 投放起止时间的 SHA256。原 URL 替换图片时必须更新 `updatedAt`；没有版本字段的旧记录每天换版本。
- 投放结束即失效；无结束时间的图片缓存每天重新核对/重取。磁盘目录是系统 Caches 下的 `CampuraAdvertisementAssets-v2`，上限 60 MB、LRU 淘汰；内存目标上限 24 MB，解码缩略图最长边 1600 px。
- 图片独立请求不使用 URLCache、不携带学生 Bearer，允许 JPEG/PNG/WebP，下载最多 8 MB（兼容服务端 5 MB 上传上限）。不允许旧 URLCache 绕过新的广告缓存生命周期。
- 退出登录清理广告缓存，切账号先清内存再核对新清单；暂停保留文件但撤销当前下载权限。迟到下载不能复活撤下图片。冷启动恢复会话阶段不清空可复用文件。
- 网络/文件写入/解码失败显示可重试占位，不改成另一种广告布局。不正确的图片不会一直留在磁盘命中。

## 恢复登录品牌页

`Views/AuthAccount/AuthSession.swift` 中 `SessionLaunchScreen` 是应用内恢复状态页，不是开屏广告。暂用 `square.stack.3d.up.fill` 和 Campura One 字样；有效保存会话恢复时至少显示约 0.5 秒，随后沿用已有主界面过渡（支持减弱动态效果）。无保存会话不人为拖延登录页。未来美工交付后只替换中央 symbol。

## 本地检查

从 iOS 仓库根目录运行缓存/日期检查，不访问生产服务：

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

2026-10-06 缓存/日期检查实际执行通过；Xcode 26.3 通用 iOS Simulator 无签名整包构建通过（arm64/x86_64）。构建日志 `/private/tmp/campura-ios-ad-build-final.log`。没有对线上广告做撤下写入，也未执行真机视觉验收。

## 仍需真机/隔离接口验收

1. 保存会话后杀进程再启动：品牌页→主界面；无凭据→登录；401→登录。
2. 交替查看大小广告，同 URL/版本不重复下载；同 URL 更新版本重新加载。
3. 本地测试服务器撤下一条/全部广告：下一次核对移除并删文件；错误响应不当成撤下。
4. 弱网下越过投放结束时刻，UI 仍按秒级检查消失；完全断网超过验证租期不继续展示旧广告。
5. 切账号、后台恢复、下载中撤下、选中最后一张后清单缩短均不串数据、不越界。
6. 检查大图内容完整和小广告横向手势、圆点天气在不同屏幕倍率下的外观；其他原有 UI 保持不变。

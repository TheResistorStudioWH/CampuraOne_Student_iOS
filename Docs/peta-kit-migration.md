# Peta Kit 调用迁移（2026-10-30）

项目继续使用 GitHub 在线包，没有新增 local package，也没有修改两个 Kit 的源码。当前 `main` 锁定版本：

- PetaToolKit：`ee0d854289cdb5bd5d74528bfbd29e49d8aac0f6`
- PetaKitUIX / PetaKitWatchUIX：`0ec57a73b21eb617c261a39518c7a218fe1e6184`

本地 `/Users/LShayc1owN/Desktop/Develop/PetaHertZ-Studio/` 仅供查阅接口；Xcode 实际依赖以项目的 `Package.resolved` 为准。其他包的锁定版本未调整。

## 已统一的调用

| 原写法 | 当前写法 | 保留的行为 |
| --- | --- | --- |
| `jumpView(to:)` | `naviLink(to:)` | 重要通知详情导航及其按钮样式 |
| `TapLight()` / `TapSoft()` | `Haptics.play(.light/.soft)` | 原触觉类型及调用顺序 |
| `TapSucceed()` | `Haptics.play(.success)` | light 后延迟 0.2 秒 rigid；不是 `.systemSuccess` |
| `DispatchAfter(after:)` | `DispatchQueue.main.asyncAfter(deadline:)` | Tab 动画原来的 0.1 / 0.3 / 0.6 秒延时及主队列执行 |
| `ClassNowTime().timeString` | 保存一次 `Date()`，由 `Calendar.current` 读取小时 | 首页原有问候时间区间、文案及视图生命周期内的时间快照 |
| 无 role 的普通 `Button` | `Text` / `Label` / 原标签视图的 `.beButton` | 原内容、modifier 所属层级、按钮样式、动作顺序及无障碍信息 |

iOS 的 UI 文件导入 `PetaKitUIX`，watchOS 导入 `PetaKitWatchUIX`；触觉和尺寸工具仍导入 `PetaToolKit`。不在 App 内增加旧名称的兼容别名。

## 有意保留的原生写法

- `Button(role: .cancel/.destructive)`：`beButton` 没有 role 参数，不能丢失取消/破坏性操作语义。
- `NavigationLink(value:)`：保留 Watch 导航选择与目标解析。
- 目标闭包形式的 `NavigationLink`：Kit 的 `naviLink(to:)` 接收已经构造的值，不能替代延迟创建；尤其磁贴通知设置的初始化会读取当前偏好。
- `onTapGesture` / 优先或同时手势：不改成 Button，以免改变手势竞争、命中和无障碍语义。
- `ForEach(days.indices, id: \.self)` 等以位置作为身份的循环：`ForEachWithIndex` 以元素 ID 作为身份，不能直接替换。已有基于元素 ID 的 `ForEachWithIndex` 继续使用。
- 用于布局、坐标和绘制的 `GeometryReader` 不替换为异步上报尺寸的 `readSize`；偏移/锚点 PreferenceKey 也不等于读取尺寸。首页已有的 `readSize` 保留。
- 日期轨道、课表、广告堆叠、波浪组件及天气图标保留业务实现；不因 Kit 出现同类组件就改变当前视觉、布局或手势。
- 可取消的 `.task` / `Task.sleep` 保留；新 Kit 已移除延时包装，不另造包装替代。

## 验证

本轮已通过 Xcode 26.3 Debug 编译（关闭签名、使用上述在线包）：

- `CampuraOne`：generic iOS Simulator，包含嵌入的 Watch App。
- `CampuraOneWatch`：generic watchOS Simulator，独立 scheme。
- `git diff --check`；Swift 源码中已无被移除的 Kit API 调用。

构建仍报告既有的 RemoteImageLoader Swift 6 捕获警告、SimpleICSGenerator actor 隔离警告、Watch AccentColor 缺失和无 AppIntents 元数据提示，未顺带改动这些内容。

尚未验证真机触觉、动画及屏幕阅读器体验。构建产物放在 `/private/tmp`，完成后清理。

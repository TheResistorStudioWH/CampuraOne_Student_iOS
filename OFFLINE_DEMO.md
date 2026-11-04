# 离线彩排 Demo

在 Xcode 中选择 `CampuraOneDemo` scheme、iPhone 设备并运行。这个 scheme 使用 `Demo` 构建配置，安装为独立的 `域校屿`（`com.LX.CampuraOne.demo`），不会覆盖正式版。手机桌面两者名称相同，请从 Xcode 的 `CampuraOneDemo` scheme 安装和启动离线版；`CampuraOne` scheme 仍为在线版。启动后自动进入本地演示学生，无需账号和服务器。不要用正式版 scheme 加 `--campura-preview` 代替真机演示，因为它会与正式版共用安装身份。

演示内容复用当前 `PreviewAPI` 和 `PreviewNavigation`：课程、校历、商品、促销、广告、搜索、通知、摘要和校园 CAMAP 均由本地数据提供。只有 MapKit 底图联网，业务接口仍被本地拦截。通知有班级投票、查寝、教学楼施工及志愿者征集四条原文，摘要引用这四条。投票与查寝的相对日期随当天时间调整，课程按七天节奏循环，涵盖早 8、早 10、上午空闲、下午空闲和晚自习。

地图内置用户提供的 `CampuraOne/OfflineResources/school-1-v2.camap`，原样保存并通过 Camap.read 校验加载。默认使用融合显示，可切换绘制图或在线原地图。该文件有 MapKit 校准数据，但 nodes、edges 均为空；不会套用旧示意路线，导航暂不可规划。后续需提供可通行路网或单独确认本地路线方案。

彩排验收：打开飞行模式，首次启动 Demo；浏览首页、课程周视图及各标签、四条通知原文与摘要、商店和搜索；确认本地校园图可显示，再联网检查底图叠加；退出应用重新打开。确认无登录页、本地校园图可见、缺失路网时不会显示虚构路线或步行时间。系统锁屏通知的聚合样式由 iOS 控制，本 Demo 提供应用内原文和示意摘要。

# 日程表详情 · 2026-10-26

`CourseTableDetail`、日期选择器、`CourseDateRail` 和周课表共用 `selectedDate`，首次打开选择今天。课表仍由 `CourseScheduleStore` 与 `CourseScheduleResolver` 提供，首页和地图不另建数据源。

详情容器仅对课表使用固定标题与单个纵向滚动区域，左侧日期刻度保持独立。顶部“日程表”下依次为日期选择器、title2 日期与课程数、日程标签、周课表、当天时间线。周从周一开始；今天整列浅强调色高亮，所选日期以描边区分。

标签规则在 `Views/Components/CourseScheduleMetrics.swift`：

- 首课开始于 08:00–09:59：早8；10:00–11:59：早10。
- 06:00–12:00 无课：上午空闲；13:00–18:00 无课：下午空闲。
- 与 18:00–当日结束相交的课程：晚自习。
- 午休按上午课程的最晚下课时间到下午首课上课时间计算，不限制在 12:00–14:00。12:00 前开始的课程归上午，12:00–18:00 前开始的课程归下午；任一侧无课或两侧重叠时不显示午休时长。保持原标签至少 30 分钟的显示门槛，不扣除吃饭或通勤时间。
- 课程数按当天解析出的 ICS 课次计数，一项 ICS 事件记为一节。

周课表按实际开课时间生成行，横向滑动查看七天。每日时间线根据容器可用宽度扣除时间栏，并将时间重叠的课程分栏；默认 08:00–20:00，遇到更早／更晚课程会扩展。批量 ICS 导出与单节 EventKit 编辑保持可用。

离线逻辑检查（不访问 API）：

```sh
swiftc -parse-as-library -module-cache-path /private/tmp/campura-swift-module-cache \
  'CampuraOne/ICS ToolKit/ICSEventItem.swift' \
  CampuraOne/Views/Components/CourseScheduleMetrics.swift \
  Tests/CourseScheduleChecks.swift -o /private/tmp/campura-course-schedule-checks
/private/tmp/campura-course-schedule-checks
```

本轮离线检查与 iOS Simulator arm64 无签名构建通过；未进行真机视觉验收。

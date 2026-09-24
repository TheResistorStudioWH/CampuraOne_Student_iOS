# 点阵天气组件

原创 Nothing OS 风格参考，非官方素材。独立组件，未改任何现有页面。

```swift
DotWeatherIcon(condition: .rain) // 默认 64 pt
DotWeatherIcon(condition: .clear, isNight: true, size: 80, tint: .white)
DotWeatherIcon(condition: .snow, size: 48, flashing: false)
```

17 种天气，晴／多云支持昼夜；32×32 点阵按 size 等比绘制，0.8 秒切帧，无 animation 插值。减少动态效果或 App 不活跃时画面静止。天气 API 的 code 到枚举映射需在选定供应商后独立实现；未知 code 使用 unknown，勿猜测。

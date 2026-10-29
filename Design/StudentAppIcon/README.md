# Student app icon draft

The outer arc is a replaceable placeholder colored sRGB 248, 217, 154 (`#F8D99A`). Six broad, solid pointed sepals in sRGB 191, 251, 139 (`#BFFB8B`) grow from a single crown at its upper-left edge, like a strawberry calyx. They radiate from that one attachment point, rotated 30° clockwise to follow the C’s upper-left curve, without a visible stalk or dark outlines. The center marker copies the visual proportions of the supplied iOS Maps location indicator: a blue disk with a pale gray rim. Its translucent heading cone points through the arc's right-hand gap.

Run `swift render.swift` to regenerate the 1024 × 1024 PNG layers and update the artwork inside `AppIcon.icon/Assets/`. Open `AppIcon.icon` in Icon Composer to edit the composition. The icon uses a solid canvas fill, which also covers the 1088-point watchOS circle. Icon Composer enables the leaf layer’s Liquid Glass effect and its group’s specular highlight, 50% blur, and 25% translucency; it also positions the leaf layer separately. The flat PNG previews show the source color and geometry, not these material effects. Xcode generates static images from the same `.icon` source for older iOS and watchOS versions.

`preview.png` shows the square composition. `preview-watch.png` uses a circular crop to check the Apple Watch silhouette; Icon Composer and the OS apply the actual final mask.

# Student app icon draft

The outer arc is a replaceable placeholder colored sRGB 248, 217, 154 (`#F8D99A`). Five broad, solid pointed leaf lobes in sRGB 191, 251, 139 (`#BFFB8B`) fan across its upper-left curve, with one short background-colored knockout seam. The center marker copies the visual proportions of the supplied iOS Maps location indicator: a blue disk with a pale gray rim. Its translucent heading cone points through the arc's right-hand gap.

Run `swift render.swift` to regenerate the 1024 × 1024 PNG layers and update the artwork inside `AppIcon.icon/Assets/`. Open `AppIcon.icon` in Icon Composer to edit the composition. The icon uses a solid canvas fill, which also covers the 1088-point watchOS circle. The current Icon Composer composition applies a gradient, glass effect, and position offset to the leaves, so its rendered appearance differs from the flat PNG previews. Xcode generates static images from the same `.icon` source for older iOS and watchOS versions.

`preview.png` shows the square composition. `preview-watch.png` uses a circular crop to check the Apple Watch silhouette; Icon Composer and the OS apply the actual final mask.

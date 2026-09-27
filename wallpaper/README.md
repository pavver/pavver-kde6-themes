# Wallpaper Target

Reserved for the future Plasma 6 wallpaper/screensaver package.

The target should reuse `../shared/PavverTheme/AnimatedBackground.qml` and
`Theme.qml`, with its own thin Plasma wallpaper API adapter and package
metadata. The screensaver presentation and responsive geometry currently used
by the lock screen are intentionally implemented in the shared background and
can be reused here without copying QML.

import QtQuick
import org.kde.plasma.plasmoid

import "PavverTheme" as Pavver

WallpaperItem {
    id: root

    readonly property real bannerAspectRatio: 675.0 / 190.0
    readonly property real bannerVisualWidth: Math.min(
        width * 0.85,
        (height * 0.70) * bannerAspectRatio)

    Pavver.AnimatedBackground {
        anchors.fill: parent
        bannerTargetCenterX: root.width / 2.0
        bannerTargetCenterY: root.height / 2.0
        bannerTargetScale: root.bannerVisualWidth / 675.0
        bannerTargetOpacity: 1.0
        enableAnimations: false
        contentAnimationsEnabled: root.configuration.EnableAnimations
    }
}

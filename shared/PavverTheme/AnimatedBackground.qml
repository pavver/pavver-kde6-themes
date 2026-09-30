import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

Item {
    id: root
    anchors.fill: parent

    // Dynamic Resolution & Supersampling Engine:
    // Reads screen dimensions & HiDPI scale factor at startup to calculate
    // the maximum physical pixel size required for the banner in screensaver mode.
    readonly property real screenW: Screen.width > 0 ? Screen.width : 1920
    readonly property real screenH: Screen.height > 0 ? Screen.height : 1080
    readonly property real screenDpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0

    // Maximum physical pixel width of the banner across all modes (screensaver is largest: 85% width)
    readonly property real maxPhysicalBannerWidth: {
        var visualW = Math.min(screenW * 0.85, (screenH * 0.70) * (675.0 / 190.0));
        var physicalW = Math.ceil(visualW * screenDpr);
        // Ensure at least 3x supersampling (2025px) or native physical width, whichever is greater
        return Math.max(2025.0, physicalW);
    }

    // Dynamic scale factor relative to the base 675x190 coordinate system
    readonly property real renderScale: maxPhysicalBannerWidth / 675.0

    // Exact texture allocation dimensions
    readonly property int texWidth: Math.round(675.0 * renderScale)
    readonly property int texHeight: Math.round(190.0 * renderScale)

    // Dynamic Gaussian blur radius:
    // In original SVG WallPapper/index.html, stdDeviation="1.5".
    // The visible Gaussian blur kernel radius (3 * sigma) is 4.5 SVG base units.
    // In texture coordinates, this translates to 4.5 * renderScale pixels.
    readonly property real dynamicBlurRadius: 4.5 * renderScale

    // Target geometric parameters driven by LockScreenUi state machine
    property real bannerTargetCenterX: parent ? parent.width / 2.0 : 960
    property real bannerTargetCenterY: parent ? parent.height / 2.0 : 540
    property real bannerTargetScale: 1.0
    property real bannerTargetOpacity: 1.0
    property bool enableAnimations: false
    property bool contentAnimationsEnabled: true

    readonly property bool isFullyVisible: bannerContainer.opacity > 0.05

    // Main background canvas color matching #555
    Rectangle {
        anchors.fill: parent
        color: Theme.screenBackground
    }

    // Centered banner container with FIXED internal resolution (675 x 190)
    // Hardware GPU matrix scaling - eliminates CPU SVG re-rasterization and FBO reallocations for silky smooth 60/120 FPS
    Item {
        id: bannerContainer
        width: 675
        height: 190
        transformOrigin: Item.Center

        x: Math.round(root.bannerTargetCenterX - width / 2.0)
        y: Math.round(root.bannerTargetCenterY - height / 2.0)
        scale: root.bannerTargetScale
        opacity: root.bannerTargetOpacity
        visible: opacity > 0.0

        Behavior on x {
            enabled: root.enableAnimations
            NumberAnimation { duration: Theme.sceneAnimation; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: root.enableAnimations
            NumberAnimation { duration: Theme.sceneAnimation; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            enabled: root.enableAnimations
            NumberAnimation { duration: Theme.sceneAnimation; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            enabled: root.enableAnimations
            NumberAnimation { duration: Theme.slowAnimation; easing.type: Easing.OutCubic }
        }

        readonly property real animTime: animationClock.elapsed

        AnimationClock {
            id: animationClock
            framesPerSecond: Theme.continuousAnimationFps
            running: root.contentAnimationsEnabled
                && bannerContainer.visible
                && bannerContainer.opacity > 0
        }

        // Exact animation timing from original WallPapper/index.html:
        // dur = 2s (2000ms), stagger = 1s (1000ms), total period = 6s (6000ms)
        // Values scale from 1.0 -> 1.3 -> 1.0 smoothly.
        // Startup condition ensures every triangle starts cleanly at rest (1.0).
        function getScale(index) {
            var startTime = index * 1000.0;
            if (animTime < startTime) {
                return 1.0;
            }
            var dt = (animTime - startTime) % 6000.0;
            if (dt < 2000.0) {
                return 1.0 + 0.3 * Math.sin((dt / 2000.0) * Math.PI);
            }
            return 1.0;
        }

        // 1. Static background: #333 box + inner glow + embossed "PAVVER" text with shadow
        // Dynamically rasterized from vector SVG to match exact screen max resolution
        Image {
            id: bgImage
            source: Qt.resolvedUrl("assets/pavver_static_bg.svg")
            anchors.fill: parent
            sourceSize.width: root.texWidth
            sourceSize.height: root.texHeight
            smooth: true
            mipmap: true
        }

        // 2. The 6 animated triangles - Dynamically scaled to match maximum screen resolution
        // Uses explicit GaussianBlur item for guaranteed hardware shader execution and visible glowing halo
        Item {
            id: trianglesContainer
            width: root.texWidth
            height: root.texHeight
            scale: 1.0 / root.renderScale
            transformOrigin: Item.TopLeft

            Item {
                id: trianglesSource
                anchors.fill: parent
                visible: false

                Item {
                    id: trianglesOrigin
                    x: Math.round(70.0 * root.renderScale)
                    y: Math.round(60.0 * root.renderScale)
                    scale: root.renderScale
                    transformOrigin: Item.TopLeft

                    Shape {
                        id: t1
                        preferredRendererType: Shape.GeometryRenderer
                        ShapePath {
                            fillColor: Theme.trianglePrimary
                            strokeWidth: 0
                            strokeColor: "transparent"
                            PathSvg { path: "M -49 0 L 0 0 L -30 -40 Z" }
                        }
                        transform: Scale {
                            origin.x: 0; origin.y: 0
                            xScale: bannerContainer.getScale(0)
                            yScale: bannerContainer.getScale(0)
                        }
                    }

                    Shape {
                        id: t2
                        preferredRendererType: Shape.GeometryRenderer
                        ShapePath {
                            fillColor: Theme.triangleSecondary
                            strokeWidth: 0
                            strokeColor: "transparent"
                            PathSvg { path: "M 24 -40 L 0 0 L -30 -40 Z" }
                        }
                        transform: Scale {
                            origin.x: 0; origin.y: 0
                            xScale: bannerContainer.getScale(1)
                            yScale: bannerContainer.getScale(1)
                        }
                    }

                    Shape {
                        id: t3
                        preferredRendererType: Shape.GeometryRenderer
                        ShapePath {
                            fillColor: Theme.trianglePrimary
                            strokeWidth: 0
                            strokeColor: "transparent"
                            PathSvg { path: "M 24 -40 L 0 0 L 24 56 Z" }
                        }
                        transform: Scale {
                            origin.x: 0; origin.y: 0
                            xScale: bannerContainer.getScale(2)
                            yScale: bannerContainer.getScale(2)
                        }
                    }

                    Shape {
                        id: t4
                        preferredRendererType: Shape.GeometryRenderer
                        ShapePath {
                            fillColor: Theme.triangleSecondary
                            strokeWidth: 0
                            strokeColor: "transparent"
                            PathSvg { path: "M 0 96 L 0 0 L 24 56 Z" }
                        }
                        transform: Scale {
                            origin.x: 0; origin.y: 0
                            xScale: bannerContainer.getScale(3)
                            yScale: bannerContainer.getScale(3)
                        }
                    }

                    Shape {
                        id: t5
                        preferredRendererType: Shape.GeometryRenderer
                        ShapePath {
                            fillColor: Theme.trianglePrimary
                            strokeWidth: 0
                            strokeColor: "transparent"
                            PathSvg { path: "M 0 96 L 0 0 L -48 96 Z" }
                        }
                        transform: Scale {
                            origin.x: 0; origin.y: 0
                            xScale: bannerContainer.getScale(4)
                            yScale: bannerContainer.getScale(4)
                        }
                    }

                    Shape {
                        id: t6
                        preferredRendererType: Shape.GeometryRenderer
                        ShapePath {
                            fillColor: Theme.triangleSecondary
                            strokeWidth: 0
                            strokeColor: "transparent"
                            PathSvg { path: "M -48 0 L 0 0 L -48 96 Z" }
                        }
                        transform: Scale {
                            origin.x: 0; origin.y: 0
                            xScale: bannerContainer.getScale(5)
                            yScale: bannerContainer.getScale(5)
                        }
                    }
                }
            }

            GaussianBlur {
                id: blurItem
                anchors.fill: trianglesSource
                source: trianglesSource
                radius: root.dynamicBlurRadius
                samples: 24
                transparentBorder: true
            }
        }

        // 3. Cat sitting on top of the triangles
        // Dynamically rasterized from vector SVG to match exact screen max resolution
        Image {
            id: catImage
            source: Qt.resolvedUrl("assets/cat.svg")
            anchors.fill: parent
            sourceSize.width: root.texWidth
            sourceSize.height: root.texHeight
            smooth: true
            mipmap: true
        }
    }
}

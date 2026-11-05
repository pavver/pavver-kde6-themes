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

    // Each triangle is blurred once into a static texture sized to the triangle area,
    // and the animation only scales those textures, so no shader runs per frame.
    readonly property real blurScale: 3.0
    readonly property real blurAreaWidth: 110.0
    readonly property real blurAreaHeight: 190.0
    readonly property real triangleOriginX: Math.round(70.0 * blurScale)
    readonly property real triangleOriginY: Math.round(60.0 * blurScale)
    readonly property var triangles: [
        { path: "M -49 0 L 0 0 L -30 -40 Z", fill: Theme.trianglePrimary },
        { path: "M 24 -40 L 0 0 L -30 -40 Z", fill: Theme.triangleSecondary },
        { path: "M 24 -40 L 0 0 L 24 56 Z", fill: Theme.trianglePrimary },
        { path: "M 0 96 L 0 0 L 24 56 Z", fill: Theme.triangleSecondary },
        { path: "M 0 96 L 0 0 L -48 96 Z", fill: Theme.trianglePrimary },
        { path: "M -48 0 L 0 0 L -48 96 Z", fill: Theme.triangleSecondary }
    ]

    component Triangle: Item {
        id: triangle
        property string path
        property color fill
        x: root.triangleOriginX
        y: root.triangleOriginY
        scale: root.blurScale
        transformOrigin: Item.TopLeft

        Shape {
            preferredRendererType: Shape.GeometryRenderer
            ShapePath {
                fillColor: triangle.fill
                strokeWidth: 0
                strokeColor: "transparent"
                PathSvg { path: triangle.path }
            }
        }
    }

    Component {
        id: triangleBlur
        GaussianBlur {
            radius: root.blurRadius
            samples: 28
        }
    }

    // In original SVG WallPapper/index.html, stdDeviation="1.5".
    // The visible Gaussian blur kernel radius (3 * sigma) is 4.5 SVG base units.
    readonly property real blurRadius: 4.5 * blurScale

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

        // 2. The 6 animated triangles over a static copy at rest, which keeps the seams between
        // separately blurred triangles filled.
        Item {
            id: trianglesContainer
            width: Math.round(root.blurAreaWidth * root.blurScale)
            height: Math.round(root.blurAreaHeight * root.blurScale)
            scale: 1.0 / root.blurScale
            transformOrigin: Item.TopLeft

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.effect: triangleBlur

                Repeater {
                    model: root.triangles
                    Triangle {
                        required property var modelData
                        path: modelData.path
                        fill: modelData.fill
                    }
                }
            }

            Repeater {
                model: root.triangles

                Item {
                    id: animatedTriangle
                    required property int index
                    required property var modelData
                    readonly property real pulse: bannerContainer.getScale(index)
                    anchors.fill: parent

                    transform: Scale {
                        origin.x: root.triangleOriginX
                        origin.y: root.triangleOriginY
                        xScale: animatedTriangle.pulse
                        yScale: animatedTriangle.pulse
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: triangleBlur

                        Triangle {
                            path: animatedTriangle.modelData.path
                            fill: animatedTriangle.modelData.fill
                        }
                    }
                }
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

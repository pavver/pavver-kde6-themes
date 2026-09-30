import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

Item {
    id: root

    // 1. Exact unscaled bounding box of the animation at peak pulse (1.3x):
    // Triangles bounds relative to trianglesOrigin: X [-63.7, +31.2], Y [-52.0, +124.8]
    // Cat bounds relative to trianglesOrigin: X [-50.0, +28.0], Y [-15.0, +76.0]
    // Total animation cluster bounds:
    readonly property real baseAnimWidth: 94.9
    readonly property real baseAnimHeight: 176.8

    // Center offset of the cluster relative to trianglesOrigin:
    readonly property real centerOffsetX: -16.25
    readonly property real centerOffsetY: 36.40

    // 2. Screen smaller side calculation (70% target size)
    readonly property real screenSmallerSide: (parent && parent.width > 0 && parent.height > 0)
                                              ? Math.min(parent.width, parent.height)
                                              : (Screen.height > 0 ? Math.min(Screen.width, Screen.height) : 1080.0)

    // Target animation rectangle is 70% of the screen's smaller dimension
    readonly property real targetAnimationSize: 0.70 * screenSmallerSide

    // Proportional scale factor so the animation occupies 70% of the smaller side
    readonly property real scaleFactor: targetAnimationSize / baseAnimHeight

    // Calculated proportional dimensions of the animation rectangle
    implicitWidth: baseAnimWidth * scaleFactor
    implicitHeight: baseAnimHeight * scaleFactor
    width: implicitWidth
    height: implicitHeight

    property real blurStrength: 12.0
    readonly property real effectiveBlurRadius: Math.max(root.blurStrength * root.scaleFactor, 10.0)
    readonly property real animTime: animationClock.elapsed

    AnimationClock {
        id: animationClock
        framesPerSecond: Theme.continuousAnimationFps
        running: root.visible && root.opacity > 0
    }

    // Mathematical scale function with smooth sine easing
    function getScale(index) {
        var startTime = index * 1000.0;
        var dt = (animTime - startTime) % 6000.0;
        if (dt < 0) dt += 6000.0;
        if (dt < 2000.0) {
            return 1.0 + 0.3 * Math.sin((dt / 2000.0) * Math.PI);
        }
        return 1.0;
    }

    // 1. The 6 animated triangles - Full native resolution, 8x MSAA, FastBlur
    Item {
        id: trianglesLayer
        anchors.fill: parent

        layer.enabled: true
        layer.samples: 8
        layer.effect: FastBlur {
            radius: root.effectiveBlurRadius
            transparentBorder: true
        }

        Item {
            id: trianglesOrigin
            // Exact mathematical centering of the cluster within the animation rectangle
            x: root.width / 2 - root.centerOffsetX * root.scaleFactor
            y: root.height / 2 - root.centerOffsetY * root.scaleFactor

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
                    xScale: root.scaleFactor * root.getScale(0)
                    yScale: root.scaleFactor * root.getScale(0)
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
                    xScale: root.scaleFactor * root.getScale(1)
                    yScale: root.scaleFactor * root.getScale(1)
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
                    xScale: root.scaleFactor * root.getScale(2)
                    yScale: root.scaleFactor * root.getScale(2)
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
                    xScale: root.scaleFactor * root.getScale(3)
                    yScale: root.scaleFactor * root.getScale(3)
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
                    xScale: root.scaleFactor * root.getScale(4)
                    yScale: root.scaleFactor * root.getScale(4)
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
                    xScale: root.scaleFactor * root.getScale(5)
                    yScale: root.scaleFactor * root.getScale(5)
                }
            }
        }
    }

    // 2. Cat silhouette sitting on top of the triangles (perfectly synchronized position)
    Image {
        id: catImage
        x: trianglesOrigin.x - 70 * root.scaleFactor
        y: trianglesOrigin.y - 60 * root.scaleFactor
        width: 675 * root.scaleFactor
        height: 190 * root.scaleFactor
        source: Qt.resolvedUrl("assets/cat.svg")
        sourceSize.width: width
        sourceSize.height: height
        smooth: true
        mipmap: true
    }
}

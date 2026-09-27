pragma Singleton

import QtQuick

QtObject {
    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    // Brand and screen
    property color screenBackground: "#555555"
    property color bannerBackground: "#333333"
    property color primary: "#00d2ff"
    property color primaryHover: "#00e5ff"
    property color primaryMuted: "#00b4d8"
    property color success: "#00e676"
    property color error: "#ff3366"
    property color errorSoft: "#ff4d6d"
    property color warning: "#ffb703"
    property color warningHover: "#ffc300"
    property color accentSecondary: "#c77dff"

    // Text
    property color textPrimary: "#ffffff"
    property color textStrong: "#f4f4f7"
    property color textSecondary: "#dddddd"
    property color textMuted: "#a0a0b0"
    property color textDim: "#666677"
    property color placeholder: "#555566"
    property color actionText: "#d0d0dc"
    property color titleText: "#eeeef4"
    property color resizeHandle: "#777784"
    property color clockSecondary: "#a4a4ba"

    // Surfaces and borders
    property color cardBackground: "#111111"
    property color inputBackground: "#161616"
    property color popupBackground: "#222222"
    property color surface: "#282828"
    property color surfaceHover: "#253744"
    property color surfaceQuiet: "#191919"
    property color surfaceControlHover: "#22222c"
    property color surfacePopupHover: "#282836"
    property color surfaceSessionHover: "#252525"
    property color surfaceSessionSelected: "#1e2832"
    property color surfaceSelected: "#20202c"
    property color surfaceSelectedCyan: "#202c32"
    property color border: "#3c3c3c"
    property color borderSoft: "#2e2e2e"
    property color borderPopup: "#3a3a3a"
    property color borderQuiet: "#383838"
    property color disabledSurface: "#222222"
    property color scrim: "#dd000000"

    // Specialized action states
    property color cyanActionHover: "#152535"
    property color confirmationHover: "#10303a"
    property color purpleActionHover: "#251835"
    property color redActionHover: "#381520"
    property color warningBackground: "#2a1c00"
    property color warningBackgroundHover: "#3d2700"
    property color keyboardPanel: "#15151b"
    property color keyboardTitleBar: "#202029"
    property color keyboardKey: "#24242c"
    property color keyboardBorder: "#444450"
    property color closeHover: "#38202a"
    property color closeText: "#c8c8d0"
    property color closeTextHover: "#ff6b81"

    // Brand animation
    property color trianglePrimary: "yellow"
    property color triangleSecondary: "blue"
    property color clockText: "#ffffff"
    property color clockAccent: "#00d2ff"

    // Typography and geometry
    property url fontSource: Qt.resolvedUrl("fonts/CascadiaCode.ttf")
    property int cardRadius: 20
    property int controlRadius: 8
    property int inputRadius: 12
    property int popupRadius: 10
    property int actionButtonSize: 48

    // Motion
    property int microAnimation: 80
    property int fastAnimation: 150
    property int revealAnimation: 180
    property int feedbackAnimation: 200
    property int normalAnimation: 300
    property int tooltipDelay: 350
    property int slowAnimation: 400
    property int sceneAnimation: 550
    property int authenticationPulseDuration: 250
    property int statusTimeout: 4000
}

import QtQuick
import QtQuick.Window

import "../PavverTheme" as Pavver

Window {
    id: window
    readonly property bool compactPreview:
        Qt.application.arguments.indexOf("--compact") !== -1

    width: compactPreview ? 640 : 1280
    height: compactPreview ? 480 : 720
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    title: "Pavver shared UI preview"
    color: Pavver.Theme.screenBackground

    readonly property bool showBanner: height >= 520 && width >= 750
    readonly property bool showClock: width >= 750

    readonly property real bannerVisualTop: Math.round(Math.max(16, height * 0.048))
    readonly property real bannerVisualHeight: {
        if (!showBanner) return 0
        var fromWidth = (width * 0.85) / (675.0 / 190.0)
        var maxRatioHeight = height * 0.45
        var minCardSpace = (180 * horizontalCardScale) + 60
        var maxSpaceHeight = Math.max(100,
            height - bannerVisualTop - minCardSpace)
        return Math.round(Math.min(fromWidth,
            Math.min(maxRatioHeight, maxSpaceHeight)))
    }
    readonly property real bannerVisualWidth:
        Math.round(bannerVisualHeight * (675.0 / 190.0))
    readonly property real bannerVisualBottom:
        bannerVisualTop + bannerVisualHeight
    readonly property real bannerScale: showBanner
        ? bannerVisualWidth / 675.0 : 1.0

    readonly property real horizontalCardScale: {
        if (!showClock) {
            return Math.min(1.0, Math.max(0.55, (width - 40) / 680.0))
        }
        return Math.min(1.0, Math.max(0.55, (width - 60) / 1176.0))
    }
    readonly property real verticalCardScale: {
        var availableHeight = showBanner
            ? height - bannerVisualBottom - 20 : height - 40
        return Math.min(1.0, Math.max(0.55, availableHeight / 220.0))
    }
    readonly property real cardScale:
        Math.min(horizontalCardScale, verticalCardScale)
    readonly property real cardTargetY: {
        if (!showBanner) {
            return Math.round((height - card.height * cardScale) / 2.0)
        }
        var availableSpace = height - bannerVisualBottom
        var cardHeight = card.height * cardScale
        return Math.round(bannerVisualBottom
            + Math.max(16, (availableSpace - cardHeight) / 2.0))
    }

    ListModel {
        id: users
        ListElement {
            name: "pavver"
            realName: "Pavver"
            icon: ""
            iconName: ""
        }
        ListElement {
            name: "demo"
            realName: "Long demonstration user name"
            icon: ""
            iconName: ""
        }
    }

    ListModel {
        id: sessions
        ListElement { name: "Plasma (Wayland)"; file: "plasma.desktop" }
        ListElement { name: "Plasma (X11)"; file: "plasma-x11.desktop" }
    }

    Pavver.AnimatedBackground {
        anchors.fill: parent
        bannerTargetCenterX: window.width / 2
        bannerTargetCenterY: window.showBanner
            ? window.bannerVisualTop + window.bannerVisualHeight / 2.0 : -100
        bannerTargetScale: window.bannerScale
        bannerTargetOpacity: window.showBanner ? 1.0 : 0.0
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: window.cardTargetY
        spacing: Math.round(36 * window.cardScale)

        Pavver.Clock {
            visible: window.showClock
            scaleFactor: window.cardScale
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: card.width * window.cardScale
            height: card.height * window.cardScale

            Pavver.AuthCard {
                id: card
                scale: window.cardScale
                transformOrigin: Item.TopLeft
                userListModel: users
                allowUserSelection: true
                allowManualUsername: true
                sessionListModel: sessions
                showSessionBadge: true
                keyboardLayouts: [
                    { shortName: "us", longName: "English (US)" },
                    { shortName: "ua", longName: "Українська" }
                ]
                capsLockActive: true
                canSuspend: true
                canReboot: true
                canPowerOff: true
                virtualKeyboardActive: keyboard.keyboardActive

                onVirtualKeyboardRequested: keyboard.showHide()
                onKeyboardLayoutRequested: function(index) {
                    keyboardLayoutIndex = index
                }
                onAuthenticationRequested: function(username, password, sessionIndex) {
                    if (password === "error") {
                        authenticationFailed("Невірний пароль")
                    } else {
                        showStatusMessage("Демо-вхід виконано", "success")
                        inputFeedbackState = "idle"
                    }
                }
            }
        }
    }

    Pavver.VirtualKeyboard {
        id: keyboard
        z: 100
        inputField: card.virtualKeyboardTarget
        onEnterPressed: card.handleVirtualKeyboardEnter()
    }
}

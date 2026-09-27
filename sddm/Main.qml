import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami

import "PavverTheme" as Pavver

Item {
    id: root

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    width: 1600
    height: 900

    property bool isLoggingIn: false
    property bool isScreensaverMode: false
    property bool ignoreScreensaverWakeup: false
    property int screensaverIdleInterval: 60000

    SddmBackend { id: backend }

    // Responsive visibility thresholds for compact displays
    readonly property bool showBanner: root.height >= 520 && root.width >= 750
    readonly property bool showClock: root.width >= 750
    readonly property real bannerVisualTop: Math.round(Math.max(16, root.height * 0.048))
    readonly property real bannerVisualHeight: {
        if (!showBanner) return 0;
        var fromWidth = (root.width * 0.85) / (675.0 / 190.0);
        var maxRatioHeight = root.height * 0.45;
        var minCardSpace = (compactLoginCard.height * horizontalCardScale) + 60;
        var maxSpaceHeight = Math.max(100,
            root.height - bannerVisualTop - minCardSpace);
        return Math.round(Math.min(fromWidth,
            Math.min(maxRatioHeight, maxSpaceHeight)));
    }
    readonly property real bannerVisualWidth: bannerVisualHeight * (675.0 / 190.0)
    readonly property real bannerVisualBottom: bannerVisualTop + bannerVisualHeight
    readonly property real bannerScale: showBanner ? bannerVisualWidth / 675.0 : 1.0

    // Screensaver banner metrics match the Plasma lockscreen theme.
    readonly property real screensaverVisualWidth: Math.round(Math.min(
        root.width * 0.85,
        (root.height * 0.70) * (675.0 / 190.0)))
    readonly property real screensaverVisualHeight:
        Math.round(screensaverVisualWidth * (190.0 / 675.0))
    readonly property real screensaverScale: screensaverVisualWidth / 675.0

    // Card scaling calculated from available dimensions
    readonly property real horizontalCardScale: {
        if (!showClock) {
            return Math.min(1.0, Math.max(0.55, (root.width - 40) / 680.0));
        }
        return Math.min(1.0, Math.max(0.55, (root.width - 60) / 1176.0));
    }
    readonly property real verticalCardScale: {
        var availH = showBanner ? (root.height - bannerVisualBottom - 20) : (root.height - 40);
        return Math.min(1.0, Math.max(0.55, availH / (compactLoginCard.height + 40.0)));
    }
    readonly property real cardScale: Math.min(horizontalCardScale, verticalCardScale)

    // Dynamic vertical positioning: centers card and clock in the space below banner
    readonly property real cardTargetY: {
        if (!showBanner) {
            return Math.round((root.height - (compactLoginCard.height * cardScale)) / 2.0);
        }
        var availSpace = root.height - bannerVisualBottom;
        var cardH = compactLoginCard.height * cardScale;
        return Math.round(bannerVisualBottom + Math.max(16, (availSpace - cardH) / 2.0));
    }

    readonly property real activeBannerCenterY: isScreensaverMode
        ? Math.round(root.height / 2.0)
        : root.bannerVisualTop + root.bannerVisualHeight / 2.0
    readonly property real activeBannerScale: isScreensaverMode
        ? screensaverScale : bannerScale
    readonly property real activeBannerOpacity: {
        if (isLoggingIn) return 0.0;
        if (isScreensaverMode) return 1.0;
        return showBanner ? 1.0 : 0.0;
    }
    readonly property real activeBottomRowY:
        isScreensaverMode || isLoggingIn ? root.height + 70 : cardTargetY
    readonly property real activeBottomRowOpacity:
        isScreensaverMode || isLoggingIn ? 0.0 : 1.0

    function registerActivity() {
        if (isLoggingIn || ignoreScreensaverWakeup) return;
        if (isScreensaverMode) {
            isScreensaverMode = false;
            Qt.callLater(compactLoginCard.focusPassword);
        }
        if (idleScreensaverTimer.running) {
            idleScreensaverTimer.restart();
        }
    }

    function enterScreensaver() {
        if (isLoggingIn || isScreensaverMode) return;
        virtualKeyboard.hide();
        compactLoginCard.closePopups();
        isScreensaverMode = true;
        ignoreScreensaverWakeup = true;
        screensaverCooldownTimer.restart();
        loginScreenRoot.forceActiveFocus();
    }

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    Pavver.AnimatedBackground {
        id: wallpaper
        anchors.fill: parent
        bannerTargetCenterX: root.width / 2.0
        bannerTargetCenterY: root.activeBannerCenterY
        bannerTargetScale: root.activeBannerScale
        bannerTargetOpacity: root.activeBannerOpacity
        enableAnimations: true
    }

    MouseArea {
        id: loginScreenRoot
        anchors.fill: parent
        focus: true
        hoverEnabled: true
        drag.filterChildren: true
        cursorShape: root.isScreensaverMode ? Qt.BlankCursor : Qt.ArrowCursor

        onPressed: root.registerActivity()
        onPositionChanged: root.registerActivity()

        Keys.onPressed: function(event) {
            if (root.ignoreScreensaverWakeup) {
                event.accepted = true;
                return;
            }
            if (root.isScreensaverMode) {
                root.registerActivity();
                event.accepted = true;
                return;
            }
            root.registerActivity();
            if (event.key === Qt.Key_Escape) {
                if (compactLoginCard.closePopups()) {
                    event.accepted = true;
                } else if (virtualKeyboard.keyboardActive) {
                    virtualKeyboard.hide();
                    compactLoginCard.focusPassword();
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            } else {
                event.accepted = false;
            }
        }

        Timer {
            id: idleScreensaverTimer
            interval: root.screensaverIdleInterval
            repeat: false
            running: !root.isLoggingIn
                && !root.isScreensaverMode
                && !compactLoginCard.hasOpenPopup
                && !virtualKeyboard.keyboardActive
            onTriggered: root.enterScreensaver()
        }

        Timer {
            id: screensaverCooldownTimer
            interval: 2500
            repeat: false
            onTriggered: root.ignoreScreensaverWakeup = false
        }

        MouseArea {
            anchors.fill: parent
            visible: compactLoginCard.hasOpenPopup
            z: 1
            onClicked: compactLoginCard.closePopups()
        }

        // Row containing Clock and Login Card, perfectly centered as a unified group
        Row {
            id: bottomRow
            z: 2
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.activeBottomRowY
            opacity: root.activeBottomRowOpacity
            visible: opacity > 0.0
            spacing: Math.round(36 * root.cardScale)

            Behavior on y {
                NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }

            // Clock & Date (Left)
            Pavver.Clock {
                id: clock
                visible: root.showClock
                anchors.verticalCenter: parent.verticalCenter
                scaleFactor: root.cardScale
            }

            // Login Card (Right, or centered automatically when clock is hidden)
            Item {
                id: cardWrapper
                width: compactLoginCard.width * root.cardScale
                height: compactLoginCard.height * root.cardScale
                anchors.verticalCenter: parent.verticalCenter
                enabled: !root.isLoggingIn

                Pavver.AuthCard {
                    id: compactLoginCard
                    anchors.top: parent.top
                    anchors.left: parent.left
                    transformOrigin: Item.TopLeft
                    scale: root.cardScale
                    userListModel: backend.usersModel
                    currentUserIndex: backend.initialUserIndex
                    rememberedUserName: backend.rememberedUserName
                    allowUserSelection: true
                    allowManualUsername: true
                    sessionListModel: backend.sessionsModel
                    currentSessionIndex: backend.initialSessionIndex
                    showSessionBadge: true
                    keyboardLayouts: backend.keyboardLayouts
                    keyboardLayoutIndex: backend.keyboardLayoutIndex
                    keyboardLayoutCount: backend.keyboardLayouts.length
                    capsLockActive: backend.capsLockActive
                    canSuspend: backend.canSuspend
                    canReboot: backend.canReboot
                    canPowerOff: backend.canPowerOff
                    fallbackFontFamily: typeof config !== "undefined" && config.font
                        ? config.font : "Cascadia Code"
                    virtualKeyboardActive: virtualKeyboard.keyboardActive

                    onUserActivity: root.registerActivity()

                    onVirtualKeyboardRequested: {
                        virtualKeyboard.showHide()
                    }

                    onKeyboardLayoutRequested: function(index) {
                        backend.setKeyboardLayout(index)
                    }
                    onSuspendRequested: backend.suspend()
                    onRebootRequested: backend.reboot()
                    onPowerOffRequested: backend.powerOff()

                    onAuthenticationRequested: function(username, password, sessionIndex) {
                        virtualKeyboard.hide()
                        root.isScreensaverMode = false
                        root.ignoreScreensaverWakeup = false
                        root.isLoggingIn = true
                        backend.authenticate(username, password, sessionIndex)
                    }
                }
            }
        }

        // Login loader: Cat silhouette on pulsing blurred triangles (Center of screen)
        Pavver.LoginLoader {
            id: catLoader
            anchors.centerIn: parent
            opacity: root.isLoggingIn ? 1.0 : 0.0
            visible: opacity > 0.0

            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
        }

        Pavver.VirtualKeyboard {
            id: virtualKeyboard
            z: 100
            inputField: compactLoginCard.virtualKeyboardTarget
            onEnterPressed: compactLoginCard.handleVirtualKeyboardEnter()
        }
    }

    Connections {
        target: backend
        function onAuthenticationFailed(message) {
            root.isLoggingIn = false
            compactLoginCard.authenticationFailed(message)
        }
        function onAuthenticationSucceeded() {
            virtualKeyboard.hide()
            compactLoginCard.closePopups()
            root.isLoggingIn = true
        }
    }
}

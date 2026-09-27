import QtQuick
import QtTest

import ".." as SddmTheme

Item {
    width: 1280
    height: 720

    SddmTheme.Main {
        id: theme
        anchors.fill: parent
        screensaverIdleInterval: 1000
    }

    TestCase {
        name: "SddmIdleActivity"
        when: windowShown

        function test_typingResetsIdleTimer() {
            for (var i = 0; i < 4; ++i) {
                keyClick(Qt.Key_A)
                wait(600)
                verify(!theme.isScreensaverMode,
                    "screensaver activated while username was being typed")
            }

            tryCompare(theme, "isScreensaverMode", true, 1500)
        }
    }
}

import QtQuick

import "PavverTheme" as Pavver

// The greeter maps its window only after this file loads, and KWin shows black
// until then, so the login screen compiles behind a flat background.
Rectangle {
    width: 1600
    height: 900
    color: Pavver.Theme.screenBackground

    Loader {
        anchors.fill: parent
        asynchronous: true
        focus: true
        source: "LoginScreen.qml"
    }
}

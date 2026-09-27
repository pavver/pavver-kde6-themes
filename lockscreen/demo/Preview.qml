import QtQuick
import QtQuick.Window

import "../contents/lockscreen" as Theme

Window {
    width: 1280
    height: 720
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    flags: Qt.Window

    Component.onCompleted: requestActivate()
    color: "#1a1a1a"
    title: "Pavver Lock Screen Preview"

    Theme.LockScreenUi {
        anchors.fill: parent
    }
}

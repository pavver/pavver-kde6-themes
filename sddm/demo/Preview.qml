import QtQuick
import QtQuick.Window

import ".." as SddmTheme

Window {
    width: 1280
    height: 720
    minimumWidth: 640
    minimumHeight: 480
    visible: true
    title: "Pavver SDDM screensaver preview"

    SddmTheme.Main {
        anchors.fill: parent
        screensaverIdleInterval: 2000
    }
}

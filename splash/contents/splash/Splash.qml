import QtQuick

import "PavverTheme" as Pavver

Rectangle {
    id: root

    // Set by ksplashqml for every startup stage.
    property int stage

    color: Pavver.Theme.loaderBackground

    // The window maps as soon as the flat background is ready, which shortens
    // the black gap left by KWin. The loader follows once it has been compiled.
    Loader {
        anchors.fill: parent
        asynchronous: true
        sourceComponent: Item {
            Pavver.LoginLoader {
                anchors.centerIn: parent
                caption: "Вхід у систему"
            }
        }
    }
}

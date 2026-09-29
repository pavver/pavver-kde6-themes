import QtQuick

Item {
    id: root
    property bool debug: false

    property bool viewVisible: false

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    implicitWidth: 800
    implicitHeight: 600

    LockScreenUi {
        id: lockScreenUi
        anchors.fill: parent
        viewVisible: root.viewVisible
    }
}

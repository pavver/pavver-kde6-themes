import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root

    property alias cfg_EnableAnimations: animationsCheckBox.checked
    property alias formLayout: root

    Controls.CheckBox {
        id: animationsCheckBox
        Kirigami.FormData.label: qsTr("Motion:")
        text: qsTr("Animate the Pavver banner")
    }
}

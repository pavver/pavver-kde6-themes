import QtQuick
import QtQuick.Controls

Item {
    id: root
    property real scaleFactor: 1.0
    property string fallbackFontFamily: "Cascadia Code"

    width: Math.max(timeText.implicitWidth, dateText.implicitWidth)
    height: timeText.implicitHeight + Math.round(10 * scaleFactor) + dateText.implicitHeight

    FontLoader {
        id: cascadiaFont
        source: Theme.fontSource
    }

    readonly property string mainFontFamily: cascadiaFont.status === FontLoader.Ready
        ? cascadiaFont.name : fallbackFontFamily
    property var currentDate: new Date()

    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: root.currentDate = new Date()
    }

    function formatUkrainianDate(d) {
        var days = ["Неділя", "Понеділок", "Вівторок", "Середа", "Четвер", "П'ятниця", "Субота"];
        var months = [
            "січня", "лютого", "березня", "квітня", "травня", "червня",
            "липня", "серпня", "вересня", "жовтня", "листопада", "грудня"
        ];
        return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear();
    }

    // Digital Time with seconds (hh:mm:ss) - native vector font rendering with antialiasing
    Text {
        id: timeText
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(root.currentDate, "hh:mm:ss")
        color: Theme.clockText
        font.family: root.mainFontFamily
        font.pixelSize: Math.round(76 * root.scaleFactor)
        font.bold: true
        renderType: Text.QtRendering
        antialiasing: true
    }

    // Ukrainian Date (e.g. "Четвер, 24 вересня 2026") - native vector font rendering with antialiasing
    Text {
        id: dateText
        anchors.top: timeText.bottom
        anchors.topMargin: Math.round(10 * root.scaleFactor)
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.formatUkrainianDate(root.currentDate)
        color: Theme.clockSecondary
        font.family: root.mainFontFamily
        font.pixelSize: Math.round(32 * root.scaleFactor)
        renderType: Text.QtRendering
        antialiasing: true
    }
}

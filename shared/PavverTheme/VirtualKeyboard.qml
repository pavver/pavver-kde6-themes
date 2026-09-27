import QtQuick

Item {
    id: root

    property Item inputField: null
    property bool keyboardActive: false
    property bool ukrainianLayout: false
    property bool shiftActive: false
    property bool positioned: false

    signal enterPressed()

    anchors.fill: parent
    visible: keyboardActive

    readonly property var numberKeys: [
        { label: shiftActive ? "!" : "1", value: shiftActive ? "!" : "1" },
        { label: shiftActive ? "@" : "2", value: shiftActive ? "@" : "2" },
        { label: shiftActive ? "#" : "3", value: shiftActive ? "#" : "3" },
        { label: shiftActive ? "$" : "4", value: shiftActive ? "$" : "4" },
        { label: shiftActive ? "%" : "5", value: shiftActive ? "%" : "5" },
        { label: shiftActive ? "^" : "6", value: shiftActive ? "^" : "6" },
        { label: shiftActive ? "&" : "7", value: shiftActive ? "&" : "7" },
        { label: shiftActive ? "*" : "8", value: shiftActive ? "*" : "8" },
        { label: shiftActive ? "(" : "9", value: shiftActive ? "(" : "9" },
        { label: shiftActive ? ")" : "0", value: shiftActive ? ")" : "0" },
        { label: shiftActive ? "_" : "-", value: shiftActive ? "_" : "-" },
        { label: shiftActive ? "+" : "=", value: shiftActive ? "+" : "=" },
        { label: "Backspace", action: "backspace", weight: 2.2 }
    ]
    readonly property var firstLetterRow: ukrainianLayout
        ? ["й", "ц", "у", "к", "е", "н", "г", "ш", "щ", "з", "х", "ї", "ґ"]
        : ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]"]
    readonly property var secondLetterRow: ukrainianLayout
        ? ["ф", "і", "в", "а", "п", "р", "о", "л", "д", "ж", "є"]
        : ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"]
    readonly property var thirdLetterRow: ukrainianLayout
        ? ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю", ".", "'"]
        : ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/", "\\"]
    readonly property var bottomKeys: [
        { label: shiftActive ? "SHIFT" : "Shift", action: "shift", weight: 1.6 },
        { label: ukrainianLayout ? "UA" : "EN", action: "layout", weight: 1.2 },
        { label: ukrainianLayout ? "Пробіл" : "Space", action: "space", weight: 5.0 },
        { label: "Enter", action: "enter", weight: 1.8 }
    ]

    FontLoader {
        id: keyboardFont
        source: Theme.fontSource
    }

    function showHide() {
        keyboardActive = !keyboardActive;
        if (keyboardActive) {
            if (!positioned) {
                keyboardPanel.x = Math.max(12, root.width - keyboardPanel.width - 24);
                keyboardPanel.y = 24;
                positioned = true;
            }
            if (inputField) {
                inputField.forceActiveFocus();
            }
        }
    }

    function hide() {
        keyboardActive = false;
        shiftActive = false;
    }

    function displayCharacter(character) {
        if (!shiftActive) {
            return character;
        }
        var shiftedCharacters = {
            "[": "{",
            "]": "}",
            ";": ":",
            "'": "\"",
            ",": "<",
            ".": ">",
            "/": "?",
            "\\": "|"
        };
        return shiftedCharacters[character] || character.toUpperCase();
    }

    function insertText(text) {
        if (!inputField || !inputField.enabled) {
            return;
        }
        if (inputField.selectionStart !== inputField.selectionEnd) {
            inputField.remove(inputField.selectionStart, inputField.selectionEnd);
        }
        inputField.insert(inputField.cursorPosition, text);
        inputField.forceActiveFocus();
        shiftActive = false;
    }

    function backspace() {
        if (!inputField || !inputField.enabled) {
            return;
        }
        if (inputField.selectionStart !== inputField.selectionEnd) {
            inputField.remove(inputField.selectionStart, inputField.selectionEnd);
        } else if (inputField.cursorPosition > 0) {
            var cursor = inputField.cursorPosition;
            inputField.remove(cursor - 1, cursor);
        }
        inputField.forceActiveFocus();
    }

    function handleKey(key) {
        if (typeof key === "string") {
            insertText(displayCharacter(key));
            return;
        }
        if (key.action === "backspace") {
            backspace();
        } else if (key.action === "shift") {
            shiftActive = !shiftActive;
        } else if (key.action === "layout") {
            ukrainianLayout = !ukrainianLayout;
            shiftActive = false;
        } else if (key.action === "space") {
            insertText(" ");
        } else if (key.action === "enter") {
            if (inputField && inputField.enabled) {
                enterPressed();
            }
        } else if (key.value) {
            insertText(key.value);
        }
    }

    function clampPanelToScreen() {
        keyboardPanel.width = Math.min(keyboardPanel.width, Math.max(240, root.width - 24));
        keyboardPanel.height = Math.min(keyboardPanel.height, Math.max(180, root.height - 24));
        keyboardPanel.x = Math.max(12, Math.min(keyboardPanel.x, root.width - keyboardPanel.width - 12));
        keyboardPanel.y = Math.max(12, Math.min(keyboardPanel.y, root.height - keyboardPanel.height - 12));
    }

    onWidthChanged: if (positioned) clampPanelToScreen()
    onHeightChanged: if (positioned) clampPanelToScreen()

    component KeyboardRow: Row {
        id: keyboardRow

        required property var keys
        signal keyPressed(var key)

        spacing: 5

        function totalWeight() {
            var total = 0;
            for (var i = 0; i < keys.length; ++i) {
                total += keys[i].weight || 1;
            }
            return total;
        }

        Repeater {
            model: keyboardRow.keys

            Rectangle {
                required property var modelData

                width: (keyboardRow.width - keyboardRow.spacing * (keyboardRow.keys.length - 1))
                    * (modelData.weight || 1) / keyboardRow.totalWeight()
                height: keyboardRow.height
                radius: 5
                color: keyMouse.pressed
                    ? Theme.primaryMuted
                    : (keyMouse.containsMouse ? Theme.surfaceHover : Theme.keyboardKey)
                border.color: keyMouse.containsMouse ? Theme.primary : Theme.keyboardBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.microAnimation } }
                Behavior on border.color { ColorAnimation { duration: Theme.microAnimation } }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    text: typeof modelData === "string"
                        ? root.displayCharacter(modelData)
                        : modelData.label
                    color: Theme.textStrong
                    font.family: keyboardFont.status === FontLoader.Ready ? keyboardFont.name : "monospace"
                    font.pixelSize: Math.max(11, Math.min(18, parent.height * 0.34))
                    font.bold: modelData.action === "enter" || modelData.action === "shift"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: keyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: keyboardRow.keyPressed(modelData)
                }
            }
        }
    }

    Rectangle {
        id: keyboardPanel

        width: Math.min(680, Math.max(500, root.width * 0.48), root.width - 24)
        height: Math.min(280, Math.max(250, root.height * 0.34), root.height - 24)
        radius: 8
        color: Theme.keyboardPanel
        border.color: Theme.primaryMuted
        border.width: 1
        clip: true

        Rectangle {
            id: titleBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 38
            color: Theme.keyboardTitleBar

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "Віртуальна клавіатура"
                color: Theme.titleText
                font.family: keyboardFont.status === FontLoader.Ready ? keyboardFont.name : "monospace"
                font.pixelSize: 14
                font.bold: true
            }

            Rectangle {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 28
                radius: 5
                color: closeMouse.containsMouse ? Theme.closeHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "X"
                    color: closeMouse.containsMouse ? Theme.closeTextHover : Theme.closeText
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.hide()
                }
            }

            MouseArea {
                id: dragArea

                anchors.left: parent.left
                anchors.right: closeButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                cursorShape: Qt.SizeAllCursor
                property point pressPoint
                property real startX
                property real startY

                onPressed: function(mouse) {
                    pressPoint = mapToItem(root, mouse.x, mouse.y);
                    startX = keyboardPanel.x;
                    startY = keyboardPanel.y;
                }
                onPositionChanged: function(mouse) {
                    if (!pressed) return;
                    var current = mapToItem(root, mouse.x, mouse.y);
                    keyboardPanel.x = Math.max(12, Math.min(startX + current.x - pressPoint.x,
                        root.width - keyboardPanel.width - 12));
                    keyboardPanel.y = Math.max(12, Math.min(startY + current.y - pressPoint.y,
                        root.height - keyboardPanel.height - 12));
                }
            }
        }

        Column {
            id: keyboardRows

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleBar.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 10
            spacing: 5

            KeyboardRow {
                width: parent.width
                height: (keyboardRows.height - keyboardRows.spacing * 4) / 5
                keys: root.numberKeys
                onKeyPressed: function(key) { root.handleKey(key); }
            }
            KeyboardRow {
                width: parent.width
                height: (keyboardRows.height - keyboardRows.spacing * 4) / 5
                keys: root.firstLetterRow
                onKeyPressed: function(key) { root.handleKey(key); }
            }
            KeyboardRow {
                width: parent.width
                height: (keyboardRows.height - keyboardRows.spacing * 4) / 5
                keys: root.secondLetterRow
                onKeyPressed: function(key) { root.handleKey(key); }
            }
            KeyboardRow {
                width: parent.width
                height: (keyboardRows.height - keyboardRows.spacing * 4) / 5
                keys: root.thirdLetterRow
                onKeyPressed: function(key) { root.handleKey(key); }
            }
            KeyboardRow {
                width: parent.width
                height: (keyboardRows.height - keyboardRows.spacing * 4) / 5
                keys: root.bottomKeys
                onKeyPressed: function(key) { root.handleKey(key); }
            }
        }

        MouseArea {
            id: resizeArea

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 26
            height: 26
            cursorShape: Qt.SizeFDiagCursor
            property point pressPoint
            property real startWidth
            property real startHeight

            onPressed: function(mouse) {
                pressPoint = mapToItem(root, mouse.x, mouse.y);
                startWidth = keyboardPanel.width;
                startHeight = keyboardPanel.height;
            }
            onPositionChanged: function(mouse) {
                if (!pressed) return;
                var current = mapToItem(root, mouse.x, mouse.y);
                var minWidth = Math.min(420, root.width - keyboardPanel.x - 12);
                var minHeight = Math.min(220, root.height - keyboardPanel.y - 12);
                keyboardPanel.width = Math.max(minWidth, Math.min(
                    startWidth + current.x - pressPoint.x,
                    root.width - keyboardPanel.x - 12));
                keyboardPanel.height = Math.max(minHeight, Math.min(
                    startHeight + current.y - pressPoint.y,
                    root.height - keyboardPanel.y - 12));
            }

            Repeater {
                model: 3

                Rectangle {
                    required property int index
                    width: 12
                    height: 1
                    x: 9 + index * 4
                    y: 20 - index * 4
                    rotation: -45
                    color: resizeArea.containsMouse ? Theme.primary : Theme.resizeHandle
                }
            }
        }
    }
}

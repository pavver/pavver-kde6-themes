import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    id: root
    width: 680
    height: 200

    property bool mockCapsLock: false
    property bool capsLockActive: false
    readonly property bool isCapsLockOn: mockCapsLock || capsLockActive

    FontLoader {
        id: cascadiaFont
        source: Theme.fontSource
    }

    property string fallbackFontFamily: "Cascadia Code"
    readonly property string mainFontFamily: cascadiaFont.status === FontLoader.Ready
        ? cascadiaFont.name : fallbackFontFamily

    // Platform adapters provide capabilities and normalized models. The
    // component never talks to SDDM or KScreenLocker directly.
    property var keyboardLayouts: []
    property int keyboardLayoutIndex: 0
    property int keyboardLayoutCount: availableLayouts.length
    property bool showKeyboardLayoutButton: keyboardLayoutCount > 1

    readonly property var availableLayouts: {
        if (keyboardLayouts && keyboardLayouts.length > 0) {
            return keyboardLayouts;
        }
        return [
            { shortName: "us", longName: "English (US)" },
            { shortName: "ua", longName: "Українська" }
        ];
    }

    property int mockLayoutIndex: 0
    readonly property int activeLayoutIndex: keyboardLayouts && keyboardLayouts.length > 0
        ? keyboardLayoutIndex : mockLayoutIndex

    readonly property string currentLayoutShortName: {
        if (availableLayouts.length > activeLayoutIndex && activeLayoutIndex >= 0) {
            var l = availableLayouts[activeLayoutIndex];
            if (l && l.shortName) return l.shortName.toUpperCase();
        }
        return "US";
    }

    readonly property string currentLayoutFullName: {
        if (availableLayouts.length > activeLayoutIndex && activeLayoutIndex >= 0) {
            var l = availableLayouts[activeLayoutIndex];
            if (l && l.longName) return "Розкладка: " + l.longName;
        }
        return "Розкладка клавіатури";
    }

    function nextKeyboardLayout() {
        if (keyboardLayoutCount <= 1) return;
        var nextIdx = (keyboardLayoutIndex + 1) % keyboardLayoutCount;
        if (keyboardLayouts && keyboardLayouts.length > 0) {
            keyboardLayoutRequested(nextIdx);
        } else {
            mockLayoutIndex = nextIdx;
        }
    }

    property var userListModel: null
    property int currentUserIndex: 0
    property var usersList: []
    property bool allowUserSelection: false
    property bool allowManualUsername: false
    property string rememberedUserName: ""
    property string defaultUserDisplayName: rememberedUserName
    property string defaultUserAvatarUrl: ""
    property bool manualUsernameMode: false
    property string manualUsername: ""
    property bool passwordlessMode: false
    property string passwordPrompt: ""
    property string authenticationHint: ""
    property string passwordlessLabel: "Розблокувати"
    property bool virtualKeyboardActive: false
    property Item virtualKeyboardTarget: passwordInput
    property alias passwordField: passwordInput
    property alias passwordText: passwordInput.text
    readonly property bool isTyping: !passwordlessMode
        && (passwordInput.text.length > 0
            || (usernameInput.visible && usernameInput.text.length > 0))

    onPasswordlessModeChanged: {
        closePopups();
        if (passwordlessMode && virtualKeyboardActive) {
            virtualKeyboardRequested();
        }
        Qt.callLater(focusPassword);
    }

    readonly property int listedUserCount: {
        if (usersList.length > 0) return usersList.length;
        if (userListModel && typeof userListModel.count === "number") return userListModel.count;
        return 0;
    }
    readonly property bool manualUsernameRequired: allowManualUsername
        && listedUserCount === 0 && rememberedUserName.length === 0

    // Extract normalized roles from either a QAbstractItemModel or ListModel.
    Item {
        id: userExtractor
        visible: false

        Repeater {
            id: userRepeater
            model: root.userListModel

            Item {
                property string uName: (typeof model.name !== "undefined" && model.name) ? model.name : ""
                property string uRealName: (typeof model.realName !== "undefined" && model.realName) ? model.realName : ""
                property string uIcon: (typeof model.icon !== "undefined" && model.icon) ? model.icon : ""
                property string uIconName: (typeof model.iconName !== "undefined" && model.iconName) ? model.iconName : ""

                Component.onCompleted: root.rebuildUserList()
                Component.onDestruction: root.rebuildUserList()
            }
        }
    }

    function rebuildUserList() {
        var arr = [];
        for (var i = 0; i < userRepeater.count; ++i) {
            var it = userRepeater.itemAt(i);
            if (it) {
                arr.push({
                    name: it.uName,
                    realName: it.uRealName,
                    icon: it.uIcon,
                    iconName: it.uIconName
                });
            }
        }
        root.usersList = arr;
    }

    readonly property string currentUserName: {
        if (manualUsernameMode || manualUsernameRequired) {
            return manualUsername.trim();
        }
        if (usersList.length > currentUserIndex && currentUserIndex >= 0) {
            var u = usersList[currentUserIndex];
            if (u && u.name) return u.name;
        }
        return rememberedUserName;
    }

    // Desktop Session handling
    property bool showSessionBadge: true
    property var sessionListModel: null
    property int currentSessionIndex: 0
    property var sessionsList: []

    Item {
        id: sessionExtractor
        visible: false
        Repeater {
            id: sessionRepeater
            model: root.sessionListModel
            Item {
                property string sName: (typeof model.name !== "undefined" && model.name) ? model.name : ""
                property string sFile: (typeof model.file !== "undefined" && model.file) ? model.file : ""
                Component.onCompleted: root.rebuildSessionList()
                Component.onDestruction: root.rebuildSessionList()
            }
        }
    }

    function rebuildSessionList() {
        var arr = [];
        for (var i = 0; i < sessionRepeater.count; ++i) {
            var it = sessionRepeater.itemAt(i);
            if (it && it.sName) {
                arr.push({
                    name: it.sName,
                    file: it.sFile,
                    index: i
                });
            }
        }
        root.sessionsList = arr;
    }

    readonly property string currentSessionDisplayName: {
        if (sessionsList.length > currentSessionIndex && currentSessionIndex >= 0) {
            var s = sessionsList[currentSessionIndex];
            if (s && s.name) return s.name;
        }
        if (sessionListModel && sessionListModel.get && currentSessionIndex >= 0 && sessionListModel.count > currentSessionIndex) {
            var item = sessionListModel.get(currentSessionIndex);
            if (item && item.name) return item.name;
        }
        return "Plasma (Wayland)";
    }

    readonly property string currentUserDisplayName: {
        if (manualUsernameMode || manualUsernameRequired) {
            return manualUsername.length > 0 ? manualUsername : "Інший користувач";
        }
        if (usersList.length > currentUserIndex && currentUserIndex >= 0) {
            var u = usersList[currentUserIndex];
            if (u && u.realName) return u.realName;
            if (u && u.name) return u.name;
        }
        return defaultUserDisplayName || currentUserName;
    }

    readonly property string currentUserAvatarUrl: {
        if (manualUsernameMode || manualUsernameRequired) return "";
        var path = defaultUserAvatarUrl || "";
        if (usersList.length > currentUserIndex && currentUserIndex >= 0) {
            var u = usersList[currentUserIndex];
            if (u && u.icon) path = u.icon;
        }
        if (!path && currentUserName.length > 0) {
            path = "/var/lib/AccountsService/icons/" + currentUserName;
        }
        if (path.length > 0 && path.indexOf("://") === -1) {
            return "file://" + path.split("/").map(encodeURIComponent).join("/");
        }
        return path;
    }

    readonly property int userCount: listedUserCount
    property bool authenticationBlocked: false
    property bool canSuspend: false
    property bool canReboot: false
    property bool canPowerOff: false
    readonly property bool effectiveAuthenticationBlocked: authenticationBlocked
        || inputFeedbackState !== "idle"
    readonly property bool canSubmitLogin: currentUserName.length > 0
        && passwordInput.text.length > 0 && !effectiveAuthenticationBlocked
    readonly property bool userChooserAvailable: (allowUserSelection && userCount > 0)
        || allowManualUsername
    readonly property bool hasOpenPopup: userDropdown.visible || sessionDropdown.visible

    signal authenticationRequested(string username, string password, int sessionIndex)
    signal keyboardLayoutRequested(int index)
    signal suspendRequested()
    signal rebootRequested()
    signal powerOffRequested()
    signal virtualKeyboardRequested()
    signal passwordlessAuthenticationRequested()
    signal userActivity()

    property string inputFeedbackState: "idle" // "idle", "success", "error"
    property real pulseAlpha: 1.0
    property real pulseBorderWidth: 1.5
    property string statusMessage: ""
    property string statusType: "info"
    readonly property string displayedStatusMessage: statusMessage || authenticationHint
    readonly property string displayedStatusType: statusMessage ? statusType : "info"
    property string failureMessage: "Не вдалося виконати автентифікацію"

    function focusUsername() {
        manualUsernameMode = true;
        virtualKeyboardTarget = usernameInput;
        usernameInput.forceActiveFocus();
    }

    function focusPassword() {
        if (passwordlessMode) {
            passwordlessButton.forceActiveFocus();
            return;
        }
        virtualKeyboardTarget = passwordInput;
        passwordInput.forceActiveFocus();
    }

    function selectListedUser(index) {
        if (index < 0 || index >= userCount) return;
        currentUserIndex = index;
        manualUsernameMode = false;
        closePopups();
        clearPassword();
        clearStatusMessage();
        focusPassword();
    }

    function selectManualUser() {
        closePopups();
        clearPassword();
        clearStatusMessage();
        focusUsername();
    }

    function clearPassword() {
        passwordInput.text = "";
        concealPassword();
    }

    function concealPassword() {
        passwordInput.echoMode = TextInput.Password;
    }

    function clearStatusMessage() {
        statusMessage = "";
        statusType = "info";
        statusClearTimer.stop();
    }

    function showStatusMessage(message, type) {
        statusMessage = message || "";
        statusType = type || "info";
        if (statusMessage.length > 0) statusClearTimer.restart();
    }

    function closePopups() {
        var hadOpenPopup = hasOpenPopup;
        userDropdown.visible = false;
        sessionDropdown.visible = false;
        return hadOpenPopup;
    }

    function handleVirtualKeyboardEnter() {
        if (passwordlessMode) {
            requestPasswordlessAuthentication();
            return;
        }
        if (virtualKeyboardTarget === usernameInput) {
            if (currentUserName.length > 0) focusPassword();
        } else {
            doLogin();
        }
    }

    Timer {
        id: statusClearTimer
        interval: Theme.statusTimeout
        repeat: false
        onTriggered: root.clearStatusMessage()
    }

    // Success animation: pulse vibrant green border for 500ms, then trigger loader transition
    SequentialAnimation {
        id: successPulseAnim
        running: false
        ScriptAction {
            script: {
                root.inputFeedbackState = "success";
                root.pulseBorderWidth = 3.0;
                root.pulseAlpha = 1.0;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 1.0; to: 0.55; duration: Theme.authenticationPulseDuration; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 3.0; to: 2.2; duration: Theme.authenticationPulseDuration; easing.type: Easing.InOutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 0.55; to: 1.0; duration: Theme.authenticationPulseDuration; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 2.2; to: 3.0; duration: Theme.authenticationPulseDuration; easing.type: Easing.InOutQuad }
        }
        ScriptAction {
            script: {
                root.authenticationRequested(currentUserName, passwordInput.text, currentSessionIndex);
            }
        }
    }

    function doLogin() {
        if (effectiveAuthenticationBlocked) return;
        if (currentUserName.length === 0) {
            focusUsername();
        } else if (passwordInput.text.length > 0) {
            closePopups();
            clearStatusMessage();
            successPulseAnim.restart();
        }
    }

    function requestPasswordlessAuthentication() {
        if (!effectiveAuthenticationBlocked) {
            closePopups();
            passwordlessAuthenticationRequested();
        }
    }

    // Error animation: clear text immediately, pulse red border twice with tactile micro-shake, then smooth exit fade
    SequentialAnimation {
        id: errorPulseAnim
        running: false
        ScriptAction {
            script: {
                root.clearPassword();
                root.inputFeedbackState = "error";
                root.pulseBorderWidth = 3.0;
                root.pulseAlpha = 1.0;
                root.showStatusMessage(root.failureMessage, "error");
                root.focusPassword();
            }
        }
        // Pulse 1 + Tactile Micro-shake
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: root; property: "x"; to: root.x - 8; duration: 40; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "x"; to: root.x + 8; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "x"; to: root.x - 5; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "x"; to: root.x + 5; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: root; property: "x"; to: root.x; duration: 40; easing.type: Easing.InOutQuad }
            }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation { target: root; property: "pulseAlpha"; from: 1.0; to: 0.55; duration: Theme.feedbackAnimation; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: root; property: "pulseBorderWidth"; from: 3.0; to: 2.2; duration: Theme.feedbackAnimation; easing.type: Easing.InOutQuad }
                }
                ParallelAnimation {
                    NumberAnimation { target: root; property: "pulseAlpha"; from: 0.55; to: 1.0; duration: Theme.feedbackAnimation; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: root; property: "pulseBorderWidth"; from: 2.2; to: 3.0; duration: Theme.feedbackAnimation; easing.type: Easing.InOutQuad }
                }
            }
        }
        // Pulse 2
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 1.0; to: 0.55; duration: Theme.feedbackAnimation; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 3.0; to: 2.2; duration: Theme.feedbackAnimation; easing.type: Easing.InOutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 0.55; to: 1.0; duration: Theme.feedbackAnimation; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 2.2; to: 3.0; duration: Theme.feedbackAnimation; easing.type: Easing.InOutQuad }
        }
        // Smooth exit fade to idle (400 ms)
        ParallelAnimation {
            NumberAnimation { target: root; property: "pulseAlpha"; from: 1.0; to: 0.0; duration: Theme.slowAnimation; easing.type: Easing.InOutQuad }
            NumberAnimation { target: root; property: "pulseBorderWidth"; from: 3.0; to: 1.5; duration: Theme.slowAnimation; easing.type: Easing.InOutQuad }
        }
        ScriptAction {
            script: {
                root.inputFeedbackState = "idle";
                root.pulseAlpha = 1.0;
                root.pulseBorderWidth = 1.5;
            }
        }
    }

    function authenticationFailed(message) {
        failureMessage = message || "Не вдалося виконати автентифікацію";
        successPulseAnim.stop();
        errorPulseAnim.restart();
    }

    // Base dark grey rectangle (#222222, darker than banner background #333333)
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: Theme.cardRadius
        color: Theme.popupBackground
        visible: false
    }

    // Hardware-accelerated smooth inner shadow (matching banner inner glow effect)
    InnerShadow {
        id: bgInnerShadow
        anchors.fill: bgRect
        source: bgRect
        radius: 16.0
        samples: 32
        horizontalOffset: 0
        verticalOffset: 0
        color: Theme.scrim
        spread: 0.2
    }

    // Crisp outer border
    Rectangle {
        id: bgBorder
        anchors.fill: parent
        radius: 20
        color: "transparent"
        border.color: Theme.borderPopup
        border.width: 1.5
    }

    // Left: Round Avatar (~124x124 px)
    Item {
        id: avatarContainer
        width: 124
        height: 124
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.verticalCenter: parent.verticalCenter

        // Avatar Image
        Image {
            id: avatarImg
            anchors.fill: parent
            source: root.currentUserAvatarUrl
            sourceSize: Qt.size(248, 248)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            visible: false
        }

        // Circular mask for clean anti-aliased round avatar
        Rectangle {
            id: avatarMask
            anchors.fill: parent
            radius: width / 2
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: avatarImg
            maskSource: avatarMask
            visible: avatarImg.status === Image.Ready
        }

        // Local fallback keeps the avatar independent from the system icon theme.
        Image {
            anchors.centerIn: parent
            width: 60
            height: 60
            source: Qt.resolvedUrl("assets/user_identity.svg")
            sourceSize: Qt.size(120, 120)
            smooth: true
            mipmap: true
            visible: avatarImg.status !== Image.Ready
        }

        // Cyan Neon Border Ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: Theme.primary
            border.width: 3
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.userChooserAvailable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                userDropdown.visible = !userDropdown.visible;
                sessionDropdown.visible = false;
            }
        }
    }

    // Right content leaves room for a compact authentication status line.
    Item {
        id: rightContent
        anchors.left: avatarContainer.right
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        height: 144

        // Top Row: Username, Session Badge, and Power buttons
        Item {
            id: topRow
            width: parent.width
            height: root.showSessionBadge ? 50 : 46
            anchors.top: parent.top

            // User and session labels consume only the space left by action buttons.
            Column {
                id: identityColumn
                anchors.left: parent.left
                anchors.right: actionButtonsRow.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Item {
                    width: parent.width
                    height: 26

                    Row {
                        id: userNameRow
                        width: parent.width
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.manualUsernameMode && !root.manualUsernameRequired

                        Text {
                            text: root.currentUserDisplayName
                            color: Theme.textPrimary
                            font.family: root.mainFontFamily
                            font.pixelSize: root.showSessionBadge ? 20 : 22
                            font.bold: true
                            width: Math.max(0, parent.width - userDropIndicator.width - parent.spacing)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            id: userDropIndicator
                            text: "▾"
                            visible: root.userChooserAvailable
                            color: Theme.primary
                            font.pixelSize: 18
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    TextInput {
                        id: usernameInput
                        anchors.fill: parent
                        visible: root.manualUsernameMode || root.manualUsernameRequired
                        text: root.manualUsername
                        color: Theme.textPrimary
                        selectionColor: Theme.primaryMuted
                        selectedTextColor: Theme.textPrimary
                        font.family: root.mainFontFamily
                        font.pixelSize: 18
                        font.bold: true
                        clip: true
                        focus: visible
                        enabled: !root.effectiveAuthenticationBlocked
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                root.virtualKeyboardTarget = usernameInput;
                                root.closePopups();
                            }
                        }
                        onTextChanged: {
                            if (root.manualUsername !== text) root.manualUsername = text;
                        }
                        onTextEdited: root.userActivity()
                        onAccepted: {
                            if (root.currentUserName.length > 0) root.focusPassword();
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Ім'я користувача..."
                            color: Theme.textDim
                            font.family: root.mainFontFamily
                            font.pixelSize: 16
                            visible: usernameInput.text.length === 0 && !usernameInput.inputMethodComposing
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        visible: !usernameInput.visible && root.userChooserAvailable
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            userDropdown.visible = !userDropdown.visible;
                            sessionDropdown.visible = false;
                        }
                    }
                }

                Rectangle {
                    id: sessionBadge
                    visible: root.showSessionBadge
                    height: 22
                    width: Math.min(parent.width,
                        sessionNameText.implicitWidth + sessionDropIndicator.implicitWidth + 20)
                    radius: 6
                    color: sessionBadgeMouse.containsMouse ? Theme.surfaceSessionHover : Theme.surfaceQuiet
                    border.color: sessionBadgeMouse.containsMouse ? Theme.primary : Theme.borderQuiet
                    border.width: 1

                    Row {
                        id: sessionBadgeRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 7
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            id: sessionNameText
                            text: root.currentSessionDisplayName
                            color: sessionBadgeMouse.containsMouse ? Theme.primary : Theme.textMuted
                            font.family: root.mainFontFamily
                            font.pixelSize: 12
                            font.bold: true
                            width: Math.max(0, parent.width - sessionDropIndicator.width - parent.spacing)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: sessionDropIndicator
                            text: "▾"
                            color: sessionBadgeMouse.containsMouse ? Theme.primary : Theme.textDim
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: sessionBadgeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionDropdown.visible = !sessionDropdown.visible;
                            if (sessionDropdown.visible) userDropdown.visible = false;
                        }
                    }
                }
            }

            // Action Buttons (Keyboard Layout Switcher + Power buttons)
            Row {
                id: actionButtonsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // Keyboard Layout Switcher Button
                Rectangle {
                    id: kbBtn
                    width: 48
                    height: 48
                    radius: 24
                    color: kbMouse.containsMouse ? Theme.cyanActionHover : Theme.surface
                    border.color: kbMouse.containsMouse ? Theme.primary : Theme.border
                    border.width: 1.5
                    visible: root.showKeyboardLayoutButton && !root.passwordlessMode

                    Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
                    Behavior on border.color { ColorAnimation { duration: Theme.fastAnimation } }

                    Text {
                        anchors.centerIn: parent
                        text: root.currentLayoutShortName
                        color: kbMouse.containsMouse ? Theme.primary : Theme.actionText
                        font.family: root.mainFontFamily
                        font.pixelSize: 24
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
                    }

                    MouseArea {
                        id: kbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextKeyboardLayout()
                    }

                    ToolTip.visible: kbMouse.containsMouse
                    ToolTip.text: root.currentLayoutFullName
                    ToolTip.delay: Theme.tooltipDelay
                }

                Rectangle {
                    id: virtualKeyboardBtn
                    width: 48
                    height: 48
                    radius: 24
                    color: virtualKeyboardMouse.containsMouse || root.virtualKeyboardActive ? Theme.cyanActionHover : Theme.surface
                    border.color: virtualKeyboardMouse.containsMouse || root.virtualKeyboardActive ? Theme.primary : Theme.border
                    border.width: 1.5
                    visible: !root.passwordlessMode

                    Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
                    Behavior on border.color { ColorAnimation { duration: Theme.fastAnimation } }

                    Image {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: virtualKeyboardMouse.containsMouse || root.virtualKeyboardActive
                            ? Qt.resolvedUrl("assets/virtual_keyboard_hover.svg")
                            : Qt.resolvedUrl("assets/virtual_keyboard_normal.svg")
                        sourceSize: Qt.size(112, 112)
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        id: virtualKeyboardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closePopups();
                            root.virtualKeyboardRequested();
                        }
                    }

                    ToolTip.visible: virtualKeyboardMouse.containsMouse
                    ToolTip.text: root.virtualKeyboardActive ? "Сховати віртуальну клавіатуру" : "Віртуальна клавіатура"
                    ToolTip.delay: Theme.tooltipDelay
                }

                // Suspend
                Rectangle {
                    width: 48; height: 48; radius: 24
                    visible: root.canSuspend
                    color: suspendMouse.containsMouse ? Theme.cyanActionHover : Theme.surface
                    border.color: suspendMouse.containsMouse ? Theme.primary : Theme.border
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
                    Behavior on border.color { ColorAnimation { duration: Theme.fastAnimation } }

                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        source: suspendMouse.containsMouse ? Qt.resolvedUrl("assets/suspend_hover.svg") : Qt.resolvedUrl("assets/suspend_normal.svg")
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        id: suspendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.suspendRequested()
                    }

                    ToolTip.visible: suspendMouse.containsMouse
                    ToolTip.text: "Сон"
                    ToolTip.delay: Theme.tooltipDelay
                }

                // Reboot
                Rectangle {
                    width: 48; height: 48; radius: 24
                    visible: root.canReboot
                    color: rebootMouse.containsMouse ? Theme.purpleActionHover : Theme.surface
                    border.color: rebootMouse.containsMouse ? Theme.accentSecondary : Theme.border
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
                    Behavior on border.color { ColorAnimation { duration: Theme.fastAnimation } }

                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        source: rebootMouse.containsMouse ? Qt.resolvedUrl("assets/reboot_hover.svg") : Qt.resolvedUrl("assets/reboot_normal.svg")
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        id: rebootMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rebootRequested()
                    }

                    ToolTip.visible: rebootMouse.containsMouse
                    ToolTip.text: "Перезавантаження"
                    ToolTip.delay: Theme.tooltipDelay
                }

                // Shutdown
                Rectangle {
                    width: 48; height: 48; radius: 24
                    visible: root.canPowerOff
                    color: powerMouse.containsMouse ? Theme.redActionHover : Theme.surface
                    border.color: powerMouse.containsMouse ? Theme.errorSoft : Theme.border
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
                    Behavior on border.color { ColorAnimation { duration: Theme.fastAnimation } }

                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        source: powerMouse.containsMouse ? Qt.resolvedUrl("assets/shutdown_hover.svg") : Qt.resolvedUrl("assets/shutdown_normal.svg")
                        sourceSize: Qt.size(128, 128)
                        smooth: true
                        mipmap: true
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.powerOffRequested()
                    }

                    ToolTip.visible: powerMouse.containsMouse
                    ToolTip.text: "Вимкнення"
                    ToolTip.delay: Theme.tooltipDelay
                }
            }
        }

        Row {
            id: statusRow
            anchors.left: passInputBox.left
            anchors.right: passInputBox.right
            anchors.bottom: root.passwordlessMode ? passwordlessButton.top : passInputBox.top
            anchors.bottomMargin: 6
            height: 18
            spacing: 8
            visible: root.displayedStatusMessage.length > 0
            opacity: visible ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: Theme.fastAnimation } }

            Rectangle {
                width: 7
                height: 7
                radius: 3.5
                anchors.verticalCenter: parent.verticalCenter
                color: root.displayedStatusType === "error" ? Theme.errorSoft
                    : (root.displayedStatusType === "success" ? Theme.success : Theme.primary)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 15
                text: root.displayedStatusMessage
                color: root.displayedStatusType === "error" ? Theme.errorSoft
                    : (root.displayedStatusType === "success" ? Theme.success : Theme.primary)
                font.family: root.mainFontFamily
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle {
            id: passwordlessButton
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 56
            radius: Theme.inputRadius
            visible: root.passwordlessMode
            activeFocusOnTab: true
            enabled: !root.effectiveAuthenticationBlocked
            color: passwordlessMouse.containsMouse || activeFocus
                ? Theme.confirmationHover : Theme.inputBackground
            border.color: passwordlessMouse.containsMouse || activeFocus
                ? Theme.primaryHover : Theme.primaryMuted
            border.width: passwordlessMouse.containsMouse || activeFocus ? 2 : 1.5

            Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
            Behavior on border.color { ColorAnimation { duration: Theme.fastAnimation } }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Image {
                    width: 24
                    height: 24
                    source: Qt.resolvedUrl("assets/unlock.svg")
                    sourceSize: Qt.size(96, 96)
                    smooth: true
                    mipmap: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.passwordlessLabel
                    color: Theme.textPrimary
                    font.family: root.mainFontFamily
                    font.pixelSize: 18
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: passwordlessMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.requestPasswordlessAuthentication()
            }

            Keys.onEnterPressed: root.requestPasswordlessAuthentication()
            Keys.onReturnPressed: root.requestPasswordlessAuthentication()
            Keys.onSpacePressed: root.requestPasswordlessAuthentication()
        }

        // Bottom Row: Password Field with embedded submit arrow (56px height)
        Rectangle {
            id: passInputBox
            visible: !root.passwordlessMode
            width: parent.width
            height: 56
            anchors.bottom: parent.bottom
            radius: Theme.inputRadius
            color: {
                if (root.inputFeedbackState === "success") {
                    return Theme.withAlpha(Theme.success, 0.08 * root.pulseAlpha);
                } else if (root.inputFeedbackState === "error") {
                    return Theme.withAlpha(Theme.error, 0.08 * root.pulseAlpha);
                }
                return Theme.inputBackground;
            }
            border.color: {
                if (root.inputFeedbackState === "success") {
                    return Theme.withAlpha(Theme.success, root.pulseAlpha);
                } else if (root.inputFeedbackState === "error") {
                    return Theme.withAlpha(Theme.error, root.pulseAlpha);
                }
                return passwordInput.activeFocus ? Theme.primary : Theme.borderSoft;
            }
            border.width: {
                if (root.inputFeedbackState === "success" || root.inputFeedbackState === "error") {
                    return root.pulseBorderWidth;
                }
                return passwordInput.activeFocus ? 2 : 1.5;
            }

            Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }

            // Caps Lock Warning Badge (Inside input box on the left)
            Rectangle {
                id: capsLockBadge
                width: root.isCapsLockOn ? (capsBadgeRow.width + 16) : 0
                height: 32
                radius: 8
                anchors.left: parent.left
                anchors.leftMargin: root.isCapsLockOn ? 10 : 0
                anchors.verticalCenter: parent.verticalCenter
                color: capsMouse.containsMouse ? Theme.warningBackgroundHover : Theme.warningBackground
                border.color: capsMouse.containsMouse ? Theme.warningHover : Theme.warning
                border.width: 1.5
                visible: width > 0
                opacity: root.isCapsLockOn ? 1.0 : 0.0
                clip: true

                Behavior on width { NumberAnimation { duration: Theme.revealAnimation; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.revealAnimation } }
                Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
                Behavior on border.color { ColorAnimation { duration: Theme.fastAnimation } }

                Row {
                    id: capsBadgeRow
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        width: 18
                        height: 18
                        source: Qt.resolvedUrl("assets/capslock_warning.svg")
                        sourceSize: Qt.size(72, 72)
                        smooth: true
                        mipmap: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "CAPS"
                        color: Theme.warning
                        font.family: root.mainFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: capsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                ToolTip.visible: capsMouse.containsMouse
                ToolTip.text: "Caps Lock увімкнено! Пароль чутливий до регістру"
                ToolTip.delay: 150
            }

            TextInput {
                id: passwordInput
                anchors.left: capsLockBadge.right
                anchors.leftMargin: root.isCapsLockOn ? 10 : 16
                anchors.right: eyeBtn.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                color: Theme.textPrimary
                font.family: root.mainFontFamily
                font.pixelSize: 18
                clip: true
                focus: !usernameInput.visible
                enabled: !root.effectiveAuthenticationBlocked
                onActiveFocusChanged: {
                    if (activeFocus) {
                        root.virtualKeyboardTarget = passwordInput;
                        root.closePopups();
                    }
                }

                Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.fastAnimation } }

                Text {
                    text: root.passwordPrompt || "Введіть пароль..."
                    color: Theme.placeholder
                    font.family: root.mainFontFamily
                    font.pixelSize: 17
                    visible: passwordInput.text.length === 0 && !passwordInput.inputMethodComposing
                    anchors.verticalCenter: parent.verticalCenter
                }

                onAccepted: root.doLogin()
                onTextEdited: root.userActivity()

                Keys.onLeftPressed: {
                    if (!text && root.userCount > 1) {
                        root.selectListedUser((root.currentUserIndex - 1 + root.userCount) % root.userCount);
                    }
                }
                Keys.onRightPressed: {
                    if (!text && root.userCount > 1) {
                        root.selectListedUser((root.currentUserIndex + 1) % root.userCount);
                    }
                }
            }

            // Show / Hide Password Eye Toggle Button
            Rectangle {
                id: eyeBtn
                width: 38
                height: 38
                radius: 8
                anchors.right: submitBtn.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: eyeMouse.containsMouse ? Theme.surfaceControlHover : "transparent"
                opacity: passwordInput.text.length > 0 ? 1.0 : 0.45
                enabled: passwordInput.text.length > 0 && !root.effectiveAuthenticationBlocked

                Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }
                Behavior on opacity { NumberAnimation { duration: Theme.fastAnimation } }

                readonly property bool isRevealed: passwordInput.echoMode === TextInput.Normal

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: {
                        if (eyeBtn.isRevealed) {
                            return eyeMouse.containsMouse ? Qt.resolvedUrl("assets/eye_hide_hover.svg") : Qt.resolvedUrl("assets/eye_hide_normal.svg")
                        } else {
                            return eyeMouse.containsMouse ? Qt.resolvedUrl("assets/eye_show_hover.svg") : Qt.resolvedUrl("assets/eye_show_normal.svg")
                        }
                    }
                    sourceSize: Qt.size(88, 88)
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: eyeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        passwordInput.echoMode = (passwordInput.echoMode === TextInput.Password) ? TextInput.Normal : TextInput.Password;
                        passwordInput.forceActiveFocus();
                    }
                }

                ToolTip.visible: eyeMouse.containsMouse && parent.enabled
                ToolTip.text: eyeBtn.isRevealed ? "Сховати пароль" : "Показати пароль"
                ToolTip.delay: Theme.tooltipDelay
            }

            // Submit Button with Mathematically Centered Vector Arrow
            Rectangle {
                id: submitBtn
                width: 42
                height: 42
                radius: 8
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    if (root.inputFeedbackState === "success") {
                        return Theme.success;
                    }
                    return root.canSubmitLogin ? (submitMouse.containsMouse ? Theme.primaryHover : Theme.primaryMuted) : Theme.popupBackground;
                }

                Behavior on color { ColorAnimation { duration: Theme.fastAnimation } }

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: root.canSubmitLogin ? Qt.resolvedUrl("assets/arrow_submit_active.svg") : Qt.resolvedUrl("assets/arrow_submit_inactive.svg")
                    sourceSize: Qt.size(88, 88)
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: submitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.canSubmitLogin ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.doLogin()
                }

                ToolTip.visible: submitMouse.containsMouse && root.canSubmitLogin
                ToolTip.text: "Увійти"
                ToolTip.delay: Theme.tooltipDelay
            }
        }
    }

    // Multi-user dropdown
    Rectangle {
        id: userDropdown
        visible: false
        width: 240
        height: Math.min((root.allowUserSelection ? root.listedUserCount : 0) * 44, 176)
            + (root.allowManualUsername ? 54 : 10)
        color: Theme.popupBackground
        radius: 10
        border.color: Theme.borderPopup
        border.width: 1.5
        anchors.top: avatarContainer.bottom
        anchors.topMargin: 10
        anchors.left: avatarContainer.left
        z: 50

        ListView {
            id: userListView
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            anchors.bottomMargin: root.allowManualUsername ? 49 : 5
            clip: true
            model: root.allowUserSelection
                ? (root.usersList.length > 0 ? root.usersList : root.userListModel) : null
            delegate: Rectangle {
                width: ListView.view.width
                height: 40
                radius: 6
                color: userMouse.containsMouse ? Theme.surfacePopupHover : (index === root.currentUserIndex ? Theme.surfaceSelected : "transparent")

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (modelData && (modelData.realName || modelData.name)) {
                                return modelData.realName || modelData.name;
                            }
                            if (model && (model.realName || model.name)) {
                                return model.realName || model.name;
                            }
                            return "";
                        }
                        color: index === root.currentUserIndex ? Theme.primary : Theme.textSecondary
                        font.family: root.mainFontFamily
                        font.pixelSize: 15
                        font.bold: index === root.currentUserIndex
                        elide: Text.ElideRight
                        width: parent.width - 20
                    }
                }

                MouseArea {
                    id: userMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectListedUser(index)
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 5
            height: 40
            visible: root.allowManualUsername
            radius: 6
            color: manualUserMouse.containsMouse || root.manualUsernameMode ? Theme.surfaceSelectedCyan : "transparent"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Інший користувач..."
                color: root.manualUsernameMode ? Theme.primary : Theme.textSecondary
                font.family: root.mainFontFamily
                font.pixelSize: 15
                font.bold: root.manualUsernameMode
            }

            MouseArea {
                id: manualUserMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectManualUser()
            }
        }
    }

    // Session dropdown
    Rectangle {
        id: sessionDropdown
        visible: false
        width: Math.max(220, sessionBadge.width + 20)
        height: Math.min((root.sessionsList.length > 0 ? root.sessionsList.length : (root.sessionListModel ? root.sessionListModel.count : 4)) * 42 + 10, 220)
        color: Theme.popupBackground
        radius: 10
        border.color: Theme.borderPopup
        border.width: 1.5
        x: avatarContainer.width + 24
        y: topRow.y + topRow.height + 4
        z: 60

        ListView {
            anchors.fill: parent
            anchors.margins: 5
            clip: true
            model: root.sessionsList.length > 0 ? root.sessionsList : (root.sessionListModel ? root.sessionListModel : null)
            delegate: Rectangle {
                width: ListView.view.width
                height: 38
                radius: 6
                color: sessMouse.containsMouse ? Theme.surfacePopupHover : (index === root.currentSessionIndex ? Theme.surfaceSessionSelected : "transparent")

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: index === root.currentSessionIndex ? "✓" : " "
                        color: Theme.primary
                        font.family: root.mainFontFamily
                        font.pixelSize: 14
                        font.bold: true
                        width: 16
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (modelData && modelData.name) return modelData.name;
                            if (model && model.name) return model.name;
                            return "";
                        }
                        color: index === root.currentSessionIndex ? Theme.primary : Theme.textSecondary
                        font.family: root.mainFontFamily
                        font.pixelSize: 13
                        font.bold: index === root.currentSessionIndex
                        elide: Text.ElideRight
                        width: parent.width - 34
                    }
                }

                MouseArea {
                    id: sessMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentSessionIndex = index;
                        sessionDropdown.visible = false;
                        root.focusPassword();
                    }
                }
            }
        }
    }
    // Prevent user/session changes while an authentication animation is active.
    MouseArea {
        anchors.fill: parent
        z: 1000
        visible: root.effectiveAuthenticationBlocked
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
    }

}

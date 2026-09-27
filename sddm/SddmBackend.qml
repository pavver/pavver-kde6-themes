import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

Item {
    id: root
    visible: false

    readonly property var usersModel: typeof userModel !== "undefined" ? userModel : null
    readonly property int initialUserIndex: usersModel
        && typeof usersModel.lastIndex === "number" && usersModel.lastIndex >= 0
        ? usersModel.lastIndex : 0
    readonly property string rememberedUserName: usersModel && usersModel.lastUser
        ? usersModel.lastUser : ""

    readonly property var sessionsModel: typeof sessionModel !== "undefined" ? sessionModel : null
    readonly property int initialSessionIndex: sessionsModel
        && typeof sessionsModel.lastIndex === "number" && sessionsModel.lastIndex >= 0
        ? sessionsModel.lastIndex : 0

    readonly property var keyboardLayouts: typeof keyboard !== "undefined"
        && keyboard && keyboard.layouts ? keyboard.layouts : []
    readonly property int keyboardLayoutIndex: typeof keyboard !== "undefined"
        && keyboard && typeof keyboard.currentLayout === "number"
        ? keyboard.currentLayout : 0

    readonly property bool capsLockActive: capsLockState.locked
    readonly property bool canSuspend: typeof sddm !== "undefined" && sddm.canSuspend
    readonly property bool canReboot: typeof sddm !== "undefined" && sddm.canReboot
    readonly property bool canPowerOff: typeof sddm !== "undefined" && sddm.canPowerOff

    signal authenticationFailed(string message)
    signal authenticationSucceeded()

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    function authenticate(username, password, sessionIndex) {
        if (typeof sddm !== "undefined") {
            sddm.login(username, password, sessionIndex);
        }
    }

    function setKeyboardLayout(index) {
        if (typeof keyboard !== "undefined" && keyboard) {
            keyboard.currentLayout = index;
        }
    }

    function suspend() {
        if (canSuspend) sddm.suspend();
    }

    function reboot() {
        if (canReboot) sddm.reboot();
    }

    function powerOff() {
        if (canPowerOff) sddm.powerOff();
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        ignoreUnknownSignals: true

        function onLoginFailed() {
            root.authenticationFailed("Не вдалося увійти");
        }

        function onLoginSucceeded() {
            root.authenticationSucceeded();
        }
    }
}

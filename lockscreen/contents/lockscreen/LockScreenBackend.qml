import QtQuick
import org.kde.plasma.private.sessions
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.workspace.components as PW

Item {
    id: root
    visible: false

    property bool standaloneDemo: false
    readonly property string userName: typeof kscreenlocker_userName !== "undefined"
        ? kscreenlocker_userName : "pavver"
    readonly property string userDisplayName: userName
    readonly property string userAvatarUrl: typeof kscreenlocker_userImage !== "undefined"
        ? kscreenlocker_userImage : ""

    readonly property bool capsLockActive: capsLockState.locked
    readonly property int authenticatorTypes: standaloneDemo
        || typeof authenticator === "undefined" ? 0 : authenticator.authenticatorTypes
    readonly property string alternativeAuthenticationHint: authenticatorTypes !== 0
        ? "Пароль, відбиток пальця або смарткартка" : ""
    readonly property bool hasRealLayoutSwitcher: layoutSwitcher.layoutNames !== undefined
        && layoutSwitcher.layoutNames !== null
    readonly property bool hasMultipleKeyboardLayouts: hasRealLayoutSwitcher
        ? layoutSwitcher.hasMultipleKeyboardLayouts : true
    readonly property var keyboardLayouts: [{
        shortName: hasRealLayoutSwitcher && layoutSwitcher.layoutNames.shortName
            ? layoutSwitcher.layoutNames.shortName : "us",
        longName: hasRealLayoutSwitcher && layoutSwitcher.layoutNames.longName
            ? layoutSwitcher.layoutNames.longName : "English (US)"
    }]
    readonly property int keyboardLayoutIndex: 0

    readonly property bool canSuspend: standaloneDemo ? true : sessionManagement.canSuspend
    readonly property bool canReboot: standaloneDemo ? false : sessionManagement.canReboot
    readonly property bool canPowerOff: standaloneDemo ? true : sessionManagement.canShutdown

    signal authenticationFailed(string message)
    signal authenticationSucceeded(bool hadPrompt)
    signal informationMessage(string message)
    signal errorMessage(string message)
    signal promptChanged(string prompt)
    signal secretPrompted()
    signal noninteractiveError(int kind, string message)
    signal aboutToSuspend()

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    PW.KeyboardLayoutSwitcher {
        id: layoutSwitcher
        acceptedButtons: Qt.NoButton
    }

    SessionManagement {
        id: sessionManagement
    }

    function startAuthenticating() {
        if (!standaloneDemo && authenticator
                && typeof authenticator.startAuthenticating === "function") {
            authenticator.startAuthenticating();
        }
    }

    function authenticate(password) {
        if (!standaloneDemo && authenticator
                && typeof authenticator.respond === "function") {
            authenticator.respond(password);
            return;
        }
        if (password === "error") {
            authenticationFailed("Невірний пароль");
        } else {
            authenticationSucceeded(true);
        }
    }

    function confirmPasswordless() {
        if (standaloneDemo) {
            informationMessage("Демо: підтвердження спрацювало");
        } else {
            Qt.quit();
        }
    }

    function setKeyboardLayout(index) {
        if (hasRealLayoutSwitcher && layoutSwitcher.keyboardLayout
                && typeof layoutSwitcher.keyboardLayout.switchToNextLayout === "function") {
            layoutSwitcher.keyboardLayout.switchToNextLayout();
        }
    }

    function suspend() {
        if (!standaloneDemo && canSuspend) sessionManagement.suspend();
    }

    function reboot() {
        if (!standaloneDemo && canReboot) sessionManagement.requestReboot();
    }

    function powerOff() {
        if (!standaloneDemo && canPowerOff) sessionManagement.requestShutdown();
    }

    Connections {
        target: sessionManagement
        ignoreUnknownSignals: true
        function onAboutToSuspend() {
            root.aboutToSuspend();
        }
    }

    Connections {
        target: root.standaloneDemo ? null : authenticator
        ignoreUnknownSignals: true

        function onFailed(kind) {
            if (typeof kind === "undefined" || kind === 0) {
                root.authenticationFailed("Невірний пароль");
            }
        }

        function onSucceeded() {
            root.authenticationSucceeded(authenticator.hadPrompt);
        }

        function onInfoMessageChanged() {
            if (authenticator.infoMessage) {
                root.informationMessage(authenticator.infoMessage);
            }
        }

        function onErrorMessageChanged() {
            if (authenticator.errorMessage) {
                root.errorMessage(authenticator.errorMessage);
            }
        }

        function onPromptChanged() {
            if (authenticator.prompt) {
                root.promptChanged(authenticator.prompt);
            }
        }

        function onPromptForSecretChanged() {
            root.secretPrompted();
        }

        function onNoninteractiveError(kind, sourceAuthenticator) {
            var message = sourceAuthenticator && sourceAuthenticator.errorMessage
                ? sourceAuthenticator.errorMessage : "Неінтерактивна автентифікація не вдалася";
            root.noninteractiveError(kind, message);
        }
    }
}

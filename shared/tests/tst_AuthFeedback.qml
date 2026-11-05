import QtQuick
import QtTest

import "../PavverTheme" as Pavver

Item {
    width: 800
    height: 400

    Pavver.AuthCard {
        id: card
        rememberedUserName: "tester"
        allowManualUsername: false
    }

    SignalSpy {
        id: requested
        target: card
        signalName: "authenticationRequested"
    }

    TestCase {
        name: "AuthFeedback"
        when: windowShown

        function init() {
            card.cancelPendingAuthentication();
            card.inputFeedbackState = "idle";
            card.statusVisibility = 0.0;
            card.clearStatusMessage();
            card.passwordText = "secret";
            requested.clear();
        }

        function test_submitWaitsForResultWithoutSuccessColor() {
            card.doLogin();
            compare(requested.count, 1);
            compare(requested.signalArguments[0][1], "secret");
            compare(card.inputFeedbackState, "pending");
            wait(700);
            compare(card.inputFeedbackState, "pending");
        }

        function test_rejectedPasswordNeverShowsSuccess() {
            card.doLogin();
            card.authenticationFailed("Невірний пароль");
            compare(card.inputFeedbackState, "error");
            tryCompare(card, "inputFeedbackState", "idle", 3000);
        }

        function test_acceptedPasswordShowsSuccess() {
            card.doLogin();
            card.authenticationSucceeded();
            compare(card.inputFeedbackState, "success");
        }

        function test_successClearsEarlierFailure() {
            card.doLogin();
            card.authenticationFailed("Невірний пароль");
            card.authenticationSucceeded();
            compare(card.inputFeedbackState, "success");
            compare(card.statusMessage, "");
        }

        function test_retryAllowedDuringErrorFeedback() {
            card.doLogin();
            card.authenticationFailed("Невірний пароль");
            card.passwordText = "secret2";
            card.doLogin();
            compare(requested.count, 2);
            compare(card.inputFeedbackState, "pending");
        }

        function test_resultStaysForHoldThenFades() {
            card.doLogin();
            card.authenticationFailed("Невірний пароль");
            wait(500);
            compare(card.inputFeedbackState, "error");
            tryCompare(card, "statusVisibility", 0.0, 2000);
        }

        function test_pendingBlocksSecondSubmit() {
            card.doLogin();
            card.doLogin();
            compare(requested.count, 1);
        }
    }
}

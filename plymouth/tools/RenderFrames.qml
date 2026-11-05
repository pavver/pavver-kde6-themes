import QtQuick
import QtQuick.Window

import "../../shared/PavverTheme" as Pavver

// Renders one loop of LoginLoader to PNG files, because Plymouth cannot run QML.
// Run through scripts/render-plymouth-frames.sh.
Window {
    id: root

    // The six triangles pulse one after another inside a 6 s cycle.
    readonly property int loopDuration: 6000
    // 100 frames show at Plymouth's 50 Hz refresh, three ticks per frame.
    readonly property int frameCount: 100
    readonly property string outputDir: Qt.application.arguments[Qt.application.arguments.length - 1]

    property var clock: null
    property int frame: 0

    width: 1920
    height: 1080
    flags: Qt.FramelessWindowHint
    visibility: Window.FullScreen
    color: Pavver.Theme.loaderBackground

    function findClock() {
        for (let i = 0; i < loader.resources.length; ++i) {
            const candidate = loader.resources[i];
            if (candidate.elapsed !== undefined) {
                return candidate;
            }
        }
        return null;
    }

    function saveFrame() {
        clock.elapsed = frame * loopDuration / frameCount;
        settle.restart();
    }

    Item {
        id: scene

        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: root.color
        }

        Pavver.LoginLoader {
            id: loader

            anchors.centerIn: parent
        }
    }

    // Gives the blur layer a rendered frame before it is captured.
    Timer {
        id: settle

        interval: 120
        onTriggered: scene.grabToImage(function(result) {
            const name = String(root.frame).padStart(3, "0");
            if (!result.saveToFile(root.outputDir + "/frame-" + name + ".png")) {
                console.error("Could not save frame", name);
                Qt.exit(1);
                return;
            }
            root.frame += 1;
            if (root.frame === root.frameCount) {
                Qt.exit(0);
            } else {
                root.saveFrame();
            }
        })
    }

    Component.onCompleted: {
        if (width !== 1920 || height !== 1080) {
            console.warn("Scene is", width, "x", height, "- waiting for full screen");
        }
        clock = findClock();
        if (clock === null) {
            console.error("LoginLoader has no AnimationClock");
            Qt.exit(1);
            return;
        }
        clock.running = false;
        start.start();
    }

    // Lets the compositor apply the full-screen size before the first frame.
    Timer {
        id: start

        interval: 1000
        onTriggered: {
            if (root.width !== 1920 || root.height !== 1080) {
                console.error("Scene must be 1920x1080, got", root.width, root.height);
                Qt.exit(1);
                return;
            }
            root.saveFrame();
        }
    }
}

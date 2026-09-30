import QtQuick

QtObject {
    id: root

    property bool running: false
    property int framesPerSecond: 30
    property real elapsed: 0

    property double _lastTick: 0

    Component.onCompleted: _lastTick = Date.now()
    onRunningChanged: _lastTick = Date.now()

    property Timer _timer: Timer {
        interval: Math.max(1, Math.ceil(1000 / Math.max(1, root.framesPerSecond)))
        repeat: true
        running: root.running

        onTriggered: {
            var now = Date.now();
            var delta = Math.max(0, Math.min(now - root._lastTick, 250));
            root._lastTick = now;
            root.elapsed += delta;
        }
    }
}

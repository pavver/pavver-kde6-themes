import QtQuick
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

import "PavverTheme" as Pavver

WallpaperItem {
    id: root

    property bool pausedByFullscreen: false

    readonly property real bannerAspectRatio: 675.0 / 190.0
    readonly property real bannerVisualWidth: Math.min(
        width * 0.85,
        (height * 0.70) * bannerAspectRatio)
    readonly property var fallbackScreenGeometry: Qt.rect(0, 0, width, height)
    readonly property var screenGeometry: root.parent
        && root.parent.screenGeometry !== undefined
        ? root.parent.screenGeometry : fallbackScreenGeometry

    function updateFullscreenState() {
        var fullscreen = false;
        for (var row = 0; row < windowModel.count; ++row) {
            var index = windowModel.makeModelIndex(row);
            var isWindow = windowModel.data(index, TaskManager.AbstractTasksModel.IsWindow);
            var isMinimized = windowModel.data(index, TaskManager.AbstractTasksModel.IsMinimized);
            var isFullscreen = windowModel.data(index, TaskManager.AbstractTasksModel.IsFullScreen);
            if (isWindow === true && isMinimized !== true && isFullscreen === true) {
                fullscreen = true;
                break;
            }
        }
        pausedByFullscreen = fullscreen;
    }

    TaskManager.ActivityInfo {
        id: activityInfo
        onCurrentActivityChanged: fullscreenUpdateTimer.restart()
    }

    TaskManager.TasksModel {
        id: windowModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByCurrentVirtualDesktop: true
        filterByActivity: true
        filterByScreen: true
        filterHidden: true
        activity: activityInfo.currentActivity
        screenGeometry: root.screenGeometry

        onActiveTaskChanged: fullscreenUpdateTimer.restart()
        onCountChanged: fullscreenUpdateTimer.restart()
        onDataChanged: fullscreenUpdateTimer.restart()
        onModelReset: fullscreenUpdateTimer.restart()
    }

    Timer {
        id: fullscreenUpdateTimer
        interval: 50
        onTriggered: root.updateFullscreenState()
    }

    Component.onCompleted: fullscreenUpdateTimer.start()

    Pavver.AnimatedBackground {
        anchors.fill: parent
        bannerTargetCenterX: root.width / 2.0
        bannerTargetCenterY: root.height / 2.0
        bannerTargetScale: root.bannerVisualWidth / 675.0
        bannerTargetOpacity: 1.0
        enableAnimations: false
        contentAnimationsEnabled: root.configuration.EnableAnimations
            && !root.pausedByFullscreen
    }
}

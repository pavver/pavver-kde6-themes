import QtQuick

// Running outline for the Pending state: a static underlay with a clockwise
// segment covering a quarter of the perimeter at 1.5x stroke width.
Canvas {
    id: root

    property bool running: false
    property real radius: 0
    property real strokeWidth: 1.5
    property color underlayColor: Theme.border
    property color segmentColor: Theme.pending
    property real progress: 0

    visible: running

    NumberAnimation on progress {
        from: 0
        to: 1
        duration: Theme.pendingBorderCycle
        loops: Animation.Infinite
        running: root.running
    }

    onProgressChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // Point at the given distance along the contour, clockwise from the top-left corner.
    function pointAt(distance, inset, w, h, r) {
        var straightX = w - 2 * r;
        var straightY = h - 2 * r;
        var arc = Math.PI * r / 2;
        var d = distance;
        var left = inset;
        var top = inset;
        var right = inset + w;
        var bottom = inset + h;

        if (d < straightX) return [left + r + d, top];
        d -= straightX;
        if (d < arc) {
            var a1 = -Math.PI / 2 + d / r;
            return [right - r + r * Math.cos(a1), top + r + r * Math.sin(a1)];
        }
        d -= arc;
        if (d < straightY) return [right, top + r + d];
        d -= straightY;
        if (d < arc) {
            var a2 = d / r;
            return [right - r + r * Math.cos(a2), bottom - r + r * Math.sin(a2)];
        }
        d -= arc;
        if (d < straightX) return [right - r - d, bottom];
        d -= straightX;
        if (d < arc) {
            var a3 = Math.PI / 2 + d / r;
            return [left + r + r * Math.cos(a3), bottom - r + r * Math.sin(a3)];
        }
        d -= arc;
        if (d < straightY) return [left, bottom - r - d];
        d -= straightY;
        var a4 = Math.PI + d / r;
        return [left + r + r * Math.cos(a4), top + r + r * Math.sin(a4)];
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        var segmentStroke = strokeWidth * 1.5;
        var inset = segmentStroke / 2;
        var w = width - segmentStroke;
        var h = height - segmentStroke;
        if (w <= 0 || h <= 0) return;

        var r = Math.max(0.01, Math.min(radius - inset, w / 2, h / 2));
        var perimeter = 2 * (w - 2 * r) + 2 * (h - 2 * r) + 2 * Math.PI * r;

        ctx.lineWidth = strokeWidth;
        ctx.strokeStyle = underlayColor;
        ctx.beginPath();
        ctx.roundedRect(inset, inset, w, h, r, r);
        ctx.stroke();

        var start = progress * perimeter;
        var length = perimeter * 0.25;
        var step = 2;
        ctx.lineWidth = segmentStroke;
        ctx.lineCap = "butt";
        ctx.lineJoin = "round";
        ctx.strokeStyle = segmentColor;
        ctx.beginPath();
        for (var s = 0; s <= length; s += step) {
            var p = pointAt((start + s) % perimeter, inset, w, h, r);
            if (s === 0) ctx.moveTo(p[0], p[1]);
            else ctx.lineTo(p[0], p[1]);
        }
        ctx.stroke();
    }
}

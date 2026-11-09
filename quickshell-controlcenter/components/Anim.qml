import QtQuick 6.8

// Default animation used by reusable components. Previously read
// Appearance.anim.* which dragged in the qs.config module (and with it a
// services <-> config import cycle), so the values are inlined here.
NumberAnimation {
    duration: 200
    easing.type: Easing.BezierSpline
    easing.bezierCurve: [0.2, 0.0, 0, 1.0]
}

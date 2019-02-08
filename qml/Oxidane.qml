import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow
{
    id: appWindow
    property var state: "paused"
    property var song: "♪"
    property var art: ""
    property var offset: 0
    property var playpause: function() {}
    initialPage: Component { FirstPage { rootwindow:appWindow } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: Orientation.All
    _defaultPageOrientations: Orientation.All

    // function playpause() {
    // 	initialPage.page.playpause()
    // }
}



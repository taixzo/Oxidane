import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    Image {
        source: appWindow.art
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        opacity: 0.6
    }
    Label {
        anchors.centerIn: parent
        text: appWindow.song
    }
    CoverActionList {
        id: coverActions
        CoverAction {
            iconSource: appWindow.state=="playing"?"image://theme/icon-cover-pause":"image://theme/icon-cover-play"
            onTriggered: {
                console.log("Cover action triggered")
                console.log(appWindow.state)
            }
        }
    }
}



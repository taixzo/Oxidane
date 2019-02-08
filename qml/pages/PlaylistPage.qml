import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.4

Page {
    id: page
    property var songlist;
    property var py;
    property var mediaplayer;
    property var duration: songlist[parentpage.currentIndex][6];
    property int currentIndex;
    property var parentpage;

    function startsWith (str, substr) {
        return str.substring(0, substr.length) === substr;
    }

    Component.onCompleted: {
        for (var i in songlist) {
            songModel.append({
                value: songlist[i][1],
                sid: songlist[i][0],
                artist: songlist[i][2],
                url: songlist[i][3],
                art: songlist[i][4],
                albumid: songlist[i][5],
                duration: songlist[i][6]*1000,
                filesize: songlist[i][7],
                index: i
            })
        }
    }
    SilicaListView {
        id: songs
        width: parent.width
        anchors.top: parent.top
        anchors.bottom: controls.bottom
        VerticalScrollDecorator {
            flickable: songs
        }
        // height: childrenRect.height

        model: ListModel {
            id: songModel
        }
        delegate: Item {
            width: ListView.view.width
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    songLoadingIndicator.running = true
                    page.duration = duration
                    page.parentpage.currentIndex = index
                    controls.visible=true
                    appWindow.state="playing"
                    appWindow.song=value
                    py.call('backend.setSong', [sid], function(result){})
                    if (1) {
                        py.call('backend.downloadSong', [url, sid, art, albumid, filesize], function(result) {
                            if (page.startsWith(result[0], "%%%ERROR")) {
                                var errno = result[0].split("|")[1]
                                // do a GUI alert
                                console.log("Error: errno "+errno)
                            } else {
                                songLoadingIndicator.running = false
                                mediaplayer.source = result[0]
                                if (result[1]) {
                                    songlist[index][4] = result[1]
                                }
                                appWindow.art = songlist[index][4]
                                mediaplayer.seek(0)
                                mediaplayer.play()
                            }
                        })
                    } else {
                        mediaplayer.source = url
                        mediaplayer.play()
                        appWindow.art=art
                        // albumart.source = art
                        // songname.text = value
                        // artistname.text = artist
                    }
                }
            }
            Label {
                id: songTitle
                text: value
                leftPadding: Theme.paddingLarge
            }
            Label {
                id: songArtist
                text: artist
                anchors.top: songTitle.bottom
                color: Theme.highlightColor
                leftPadding: Theme.paddingLarge
                font.pixelSize: Theme.fontSizeSmall
            }
            height: (songTitle.lineCount-1)*(songTitle.font.pixelSize) + Theme.itemSizeSmall
        }

    }
    Rectangle {
        anchors.fill: controls
        color: Theme.secondaryHighlightColor
        visible: controls.visible
    }
    Column {
        id: controls
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height/3
        visible: false

        Slider {
            id: trackposition
            width: parent.width * 0.9
            anchors.horizontalCenter: parent.horizontalCenter
            maximumValue: duration
            value: mediaplayer.position
        }
        Row {
            id: controlrow
            width: parent.width
            property real itemwidth: width/4

            Image {
                id: albumart
                anchors.leftMargin: Theme.itemSizeSmall / 2
                // width: Theme.itemSizeSmall
                // height: Theme.itemSizeSmall
                width: controlrow.itemwidth
                height: controlrow.itemwidth
                source: parentpage.songlist[parentpage.currentIndex][4]
            }

            IconButton {
                width: controlrow.itemwidth
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-previous"
                onClicked: {
                    if (mediaplayer.position<5000 && parentpage.currentIndex>0) {
                        page.parentpage.currentIndex -= 1
                    }
                    parentpage.playSong(parentpage.currentIndex)
                }
            }

            IconButton {
                id: playbutton
                width: controlrow.itemwidth
                anchors.verticalCenter: parent.verticalCenter
                icon.source: mediaplayer.playbackState==MediaPlayer.PlayingState ? "image://theme/icon-l-pause"
                                                                                 : "image://theme/icon-l-play"


                BusyIndicator {
                    id: songLoadingIndicator
                    running: false
                    anchors.centerIn: playbutton
                    size: BusyIndicatorSize.Large
                }
                onClicked: {
                    if (mediaplayer.playbackState==MediaPlayer.PlayingState) {
                        mediaplayer.pause()
                        appWindow.state="paused"
                    } else {
                        mediaplayer.play()
                        appWindow.state="playing"
                    }
                }
            }

            IconButton {
                width: controlrow.itemwidth
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-next"
                onClicked: {
                    page.parentpage.currentIndex += 1
                    parentpage.playSong(page.parentpage.currentIndex)
                }
            }
        }
        Label {
            id: songname
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Theme.fontSizeLarge
            text: parentpage.songlist[parentpage.currentIndex][1]
        }
        Label {
            id: artistname
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: Theme.fontSizeSmall
            text: parentpage.songlist[parentpage.currentIndex][2]
        }
    }

}






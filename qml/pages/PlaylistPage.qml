import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.4
import QtQml 2.2

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
                src: songlist[i][8],
                index: i
            })
        }
    }
    StateGroup {
        states: [
            State {
                when: (page.width / page.height) < 1
                AnchorChanges {
                    target: songs;
                    anchors.top: page.top;
                    anchors.bottom: controls.top;
                    anchors.left: page.left;
                    anchors.right: page.right;
                }
                AnchorChanges {
                    target: controls;
                    // anchors.top: page.verticalCenter;
                    // anchors.top: page.verticalCenter;
                    // anchors.top: page.height / 3
                    // anchors.topMargin: page.height / 6
                    anchors.bottom: page.bottom
                    anchors.right: page.right
                    anchors.left: page.left
                }
                PropertyChanges {
                    target: controls;
                    height: controls.visible? page.height/3 : 1
                }
            },
            State {
                when: (page.width / page.height) > 1
                AnchorChanges {
                    target: songs;
                    anchors.top: page.top;
                    anchors.bottom: page.bottom;
                    anchors.left: page.left;
                    anchors.right: controls.left;
                }
                AnchorChanges {
                    target: controls;
                    // anchors.top: page.top
                    // anchors.topMargin: 0
                    anchors.bottom: page.bottom
                    anchors.right: page.right
                    anchors.left: page.horizontalCenter
                }
                PropertyChanges {
                    target: controls;
                    height: page.height
                }
            }
        ]
    }
    SilicaListView {
        id: songs
        // width: parent.width
        // anchors.top: parent.top
        // anchors.bottom: controls.top
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
                    if (src=="oc") {
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
                                // mediaplayer.play()
                                parentpage.queueMedia()
                            }
                        })
                    } else if (src=="spot") {
                        py.call("backend.play_spot_playlist", [songlist, index], function() {
                            songLoadingIndicator.running = false
                            appWindow.art = songlist[index][4]
                        })
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
        // anchors.bottom: parent.bottom
        // width: parent.width
        // height: parent.height/3
        visible: false

        Image {
            id: bigalbumart
            visible: page.width > page.height
            anchors.horizontalCenter: parent.horizontalCenter
            // visible: false
            // width: Theme.itemSizeSmall
            // height: Theme.itemSizeSmall
            width: parent.height/2
            height: parent.height/2
            source: parentpage.songlist[parentpage.currentIndex][4]
        }
        Slider {
            id: trackposition
            width: parent.width * 0.9
            anchors.horizontalCenter: parent.horizontalCenter
            maximumValue: duration
            property bool gotPosition: true
            property var oldval: 0
            // property var name
            // value: songlist[parentpage.currentIndex][8]=="spot" ? appWindow.offset : mediaplayer.position
            onValueChanged: {
                if (pressed) {
                    gotPosition = false
                    oldval = value
                } else if(gotPosition==false) {
                    gotPosition = true
                    console.log(value)
                    if (songlist[parentpage.currentIndex][8]=="spot") {
                        py.call('backend.seek_spot', [oldval], function(){})
                    } else {
                        mediaplayer.seek(oldval)
                    }
                }
            }
        }
        Binding {
            target: trackposition
            property: "value"
            value: trackposition.pressed ? trackposition.value
                                         : (songlist[parentpage.currentIndex][8]=="spot" ? appWindow.offset : mediaplayer.position)
        }
        Row {
            id: controlrow
            width: parent.width
            property real itemwidth: page.width < page.height ? width/4 : width/3

            Image {
                id: albumart
                anchors.leftMargin: Theme.itemSizeSmall / 2
                visible: page.width < page.height
                // width: Theme.itemSizeSmall
                // height: Theme.itemSizeSmall
                width: controlrow.itemwidth
                height: controlrow.itemwidth
                source: appWindow.art//parentpage.songlist[parentpage.currentIndex][4]
            }

            IconButton {
                width: controlrow.itemwidth
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-previous"
                onClicked: {
                    if (songlist[parentpage.currentIndex][8]=="spot") {
                        py.call('backend.prev_spot', [], function(){})
                        page.parentpage.currentIndex -= 1
                    } else {
                        if (mediaplayer.position<5000 && parentpage.currentIndex>0) {
                            page.parentpage.currentIndex -= 1
                        }
                        parentpage.playSong(parentpage.currentIndex)
                    }
                }
            }

            IconButton {
                id: playbutton
                width: controlrow.itemwidth
                anchors.verticalCenter: parent.verticalCenter
                // icon.source: mediaplayer.playbackState==MediaPlayer.PlayingState ? "image://theme/icon-l-pause"
                //                                                                  : "image://theme/icon-l-play"
                icon.source: appWindow.state=="playing" ? "image://theme/icon-l-pause"
                                                        : "image://theme/icon-l-play"


                BusyIndicator {
                    id: songLoadingIndicator
                    running: false
                    anchors.centerIn: playbutton
                    size: BusyIndicatorSize.Large
                }
                onClicked: {
                    if (songlist[parentpage.currentIndex][8]=="spot") {
                        py.call('backend.pause_spot', [], function(){})
                    } else {
                        if (mediaplayer.playbackState==MediaPlayer.PlayingState) {
                            mediaplayer.pause()
                            appWindow.state="paused"
                        } else {
                            mediaplayer.play()
                            appWindow.state="playing"
                        }
                    }
                }
            }

            IconButton {
                width: controlrow.itemwidth
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "image://theme/icon-m-next"
                onClicked: {
                    if (songlist[parentpage.currentIndex][8]=="spot") {
                        py.call('backend.next_spot', [], function(){})
                    } else {
                        page.parentpage.currentIndex += 1
                        parentpage.playSong(page.parentpage.currentIndex)
                    }
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






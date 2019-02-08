import QtQuick 2.0
import Sailfish.Silica 1.0
import io.thp.pyotherside 1.3
import QtMultimedia 5.4


Page {
    property int count
    property var playlist
    property var songlist;
    property int currentIndex;
    property var rootwindow;
    id: page

    function playSong (i) {
        py.call('backend.setSong', [songlist[i][0]], function(result){})
        appWindow.song = songlist[i][1]
        appWindow.art = songlist[i][4]
        if (0) {
            py.call('backend.downloadSong', [
                    songlist[i][3],
                    songlist[i][0],
                    songlist[i][4],
                    songlist[i][5],
                    songlist[i][7]], function(result) {
                if (page.startsWith(result[0], "%%%ERROR")) {
                    errno = result[0].split("|")[1]
                    // do a GUI alert
                    console.log("Error: errno "+errno)
                } else {
                    mediaplayer.source = result[0]
                    mediaplayer.seek(0)
                    mediaplayer.play()
                }
            })
        } else {
            mediaplayer.source = songlist[i][3]
            mediaplayer.seek(0)
            mediaplayer.play()
            // albumart.source = songlist[i][4]
            // songname.text = songlist[i][1]
            // artistname.text = songlist[i][2]
        }
    }

    function update_state(state, offset, index) {
        appWindow.state = state.toLowerCase()
        appWindow.offset = offset
        page.currentIndex = index
    }

    SilicaFlickable {
        anchors.fill: parent
        PullDownMenu {
            MenuItem {
                text: qsTr("Show Second page")
                onClicked: pageStack.push(Qt.resolvedUrl("SecondPage.qml"))
            }
        }
        Column {
            width: parent.width
            TextField {
                id: searchField
                width: parent.width
                placeholderText: "Search..."
                EnterKey.onClicked: {
                    parent.focus = true;
                    busyIndicator.running = true;
                    py.call('backend.search', [text], function(result) {
                        busyIndicator.running = false;
                        playlistModel.clear()
                        songModel.clear()
                        if (result[0].length==0) {
                            songLabel.visible = false
                            songs.visible = false
                        } else {
                            songLabel.visible = true
                            songs.visible = true
                            for (var i in result[0]) {
                                songModel.append({value: result[0][i][1], pid: result[0][i][0]})
                            }
                        }
                        if (result[1].length==0) {
                            playlistLabel.visible = false
                            playlists.visible = false
                        } else {
                            playlistLabel.visible = true
                            playlists.visible = true
                            for (var i in result[1]) {
                                playlistModel.append({value: result[1][i][1], pid: result[1][i][0]})
                            }
                        }
                    })
                }
            }
            Label {
                id: playlistLabel
                visible: false
                text: "Playlists"
                font.pixelSize: Theme.fontSizeSmall
            }
            SilicaListView {
                id: playlists
                visible: false
                width: parent.width
                height: childrenRect.height

                model: ListModel {
                    id: playlistModel
                }
                delegate: Item {
                    width: ListView.view.width
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log(value + " " + pid)
                            busyIndicator.running = true
                            py.call('backend.loadPlaylist', [pid, src], function(result) {
                                busyIndicator.running = false
                                page.playlist = result
                                page.songlist = result
                                pageStack.push(Qt.resolvedUrl("PlaylistPage.qml"), {
                                    songlist: result,
                                    py:py,
                                    mediaplayer:mediaplayer,
                                    parentpage: page
                                })
                            })
                        }
                    }
                    Image {
                        id: srcimg
                        source: "resources/" + src + "64.png"
                        width: Theme.itemSizeSmall / 2
                        height: Theme.itemSizeSmall / 2
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.paddingLarge
                    }
                    Label {
                        id: playlistTitle
                        text: value
                        leftPadding: Theme.paddingLarge
                        anchors.left: srcimg.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    height: (playlistTitle.lineCount-1)*(playlistTitle.font.pixelSize) + Theme.itemSizeSmall
                }
            }
            Label {
                id: songLabel
                text: "Songs"
                visible: false
                font.pixelSize: Theme.fontSizeSmall
            }
            SilicaListView {
                id: songs
                visible: false
                width: parent.width
                height: childrenRect.height

                model: ListModel {
                    id: songModel
                }
                delegate: Item {
                    width: ListView.view.width
                    Label {
                        id: songTitle
                        text: value
                        leftPadding: Theme.paddingLarge
                    }
                    height: (songTitle.lineCount-1)*(songTitle.font.pixelSize) + Theme.itemSizeSmall
                }
            }
        }
    }
    BusyIndicator {
        id: busyIndicator
        anchors.centerIn: page
        running: true
        color: Theme.primaryColor
        size: BusyIndicatorSize.Large
    }
    Python {
        id: py
        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('.'));
            importModule('backend', function() {
                py.call('backend.setupoc',[],function(result) {
                    if (result) {
                        busyIndicator.running = false
                        playlistLabel.visible = true
                        playlists.visible = true
                        for (var i in result) {
                            console.log(i)
                            playlistModel.append({value: result[i][1], pid: result[i][0], src: result[i][2]})
                        }
                    }
                    py.call('backend.setupspot', [], function(result) {
                        busyIndicator.running = false
                        playlistLabel.visible = true
                        playlists.visible = true
                        for (var i in result) {
                            console.log(i)
                            playlistModel.append({value: result[i][1], pid: result[i][0], src: result[i][2]})
                        }
                    })
                })
            });
            setHandler('update_state', page.update_state)

        }
    }
    Timer {
        id: cleanupTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            //console.log(mediaplayer.position)
            py.call('backend.check_transfers', [], function(){})
        }
    }
    Timer {
        id: fixthemusicTimer
        property int offset;
        interval: 250
        running: false
        repeat: false
        onTriggered: {
            console.log("fixing damn mediaplayer position")
            mediaplayer.seek(offset)
        }
    }
    MediaPlayer {
        id: mediaplayer
        onPlaybackStateChanged: {
            if (mediaplayer.playbackState==MediaPlayer.PlayingState) {
                console.log("Playing song, duration: "+mediaplayer.duration)
            }
            if (mediaplayer.playbackState==MediaPlayer.StoppedState && mediaplayer.position > songlist[currentIndex][6]*1000-10000) {
                console.log("Error: "+mediaplayer.errorString)
                console.log("Duration: "+mediaplayer.duration)
                console.log("Position: "+mediaplayer.position+" / "+songlist[currentIndex][6]*1000)
                currentIndex+=1
                playSong(currentIndex)
            } else if (mediaplayer.playbackState==MediaPlayer.StoppedState) {
                console.log("Force playing")
                var curpos = mediaplayer.position
                console.log("Position: "+curpos)
                mediaplayer.play()
                console.log("Can seek: "+mediaplayer.seekable)
                mediaplayer.seek(curpos)
                console.log("Position: "+curpos)
                fixthemusicTimer.offset = curpos
                fixthemusicTimer.restart()
            }
        }
    }
}



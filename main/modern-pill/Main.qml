import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0B0B10"

    property int sessionIndex: 0
    property int userIndex: 0
    property string currentUser: "moonlight"
    property string currentSessionName: "PLASMA"

    // Live color automatically extracted from the video wallpaper
    property color dynamicAccent: config.AccentColor || "#94E2D5"
    property color dynamicTextOnAccent: "#11111B"

    Repeater {
        model: userModel
        delegate: Item {
            property string uName: model.name || model.display || ""
            function syncUser() {
                if (index === root.userIndex && uName !== "") {
                    root.currentUser = uName
                }
            }
            Component.onCompleted: {
                if (uName.toLowerCase() === "moonlight") {
                    root.userIndex = index
                    root.currentUser = uName
                } else {
                    syncUser()
                }
            }
            Connections {
                target: root
                function onUserIndexChanged() { syncUser() }
            }
        }
    }

    Repeater {
        model: sessionModel
        delegate: Item {
            property string sName: model.name || model.display || ""
            function syncSession() {
                if (index === root.sessionIndex && sName !== "") {
                    root.currentSessionName = sName
                }
            }
            Component.onCompleted: {
                if (sName.toLowerCase().indexOf("plasma") !== -1) {
                    root.sessionIndex = index
                    root.currentSessionName = sName
                } else {
                    syncSession()
                }
            }
            Connections {
                target: root
                function onSessionIndexChanged() { syncSession() }
            }
        }
    }

    // Video Wallpaper Layer
    MediaPlayer {
        id: bgPlayer
        source: Qt.resolvedUrl(config.VideoBackground || "background.mp4")
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { muted: true }
        videoOutput: bgVideoOutput
        Component.onCompleted: play()
    }

    VideoOutput {
        id: bgVideoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // Live 4x4 downsampled texture of the video to extract dominant color
    ShaderEffectSource {
        id: colorSamplerSource
        width: 4
        height: 4
        sourceItem: bgVideoOutput
        live: true
        hideSource: false
        visible: false
    }

    Canvas {
        id: colorSamplerCanvas
        width: 4
        height: 4
        visible: false
        onPaint: {
            var ctx = getContext("2d")
            ctx.drawImage(colorSamplerSource, 0, 0, 4, 4)
            var imgData = ctx.getImageData(0, 0, 4, 4).data
            var r = 0, g = 0, b = 0, count = 0
            for (var i = 0; i < imgData.length; i += 4) {
                r += imgData[i]
                g += imgData[i + 1]
                b += imgData[i + 2]
                count++
            }
            if (count > 0) {
                r = Math.round(r / count)
                g = Math.round(g / count)
                b = Math.round(b / count)

                // Boost brightness so the accent color stays vibrant and readable against dark video
                var maxVal = Math.max(r, g, b, 1)
                var boost = Math.max(1.0, 210 / maxVal)
                r = Math.min(255, Math.round(r * boost))
                g = Math.min(255, Math.round(g * boost))
                b = Math.min(255, Math.round(b * boost))

                root.dynamicAccent = Qt.rgba(r / 255.0, g / 255.0, b / 255.0, 1.0)
            }
        }
    }

    // Sample the video color on startup and smoothly adapt as the video plays
    Timer {
        interval: 800
        running: true
        repeat: true
        triggeredOnStart: true
    }

    Behavior on dynamicAccent { ColorAnimation { duration: 600 } }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: config.DimBackground || 0.25
    }

    // Left Column: Clock & Date Pill
    Column {
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
            id: hourText
            text: Qt.formatTime(new Date(), "hh")
            font.family: config.ClockFontFamily || "sans-serif"
            font.pixelSize: 150
            font.weight: Font.Bold
            color: root.dynamicAccent
            lineHeight: 0.85
        }

        Text {
            id: minText
            text: Qt.formatTime(new Date(), "mm")
            font.family: config.ClockFontFamily || "sans-serif"
            font.pixelSize: 150
            font.weight: Font.Bold
            color: root.dynamicAccent
            lineHeight: 0.85
        }

        Item { width: 1; height: 14 }

        GlassCard {
            width: dateLabel.implicitWidth + 36
            height: 40
            cardRadius: 20
            hoverable: false

            contentItem: Text {
                id: dateLabel
                anchors.centerIn: parent
                text: Qt.formatDate(new Date(), "dddd, MMM d").toUpperCase()
                font.family: config.FontFamily || "sans-serif"
                font.pixelSize: 13
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                color: config.TextColor || "#FFFFFF"
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            hourText.text = Qt.formatTime(now, "hh")
            minText.text = Qt.formatTime(now, "mm")
            dateLabel.text = Qt.formatDate(now, "dddd, MMM d").toUpperCase()
        }
    }

    // Right Column: Quick Settings & Login Card
    Column {
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.10
        anchors.verticalCenter: parent.verticalCenter
        width: 440
        spacing: 16

        Text {
            text: "QUICK SETTINGS"
            font.family: config.FontFamily || "sans-serif"
            font.pixelSize: 12
            font.weight: Font.Bold
            font.letterSpacing: 1.5
            color: config.SubTextColor || "#D0D7E5"
            leftPadding: 6
        }

        GridLayout {
            width: parent.width
            columns: 2
            rowSpacing: 14
            columnSpacing: 14

            ActionPill {
                Layout.fillWidth: true
                iconChar: "⏻"
                title: "POWER"
                subtitle: "SHUT DOWN"
                onClicked: sddm.powerOff()
            }

            ActionPill {
                Layout.fillWidth: true
                iconChar: "⚙"
                title: "SESSION"
                subtitle: root.currentSessionName.toUpperCase()
                onClicked: {
                    if (sessionModel.rowCount() > 0)
                        root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
                }
            }

            ActionPill {
                Layout.fillWidth: true
                iconChar: "↻"
                title: "REBOOT"
                subtitle: "RESTART"
                onClicked: sddm.reboot()
            }

            ActionPill {
                Layout.fillWidth: true
                iconChar: "☾"
                title: "SLEEP"
                subtitle: "SUSPEND"
                onClicked: sddm.suspend()
            }
        }

        Item {
            id: authCardContainer
            width: parent.width
            height: 205

            Column {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14
                z: 5

                Text {
                    text: "🔒  SYSTEM UI  •  now"
                    font.family: config.FontFamily || "sans-serif"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.1
                    color: config.SubTextColor || "#D0D7E5"
                    leftPadding: 6
                }

                // Password Box with independent hover/focus glow
                GlassCard {
                    id: passGlassBox
                    width: parent.width
                    height: 56
                    cardRadius: 28
                    hoverable: true
                    customHover: passwordInput.activeFocus

                    contentItem: Item {
                        anchors.fill: parent

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            font.family: config.ClockFontFamily || "sans-serif"
                            font.pixelSize: 20
                            font.letterSpacing: 6
                            color: "#FFFFFF"
                            focus: true

                            Keys.onReturnPressed: sddm.login(root.currentUser, passwordInput.text, root.sessionIndex)
                            Keys.onEnterPressed: sddm.login(root.currentUser, passwordInput.text, root.sessionIndex)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "PASSWORD REQUIRED"
                            font.family: config.FontFamily || "sans-serif"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.letterSpacing: 1.8
                            color: passGlassBox.isHighlighted ? root.dynamicTextOnAccent : "#D0D7E5"
                            visible: passwordInput.text.length === 0
                        }
                    }

                    Component.onCompleted: {
                        mouseArea.acceptedButtons = Qt.LeftButton
                        mouseArea.cursorShape = Qt.IBeamCursor
                        mouseArea.onClicked.connect(function() { passwordInput.forceActiveFocus() })
                    }
                }

                RowLayout {
                    width: parent.width
                    height: 48
                    spacing: 12

                    // User Switcher Pill ("MOONLIGHT") with independent hover glow
                    GlassCard {
                        id: userPillGlass
                        Layout.preferredWidth: 140
                        Layout.fillHeight: true
                        cardRadius: 24
                        hoverable: true

                        contentItem: Text {
                            anchors.centerIn: parent
                            text: root.currentUser.toUpperCase()
                            font.family: config.FontFamily || "sans-serif"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            color: userPillGlass.isHighlighted ? root.dynamicTextOnAccent : "#FFFFFF"
                        }

                        Component.onCompleted: {
                            mouseArea.acceptedButtons = Qt.LeftButton
                            mouseArea.cursorShape = Qt.PointingHandCursor
                            mouseArea.onClicked.connect(function() {
                                if (userModel.rowCount() > 0)
                                    root.userIndex = (root.userIndex + 1) % userModel.rowCount()
                            })
                        }
                    }

                    // Solid Unlock Button matching live wallpaper color
                    Rectangle {
                        id: unlockSolidBtn
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 24
                        color: unlockMouse.containsMouse ? Qt.lighter(root.dynamicAccent, 1.15) : root.dynamicAccent

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "UNLOCK  →"
                            font.family: config.FontFamily || "sans-serif"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            font.letterSpacing: 1.4
                            color: root.dynamicTextOnAccent
                        }

                        MouseArea {
                            id: unlockMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sddm.login(root.currentUser, passwordInput.text, root.sessionIndex)
                        }
                    }
                }
            }
        }
    }

    // Glass Card Component with full background fill glow matching live wallpaper
    component GlassCard: Item {
        id: glassRoot
        property real cardRadius: 32
        property bool hoverable: true
        property bool customHover: false
        property alias contentItem: contentContainer.data
        property alias mouseArea: cardMouse

        readonly property bool isHighlighted: cardMouse.containsMouse || glassRoot.customHover

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: glassRoot.isHighlighted ? 0.65 : 0.0
                blurMax: 32
                Behavior on blur { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                anchors.fill: parent
                radius: glassRoot.cardRadius
                color: root.dynamicAccent
                opacity: glassRoot.isHighlighted ? 0.85 : 0.0
                border.color: glassRoot.isHighlighted ? Qt.lighter(root.dynamicAccent, 1.25) : "transparent"
                border.width: glassRoot.isHighlighted ? 1.5 : 0

                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }
        }

        Item {
            id: contentContainer
            anchors.fill: parent
            z: 2
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: glassRoot.hoverable
            z: 3
        }
    }

    component ActionPill: GlassCard {
        id: pillItem
        property string iconChar: ""
        property string title: ""
        property string subtitle: ""
        signal clicked()

        height: 76
        cardRadius: 38

        contentItem: Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 16
            spacing: 14

            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: pillItem.isHighlighted ? Qt.rgba(0, 0, 0, 0.25) : "#22FFFFFF"

                Text {
                    anchors.centerIn: parent
                    text: iconChar
                    font.pixelSize: 18
                    color: pillItem.isHighlighted ? root.dynamicTextOnAccent : "#FFFFFF"
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: title
                    font.family: config.FontFamily || "sans-serif"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    color: pillItem.isHighlighted ? root.dynamicTextOnAccent : "#FFFFFF"
                }

                Text {
                    text: subtitle
                    font.family: config.FontFamily || "sans-serif"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 0.8
                    color: pillItem.isHighlighted ? Qt.rgba(0, 0, 0, 0.75) : "#D0D7E5"
                }
            }
        }

        Component.onCompleted: {
            mouseArea.acceptedButtons = Qt.LeftButton
            mouseArea.cursorShape = Qt.PointingHandCursor
            mouseArea.onClicked.connect(function() { parent.clicked() })
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordInput.text = ""
            passwordInput.focus = true
        }
    }
}

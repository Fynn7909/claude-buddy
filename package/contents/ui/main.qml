import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color coral: "#D97757"
    readonly property string script: "python3 '" + Qt.resolvedUrl("../code/buddy.py").toString().replace("file://", "") + "' state"

    // Ausgabe von `buddy.py state`
    property var info: null
    readonly property bool awake: info !== null && info.awake
    readonly property bool working: info !== null && info.working
    // Claude braucht eine Erlaubnis oder Antwort
    readonly property bool waiting: info !== null && info.waiting
    // "sleep", "idle", "work", "think", "wait", "happy", "confused" oder "tired"
    readonly property string mood: info ? info.mood : "sleep"
    readonly property bool night: info !== null && info.daytime === "night"
    readonly property bool coffee: awake && info.daytime === "morning"
    readonly property var idea: info ? info.idea : null
    readonly property string tool: working ? info.tool : ""

    // Dauer seit einem Zeitpunkt in Worten, leer unter einer Minute
    function since(ms) {
        const minutes = Math.floor((Date.now() - ms) / 60000)
        if (!ms || minutes < 1) return ""
        if (minutes < 60) return minutes + " min"
        return Math.floor(minutes / 60) + " h " + (minutes % 60) + " min"
    }

    function statusText() {
        if (!awake) return idea ? "Idee des Tages · " + idea.tag : "Schläft"
        const parts = []
        if (waiting) {
            parts.push("Wartet auf dich")
            if (info.project) parts.push(info.project)
        } else if (working) {
            parts.push(info.project ? "Arbeitet in " + info.project : "Arbeitet")
            if (since(info.turn)) parts.push(since(info.turn))
        } else {
            parts.push(mood === "tired" ? "Müde" : "Wach")
            if (info.project) parts.push(info.project)
            if (since(info.started)) parts.push("seit " + since(info.started))
        }
        return parts.join(" · ")
    }

    function sentenceText() {
        if (waiting) return info.note || "Claude braucht deine Antwort."
        if (idea) return idea.title
        return (info && info.summary) || "Noch keine Antwort von Claude."
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            if (sourceName !== root.script) return
            try {
                root.info = JSON.parse(data["stdout"])
            } catch (e) {}
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: shell.connectSource(root.script)
    }

    // Hintergrundbild der Arbeitsfläche und die Lage des Widgets darauf
    property Item wallpaper: null
    property point origin: Qt.point(0, 0)

    function locate(item) {
        for (let p = item.parent; p; p = p.parent) {
            if (p.wallpaper) {
                wallpaper = p.wallpaper
                origin = item.mapToItem(p.wallpaper, 0, 0)
                return
            }
        }
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    toolTipMainText: "Claude Buddy"
    toolTipSubText: "Wach, solange du mit Claude Code arbeitest · winkt, wenn Claude auf dich wartet · Klicken öffnet Claude Hub"

    // Schrift und Farbe für alle Texte im Widget
    component Txt: PC3.Label {
        color: "white"
        font.family: "Inter"
    }

    fullRepresentation: MouseArea {
        id: area
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: Kirigami.Units.gridUnit * 21
        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Component.onCompleted: root.locate(area)
        onWidthChanged: root.locate(area)
        onHeightChanged: root.locate(area)
        Timer {
            interval: 2000
            running: true
            repeat: true
            onTriggered: root.locate(area)
        }

        onClicked: shell.connectSource("gtk-launch claude-hub")

        Item {
            id: card
            anchors.fill: parent
            transformOrigin: Item.Center
            scale: area.pressed ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: area.pressed ? 100 : 350; easing.type: Easing.OutQuint } }

            // Einblenden beim Start
            opacity: 0
            transform: Translate { id: rise; y: 14 }
            ParallelAnimation {
                running: true
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 500; easing.type: Easing.OutCubic }
                NumberAnimation { target: rise; property: "y"; to: 0; duration: 600; easing.type: Easing.OutCubic }
            }

            // Hintergrundbild hinter dem Widget, weichgezeichnet statt abgedunkelt
            Item {
                id: glass
                anchors.fill: parent

                ShaderEffectSource {
                    id: behind
                    anchors.fill: parent
                    visible: false
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.origin.x + glass.x, root.origin.y + glass.y, glass.width, glass.height)
                }
                Rectangle {
                    id: rounded
                    anchors.fill: parent
                    radius: 22
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: parent
                    visible: root.wallpaper !== null
                    source: behind
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 0.75
                    blurMax: 64
                    saturation: 0.35
                    maskEnabled: true
                    maskSource: rounded
                }
                // Material: leichte Tönung für Lesbarkeit, helle Haarlinie als Lichtkante
                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    color: Qt.rgba(0.07, 0.07, 0.08, root.wallpaper ? 0.3 : 0.7)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                // Maskottchen aus Pixelblöcken, 14 × 8 Felder
                Item {
                    id: buddy
                    readonly property real u: 7
                    Layout.preferredWidth: u * 14
                    Layout.preferredHeight: u * 8
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: u * (root.coffee ? 5 : 2)

                    // Augenlid: 1 offen, 0 zu; müde nur halb offen
                    property real lid: !root.awake ? 0 : root.mood === "tired" ? 0.45 : 1
                    property real blink: 1
                    // Blickrichtung in Feldern, wandert beim Arbeiten; beim Nachdenken geht der Blick nach oben
                    property real look: 0
                    property real gaze: root.mood === "think" ? -0.5 : 0
                    property real breath: 0
                    // Freude kneift beide Augen zusammen, Verwirrung nur das rechte
                    property real squint: root.mood === "happy" ? 1 : 0
                    property real skew: root.mood === "confused" ? 1 : 0
                    // Kleiner Hüpfer bei Freude, gehobener Arm beim Winken (je 0 bis 1)
                    property real hop: 0
                    property real wave: 0
                    Behavior on lid { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
                    Behavior on gaze { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
                    Behavior on squint { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    Behavior on skew { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                    // Im Schlaf blasser; als Farbe statt Deckkraft, sonst scheinen die überlappenden Blöcke durch
                    property color skin: root.awake ? root.coral : "#8F5A49"
                    Behavior on skin { ColorAnimation { duration: 600; easing.type: Easing.OutQuint } }

                    SequentialAnimation {
                        running: root.awake
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) buddy.blink = 1
                        PauseAnimation { duration: 3400 }
                        NumberAnimation { target: buddy; property: "blink"; to: 0; duration: 70 }
                        NumberAnimation { target: buddy; property: "blink"; to: 1; duration: 130 }
                        PauseAnimation { duration: 2100 }
                        NumberAnimation { target: buddy; property: "blink"; to: 0; duration: 70 }
                        NumberAnimation { target: buddy; property: "blink"; to: 1; duration: 130 }
                    }
                    SequentialAnimation {
                        running: root.mood === "work"
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) center.restart()
                        NumberAnimation { target: buddy; property: "look"; to: -0.5; duration: 350; easing.type: Easing.OutQuint }
                        PauseAnimation { duration: 900 }
                        NumberAnimation { target: buddy; property: "look"; to: 0.5; duration: 450; easing.type: Easing.OutQuint }
                        PauseAnimation { duration: 900 }
                    }
                    NumberAnimation { id: center; target: buddy; property: "look"; to: 0; duration: 350; easing.type: Easing.OutQuint }
                    // Ruhiges Atmen im Schlaf
                    SequentialAnimation {
                        running: !root.awake
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) buddy.breath = 0
                        NumberAnimation { target: buddy; property: "breath"; to: 1; duration: 2200; easing.type: Easing.InOutSine }
                        NumberAnimation { target: buddy; property: "breath"; to: 0; duration: 2200; easing.type: Easing.InOutSine }
                    }

                    Connections {
                        target: root
                        function onMoodChanged() { if (root.mood === "happy") jump.restart() }
                    }
                    SequentialAnimation {
                        id: jump
                        NumberAnimation { target: buddy; property: "hop"; to: 1; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { target: buddy; property: "hop"; to: 0; duration: 320; easing.type: Easing.InOutSine }
                    }
                    // Winken, solange Claude auf dich wartet
                    SequentialAnimation {
                        running: root.waiting
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) lower.restart()
                        NumberAnimation { target: buddy; property: "wave"; to: 1; duration: 380; easing.type: Easing.InOutSine }
                        NumberAnimation { target: buddy; property: "wave"; to: 0.5; duration: 380; easing.type: Easing.InOutSine }
                    }
                    NumberAnimation { id: lower; target: buddy; property: "wave"; to: 0; duration: 350; easing.type: Easing.OutQuint }

                    // Beine bleiben stehen, der Körper hebt sich beim Atmen leicht
                    Repeater {
                        model: [2, 4, 9, 11]
                        delegate: Rectangle {
                            required property int modelData
                            x: buddy.u * modelData; y: buddy.u * 5
                            width: buddy.u; height: buddy.u * 3
                            color: buddy.skin
                        }
                    }
                    Item {
                        width: parent.width
                        height: buddy.u * 6
                        y: -buddy.breath * 2 - buddy.hop * 4

                        Rectangle { x: buddy.u * 2; width: buddy.u * 10; height: buddy.u * 6; color: buddy.skin }
                        // Arme; der rechte hebt sich zum Winken
                        Rectangle { y: buddy.u * 3; width: buddy.u * 2; height: buddy.u * 2; color: buddy.skin }
                        Rectangle { x: buddy.u * 12; y: buddy.u * (3 - buddy.wave * 2); width: buddy.u * 2; height: buddy.u * 2; color: buddy.skin }
                        Repeater {
                            model: [4, 9]
                            delegate: Rectangle {
                                required property int modelData
                                required property int index
                                x: buddy.u * (modelData + buddy.look)
                                width: buddy.u
                                height: Math.max(2, buddy.u * 2 * buddy.lid * buddy.blink
                                    * (1 - 0.5 * buddy.squint) * (1 - 0.5 * buddy.skew * index))
                                y: buddy.u * (2 + buddy.gaze - 0.4 * buddy.squint) - height / 2
                                color: "#1f1e1d"
                            }
                        }

                        // Schlafmütze von 22 bis 6 Uhr
                        Item {
                            visible: root.night
                            Rectangle { x: buddy.u * 3; y: -buddy.u * 2; width: buddy.u * 9; height: buddy.u; color: "#5E7FA8" }
                            Rectangle { x: buddy.u * 5; y: -buddy.u * 3; width: buddy.u * 7; height: buddy.u; color: "#5E7FA8" }
                            Rectangle { x: buddy.u * 8; y: -buddy.u * 4; width: buddy.u * 5; height: buddy.u; color: "#5E7FA8" }
                            Rectangle { x: buddy.u * 12; y: -buddy.u * 3; width: buddy.u; height: buddy.u; color: "#5E7FA8" }
                            Rectangle { x: buddy.u * 2; y: -buddy.u; width: buddy.u * 10; height: buddy.u; color: "#F2EFEA" }
                            Rectangle { x: buddy.u * 12; y: -buddy.u * 2; width: buddy.u * 1.5; height: buddy.u * 1.5; color: "#F2EFEA" }
                        }
                    }

                    // Gedankenpunkte bei langen Aufgaben
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            id: dot
                            required property int index
                            width: 3 + index
                            height: width
                            x: buddy.u * (11.5 + index * 1.1)
                            y: -buddy.u * (0.6 + index * 0.9)
                            color: "white"
                            opacity: 0
                            visible: root.mood === "think"
                            SequentialAnimation {
                                running: dot.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: dot.index * 350 }
                                NumberAnimation { target: dot; property: "opacity"; to: 0.8; duration: 300 }
                                PauseAnimation { duration: (2 - dot.index) * 350 + 900 }
                                NumberAnimation { target: dot; property: "opacity"; to: 0; duration: 400 }
                                PauseAnimation { duration: 300 }
                            }
                        }
                    }

                    // Fragezeichen nach einem Fehler
                    Txt {
                        text: "?"
                        x: buddy.u * 12.5
                        y: -buddy.u * 2.2
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        opacity: root.mood === "confused" ? 0.85 : 0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                    }

                    // Kaffee von 6 bis 10 Uhr
                    Item {
                        visible: root.coffee
                        x: buddy.u * 15.5
                        y: buddy.u * 6
                        Rectangle { width: buddy.u * 2; height: buddy.u * 2; color: "#F2EFEA" }
                        Rectangle { x: buddy.u * 2; y: buddy.u * 0.4; width: buddy.u * 0.7; height: buddy.u; color: "#F2EFEA" }
                        Rectangle { x: 2; y: 2; width: buddy.u * 2 - 4; height: 3; color: "#5A3A2B" }
                        Repeater {
                            model: 2
                            delegate: Rectangle {
                                id: steam
                                required property int index
                                x: buddy.u * (0.4 + index * 0.9)
                                width: 2
                                height: 5
                                color: "white"
                                opacity: 0
                                SequentialAnimation {
                                    running: root.coffee
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: steam.index * 900 }
                                    ParallelAnimation {
                                        NumberAnimation { target: steam; property: "y"; from: -6; to: -18; duration: 1800; easing.type: Easing.OutCubic }
                                        SequentialAnimation {
                                            NumberAnimation { target: steam; property: "opacity"; from: 0; to: 0.6; duration: 500 }
                                            NumberAnimation { target: steam; property: "opacity"; to: 0; duration: 1300 }
                                        }
                                    }
                                    PauseAnimation { duration: (1 - steam.index) * 900 + 400 }
                                }
                            }
                        }
                    }

                    // Zzz steigt auf, solange er schläft
                    Repeater {
                        model: 3
                        delegate: Txt {
                            id: zed
                            required property int index
                            text: "z"
                            font.pixelSize: 11 + index * 3
                            font.weight: Font.DemiBold
                            x: buddy.u * (root.night ? 14.5 : 12.5) + index * 7
                            opacity: 0
                            visible: !root.awake
                            SequentialAnimation {
                                running: zed.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: zed.index * 700 }
                                ParallelAnimation {
                                    NumberAnimation { target: zed; property: "y"; from: 0; to: -14 - zed.index * 6; duration: 2400; easing.type: Easing.OutCubic }
                                    SequentialAnimation {
                                        NumberAnimation { target: zed; property: "opacity"; from: 0; to: 0.75; duration: 600 }
                                        PauseAnimation { duration: 800 }
                                        NumberAnimation { target: zed; property: "opacity"; to: 0; duration: 1000 }
                                    }
                                }
                                PauseAnimation { duration: (2 - zed.index) * 700 + 600 }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: root.waiting ? "#FFD60A"
                                 : root.working ? root.coral
                                 : root.awake ? "#30D158"
                                 : Qt.rgba(1, 1, 1, 0.3)
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: root.statusText()
                            opacity: 0.7
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    // Was Claude gerade tut
                    Txt {
                        Layout.fillWidth: true
                        visible: root.tool !== ""
                        text: root.tool
                        opacity: 0.55
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    // Letzte Antwort in einem Satz; im Schlaf die Idee des Tages, beim Warten der Grund
                    Txt {
                        id: sentence
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: root.sentenceText()
                        opacity: root.awake || root.idea ? 1 : 0.6
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        lineHeight: 1.15
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 5
                        verticalAlignment: Text.AlignTop
                        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }

                        // Neuer Satz blendet ein
                        transform: Translate { id: shift }
                        onTextChanged: arrive.restart()
                        NumberAnimation { id: arrive; target: shift; property: "y"; from: 6; to: 0; duration: 450; easing.type: Easing.OutQuint }
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    width: 300
    height: 150
    property var readings: ({})
    property string errorText: ""

    function refresh() {
        var request = new XMLHttpRequest()
        request.open("GET", "http://127.0.0.1:8765/api/readings")
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            if (request.status === 200) {
                var response = JSON.parse(request.responseText)
                var selected = {}
                for (var index = 0; index < response.readings.length; index++) {
                    var reading = response.readings[index]
                    if ((reading.id === "231" || reading.id === "232") && selected[reading.id] === undefined)
                        selected[reading.id] = reading.temperature_C
                }
                root.readings = selected
                root.errorText = ""
            } else {
                root.errorText = i18n("Service unavailable")
            }
        }
        request.send()
    }

    Component.onCompleted: refresh()
    Timer { interval: 1800000; running: true; repeat: true; onTriggered: root.refresh() }

    compactRepresentation: Kirigami.Icon {
        source: "weather-clear"
        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: root.readings["231"] !== undefined ? Number(root.readings["231"]).toFixed(1) + " °C" : i18n("No readings")
        }
    }

    fullRepresentation: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon { source: "weather-clear"; implicitWidth: 28; implicitHeight: 28 }
            PlasmaComponents3.Label { text: i18n("Telldus temperature"); font.weight: Font.DemiBold; Layout.fillWidth: true }
        }
        PlasmaComponents3.Label { visible: root.errorText !== ""; text: root.errorText; opacity: 0.7 }
        PlasmaComponents3.Label {
            visible: root.errorText === "" && root.readings["231"] === undefined && root.readings["232"] === undefined
            text: i18n("Waiting for a reading...")
            opacity: 0.7
        }
        RowLayout {
            visible: root.readings["231"] !== undefined
            Layout.fillWidth: true
            PlasmaComponents3.Label { text: i18n("Air"); Layout.preferredWidth: 60; opacity: 0.7 }
            PlasmaComponents3.Label {
                text: Number(root.readings["231"]).toFixed(1) + " °C"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
        }
        RowLayout {
            visible: root.readings["232"] !== undefined
            Layout.fillWidth: true
            PlasmaComponents3.Label { text: i18n("Water"); Layout.preferredWidth: 60; opacity: 0.7 }
            PlasmaComponents3.Label {
                text: Number(root.readings["232"]).toFixed(1) + " °C"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
        }
        Item { Layout.fillHeight: true }
    }
}
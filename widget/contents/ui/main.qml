import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    width: 300
    height: Math.max(150, 72 + readings.length * 76)
    property var readings: []
    property string errorText: ""

    function refresh() {
        var request = new XMLHttpRequest()
        request.open("GET", "http://127.0.0.1:8765/api/readings")
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            if (request.status === 200) {
                var response = JSON.parse(request.responseText)
                root.readings = response.readings
                root.errorText = ""
            } else {
                root.errorText = i18n("Service unavailable")
            }
        }
        request.send()
    }

    Component.onCompleted: refresh()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refresh() }

    compactRepresentation: Kirigami.Icon {
        source: "weather-clear"
        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: root.readings.length > 0 ? root.readings[0].temperature_C.toFixed(1) + " °C" : i18n("No readings")
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
            visible: root.errorText === "" && root.readings.length === 0
            text: i18n("Waiting for a reading...")
            opacity: 0.7
        }
        Repeater {
            model: root.readings
            delegate: RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label { text: "#" + modelData.id; Layout.preferredWidth: 48; opacity: 0.7 }
                PlasmaComponents3.Label {
                    text: Number(modelData.temperature_C).toFixed(1) + " °C"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    visible: modelData.humidity !== null
                    text: modelData.humidity === null ? "" : Number(modelData.humidity).toFixed(0) + " %"
                    opacity: 0.75
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import "qrc:/teraguchi"

ApplicationWindow {
    id: preview
    visible: true
    width: previewWidth
    height: previewHeight
    minimumWidth: 860
    minimumHeight: 680
    title: "Teraguchi · Interface preview"
    color: "#171B1D"

    WorkstationFlow {
        id: previewFlow
    }
    property int pendingCheck: 0
    property int pendingConnection: 0
    property int requestedDisplays: 1
    property string scenario: initialScenario

    function sampleHosts() {
        return [
            {
                id: "studio-a",
                name: "Studio A",
                assigned: true,
                status: "ready"
            },
            {
                id: "studio-b",
                name: "Studio B",
                assigned: true,
                status: "offline"
            },
            {
                id: "studio-c",
                name: "Studio C",
                assigned: true,
                status: "occupied"
            },
            {
                id: "studio-d",
                name: "Studio D",
                assigned: true,
                status: "incompatible"
            }
        ];
    }
    function reset() {
        checkTimer.stop();
        connectTimer.stop();
        if (previewFlow.busy)
            previewFlow.cancel();
        if (previewFlow.sessionOpen)
            previewFlow.disconnect();
        previewFlow.setWorkstations(sampleHosts());
        previewFlow.selectWorkstation("studio-a");
        previewFlow.chooseDisplays(1);
    }
    Connections {
        target: previewFlow
        function onCheckRequested(token, workstationId, displays, resume) {
            pendingCheck = token;
            requestedDisplays = displays;
            checkTimer.restart();
        }
        function onConnectionRequested(token, workstationId, displays, resume) {
            pendingConnection = token;
            connectTimer.restart();
        }
        function onCancelRequested(token) {
            checkTimer.stop();
            connectTimer.stop();
        }
        function onRefreshRequested(workstationId) {
            previewFlow.setWorkstations(sampleHosts());
        }
    }
    Timer {
        id: checkTimer
        interval: 550
        onTriggered: {
            var result = {
                outcome: "pass",
                authorized: true,
                seatAvailable: true,
                displays: requestedDisplays,
                nativeSourceDepth: 10,
                profile: "hevc-rext-444-10",
                hardwareDecode: true
            };
            if (scenario === "seat-race")
                result.outcome = "occupied";
            if (scenario === "permissions")
                result.outcome = "permissions";
            if (scenario === "display-mismatch")
                result.displays = requestedDisplays === 2 ? 1 : 2;
            if (scenario === "source-depth")
                result.nativeSourceDepth = 8;
            previewFlow.acceptCheck(pendingCheck, result);
        }
    }
    Timer {
        id: connectTimer
        interval: 500
        onTriggered: {
            previewFlow.acceptConnection(pendingConnection, scenario !== "connection-failure");
            if (scenario === "interrupted")
                previewFlow.interrupted(pendingConnection);
        }
    }
    Component.onCompleted: {
        reset();
        if (scenario === "offline")
            previewFlow.selectWorkstation("studio-b");
        else if (scenario === "occupied")
            previewFlow.selectWorkstation("studio-c");
        else if (scenario === "incompatible")
            previewFlow.selectWorkstation("studio-d");
        else if (scenario === "empty") {
            previewFlow.selectedId = "";
            previewFlow.setWorkstations([]);
        } else if (["interrupted", "connected", "display-mismatch", "source-depth", "permissions", "seat-race", "connection-failure"].indexOf(scenario) >= 0) {
            if (scenario === "display-mismatch")
                previewFlow.chooseDisplays(2);
            previewFlow.begin(false);
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            color: "#344238"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 30
                Label {
                    text: "INTERFACE PREVIEW"
                    color: "#D4E4D7"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
                Rectangle {
                    width: 1
                    height: 14
                    color: "#65766B"
                }
                Label {
                    Layout.fillWidth: true
                    text: "Sample workstations. No network connection, video, or input forwarding."
                    color: "#D4E4D7"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
        WorkstationPicker {
            Layout.fillWidth: true
            Layout.fillHeight: true
            flow: previewFlow
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 64
            color: "#202629"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 30
                spacing: 12
                Label {
                    text: "SIMULATE"
                    color: "#B3BCBF"
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
                ComboBox {
                    id: scenarios
                    Layout.preferredWidth: 230
                    model: ["Normal connection", "Workstation becomes occupied", "Missing Mac permissions", "Missing selected display", "8-bit capture source", "Connection fails"]
                    onActivated: {
                        reset();
                        scenario = ["ready", "seat-race", "permissions", "display-mismatch", "source-depth", "connection-failure"][currentIndex];
                    }
                    Accessible.name: "Preview scenario"
                    background: Rectangle {
                        radius: 5
                        color: "#293136"
                        border.color: scenarios.activeFocus ? "#C0DFC8" : "#404A4F"
                    }
                    contentItem: Text {
                        leftPadding: 12
                        rightPadding: 26
                        text: scenarios.displayText
                        color: "#F0EEE7"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                TeraguchiButton {
                    text: "Simulate drop"
                    enabled: previewFlow.phase === "connected"
                    onClicked: previewFlow.interrupted(previewFlow.generation)
                }
                TeraguchiButton {
                    text: "Reset preview"
                    onClicked: {
                        scenario = "ready";
                        scenarios.currentIndex = 0;
                        reset();
                    }
                }
            }
        }
    }
}

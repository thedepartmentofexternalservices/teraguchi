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
    minimumWidth: 780
    minimumHeight: 570
    title: "Teraguchi · Interface preview"
    color: theme.canvas
    TeraguchiTheme {
        id: theme
    }

    WorkstationFlow {
        id: previewFlow
    }
    PreviewPower {
        id: previewPower
        flow: previewFlow
        enabled: preview.scenario.indexOf("power-") === 0
        scenario: preview.scenario
    }
    QtObject {
        id: previewPermissions
        property bool checked: true
        property bool supported: true
        property bool accessibility: preview.scenario === "permission-setup-allowed"
        property bool inputMonitoring: preview.scenario === "permission-setup-allowed"
        readonly property bool ready: accessibility && inputMonitoring
        property string applicationName: "Example Client"
        function refresh() { return ready; }
        function openAccessibilitySettings() { return false; }
        function openInputMonitoringSettings() { return false; }
    }
    QtObject {
        id: previewSetup
        property string state: preview.scenario === "studio-ready" ? "ready" : preview.scenario === "studio-expired" ? "expired" : "needed"
        property string label: "Example Studio"
        property bool ready: state === "ready"
        property bool canImport: true
        property string message: state === "expired" ? "Studio setup has expired. Import a new file from your administrator." : ""
    }
    MacPermissionsDialog { id: permissionsDialog; permissions: previewPermissions }
    QtObject {
        id: previewDiagnostics
        property string preview: ""
        property bool saved: false
        property string message: ""
        function prepare(state) { previewDiagnostics.preview = supportSampleReport; previewDiagnostics.message = ""; }
        function save() { previewDiagnostics.message = "Preview only. Report saving is disabled."; return false; }
        function showFolder() { return false; }
    }
    SupportDialog {
        id: supportDialog
        flow: previewFlow; diagnostics: previewDiagnostics; permissions: previewPermissions
        studioState: "ready"; tailscaleState: "ready"
        onReviewPermissionsRequested: permissionsDialog.open()
    }
    property int pendingCheck: 0
    property int pendingConnection: 0
    property int requestedDisplays: 1
    property string scenario: initialScenario

    function sampleHosts() {
        var hosts = [
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
        if (previewPower.enabled) {
            hosts[0].status = "offline";
            hosts.push({
                id: "studio-e",
                name: "Studio E",
                assigned: true,
                status: "offline"
            });
            hosts.push({
                id: "studio-f",
                name: "Studio F",
                assigned: true,
                status: "ready"
            });
            hosts.push({
                id: "studio-g",
                name: "Studio G",
                assigned: true,
                status: "offline"
            });
        }
        if (previewPower.readyId) {
            hosts.forEach(function (host) {
                if (host.id === previewPower.readyId)
                    host.status = "ready";
            });
        }
        return hosts;
    }
    function reset() {
        previewPower.reset();
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
        function onRefreshRequested(token) {
            if (scenario === "assignment-refreshing")
                return;
            if (scenario === "assignment-failure")
                previewFlow.rejectCatalog(token);
            else
                previewFlow.acceptCatalog(token, sampleHosts(), 60000);
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
        if (scenario.indexOf("permission-setup-") === 0) permissionsDialog.open();
        if (scenario.indexOf("support-") === 0) {
            supportDialog.open();
            supportDialog.topicIndex = scenario === "support-tablet" ? 1 : scenario === "support-access" ? 2 : scenario === "support-report" ? 4 : 0;
            if (scenario === "support-report") supportDialog.prepareReport();
        }
        if (scenario === "studio-needed") {
            previewFlow.selectedId = "";
            previewFlow.setWorkstations([]);
            previewFlow.invalidateCatalog();
        } else if (scenario === "studio-expired") previewFlow.invalidateCatalog();
        if (scenario === "assignment-stale")
            previewFlow.invalidateCatalog();
        else if (scenario === "assignment-refreshing" || scenario === "assignment-failure")
            previewFlow.refresh();
        else if (scenario === "offline")
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
        StudioSetupPanel {
            Layout.fillWidth: true
            Layout.margins: 12
            setup: previewSetup
            visible: preview.scenario.indexOf("studio-") === 0
        }
        MacPermissionsPanel {
            Layout.fillWidth: true
            permissions: previewPermissions
            visible: preview.scenario.indexOf("permission-") === 0
            onReviewRequested: permissionsDialog.open()
        }
        WorkstationPicker {
            Layout.fillWidth: true
            Layout.fillHeight: true
            flow: previewFlow
            studioPower: previewPower
            onHelpRequested: supportDialog.open()
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            color: theme.toolbar
            Rectangle {
                width: parent.width
                height: 1
                color: theme.stroke
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                Label {
                    Layout.fillWidth: true
                    text: "Preview only. Sample workstations; no network or power commands."
                    font.pixelSize: 11
                    color: theme.muted
                    elide: Text.ElideRight
                }
                TeraguchiButton {
                    text: "Scenarios…"
                    onClicked: scenarioDialog.open()
                }
            }
        }
    }
    Dialog {
        id: scenarioDialog
        title: "Preview scenarios"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 440
        modal: true
        standardButtons: Dialog.Close
        ColumnLayout {
            spacing: 12
            Label {
                Layout.fillWidth: true
                text: "These scenarios use simulated workstations. No connections or power commands are sent."
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            ComboBox {
                id: scenarios
                Layout.fillWidth: true
                font.pixelSize: 13
                model: ["Normal connection", "Workstation becomes occupied", "Missing Mac permissions", "Missing selected display", "8-bit capture source", "Connection fails", "Power: outlet off", "Power: verified standby", "Power: unknown", "Power: starting", "Power: unavailable", "Power: no permission", "Power: stale status"]
                property var presetKeys: ["ready", "seat-race", "permissions", "display-mismatch", "source-depth", "connection-failure", "power-off", "power-standby", "power-unknown", "power-starting", "power-unavailable", "power-no-access", "power-stale"]
                currentIndex: Math.max(0, presetKeys.indexOf(preview.scenario))
                onActivated: {
                    scenario = presetKeys[currentIndex];
                    reset();
                    scenarioDialog.close();
                }
                Accessible.name: "Preview scenario"
            }
            RowLayout {
                TeraguchiButton {
                    text: "Simulate interruption"
                    enabled: previewFlow.phase === "connected"
                    onClicked: {
                        previewFlow.interrupted(previewFlow.generation);
                        scenarioDialog.close();
                    }
                }
                TeraguchiButton {
                    text: "Reset preview"
                    onClicked: {
                        scenario = "ready";
                        reset();
                        scenarioDialog.close();
                    }
                }
            }
        }
    }
}

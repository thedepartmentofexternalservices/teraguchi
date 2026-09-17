import QtQuick 2.15
import QtTest 1.3
import "../../../apps/client/app/gui/teraguchi"

TestCase {
    id: tests
    name: "MacPermissions"
    width: 780; height: 560
    visible: true
    when: windowShown
    property var flow
    property var provider
    property var gate
    property var dialog
    Component { id: flowType; WorkstationFlow {} }
    Component { id: gateType; MacPermissionsGate {} }
    Component { id: dialogType; MacPermissionsDialog {} }
    Component {
        id: providerType
        QtObject {
            property bool checked: false
            property bool supported: true
            property bool accessibility: false
            property bool inputMonitoring: false
            readonly property bool ready: checked && supported && accessibility && inputMonitoring
            property string applicationName: "Example Client"
            property int reads: 0
            property int opens: 0
            property var requests: []
            property bool openResult: true
            signal statusChanged()
            function refresh() { checked = true; reads++; statusChanged(); return ready; }
            function openAccessibilitySettings() { opens++; return openResult; }
            function openInputMonitoringSettings() { opens++; return openResult; }
            function requestAccessibility() { requests.push("accessibility"); return openResult; }
            function requestInputMonitoring() { requests.push("input-monitoring"); return openResult; }
        }
    }
    function init() {
        flow = createTemporaryObject(flowType, tests);
        provider = createTemporaryObject(providerType, tests);
        gate = createTemporaryObject(gateType, tests, {flow: flow, provider: provider});
        dialog = createTemporaryObject(dialogType, tests, {permissions: provider});
        flow.setWorkstations([{id: "node-a", name: "Studio A", assigned: true, status: "ready"}]);
        flow.selectWorkstation("node-a"); flow.chooseDisplays(2);
    }
    function test_panelChecksWithoutPromptingOrConnecting() {
        dialog.open();
        tryCompare(dialog, "visible", true);
        verify(provider.reads > 0); compare(provider.opens, 0);
        verify(dialog.height <= tests.height - 32);
        compare(provider.requests.length, 0);
        compare(flow.phase, "idle"); compare(flow.displayCount, 2);
        dialog.reject(); compare(flow.selectedId, "node-a");
    }
    function test_requestsStayExplicitAndNeverAutoConnect() {
        dialog.open(); tryCompare(dialog, "visible", true);
        compare(provider.requests.length, 0);
        dialog.requestAccess("input-monitoring");
        compare(provider.requests, ["input-monitoring"]);
        dialog.requestAccess("accessibility");
        compare(provider.requests, ["input-monitoring", "accessibility"]);
        compare(provider.opens, 0); verify(!provider.ready);
        compare(flow.phase, "idle"); verify(!flow.sessionOpen);
        provider.openResult = false;
        dialog.requestAccess("input-monitoring");
        verify(dialog.settingsError.indexOf("+ button") >= 0);
    }
    function test_settingsRequireExplicitActionAndCannotGrantAccess() {
        dialog.open(); tryCompare(dialog, "visible", true);
        dialog.openSettings("accessibility"); compare(provider.opens, 1);
        verify(!provider.ready); compare(flow.phase, "idle");
        dialog.openSettings("input-monitoring"); compare(provider.opens, 2);
        verify(!provider.ready);
    }
    function test_failedSettingsOpenExplainsManualRoute() {
        provider.openResult = false;
        dialog.openSettings("accessibility");
        verify(dialog.settingsError.indexOf("Privacy & Security") >= 0);
        verify(!provider.ready);
    }
    function test_returnAndRetryNeverAutoConnect() {
        dialog.open(); tryCompare(dialog, "visible", true);
        provider.accessibility = true; provider.inputMonitoring = true;
        gate.refresh(); verify(provider.ready);
        compare(flow.phase, "idle"); verify(!flow.sessionOpen);
        compare(flow.selectedId, "node-a"); compare(flow.displayCount, 2);
    }
    function test_lossCancelsPendingAttemptAndPreservesChoice() {
        provider.accessibility = true; provider.inputMonitoring = true; gate.refresh();
        flow.begin(false); var oldToken = flow.generation;
        provider.inputMonitoring = false; gate.refresh();
        verify(flow.generation > oldToken); compare(flow.phase, "blocked");
        compare(flow.problemTitle, "Mac permissions needed");
        compare(flow.displayCount, 2); compare(flow.selectedId, "node-a");
    }
    function test_lossDisconnectsRetainedSession() {
        provider.accessibility = true; provider.inputMonitoring = true; gate.refresh();
        flow.begin(false); flow.beginNativeSession(flow.generation); flow.acceptNativeConnection(flow.generation);
        verify(flow.sessionOpen);
        provider.accessibility = false; gate.refresh();
        verify(!flow.sessionOpen); compare(flow.phase, "blocked");
    }
}

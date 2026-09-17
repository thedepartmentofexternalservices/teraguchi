import QtQuick 2.15
import QtTest 1.3
import "../../../apps/client/app/gui/teraguchi"

TestCase {
    id: tests
    name: "Support"
    property var flow
    property var provider
    property var permissions
    property var dialog
    Component { id: flowType; WorkstationFlow {} }
    Component { id: dialogType; SupportDialog {} }
    Component {
        id: permissionsType
        QtObject {
            property bool checked: true
            property bool supported: true
            property bool accessibility: true
            property bool inputMonitoring: false
        }
    }
    Component {
        id: providerType
        QtObject {
            property string preview: ""
            property bool saved: false
            property string message: ""
            property int preparations: 0
            property int saves: 0
            property int opens: 0
            property var lastState: null
            function prepare(state) { lastState = state; preparations++; preview = "{}"; saved = false; }
            function save() { saves++; saved = true; return true; }
            function showFolder() { opens++; return true; }
        }
    }
    function init() {
        flow = createTemporaryObject(flowType, tests);
        provider = createTemporaryObject(providerType, tests);
        permissions = createTemporaryObject(permissionsType, tests);
        dialog = createTemporaryObject(dialogType, tests, {flow: flow, diagnostics: provider, permissions: permissions});
        flow.setWorkstations([{id: "private-node", name: "PRIVATE NAME", assigned: true, status: "ready"}]);
        flow.selectWorkstation("private-node"); flow.chooseDisplays(2);
    }
    function test_openCloseHasNoSideEffects() {
        dialog.open(); tryCompare(dialog, "visible", true);
        compare(provider.preparations, 0); compare(provider.saves, 0); compare(provider.opens, 0);
        dialog.reject(); compare(flow.selectedId, "private-node"); compare(flow.displayCount, 2);
        compare(flow.phase, "idle");
    }
    function test_errorChoosesHelpWithoutChangingSelection() {
        flow.block("PRIVATE ERROR", "PRIVATE DETAIL", "displays");
        dialog.open(); tryCompare(dialog, "visible", true);
        compare(dialog.topicIndex, 0); compare(flow.supportCode, "displays");
        verify(dialog.guidance(0).indexOf("exactly two") >= 0);
        verify(dialog.guidance(0).indexOf("choose One display yourself") >= 0);
        compare(flow.displayCount, 2); compare(flow.phase, "blocked");
    }
    function test_tabletHelpDoesNotClaimPermissionProof() {
        flow.block("Failure", "Detail", "permissions");
        dialog.open(); tryCompare(dialog, "visible", true);
        compare(dialog.topicIndex, 1);
        verify(dialog.guidance(1).indexOf("local drawing app") >= 0);
        verify(dialog.guidance(1).indexOf("cannot prove") >= 0);
        compare(provider.preparations, 0);
    }
    function test_reportUsesOnlyExplicitFields() {
        flow.block("PRIVATE ERROR", "PRIVATE DETAIL", "trust");
        dialog.prepareReport();
        compare(provider.preparations, 1);
        compare(provider.lastState.issue, "trust");
        compare(provider.lastState.selected_displays, 2);
        compare(provider.lastState.input_monitoring, false);
        compare(Object.keys(provider.lastState).sort(), ["accessibility", "catalog_fresh", "catalog_refreshing", "input_monitoring", "issue", "permissions_checked", "permissions_supported", "phase", "runtime_pending", "selected_displays", "studio_setup", "tailscale", "workstation"]);
        var text = JSON.stringify(provider.lastState);
        verify(text.indexOf("PRIVATE") < 0); verify(text.indexOf("private-node") < 0);
        verify(text.indexOf("password") < 0); verify(text.indexOf("address") < 0);
        compare(provider.saves, 0); compare(provider.opens, 0);
    }
    function test_saveAndRevealRequireSeparateActions() {
        dialog.open(); tryCompare(dialog, "visible", true); dialog.topicIndex = 4;
        var save = findChild(dialog, "saveSupportReport");
        var show = findChild(dialog, "showSupportFolder");
        verify(!save.enabled); verify(!show.enabled);
        dialog.prepareReport(); verify(save.enabled); verify(!show.enabled);
        save.clicked(); compare(provider.saves, 1); compare(provider.opens, 0);
        verify(!save.enabled); verify(show.enabled);
        show.clicked(); compare(provider.opens, 1);
    }
    function test_failureCodeCannotContainFreeText() {
        flow.block("Title", "Detail", "PRIVATE DETAIL"); compare(flow.supportCode, "unknown");
        dialog.prepareReport(); compare(provider.lastState.issue, "unknown");
        flow.selectWorkstation("private-node"); compare(flow.supportCode, "none");
    }
    function test_permissionLinkDoesNotConnect() {
        dialog.open(); tryCompare(dialog, "visible", true); dialog.topicIndex = 1;
        findChild(dialog, "supportReviewPermissions").clicked();
        tryCompare(dialog, "visible", false);
        compare(flow.phase, "idle"); compare(flow.displayCount, 2);
        compare(provider.saves, 0);
    }
}

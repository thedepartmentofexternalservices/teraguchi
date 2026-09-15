import QtQuick 2.15
import QtTest 1.3
import "../../../apps/client/app/gui/teraguchi"

TestCase {
    id: tests
    name: "Onboarding"
    width: 780; height: 560
    visible: true
    when: windowShown
    property var home
    property var flow
    property var setup
    property var permissions
    property var settings
    Component { id: flowType; WorkstationFlow {} }
    Component { id: setupType; QtObject {
        property bool ready: true
        property bool canImport: true
        property string label: "Example Studio"
        property string state: "ready"
        property string message: ""
    } }
    Component { id: permissionsType; QtObject {
        property bool checked: true
        property bool supported: true
        property bool ready: true
    } }
    Component { id: homeType; WorkstationHome { width: 780; height: 560 } }
    Component { id: settingsType; WorkstationSettings {} }
    SignalSpy { id: settingsOpened; target: tests.home; signalName: "settingsRequested" }
    SignalSpy { id: permissionsOpened; target: tests.home; signalName: "permissionsRequested" }
    SignalSpy { id: imports; target: tests.settings; signalName: "importRequested" }
    function cleanup() {
        if (settings) settings.destroy();
        if (home) home.destroy();
        settings = null;
        home = null;
        // Destroy the views before QtTest clears their service fixtures.
        wait(0);
    }
    function init() {
        flow = createTemporaryObject(flowType, tests);
        setup = createTemporaryObject(setupType, tests);
        permissions = createTemporaryObject(permissionsType, tests);
        home = homeType.createObject(tests, {flow:flow, studioSetup:setup, permissions:permissions, tailscaleState:"ready"});
        settings = settingsType.createObject(tests, {studioSetup:setup, permissions:permissions});
        flow.setWorkstations([{id:"node-a",name:"Studio A",assigned:true,status:"ready"}]);
        flow.selectWorkstation("node-a");
        settingsOpened.clear(); permissionsOpened.clear(); imports.clear();
    }
    function test_readyHomeHasOnlyCompactStudioHeader() {
        compare(home.nextStep, "");
        verify(!findChild(home,"setupNotice").visible);
        compare(findChild(home,"studioHeaderLabel").text,"Example Studio");
        verify(findChild(home,"settingsButton").visible);
        compare(findChild(home,"importStudioSetup"),null);
        compare(findChild(home,"reviewPermissions"),null);
    }
    function test_permissionNoticeDisappearsAfterApproval() {
        permissions.ready=false;
        compare(home.nextStep,"permissions");
        var action=findChild(home,"setupNoticeAction"); waitForRendering(action); mouseClick(action);
        compare(permissionsOpened.count,1); compare(flow.phase,"idle");
        permissions.ready=true;
        verify(!findChild(home,"setupNotice").visible);
    }
    function test_onlyNextRequiredStepIsShown() {
        setup.ready=false; permissions.ready=false; home.tailscaleState="stopped";
        compare(home.nextStep,"studio");
        home.noticeRequested(); compare(settingsOpened.count,1);
        setup.ready=true; compare(home.nextStep,"tailscale");
        home.tailscaleState="ready"; compare(home.nextStep,"permissions");
        home.cleanupPending=true; compare(home.nextStep,"cleanup"); compare(home.noticeAction,"");
    }
    function test_settingsKeepsImportExplicit() {
        settings.open(); tryCompare(settings,"visible",true);
        compare(imports.count,0);
        var button=findChild(settings,"importStudioSetup");
        settings.busy=true; verify(!button.enabled);
        settings.busy=false; waitForRendering(button); mouseClick(button);
        compare(imports.count,1); tryCompare(settings,"visible",false);
        compare(flow.phase,"idle");
    }
    function test_settingsFitsSmallWindow() {
        settings.open(); tryCompare(settings,"visible",true);
        verify(settings.width<=tests.width-32); verify(settings.height<=tests.height-32);
        verify(settings.y>=0); verify(settings.y+settings.height<=tests.height);
    }
}

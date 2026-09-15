import QtQuick 2.15
import QtTest 1.3
import QtQuick.Window 2.15
import "../../../apps/client/app/gui/teraguchi"

TestCase {
    id: tests
    name: "TeraguchiWorkstations"
    when: windowShown
    visible: true
    width: 1120
    height: 690
    property var controller
    property var activeView: null
    Component {
        id: flowComponent
        WorkstationFlow {}
    }
    Component {
        id: pickerComponent
        WorkstationPicker {}
    }
    SignalSpy {
        id: checkSpy
        target: tests.controller
        signalName: "checkRequested"
    }
    SignalSpy {
        id: connectionSpy
        target: tests.controller
        signalName: "connectionRequested"
    }
    SignalSpy {
        id: cancelSpy
        target: tests.controller
        signalName: "cancelRequested"
    }
    SignalSpy {
        id: disconnectSpy
        target: tests.controller
        signalName: "disconnectRequested"
    }

    function hosts() {
        return [
            {
                id: "a",
                name: "Studio A",
                assigned: true,
                status: "ready"
            },
            {
                id: "b",
                name: "Studio B",
                assigned: true,
                status: "offline"
            },
            {
                id: "c",
                name: "Studio C",
                assigned: true,
                status: "occupied"
            },
            {
                id: "d",
                name: "Studio D",
                assigned: true,
                status: "incompatible"
            }
        ];
    }
    function pass(displays) {
        return {
            outcome: "pass",
            authorized: true,
            seatAvailable: true,
            displays: displays || 1,
            nativeSourceDepth: 10,
            profile: "hevc-rext-444-10",
            hardwareDecode: true
        };
    }
    function cleanup() {
        if (activeView)
            activeView.destroy();
        activeView = null;
        wait(0);
    }
    function init() {
        tests.Window.window.width = 1120;
        tests.Window.window.height = 690;
        controller = createTemporaryObject(flowComponent, tests);
        verify(controller !== null);
        controller.setWorkstations(hosts());
        controller.selectWorkstation("a");
        checkSpy.clear();
        connectionSpy.clear();
        cancelSpy.clear();
        disconnectSpy.clear();
    }
    function connect() {
        verify(controller.begin(false));
        var token = controller.generation;
        verify(controller.acceptCheck(token, pass(controller.displayCount)));
        verify(controller.acceptConnection(token, true));
        return token;
    }
    function test_onlyAssignedWorkstations() {
        var snapshot = hosts();
        snapshot.push({
            id: "hidden",
            name: "Not assigned",
            assigned: false,
            status: "ready"
        });
        snapshot.push({
            id: "unknown",
            name: "Assignment unknown",
            status: "ready"
        });
        snapshot.push({
            id: "a",
            name: "Duplicate",
            assigned: true,
            status: "ready"
        });
        snapshot.push({
            id: "toString",
            name: "Inherited property",
            assigned: true,
            status: "ready"
        });
        snapshot.push(null);
        controller.setWorkstations(snapshot);
        compare(controller.workstations.length, 5);
        verify(controller.findWorkstation("toString") !== null);
        verify(!controller.selectWorkstation("hidden"));
    }
    function test_unavailable_data() {
        return [
            {
                tag: "offline",
                id: "b"
            },
            {
                tag: "occupied",
                id: "c"
            },
            {
                tag: "incompatible",
                id: "d"
            }
        ];
    }
    function test_unavailable(data) {
        verify(controller.selectWorkstation(data.id));
        verify(!controller.canConnect);
        verify(!controller.begin(false));
        compare(checkSpy.count, 0);
        compare(connectionSpy.count, 0);
    }
    function test_unknownStatusCannotConnect() {
        controller.setWorkstations([
            {
                id: "a",
                name: "Studio A",
                assigned: true,
                status: "future-state"
            }
        ]);
        compare(controller.selected.status, "unknown");
        verify(!controller.begin(false));
    }
    function test_checkBeforeConnectionAndLockSelection() {
        controller.chooseDisplays(2);
        verify(controller.begin(false));
        compare(controller.phase, "checking");
        compare(connectionSpy.count, 0);
        compare(checkSpy.signalArguments[0][2], 2);
        verify(!controller.chooseDisplays(1));
        verify(!controller.selectWorkstation("b"));
        verify(!controller.begin(false));
        verify(controller.acceptCheck(controller.generation, pass(2)));
        compare(controller.phase, "connecting");
        compare(connectionSpy.count, 1);
    }
    function test_cancelInvalidatesLateCheck() {
        controller.begin(false);
        var token = controller.generation;
        verify(controller.cancel());
        compare(cancelSpy.signalArguments[0][0], token);
        verify(!controller.acceptCheck(token, pass()));
        compare(controller.phase, "idle");
        compare(connectionSpy.count, 0);
    }
    function test_cancelInvalidatesLateConnection() {
        controller.begin(false);
        var token = controller.generation;
        controller.acceptCheck(token, pass());
        controller.cancel();
        verify(!controller.acceptConnection(token, true));
        compare(controller.phase, "idle");
    }
    function test_previousRequestCannotCompleteNewRequest() {
        controller.begin(false);
        var old = controller.generation;
        controller.cancel();
        controller.begin(false);
        verify(!controller.acceptCheck(old, pass()));
        verify(controller.acceptCheck(controller.generation, pass()));
        compare(connectionSpy.count, 1);
    }
    function test_badAttestation_data() {
        return [
            {
                tag: "missing result",
                field: "all",
                value: null
            },
            {
                tag: "unauthorized",
                field: "authorized",
                value: false
            },
            {
                tag: "seat unavailable",
                field: "seatAvailable",
                value: false
            },
            {
                tag: "source8",
                field: "nativeSourceDepth",
                value: 8
            },
            {
                tag: "source string",
                field: "nativeSourceDepth",
                value: "10"
            },
            {
                tag: "software decode",
                field: "hardwareDecode",
                value: false
            },
            {
                tag: "unattested decode",
                field: "hardwareDecode",
                value: undefined
            },
            {
                tag: "wrong profile",
                field: "profile",
                value: "hevc-main10"
            }
        ];
    }
    function test_badAttestation(data) {
        controller.begin(false);
        var result = pass();
        if (data.field === "all")
            result = null;
        else
            result[data.field] = data.value;
        verify(!controller.acceptCheck(controller.generation, result));
        compare(controller.phase, "blocked");
        compare(connectionSpy.count, 0);
    }
    function test_displayMismatchNeverReducesRequest() {
        controller.chooseDisplays(2);
        controller.begin(false);
        verify(!controller.acceptCheck(controller.generation, pass(1)));
        compare(controller.displayCount, 2);
        compare(controller.phase, "blocked");
        compare(connectionSpy.count, 0);
    }
    function test_failedCheck_data() {
        return [
            {
                tag: "occupied",
                outcome: "occupied"
            },
            {
                tag: "permissions",
                outcome: "permissions"
            },
            {
                tag: "offline",
                outcome: "offline"
            },
            {
                tag: "unrecognized",
                outcome: "anything"
            }
        ];
    }
    function test_failedCheck(data) {
        controller.begin(false);
        verify(!controller.acceptCheck(controller.generation, {
            outcome: data.outcome
        }));
        compare(controller.phase, "blocked");
        verify(controller.problem.length > 0);
        compare(connectionSpy.count, 0);
    }
    function test_catalogChangeInvalidatesCheck() {
        controller.begin(false);
        var token = controller.generation;
        var changed = hosts();
        changed[0].status = "occupied";
        controller.setWorkstations(changed);
        compare(cancelSpy.count, 1);
        compare(controller.phase, "blocked");
        verify(!controller.acceptCheck(token, pass()));
        verify(!controller.canConnect);
    }
    function test_removedAssignmentInvalidatesCheck() {
        controller.begin(false);
        var token = controller.generation;
        controller.setWorkstations([]);
        compare(cancelSpy.count, 1);
        compare(controller.selectedId, "");
        verify(!controller.acceptCheck(token, pass()));
    }
    function test_removedAssignmentClosesOnlyOwnConnection() {
        connect();
        controller.setWorkstations([]);
        compare(disconnectSpy.count, 1);
        compare(disconnectSpy.signalArguments[0][0], "a");
        verify(!controller.sessionOpen);
        verify(!controller.begin(true));
    }
    function test_disconnectDoesNotLogOut() {
        connect();
        verify(controller.disconnect());
        compare(disconnectSpy.count, 1);
        compare(disconnectSpy.signalArguments[0][0], "a");
        compare(controller.phase, "idle");
        verify(!controller.disconnect());
        // The presentation API has no logout, power or seat-takeover operation.
        compare(controller.logoutRequested, undefined);
        compare(controller.takeOverRequested, undefined);
    }
    function test_interruptionRequiresExplicitRecheck() {
        controller.chooseDisplays(2);
        var token = connect();
        verify(controller.interrupted(token));
        compare(checkSpy.count, 1);
        verify(!controller.selectWorkstation("b"));
        verify(!controller.chooseDisplays(1));
        verify(controller.begin(true));
        compare(checkSpy.count, 2);
        compare(checkSpy.signalArguments[1][2], 2);
        compare(checkSpy.signalArguments[1][3], true);
        verify(controller.acceptCheck(controller.generation, pass(2)));
        verify(controller.acceptConnection(controller.generation, true));
        compare(controller.phase, "connected");
    }
    function test_cancelReconnectKeepsRecovery() {
        controller.interrupted(connect());
        controller.begin(true);
        controller.cancel();
        compare(controller.phase, "interrupted");
        verify(controller.disconnect());
    }
    function test_failedReconnectKeepsDisconnectAction() {
        controller.interrupted(connect());
        controller.begin(true);
        controller.acceptCheck(controller.generation, {
            outcome: "occupied"
        });
        compare(controller.phase, "blocked");
        verify(controller.sessionOpen);
        verify(!controller.canConnect);
        verify(controller.disconnect());
    }
    function test_assignmentRemovalDuringReconnectClosesRetainedSession() {
        controller.interrupted(connect());
        controller.begin(true);
        var token = controller.generation;
        controller.setWorkstations([]);
        compare(cancelSpy.count, 1);
        compare(disconnectSpy.count, 1);
        verify(!controller.sessionOpen);
        verify(!controller.acceptCheck(token, pass()));
    }
    function test_disconnectDuringReconnectCancelsAttempt() {
        controller.interrupted(connect());
        controller.begin(true);
        var token = controller.generation;
        verify(controller.disconnect());
        compare(cancelSpy.count, 1);
        compare(disconnectSpy.count, 1);
        verify(!controller.acceptCheck(token, pass()));
    }
    function test_malformedCatalogClearsAvailability() {
        controller.setWorkstations(null);
        compare(controller.workstations.length, 0);
        verify(!controller.canConnect);
    }
    function test_reentrantCatalogCancellation_data() {
        return [
            {
                tag: "assignment removal",
                remove: true
            },
            {
                tag: "occupied",
                remove: false
            }
        ];
    }
    function test_reentrantCatalogCancellation(data) {
        controller.begin(false);
        controller.cancelRequested.connect(function (token) {
            controller.acceptCheck(token, pass());
        });
        var changed = hosts();
        changed[0].status = "occupied";
        controller.setWorkstations(data.remove ? [] : changed);
        compare(connectionSpy.count, 0);
        compare(controller.phase, "blocked");
    }
    function test_reentrantDisconnectCancellation() {
        controller.interrupted(connect());
        controller.begin(true);
        controller.cancelRequested.connect(function (token) {
            controller.acceptCheck(token, pass());
        });
        controller.disconnect();
        compare(connectionSpy.count, 1);
        compare(controller.phase, "idle");
    }
    function test_lateInterruptionIgnored() {
        var token = connect();
        controller.disconnect();
        verify(!controller.interrupted(token));
        compare(controller.phase, "idle");
    }
    function test_failedStartKeepsSettings() {
        controller.chooseDisplays(2);
        controller.begin(false);
        controller.acceptCheck(controller.generation, pass(2));
        verify(!controller.acceptConnection(controller.generation, false));
        compare(controller.phase, "blocked");
        compare(controller.displayCount, 2);
    }
    function test_invalidDisplayCount() {
        verify(!controller.chooseDisplays(0));
        verify(!controller.chooseDisplays(3));
        verify(!controller.chooseDisplays("2"));
        compare(controller.displayCount, 1);
    }
    function test_uiButtonsDriveTheFlow() {
        var view = pickerComponent.createObject(tests, {
            flow: controller,
            width: 1120,
            height: 690
        });
        activeView = view;
        verify(view !== null);
        waitForRendering(view);
        var displays = findChild(view, "display-2");
        verify(displays !== null);
        mouseClick(displays, displays.width / 2, displays.height / 2);
        compare(controller.displayCount, 2);
        var connectButton = findChild(view, "connectButton");
        verify(connectButton.enabled);
        mouseClick(connectButton);
        compare(controller.phase, "checking");
        var cancelButton = findChild(view, "cancelButton");
        verify(cancelButton.visible);
        mouseClick(cancelButton);
        compare(controller.phase, "idle");
    }
    function test_uiCompactKeepsPrimaryActionVisible() {
        tests.Window.window.width = 860;
        tests.Window.window.height = 680;
        var view = pickerComponent.createObject(tests, {
            flow: controller,
            width: 860,
            height: 574
        });
        activeView = view;
        controller.chooseDisplays(2);
        controller.begin(false);
        controller.acceptCheck(controller.generation, pass(1));
        waitForRendering(view);
        var button = findChild(view, "connectButton");
        verify(button.visible && button.enabled);
        var corner = button.mapToItem(view, 0, 0);
        verify(corner.y >= 0 && corner.y + button.height <= view.height);
        mouseClick(button);
        compare(controller.phase, "checking");
        compare(controller.displayCount, 2);
    }
    function test_uiCompactCanScrollToDetails() {
        var view = pickerComponent.createObject(tests, {
            flow: controller,
            width: 860,
            height: 574
        });
        activeView = view;
        waitForRendering(view);
        var scroll = findChild(view, "connectionScroll");
        var bar = findChild(view, "connectionScrollBar");
        verify(scroll.contentHeight > scroll.availableHeight);
        verify(bar.height > 100);
        var corner = bar.mapToItem(scroll, 0, 0);
        compare(corner.x + bar.width, scroll.width);
        compare(corner.y, scroll.topPadding);
        // Exercise the scrollbar itself, not a direct contentY assignment.
        bar.forceActiveFocus();
        for (var step = 0; step < 12; ++step)
            keyClick(Qt.Key_Down);
        waitForRendering(view);
        var details = findChild(view, "detailsButton");
        corner = details.mapToItem(scroll, 0, 0);
        verify(corner.y >= 0 && corner.y + details.height <= scroll.height);
        mouseClick(details);
        verify(view.detailsOpen);
    }
    function test_uiDisplayChoiceKeyboardAndSessionLock() {
        var view = pickerComponent.createObject(tests, {
            flow: controller,
            width: 1120,
            height: 690
        });
        activeView = view;
        waitForRendering(view);
        var dual = findChild(view, "display-2");
        dual.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(controller.displayCount, 2);
        verify(dual.selected);
        controller.begin(false);
        verify(!dual.enabled);
        verify(dual.selected);
        verify(!findChild(view, "display-1").selected);
        compare(controller.displayCount, 2);
    }
    function test_uiUnavailableAndKeyboardActivation() {
        var view = pickerComponent.createObject(tests, {
            flow: controller,
            width: 1120,
            height: 690
        });
        activeView = view;
        verify(view !== null);
        waitForRendering(view);
        var offline = findChild(view, "host-b");
        verify(offline !== null);
        offline.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(controller.selectedId, "b");
        verify(!findChild(view, "connectButton").enabled);
        compare(findChild(view, "flowHeading").text, "Studio B");
        verify(findChild(view, "flowDescription").text.indexOf("network") >= 0);
    }
}

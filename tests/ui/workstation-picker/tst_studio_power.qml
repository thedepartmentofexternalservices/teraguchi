import QtQuick 2.15
import QtTest 1.3
import QtQuick.Window 2.15
import "../../../apps/client/app/gui/teraguchi"
import "../../../probes/workstation-picker" as Preview

TestCase {
    id: tests
    name: "TeraguchiStudioPower"
    when: windowShown
    visible: true
    width: 1120
    height: 690
    property var flow
    property var provider
    property var view: null
    Component {
        id: flowComponent
        WorkstationFlow {}
    }
    Component {
        id: pickerComponent
        WorkstationPicker {}
    }
    Component {
        id: previewProviderComponent
        Preview.PreviewPower {}
    }
    Component {
        id: providerComponent
        QtObject {
            property bool enabled: true
            property int revision: 0
            property bool pending: false
            property var currentReport: ({})
            signal startRequested(string workstationId)
            signal refreshRequested(string workstationId)
            function report(id) {
                return currentReport;
            }
            function requestStart(id) {
                if (pending)
                    return;
                pending = true;
                startRequested(id);
            }
            function requestRefresh(id) {
                refreshRequested(id);
            }
        }
    }
    SignalSpy {
        id: starts
        target: tests.provider
        signalName: "startRequested"
    }
    SignalSpy {
        id: refreshes
        target: tests.provider
        signalName: "refreshRequested"
    }
    function init() {
        tests.Window.window.width = 1120;
        tests.Window.window.height = 790;
        flow = createTemporaryObject(flowComponent, tests);
        provider = createTemporaryObject(providerComponent, tests);
        flow.setWorkstations([
            {
                id: "a",
                name: "Studio A",
                assigned: true,
                status: "offline"
            },
            {
                id: "b",
                name: "Studio B",
                assigned: true,
                status: "offline"
            }
        ]);
        flow.selectWorkstation("a");
        provider.currentReport = {
            workstationId: "a",
            state: "off",
            outlet: "off",
            startAllowed: true,
            fresh: true
        };
        starts.clear();
        refreshes.clear();
    }
    function cleanup() {
        if (view)
            view.destroy();
        view = null;
        wait(0);
    }
    function show(adapter, compact) {
        view = pickerComponent.createObject(tests, {
            flow: flow,
            studioPower: adapter,
            width: compact ? 860 : 1120,
            height: compact ? 574 : 690
        });
        verify(view !== null);
        waitForRendering(view);
    }
    function test_optionalDisabledAndAbsent() {
        show(null, false);
        verify(!findChild(view, "studioPowerPanel").visible);
        verify(!findChild(view, "powerOnButton").visible);
        view.studioPower = provider;
        provider.enabled = false;
        verify(!view.powerVisible);
        view.requestPower();
        compare(starts.count, 0);
    }
    function test_startPolicy_data() {
        return [
            {
                tag: "outlet-off",
                state: "off",
                fresh: true,
                allowed: true,
                expected: true
            },
            {
                tag: "verified-standby",
                state: "standby",
                fresh: true,
                allowed: true,
                expected: true
            },
            {
                tag: "unknown-is-not-off",
                state: "unknown",
                fresh: true,
                allowed: true,
                expected: false
            },
            {
                tag: "starting",
                state: "starting",
                fresh: true,
                allowed: true,
                expected: false
            },
            {
                tag: "online",
                state: "online",
                fresh: true,
                allowed: true,
                expected: false
            },
            {
                tag: "service-unavailable",
                state: "unavailable",
                fresh: true,
                allowed: true,
                expected: false
            },
            {
                tag: "stale",
                state: "off",
                fresh: false,
                allowed: true,
                expected: false
            },
            {
                tag: "no-permission",
                state: "off",
                fresh: true,
                allowed: false,
                expected: false
            },
            {
                tag: "truthy-permission",
                state: "off",
                fresh: true,
                allowed: "true",
                expected: false
            },
            {
                tag: "unknown-state",
                state: "asleep",
                fresh: true,
                allowed: true,
                expected: false
            }
        ];
    }
    function test_startPolicy(data) {
        provider.currentReport = {
            workstationId: "a",
            state: data.state,
            outlet: "on",
            fresh: data.fresh,
            startAllowed: data.allowed
        };
        show(provider, false);
        compare(view.canRequestPower, data.expected);
        view.requestPower();
        compare(starts.count, data.expected ? 1 : 0);
        compare(flow.phase, "idle");
    }
    function test_wrongTargetCannotStart() {
        show(provider, false);
        flow.selectWorkstation("b");
        verify(!view.canRequestPower);
        view.requestPower();
        compare(starts.count, 0);
    }
    function test_pendingPreventsDuplicateRequests() {
        show(provider, false);
        var button = findChild(view, "powerOnButton");
        mouseClick(button);
        verify(provider.pending);
        verify(!view.canRequestPower);
        view.requestPower();
        compare(starts.count, 1);
        compare(starts.signalArguments[0][0], "a");
        compare(flow.phase, "idle");
    }
    function test_policyAndFreshnessRecheckedAtClick() {
        show(provider, false);
        verify(view.canRequestPower);
        provider.currentReport = {
            workstationId: "a",
            state: "off",
            fresh: false,
            startAllowed: true
        };
        provider.revision++;
        view.requestPower();
        compare(starts.count, 0);
        compare(findChild(view, "machinePowerLabel").text, "Unknown");
        provider.enabled = false;
        verify(!view.powerVisible);
    }
    function test_availableOrOccupiedHostNeverHasPowerAction_data() {
        return [
            {
                tag: "ready",
                status: "ready"
            },
            {
                tag: "occupied",
                status: "occupied"
            },
            {
                tag: "incompatible",
                status: "incompatible"
            }
        ];
    }
    function test_availableOrOccupiedHostNeverHasPowerAction(data) {
        flow.setWorkstations([
            {
                id: "a",
                name: "Studio A",
                assigned: true,
                status: data.status
            }
        ]);
        show(provider, false);
        verify(!view.powerVisible);
        view.requestPower();
        compare(starts.count, 0);
    }
    function test_removedAssignmentCannotStart() {
        show(provider, false);
        flow.setWorkstations([]);
        view.requestPower();
        compare(starts.count, 0);
        verify(!view.powerVisible);
    }
    function test_compactPowerAndRefreshAreClickable() {
        show(provider, true);
        var button = findChild(view, "powerOnButton");
        var corner = button.mapToItem(view, 0, 0);
        verify(corner.y >= 0 && corner.y + button.height <= view.height);
        mouseClick(findChild(view, "powerRefreshButton"));
        compare(refreshes.count, 1);
        compare(starts.count, 0);
        mouseClick(button);
        compare(starts.count, 1);
    }
    function test_unknownOutletDoesNotBecomePoweredOff() {
        provider.currentReport = {
            workstationId: "a",
            state: "unknown",
            outlet: "on",
            startAllowed: false,
            fresh: true
        };
        show(provider, false);
        compare(findChild(view, "outletPowerLabel").text, "On");
        var machine = findChild(view, "machinePowerLabel");
        var outlet = findChild(view, "outletPowerLabel");
        compare(machine.text, "Unknown");
        verify(machine.mapToItem(view, 0, 0).x - outlet.mapToItem(view, 0, 0).x >= 100);
        verify(!view.canRequestPower);
        // Other studios can supply providers with no outlet telemetry.
        provider.currentReport = {
            workstationId: "a",
            state: "unknown",
            startAllowed: false,
            fresh: true
        };
        provider.revision++;
        verify(view.description().indexOf("outlet") < 0);
        verify(!outlet.visible);
    }
    function test_simulatedStartWaitsForAvailabilityWithoutConnecting() {
        var fake = createTemporaryObject(previewProviderComponent, tests, {
            flow: flow,
            enabled: true,
            scenario: "power-off"
        });
        fake.requestStart("a");
        verify(fake.pending);
        compare(fake.report("a").state, "starting");
        fake.requestStart("b");
        compare(fake.pendingId, "a");
        compare(flow.selected.status, "offline");
        compare(flow.phase, "idle");
        tryCompare(fake, "pending", false, 4500);
        compare(flow.selected.status, "ready");
        compare(flow.phase, "idle");
    }
}

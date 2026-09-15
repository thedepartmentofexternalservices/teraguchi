import QtQuick 2.15

// Pure simulation. No socket, HTTP client, Slack client, settings or PDU code.
QtObject {
    id: power
    required property QtObject flow
    property bool enabled: false
    property string scenario: "power-off"
    property int revision: 0
    property bool pending: false
    property string pendingId: ""
    property string readyId: ""
    function reset() {
        finishTimer.stop();
        pending = false;
        pendingId = "";
        readyId = "";
        revision++;
    }
    function report(id) {
        var state = id === "studio-b" ? "standby" : id === "studio-d" ? "unknown" : "off";
        if (id === "studio-a")
            state = scenario === "power-standby" ? "standby" : scenario === "power-unknown" ? "unknown" : scenario === "power-starting" ? "starting" : scenario === "power-unavailable" ? "unavailable" : "off";
        if (id === pendingId && pending)
            state = "starting";
        if (id === readyId)
            state = "online";
        return {
            workstationId: id,
            state: state,
            outlet: state === "off" ? "off" : state === "unavailable" ? "unknown" : "on",
            startAllowed: scenario !== "power-no-access" && ["off", "standby"].indexOf(state) >= 0,
            fresh: scenario !== "power-stale" && state !== "unavailable"
        };
    }
    function requestStart(id) {
        var info = report(id);
        if (!enabled || pending || !info.fresh || !info.startAllowed || !flow.selected || flow.selectedId !== id || flow.selected.status !== "offline" || !flow.canChoose)
            return;
        // Latch before returning to the view: repeated clicks cannot start twice.
        pendingId = id;
        pending = true;
        revision++;
        finishTimer.restart();
    }
    function requestRefresh(id) {
        // Keep error/unknown fixtures honest. A refresh never fabricates readiness.
        revision++;
    }
    property Timer finishTimer: Timer {
        interval: 3000
        onTriggered: {
            var id = power.pendingId;
            power.readyId = id;
            power.pending = false;
            power.pendingId = "";
            power.revision++;
            // Simulate a separate remote-service observation; power alone is not ready.
            var hosts = power.flow.workstations.map(function (host) {
                return {
                    id: host.id,
                    name: host.name,
                    assigned: host.assigned,
                    status: host.id === id ? "ready" : host.status
                };
            });
            power.flow.setWorkstations(hosts);
        }
    }
}

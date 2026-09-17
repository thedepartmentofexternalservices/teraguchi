import QtQuick 2.15
import QtTest 1.3
import "../../../apps/client/app/gui/teraguchi"

TestCase {
    id: tests
    name: "WorkstationSession"
    property var flow
    property var runtime
    property var nativeSession
    Component { id: flowType; WorkstationFlow {} }
    Component { id: runtimeType; WorkstationSession {} }
    Component {
        id: sessionType
        QtObject {
            property int executions: 0
            property int stops: 0
            property bool finishInsideExec: false
            property bool pendingDuringReady: false
            signal presentationReady()
            signal displayLaunchError(string text)
            signal stageFailed(string stage, int code, string ports)
            signal sessionFinished()
            signal readyForDeletion()
            function requestDisconnect() { stops++; }
            function exec(window) {
                executions++;
                if (finishInsideExec) {
                    sessionFinished(); readyForDeletion();
                    pendingDuringReady = tests.runtime.pending;
                }
            }
        }
    }
    function init() {
        flow = createTemporaryObject(flowType, tests);
        nativeSession = createTemporaryObject(sessionType, tests);
        runtime = createTemporaryObject(runtimeType, tests, {flow: flow});
        flow.setWorkstations([{id: "node-a", name: "Studio A", assigned: true, status: "ready"}]);
        flow.selectWorkstation("node-a");
        flow.begin(false);
    }
    function prepare() { verify(runtime.prepare(flow.generation, nativeSession)); }
    function complete() { nativeSession.sessionFinished(); nativeSession.readyForDeletion(); }
    function test_preparationDoesNotInventConnection() {
        prepare();
        compare(flow.phase, "connecting");
        verify(!flow.sessionOpen);
        tryCompare(nativeSession, "executions", 1);
        nativeSession.presentationReady();
        compare(flow.phase, "connected");
        verify(flow.sessionOpen);
        complete();
        verify(!runtime.pending); verify(!flow.sessionOpen);
    }
    function test_cancelRetiresLatePresentationAndWaitsForCleanup() {
        prepare();
        tryCompare(nativeSession, "executions", 1);
        flow.cancel();
        verify(nativeSession.stops > 0);
        nativeSession.presentationReady();
        verify(!flow.sessionOpen);
        verify(!flow.canConnect);
        nativeSession.sessionFinished();
        verify(runtime.pending);
        nativeSession.readyForDeletion();
        verify(!runtime.pending); verify(flow.canConnect);
    }
    function test_readyInsideExecCannotReleaseLiveObject() {
        nativeSession.finishInsideExec = true;
        prepare();
        tryCompare(nativeSession, "executions", 1);
        verify(nativeSession.pendingDuringReady);
        verify(!runtime.pending);
    }
    function test_shareRemovalDisconnectsAndPreservesReason() {
        prepare(); tryCompare(nativeSession, "executions", 1);
        nativeSession.presentationReady();
        flow.setWorkstations([]);
        verify(nativeSession.stops > 0);
        complete();
        compare(flow.problemTitle, "Workstation no longer assigned");
        verify(!flow.sessionOpen);
    }
    function test_nativeErrorReturnsToBlockedPicker() {
        prepare(); tryCompare(nativeSession, "executions", 1);
        nativeSession.displayLaunchError("Required display unavailable");
        complete();
        compare(flow.phase, "blocked");
        compare(flow.problem, "Required display unavailable");
    }
    function test_refreshFailureKeepsEstablishedSession() {
        prepare(); tryCompare(nativeSession, "executions", 1);
        nativeSession.presentationReady();
        flow.invalidateCatalog();
        compare(nativeSession.stops, 0);
        verify(flow.sessionOpen);
        flow.disconnect();
        verify(nativeSession.stops > 0);
        complete();
    }
    function test_cancelBeforeDeferredExecStillCleansUp() {
        prepare(); flow.cancel(); nativeSession.finishInsideExec = true;
        tryCompare(nativeSession, "executions", 1);
        verify(nativeSession.stops > 0);
        verify(!runtime.pending);
    }
    function test_nativeGuardOwnsFreshnessDuringDisplayTransition() {
        prepare(); tryCompare(nativeSession, "executions", 1);
        flow.invalidateCatalog();
        compare(nativeSession.stops, 0);
        compare(flow.phase, "connecting");
        // The real Session checks the background guard before this signal.
        nativeSession.presentationReady();
        compare(flow.phase, "connected");
        flow.disconnect(); complete();
    }
    function test_noSecondSessionWhileCleaningUp() {
        prepare(); tryCompare(nativeSession, "executions", 1);
        nativeSession.sessionFinished();
        verify(!flow.begin(false));
        verify(!runtime.prepare(flow.generation, nativeSession));
        nativeSession.readyForDeletion();
        verify(flow.begin(false));
    }
}

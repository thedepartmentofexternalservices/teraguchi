import QtQuick 2.15
import QtTest 1.3
import "../../../apps/client/app/gui/teraguchi"

TestCase {
    id: tests
    name: "TailscaleAssignments"
    property var flow
    property var provider
    property var login
    property var computers
    property var adapter
    Component { id: flowType; WorkstationFlow {} }
    Component {
        id: providerType
        QtObject {
            property int requestToken: 0
            property var entries: [{id: "node-a", name: "Studio A", address: "100.100.1.1", identity: "account-a", assigned: true, status: "ready"}]
            signal catalogReady(int token, var entries, int validityMs)
            signal catalogFailed(int token, string reason)
            signal catalogInvalidated()
            signal identityChanged()
            function refresh(token) { requestToken = token; }
            function cancel(token) {}
            function resolve(id) {
                for (var i = 0; i < entries.length; ++i)
                    if (entries[i].id === id) return entries[i];
                return ({});
            }
        }
    }
    Component { id: adapterType; TailscaleAssignments {} }
    Component {
        id: computersType
        QtObject {
            property int requests: 0
            property bool hostVerified: true
            property string trustError: ""
            property bool canPrepare: false
            property int sessions: 0
            property QtObject session: QtObject {}
            signal assignedAuthenticationCompleted(string requestId, string computerId, var error)
            property bool inputAllowed: true
            function assignedInputPermissionsReady() { return inputAllowed; }
            property int cancellations: 0
            function cancelAssignedAuthentication(id) { cancellations++; }
            property string displayError: ""
            property bool displaysCurrent: true
            property string displayToken: ""
            property int displayCancellations: 0
            function prepareAssignedDisplays(displays, window) {
                if (displayError) return {error: displayError};
                displayToken = "selection-a";
                return {token: displayToken};
            }
            function assignedDisplaysCurrent(token) { return displaysCurrent && token !== "" && token === displayToken; }
            function cancelAssignedDisplays(token) { if (token === displayToken) { displayToken = ""; displayCancellations++; } }
            function prepareAssignedTarget(provider, nodeId) { return canPrepare; }
            function assignedLoginTarget(provider, nodeId) {
                if (trustError) return {trustError: trustError};
                if (!hostVerified) return ({});
                var peer = provider.resolve(nodeId);
                return {id: peer.id, address: peer.address, identity: peer.identity, computerId: "bookmark-a", hostId: "host-a", status: "ready"};
            }
            function authenticateAssignedTarget(provider, target, username, password) {
                requests++;
                return "request-" + requests;
            }
            function createAssignedSession(provider, target) { sessions++; return session; }
        }
    }
    Component { id: dialogType; AssignedLoginDialog {} }
    Component { id: loginType; TailscaleLogin {} }
    SignalSpy { id: credentialsSpy; target: tests.login; signalName: "credentialsRequested" }
    SignalSpy { id: sessionSpy; target: tests.login; signalName: "sessionPrepared" }
    SignalSpy { id: loginSpy; target: tests.adapter; signalName: "loginRequested" }
    SignalSpy { id: disconnectSpy; target: tests.flow; signalName: "disconnectRequested" }
    function init() {
        flow = createTemporaryObject(flowType, tests);
        provider = createTemporaryObject(providerType, tests);
        adapter = createTemporaryObject(adapterType, tests, {flow: flow, provider: provider});
        computers = createTemporaryObject(computersType, tests);
        login = createTemporaryObject(loginType, tests, {assignments: adapter, computers: computers});
        loginSpy.clear(); disconnectSpy.clear(); credentialsSpy.clear(); sessionSpy.clear();
        flow.refresh();
        provider.catalogReady(provider.requestToken, provider.entries, 30000);
        flow.selectWorkstation("node-a");
    }
    function test_missingHostTrustBlocksCredentialsAndReleasesDisplays() {
        computers.trustError = "Import current studio setup";
        flow.begin(false);
        compare(credentialsSpy.count, 0);
        compare(computers.requests, 0);
        compare(computers.displayToken, "");
        compare(login.target, null);
        compare(flow.problemTitle, "Workstation verification needed");
    }
    function test_credentialDialogClearsPasswordAndCancelsNativeRequest() {
        var dialog = createTemporaryObject(dialogType, tests, {flow: flow, login: login});
        flow.begin(false);
        tryCompare(dialog, "visible", true);
        var username = findChild(dialog, "assignedUsername");
        var password = findChild(dialog, "assignedPassword");
        username.text = "example-artist"; password.text = "synthetic-test-value";
        dialog.submit();
        compare(password.text, "");
        compare(computers.requests, 1);
        dialog.reject();
        compare(computers.cancellations, 1);
        compare(login.requestId, "");
        compare(username.text, "");
    }
    function test_twoDisplaysAreExplicitlyRejectedBeforeLogin() {
        computers.displayError = "Two displays unavailable";
        flow.chooseDisplays(2);
        flow.begin(false);
        compare(credentialsSpy.count, 0);
        compare(computers.requests, 0);
        compare(flow.displayCount, 2);
        compare(flow.problemTitle, "Selected displays unavailable");
    }
    function test_displayChangeBeforeCredentialsBlocksLogin() {
        computers.displaysCurrent = false;
        flow.begin(false);
        compare(credentialsSpy.count, 0); compare(computers.requests, 0);
        compare(flow.problemTitle, "Selected displays unavailable");
        compare(computers.displayCancellations, 1);
    }
    function test_displayChangeBeforeSubmitDoesNotSendPassword() {
        flow.begin(false);
        computers.displaysCurrent = false;
        verify(!login.submit(flow.generation, "example-artist", "synthetic-value"));
        compare(computers.requests, 0); compare(computers.sessions, 0);
        compare(flow.problemTitle, "Selected displays unavailable");
    }
    function test_displayChangeDuringPamDiscardsResult() {
        flow.begin(false);
        verify(login.submit(flow.generation, "example-artist", "synthetic-value"));
        const request = login.requestId;
        computers.displaysCurrent = false;
        computers.assignedAuthenticationCompleted(request, "bookmark-a", undefined);
        compare(computers.sessions, 0); compare(computers.cancellations, 1);
        compare(flow.problemTitle, "Selected displays unavailable");
    }
    function test_twoDisplaysRetainSelectionThroughLogin() {
        flow.chooseDisplays(2); flow.begin(false);
        compare(credentialsSpy.count, 1); compare(login.target.displayToken, "selection-a");
        verify(login.submit(flow.generation, "example-artist", "synthetic-value"));
        computers.assignedAuthenticationCompleted(login.requestId, "bookmark-a", undefined);
        compare(sessionSpy.count, 1); compare(computers.sessions, 1);
        compare(flow.attemptDisplays, 2); compare(computers.displayCancellations, 1);
    }
    function test_missingPermissionsBlocksBeforeHostPreparation() {
        computers.inputAllowed = false;
        flow.begin(false);
        compare(credentialsSpy.count, 0); compare(computers.requests, 0);
        compare(login.preparingNodeId, ""); compare(flow.problemTitle, "Mac permissions needed");
    }
    function test_permissionLossBeforeSubmitDoesNotSendCredentials() {
        flow.begin(false); computers.inputAllowed = false;
        verify(!login.submit(flow.generation, "example-artist", "synthetic-value"));
        compare(computers.requests, 0); compare(login.token, -1);
        compare(flow.problemTitle, "Mac permissions needed");
    }
    function test_permissionLossDuringPamDiscardsResult() {
        flow.begin(false); verify(login.submit(flow.generation, "example-artist", "synthetic-value"));
        var requestId = login.requestId;
        computers.inputAllowed = false;
        computers.assignedAuthenticationCompleted(requestId, "bookmark-a", undefined);
        compare(computers.sessions, 0); compare(computers.cancellations, 1);
        compare(flow.problemTitle, "Mac permissions needed");
    }
    function test_dispatchesCurrentTargetWithoutAttestations() {
        flow.begin(false);
        compare(loginSpy.count, 1);
        compare(loginSpy.signalArguments[0][1], "node-a");
        compare(loginSpy.signalArguments[0][2], "100.100.1.1");
        compare(flow.phase, "checking");
        verify(!flow.sessionOpen);
    }
    function test_addressOrAccountChangeInvalidatesLogin() {
        flow.begin(false);
        var token = flow.generation;
        verify(adapter.targetStillCurrent(token, "node-a", "100.100.1.1", "account-a"));
        provider.entries = [{id: "node-a", address: "100.100.1.2", identity: "account-a", status: "ready"}];
        verify(!adapter.targetStillCurrent(token, "node-a", "100.100.1.1", "account-a"));
        provider.entries = [{id: "node-a", address: "100.100.1.1", identity: "account-b", status: "ready"}];
        verify(!adapter.targetStillCurrent(token, "node-a", "100.100.1.1", "account-a"));
    }
    function test_removedPeerDoesNotRequestLogin() {
        provider.entries = [];
        flow.begin(false);
        compare(loginSpy.count, 0);
        verify(!flow.catalogFresh);
    }
    function test_cancelledLoginCannotResolve() {
        flow.begin(false);
        var token = flow.generation;
        flow.cancel();
        compare(adapter.resolveLoginTarget(token, "node-a"), null);
    }
    function test_identityChangeClearsOldAccountAndSession() {
        flow.begin(false);
        flow.acceptCheck(flow.generation, {outcome: "pass", authorized: true, seatAvailable: true, displays: 1, nativeSourceDepth: 10, profile: "hevc-rext-444-10", hardwareDecode: true});
        flow.acceptConnection(flow.generation, true);
        provider.identityChanged();
        compare(disconnectSpy.count, 1);
        compare(flow.workstations.length, 0);
        verify(!flow.sessionOpen);
        verify(!flow.catalogFresh);
    }
    function test_failureKeepsListButBlocksLogin() {
        flow.refresh();
        provider.catalogFailed(provider.requestToken, "unavailable");
        compare(flow.workstations.length, 1);
        verify(!flow.begin(false));
        compare(loginSpy.count, 0);
    }
    function test_pamReplyPreparesSessionWithoutInventingVideoPass() {
        flow.begin(false);
        compare(credentialsSpy.count, 1);
        verify(login.submit(flow.generation, "example-artist", "fixture-only"));
        computers.assignedAuthenticationCompleted("request-1", "bookmark-a", undefined);
        compare(sessionSpy.count, 1);
        compare(computers.sessions, 1);
        compare(flow.phase, "checking");
        verify(!flow.sessionOpen);
    }
    function test_oldPamReplyCannotCompleteNewLogin() {
        flow.begin(false);
        login.submit(flow.generation, "example-artist", "fixture-only");
        flow.cancel();
        flow.begin(false);
        login.submit(flow.generation, "example-artist", "fixture-only");
        computers.assignedAuthenticationCompleted("request-1", "bookmark-a", undefined);
        compare(sessionSpy.count, 0);
        computers.assignedAuthenticationCompleted("request-2", "bookmark-a", undefined);
        compare(sessionSpy.count, 1);
    }
    function test_wrongWorkstationPamReplyCannotComplete() {
        flow.begin(false);
        login.submit(flow.generation, "example-artist", "fixture-only");
        computers.assignedAuthenticationCompleted("request-1", "bookmark-b", undefined);
        compare(sessionSpy.count, 0);
    }
    function test_assignmentChangeDuringPamDoesNotStartSession() {
        flow.begin(false);
        login.submit(flow.generation, "example-artist", "fixture-only");
        provider.entries = [];
        computers.assignedAuthenticationCompleted("request-1", "bookmark-a", undefined);
        compare(sessionSpy.count, 0);
        compare(computers.sessions, 0);
    }
    function test_unverifiedHostNeverAsksForCredentials() {
        computers.hostVerified = false;
        flow.begin(false);
        compare(credentialsSpy.count, 0);
        compare(flow.phase, "blocked");
    }
    function test_deniedLoginDoesNotStartSession() {
        flow.begin(false);
        login.submit(flow.generation, "example-artist", "fixture-only");
        computers.assignedAuthenticationCompleted("request-1", "bookmark-a", "denied");
        compare(sessionSpy.count, 0);
        compare(flow.phase, "blocked");
    }

    function test_discoveryWaitsForVerifiedHost() {
        computers.hostVerified = false;
        computers.canPrepare = true;
        flow.begin(false);
        compare(credentialsSpy.count, 0);
        computers.hostVerified = true;
        tryCompare(credentialsSpy, "count", 1);
        compare(flow.phase, "checking");
    }
    function test_cancelStopsHostPreparation() {
        computers.hostVerified = false;
        computers.canPrepare = true;
        flow.begin(false);
        flow.cancel();
        computers.hostVerified = true;
        wait(300);
        compare(credentialsSpy.count, 0);
        verify(!login.preparationTimer.running);
    }

}

import QtQuick 2.15
import QtTest 1.3
import "../../../apps/client/app/gui/teraguchi"
TestCase {
    id: tests
    name: "StudioSetupPanel"
    width: 780; height: 180
    visible: true
    when: windowShown
    property var setup
    property var panel
    Component { id: setupType; QtObject {
        property string state: "needed"
        property string label: "Example Studio"
        property string message: ""
        property bool ready: false
        property bool canImport: true
    } }
    Component { id: panelType; StudioSetupPanel { width: 740; height: 140 } }
    SignalSpy { id: imports; target: tests.panel; signalName: "importRequested" }
    function init() {
        setup = createTemporaryObject(setupType, tests);
        panel = createTemporaryObject(panelType, tests, {setup:setup});
        imports.clear();
    }
    function test_importIsExplicit() {
        compare(imports.count,0);
        var button=findChild(panel,"importStudioSetup");
        waitForRendering(button);
        mouseClick(button);
        compare(imports.count,1);
    }
    function test_noKeyAndBusyDisableImport() {
        var button=findChild(panel,"importStudioSetup");
        setup.canImport=false; verify(!button.enabled);
        setup.canImport=true; panel.busy=true; verify(!button.enabled);
        panel.busy=false; verify(button.enabled);
    }
    function test_verifiedStudioAndFailureAreVisible() {
        setup.ready=true; setup.state="ready";
        compare(findChild(panel,"studioSetupTitle").text,"Example Studio");
        setup.message="The studio signature could not be verified.";
        compare(findChild(panel,"studioSetupMessage").text,setup.message);
        setup.ready=false; setup.state="expired";
        compare(findChild(panel,"studioSetupTitle").text,"Studio setup needed");
    }
    function test_developmentIsLabelled() {
        setup.ready=true; setup.state="development";
        verify(findChild(panel,"studioSetupMessage").text.indexOf("development")>=0);
    }
    function test_compactFits() {
        panel.width=700; setup.message="Studio setup has expired. Import a new file from your administrator.";
        var button=findChild(panel,"importStudioSetup");
        var mapped=button.mapToItem(panel,0,0);
        verify(mapped.x+button.width<=panel.width);
        verify(mapped.y+button.height<=panel.height);
    }
}

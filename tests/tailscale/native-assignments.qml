import QtQuick
import "../../apps/client/app/gui/teraguchi"

QtObject {
    id: bridge
    property WorkstationFlow flow: WorkstationFlow { objectName: "flow" }
    property TailscaleAssignments assignments: TailscaleAssignments {
        flow: bridge.flow
        provider: nativeProvider
    }
    readonly property int workstationCount: flow.workstations.length
}

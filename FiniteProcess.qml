import QtQuick
import Quickshell.Io

// Collectors only see the supervisor's bounded, completed output. The Python
// supervisor owns cleanup of the entire job session, including shell helpers.
Process {
  id: root
  property var jobCommand: []
  property real timeoutSeconds: 4
  command: ["python3", decodeURIComponent(Qt.resolvedUrl("bounded_process.py").toString().replace(/^file:\/\//, "")),
    String(timeoutSeconds)].concat(jobCommand)
  property Timer watchdog: Timer {
    interval: (root.timeoutSeconds + 2) * 1000
    running: root.running
    onTriggered: root.signal(15)
  }
}

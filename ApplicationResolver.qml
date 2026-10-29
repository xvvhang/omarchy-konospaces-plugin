import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "ApplicationIdentity.js" as Identity

Item {
  id: root
  visible: false

  readonly property var entries: DesktopEntries.applications.values.map(function(entry) {
    return {
      id: entry.id, name: entry.name, icon: entry.icon,
      startupClass: entry.startupClass, command: Array.from(entry.command),
      execString: entry.execString, workingDirectory: entry.workingDirectory || ""
    }
  })
  readonly property var windows: Hyprland.toplevels.values.map(function(window) {
    return root.identity(window)
  })
  // Binding dependencies include model membership, app ID, and lastIpcObject.
  // Query again when PIDs become available, not a fixed delay after openwindow.
  readonly property string processRequest: JSON.stringify({
    entries: entries.map(function(entry) {
      return {id: entry.id, executable: entry.command[0] || "", workingDirectory: entry.workingDirectory}
    }),
    pids: windows.map(function(window) { return window.pid }).filter(function(pid) { return pid > 0 })
  })
  property var processApplications: ({})
  property string processError: ""
  property string defaultTerminalId: ""
  property string terminalError: ""
  property bool queryPending: false

  function identity(window) {
    var ipc = window.lastIpcObject || {}
    return {
      address: window.address, pid: ipc.pid || 0,
      appId: window.wayland ? window.wayland.appId : "",
      className: ipc.class || "", initialClass: ipc.initialClass || ""
    }
  }
  function resolveWindow(window) {
    return Identity.resolve(identity(window), entries, processApplications, defaultTerminalId)
  }
  function diagnostics() {
    return {
      processError: processError,
      terminalError: terminalError,
      defaultTerminalId: defaultTerminalId,
      queryRunning: processQuery.running,
      windows: windows.map(function(window) {
        return {window: window, application: Identity.resolve(window, root.entries, root.processApplications, root.defaultTerminalId)}
      })
    }
  }
  function queryProcesses() {
    if (processQuery.running) {
      queryPending = true
      return
    }
    queryPending = false
    processError = ""
    processQuery.request = processRequest
    processQuery.command = ["python3", Qt.resolvedUrl("process-apps.py").toString().replace(/^file:\/\//, ""), processQuery.request]
    processQuery.running = true
  }
  Component.onCompleted: Qt.callLater(queryProcesses)
  onProcessRequestChanged: Qt.callLater(queryProcesses)

  Process {
    command: ["xdg-terminal-exec", "--print-id"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.defaultTerminalId = text.trim().split(":")[0]
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) {
        root.terminalError = text.trim()
        console.warn("konospaces", "Default terminal discovery:", root.terminalError)
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        root.defaultTerminalId = ""
        root.terminalError = "Default terminal discovery exited with code " + code
        console.warn("konospaces", root.terminalError)
      }
    }
  }

  Process {
    id: processQuery
    property string request: ""
    stdout: StdioCollector {
      onStreamFinished: {
        // Never publish results for a superseded window/desktop-entry snapshot.
        if (processQuery.request !== root.processRequest) return
        try {
          root.processApplications = JSON.parse(text)
        } catch (error) {
          root.processApplications = ({})
          root.processError = "Invalid process lookup output: " + error
          console.warn("konospaces", root.processError)
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) {
        root.processError = text.trim()
        console.warn("konospaces", root.processError)
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        root.processApplications = ({})
        root.processError = "Process lookup exited with code " + code + ": " + root.processError
        console.warn("konospaces", root.processError)
      }
      if (root.queryPending) Qt.callLater(root.queryProcesses)
    }
  }
}

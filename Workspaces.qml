pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "konochi.konospaces"

  readonly property real iconSize: Style.space(16)
  readonly property var applicationEntries: DesktopEntries.applications.values
  readonly property bool textMode: setting("displayMode", "icons") === "text"
  readonly property real windowNameMaxWidth: Style.space(Math.max(40, Number(setting("windowNameMaxWidth", 100)) || 100))
  property var specialWorkspaces: ({})
  property var processApplications: ({})
  readonly property int focusedWorkspaceId: {
    var monitor = Hyprland.focusedMonitor
    var special = monitor ? specialWorkspaces[monitor.name] : 0
    return special || (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0)
  }

  Component.onCompleted: {
    monitorQuery.running = true
    processRefresh.restart()
  }
  onApplicationEntriesChanged: processRefresh.restart()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "openwindow" || event.name === "closewindow") processRefresh.restart()
      if (event.name.indexOf("activespecial") === 0 || event.name.indexOf("focusedmon") === 0 || event.name.indexOf("monitor") === 0)
        monitorRefresh.restart()
    }
  }

  Timer {
    id: processRefresh
    interval: 150
    onTriggered: {
      if (processQuery.running) {
        restart()
        return
      }
      var entries = root.applicationEntries.map(function(entry) {
        return { id: entry.id, executable: entry.command[0] || "", workingDirectory: entry.workingDirectory || "" }
      })
      var pids = []
      var workspaces = Hyprland.workspaces.values
      for (var i = 0; i < workspaces.length; i++) {
        var windows = workspaces[i].toplevels.values
        for (var j = 0; j < windows.length; j++) {
          var ipc = windows[j].lastIpcObject || {}
          if (ipc.pid > 0 && pids.indexOf(ipc.pid) === -1) pids.push(ipc.pid)
        }
      }
      processQuery.command = ["python3", Qt.resolvedUrl("process-apps.py").toString().replace(/^file:\/\//, ""), JSON.stringify({ entries: entries, pids: pids })]
      processQuery.running = true
    }
  }

  Process {
    id: processQuery
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.processApplications = JSON.parse(text)
        } catch (error) { console.warn("workspaces: could not resolve process applications", error) }
      }
    }
  }

  Timer {
    id: monitorRefresh
    interval: 30
    onTriggered: {
      if (monitorQuery.running) restart()
      else monitorQuery.running = true
    }
  }

  Process {
    id: monitorQuery
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var monitors = JSON.parse(text)
          var special = ({})
          for (var i = 0; i < monitors.length; i++)
            special[monitors[i].name] = monitors[i].specialWorkspace ? monitors[i].specialWorkspace.id : 0
          root.specialWorkspaces = special
        } catch (error) { console.warn("workspaces: could not read special workspaces", error) }
      }
    }
  }

  function webAppEntry(candidates, entries) {
    for (var i = 0; i < entries.length; i++) {
      var command = entries[i].execString || ""
      var match = command.match(/https?:\/\/[^\s"']+/)
      if (!match) continue
      var address = match[0].replace(/^https?:\/\//, "")
      // Match URL-derived window IDs without depending on a browser or launcher name.
      if (address.indexOf("/") === -1) address += "/"
      var key = address.replace("/", "_/").replace(/\//g, "_")
      for (var j = 0; j < candidates.length; j++) {
        var candidate = String(candidates[j] || "")
        if (candidate === key || candidate.indexOf("-" + key + "-") !== -1)
          return entries[i]
      }
    }
    return null
  }

  function toggleDisplayMode() {
    var entry = { id: moduleName }
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    entry.displayMode = textMode ? "icons" : "text"
    settings = entry
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, entry)
  }

  function windowEntry(toplevel) {
    var ipc = toplevel.lastIpcObject || {}
    var appId = toplevel.wayland ? toplevel.wayland.appId : ""
    var entry = webAppEntry([appId, ipc.class, ipc.initialClass], root.applicationEntries)
    if (entry) return entry
    var candidates = [appId, ipc.class, ipc.initialClass]
    for (var i = 0; i < candidates.length; i++) {
      if (!candidates[i]) continue
      entry = DesktopEntries.heuristicLookup(candidates[i])
      if (entry) return entry
    }
    var processEntryId = root.processApplications[ipc.pid]
    if (processEntryId) {
      for (var k = 0; k < root.applicationEntries.length; k++) {
        if (root.applicationEntries[k].id === processEntryId) return root.applicationEntries[k]
      }
    }
    if (!appId && !ipc.class && !ipc.initialClass) {
      for (var j = 0; j < root.applicationEntries.length; j++) {
        entry = root.applicationEntries[j]
        if (entry.name === toplevel.title || entry.name === ipc.initialTitle) return entry
      }
    }
    return null
  }

  function windowName(toplevel) {
    var entry = windowEntry(toplevel)
    if (entry && entry.name) return entry.name
    var ipc = toplevel.lastIpcObject || {}
    var appId = toplevel.wayland ? toplevel.wayland.appId : ""
    return ipc.initialClass || ipc.class || appId || "Window"
  }

  function windowIcon(toplevel) {
    var ipc = toplevel.lastIpcObject || {}
    var appId = toplevel.wayland ? toplevel.wayland.appId : ""
    var entry = windowEntry(toplevel)
    var icon = entry ? entry.icon : (appId || ipc.class || "")
    if (icon.indexOf("/") === 0) return Util.fileUrl(icon)
    var source = icon ? Quickshell.iconPath(icon, true) : ""
    return source || Quickshell.iconPath("application-x-executable")
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (values[i].toplevels.values.length > 0 || id === root.focusedWorkspaceId) ids.push(id)
    }

    ids.sort(function(left, right) {
      if ((left < 0) !== (right < 0)) return left < 0 ? 1 : -1
      return left - right
    })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    var workspace = workspaceById(id)
    if (!workspace) return
    var name = workspace.name || String(id)
    var command = name.indexOf("special:") === 0
      ? "hl.dsp.workspace.toggle_special(" + JSON.stringify(name.slice(8)) + ")"
      : "hl.dsp.focus({ workspace = " + JSON.stringify(name) + " })"
    root.bar.run("hyprctl dispatch " + Util.shellQuote(command))
  }

  readonly property real trailingGap: root.vertical || workspaceIds().length === 0 ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: workspaceButton
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property var windows: workspace ? workspace.toplevels.values : []
        readonly property bool occupied: windows.length > 0
        readonly property bool focused: root.focusedWorkspaceId === modelData

        bar: root.bar
        text: workspace && workspace.name === "special:scratchpad" ? "S" : (workspace && workspace.name.indexOf("special:") === 0 ? workspace.name.slice(8) : (workspace ? workspace.name : String(modelData)))
        labelVisible: false
        tooltipText: "Workspace " + workspaceButton.text + (workspaceButton.occupied ? "\n" + workspaceButton.windows.map(function(window) { return window.title }).join("\n") : "")
        opacity: 1
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Math.max(Style.space(20), content.implicitWidth + workspaceButton.scaledHorizontalMargin * 2)
        fixedHeight: root.vertical ? Math.max(root.barSize, content.implicitHeight + workspaceButton.scaledVerticalPadding * 2) : root.barSize
        onPressed: function(button) {
          if (button === Qt.RightButton) root.toggleDisplayMode()
          else if (button === Qt.LeftButton) root.focusWorkspace(modelData)
        }

        GridLayout {
          id: content
          anchors.centerIn: parent
          columns: root.vertical ? 1 : 2
          columnSpacing: Style.space(5)
          rowSpacing: Style.space(4)

          Text {
            text: workspaceButton.text
            color: workspaceButton.foreground
            opacity: workspaceButton.focused ? 1 : 0.5
            font.family: workspaceButton.fontFamily
            font.pixelSize: workspaceButton.fontSize
            font.bold: workspaceButton.focused
            renderType: Text.NativeRendering
            Layout.alignment: Qt.AlignCenter
          }

          GridLayout {
            visible: workspaceButton.occupied
            columns: root.vertical ? 1 : Math.max(1, workspaceButton.windows.length)
            columnSpacing: Style.space(root.textMode ? 8 : 3)
            rowSpacing: Style.space(3)
            Layout.alignment: Qt.AlignCenter

            Repeater {
              model: workspaceButton.windows
              Item {
                id: windowItem
                required property var modelData
                readonly property real maxTextWidth: root.vertical
                  ? Math.max(1, root.barSize - workspaceButton.scaledHorizontalMargin * 2)
                  : root.windowNameMaxWidth
                implicitWidth: root.textMode ? Math.min(windowLabel.implicitWidth, maxTextWidth) : root.iconSize
                implicitHeight: root.textMode ? windowLabel.implicitHeight : root.iconSize
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                Layout.alignment: Qt.AlignCenter
                opacity: modelData.activated ? 1 : 0.5

                Text {
                  id: windowLabel
                  anchors.fill: parent
                  visible: root.textMode
                  text: root.windowName(windowItem.modelData)
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  maximumLineCount: 1
                  verticalAlignment: Text.AlignVCenter
                  color: workspaceButton.foreground
                  font.family: workspaceButton.fontFamily
                  font.pixelSize: workspaceButton.fontSize
                  renderType: Text.NativeRendering
                }

                Image {
                  anchors.fill: parent
                  visible: !root.textMode
                  source: root.textMode ? "" : root.windowIcon(windowItem.modelData)
                  sourceSize.width: root.iconSize
                  sourceSize.height: root.iconSize
                  fillMode: Image.PreserveAspectFit
                  layer.enabled: !root.textMode && !windowItem.modelData.activated
                  layer.effect: MultiEffect {
                    saturation: -1
                    colorization: 1
                    colorizationColor: workspaceButton.foreground
                    contrast: -0.3
                    brightness: 0.1
                    autoPaddingEnabled: false
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

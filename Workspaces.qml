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
  moduleName: "xvvhang.workspaces"

  readonly property real iconSize: Style.space(16)
  property var specialWorkspaces: ({})
  readonly property int focusedWorkspaceId: {
    var monitor = Hyprland.focusedMonitor
    var special = monitor ? specialWorkspaces[monitor.name] : 0
    return special || (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0)
  }

  Component.onCompleted: monitorQuery.running = true

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name.indexOf("activespecial") === 0 || event.name.indexOf("focusedmon") === 0 || event.name.indexOf("monitor") === 0)
        monitorRefresh.restart()
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
      if (command.indexOf("omarchy-launch-webapp") === -1 && command.indexOf("--app=") === -1) continue
      var match = command.match(/https?:\/\/[^\s"']+/)
      if (!match) continue
      var address = match[0].replace(/^https?:\/\//, "")
      // Chromium uses host + '_' + path, then replaces '/' with '_'.
      if (address.indexOf("/") === -1) address += "/"
      var key = address.replace("/", "_/").replace(/\//g, "_")
      for (var j = 0; j < candidates.length; j++) {
        var candidate = String(candidates[j] || "")
        if (candidate.indexOf("chrome-" + key + "-") === 0 || candidate.indexOf("chromium-" + key + "-") === 0)
          return entries[i]
      }
    }
    return null
  }

  function windowIcon(toplevel) {
    var ipc = toplevel.lastIpcObject || {}
    var appId = toplevel.wayland ? toplevel.wayland.appId : ""
    var candidates = [appId, ipc.class, ipc.initialClass]
    if (!appId && !ipc.class && (toplevel.title === "飞书" || ipc.initialTitle === "飞书"))
      candidates.push("feishu")
    var entries = DesktopEntries.applications.values
    var entry = webAppEntry(candidates, entries)
    for (var i = 0; i < candidates.length && !entry; i++) {
      if (candidates[i]) entry = DesktopEntries.heuristicLookup(candidates[i])
    }
    // Some clients (e.g. Feishu) do not advertise an app ID or class.
    if (!entry && !appId && !ipc.class) {
      for (var j = 0; j < entries.length; j++) {
        if (entries[j].name === toplevel.title || entries[j].name === ipc.initialTitle) {
          entry = entries[j]
          break
        }
      }
    }
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
        tooltipText: "Workspace " + text + (occupied ? "\n" + windows.map(function(window) { return window.title }).join("\n") : "")
        opacity: 1
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Math.max(Style.space(20), content.implicitWidth + scaledHorizontalMargin * 2)
        fixedHeight: root.vertical ? Math.max(root.barSize, content.implicitHeight + scaledVerticalPadding * 2) : root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

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

          Item {
            visible: workspaceButton.occupied
            readonly property real spacing: Style.space(3)
            implicitWidth: root.vertical ? root.iconSize : workspaceButton.windows.length * (root.iconSize + spacing) - spacing
            implicitHeight: root.vertical ? workspaceButton.windows.length * (root.iconSize + spacing) - spacing : root.iconSize
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.alignment: Qt.AlignCenter

            Repeater {
              model: workspaceButton.windows
              Image {
                required property var modelData
                required property int index
                x: root.vertical ? 0 : index * (root.iconSize + Style.space(3))
                y: root.vertical ? index * (root.iconSize + Style.space(3)) : 0
                width: root.iconSize
                height: root.iconSize
                source: root.windowIcon(modelData)
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                opacity: modelData.activated ? 1 : 0.5
                layer.enabled: !modelData.activated
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

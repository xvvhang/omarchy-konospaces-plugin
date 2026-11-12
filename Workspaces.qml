pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "WorkspaceModel.js" as Policy

BarWidget {
  id: root
  moduleName: "konochi.konospaces"
  readonly property real iconSize: Style.space(16)
  readonly property string displayMode: setting("displayMode", "icons")
  readonly property bool textMode: displayMode === "text"
  readonly property bool originalIconMode: displayMode === "original"
  readonly property bool noIconsMode: displayMode === "none"
  readonly property real windowNameMaxWidth: Style.space(Math.max(40, Number(setting("windowNameMaxWidth", 100)) || 100))
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
  readonly property string actionScript: decodeURIComponent(Qt.resolvedUrl("workspace-actions.py").toString().replace(/^file:\/\//, ""))
  readonly property var monitor: {
    var window = root.QsWindow.window
    return window && window.screen ? Hyprland.monitorFor(window.screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: monitor ? monitor.name : ""
  property var monitors: []
  property var blocks: ({})
  readonly property var currentMonitor: monitors.find(function(m) { return m.name === root.monitorName }) || ({})
  readonly property int activeWorkspaceId: currentMonitor.activeWorkspace ? currentMonitor.activeWorkspace.id
    : (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0)
  readonly property string activeWorkspaceName: currentMonitor.activeWorkspace ? currentMonitor.activeWorkspace.name
    : (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : "")
  readonly property string activeSpecial: currentMonitor.specialWorkspace ? currentMonitor.specialWorkspace.name : ""
  readonly property int block: blocks[monitorName] !== undefined ? blocks[monitorName]
    : (activeWorkspaceId > 0 ? Policy.block(activeWorkspaceId) : 0)
  readonly property var workspaceSnapshot: Hyprland.workspaces.values.map(function(ws) {
    return {id: ws.id, name: ws.name, monitorName: ws.monitor ? ws.monitor.name : "", windows: ws.toplevels.values}
  })
  readonly property var groups: Policy.partition(workspaceSnapshot, monitorName, block, activeWorkspaceId, monitors)
  readonly property var minimizedWindows: Hyprland.toplevels.values.filter(function(window) {
    return window.workspace && Policy.kind(window.workspace.name) === "minimized"
  })
  property var modeCache: ({})
  property string lastMode: "dwindle"
  readonly property string activeMode: modeCache[activeWorkspaceId] || lastMode
  readonly property string layoutGlyph: activeMode === "floating" ? "󰔶" : activeMode === "scrolling" ? "󰝥" : activeMode === "dwindle" ? "󱓻" : ""
  property int modeGeneration: 0
  property string monitorError: ""
  property string layoutError: ""
  property string actionError: ""
  readonly property bool actionBusy: actionProcess.running

  Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  ApplicationResolver { id: applications }
  function translate(key) { return strings.t(key) }
  function resolveWindow(window) { return applications.resolveWindow(window) }

  function workspaceLabel(workspace) { return Policy.label(workspace, block) }
  function workspaceIcon(workspace) { return Policy.icon(workspace.name) }
  function workspaceTooltip(workspace) {
    if (workspace.minimized && workspace.windows.length) {
      var window = workspace.windows[0]
      var current = workspaceSnapshot.find(function(w) { return w.name === root.activeWorkspaceName })
      var destination = current ? workspaceLabel(current) : activeWorkspaceName
      return Policy.safeTooltip(resolveWindow(window).name + "\n" + String(window.title || "")
        + "\n" + originLabel(window) + "\n" + strings.t("restoreTo").arg(destination)
        + (actionError ? "\n" + actionError : ""))
    }
    var label = workspace.name === "special:scratchpad" ? strings.t("scratchpad")
      : workspace.name === "special:qconsole" ? strings.t("console")
      : strings.t("workspace").arg(workspaceLabel(workspace))
    return Policy.safeTooltip(label + (workspace.windows.length ? "\n" + workspace.windows.map(function(w) { return w.title }).join("\n") : ""))
  }
  function applicationIcon(application) {
    var icon = application.icon || ""
    return icon.indexOf("/") === 0 ? Util.fileUrl(icon) : (icon ? Quickshell.iconPath(icon, true) : "") || Quickshell.iconPath("application-x-executable")
  }
  function originLabel(window) {
    var origin = Policy.origin((window.lastIpcObject || {}).tags || [])
    if (!origin) return strings.t("unknownOrigin")
    var ws = workspaceSnapshot.find(function(w) { return w.id === origin })
    var label = ws ? workspaceLabel(ws) : String(origin)
    if (ws && ws.monitorName && ws.monitorName !== monitorName) label += " · " + ws.monitorName
    return strings.t("origin").arg(label)
  }
  function toggleDisplayMode() {
    var entry = {id: moduleName}
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    var modes = ["icons", "text", "original", "none"]
    entry.displayMode = modes[(modes.indexOf(displayMode) + 1) % modes.length]
    settings = entry
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, entry)
  }
  function runAction(action, target) {
    if (actionBusy || !monitorName) return
    actionError = ""
    actionProcess.requestAction = action
    actionProcess.jobCommand = ["python3", actionScript, action, monitorName, String(target || ""),
      action === "restore" ? activeWorkspaceName : ""]
    actionProcess.running = true
  }
  function selectWorkspace(workspace) {
    if (Policy.kind(workspace.name) === "overlay") runAction("overlay", workspace.name)
    else runAction("workspace", workspace.name)
  }
  function restoreWindow(window) { runAction("restore", window.address) }
  function refreshState() { monitorRefresh.restart() }
  function refreshMode() {
    modeGeneration++
    modeRefresh.restart()
  }
  function refresh() { refreshState(); refreshMode() }
  function diagnostics() {
    var result = applications.diagnostics()
    result.displayMode = displayMode
    result.monitor = monitorName
    result.activeWorkspace = activeWorkspaceId
    result.activeSpecial = activeSpecial
    result.layout = activeMode
    result.monitorError = monitorError
    result.layoutError = layoutError
    result.monitorQueryRunning = monitorQuery.running
    result.layoutQueryRunning = modeProcess.running
    result.regular = groups.regular.map(function(ws) { return {id: ws.id, name: ws.name, label: root.workspaceLabel(ws), viewed: Policy.isViewed(ws, root.activeWorkspaceId, root.activeSpecial)} })
    result.overlays = groups.overlays.map(function(ws) { return {id: ws.id, name: ws.name, label: root.workspaceLabel(ws), icon: root.workspaceIcon(ws), viewed: Policy.isViewed(ws, root.activeWorkspaceId, root.activeSpecial)} })
    result.minimized = minimizedWindows.map(function(w) { return {address: w.address, origin: Policy.origin((w.lastIpcObject || {}).tags || [])} })
    result.minimizedDisplay = "inline"
    result.minimizedLabels = minimizedStrip.windowLabels()
    result.actionError = actionError
    result.labels = []
    result.geometry = []
    for (var i = 0; i < workspaceRepeater.count; i++) {
      var item = workspaceRepeater.itemAt(i)
      if (item) {
        result.labels = result.labels.concat(item.windowLabels())
        result.geometry.push(item.geometry())
      }
    }
    return result
  }

  IpcHandler {
    target: "konochi.konospaces"
    function status(): string { return JSON.stringify(root.diagnostics()) }
    function refresh(): void { root.broadcast("refresh") }
  }

  FileView {
    path: root.stateHome + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var next = {}
      var rows = text().split("\n")
      for (var i = 0; i < rows.length; i++) {
        var fields = rows[i].split("\t")
        if (fields.length >= 3 && fields[1]) next[fields[1]] = Number(fields[0])
      }
      root.blocks = next
    }
  }
  Process {
    command: ["python3", root.actionScript, "watch-modes"]
    running: true
    stdout: SplitParser { onRead: data => root.refreshMode() }
    stderr: SplitParser { onRead: data => console.warn("Konospaces layout watcher:", data) }
  }
  Timer {
    id: monitorRefresh
    interval: 30
    onTriggered: {
      if (monitorQuery.running) monitorQuery.again = true
      else { root.monitorError = ""; monitorQuery.running = true }
    }
  }
  FiniteProcess {
    id: monitorQuery
    property bool again: false
    jobCommand: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.monitors = JSON.parse(text) }
        catch (error) { console.warn("Konospaces: monitor query failed", error) }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) root.monitorError = text.trim()
    }
    onExited: function(code) {
      if (code !== 0) {
        if (!root.monitorError) root.monitorError = "Monitor query exited with code " + code
        console.warn("Konospaces:", root.monitorError)
      }
      if (again) { again = false; monitorRefresh.restart() }
    }
  }
  Timer {
    id: modeRefresh
    interval: 40
    onTriggered: {
      if (modeProcess.running) return
      if (root.activeWorkspaceId <= 0) return
      root.layoutError = ""
      modeProcess.workspace = root.activeWorkspaceId
      modeProcess.generation = root.modeGeneration
      modeProcess.jobCommand = ["omarchy-hyprland-workspace-layout-current", String(root.activeWorkspaceId)]
      modeProcess.running = true
    }
  }
  FiniteProcess {
    id: modeProcess
    property int workspace: 0
    property int generation: 0
    stdout: StdioCollector {
      onStreamFinished: {
        var mode = text.trim()
        if (modeProcess.workspace === root.activeWorkspaceId && modeProcess.generation === root.modeGeneration
            && ["dwindle", "scrolling", "floating"].indexOf(mode) !== -1) {
          var next = Object.assign({}, root.modeCache)
          next[modeProcess.workspace] = mode
          root.modeCache = next
          root.lastMode = mode
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) root.layoutError = text.trim()
    }
    onExited: function(code) {
      if (code !== 0) {
        if (!root.layoutError) root.layoutError = "Layout query exited with code " + code
        console.warn("Konospaces:", root.layoutError)
      }
      if (workspace !== root.activeWorkspaceId || generation !== root.modeGeneration) modeRefresh.restart()
    }
  }
  FiniteProcess {
    id: actionProcess
    timeoutSeconds: 15
    property string requestAction: ""
    stderr: StdioCollector { onStreamFinished: root.actionError = text.trim() }
    onExited: function(code) {
      if (code !== 0) {
        if (!root.actionError) root.actionError = "Action exited with code " + code
        console.warn("Konospaces action:", root.actionError)
      }
      Hyprland.refreshMonitors()
      Hyprland.refreshWorkspaces()
      Hyprland.refreshToplevels()
      root.refresh()
    }
  }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name.indexOf("activespecial") === 0 || name.indexOf("focusedmon") === 0 || name.indexOf("monitor") === 0
          || name === "workspacev2" || name === "moveworkspacev2" || name === "changeworkspaceid") {
        root.refreshState()
        Hyprland.refreshMonitors()
        if (name === "moveworkspacev2" || name === "changeworkspaceid") Hyprland.refreshWorkspaces()
      }
      if (name === "configreloaded") root.refresh()
      // A just-mapped window can reach the Wayland list before IPC metadata.
      // Moves also change minimized-origin tags; refresh identities on these
      // events rather than retaining the initial PID/class/tag snapshot.
      if (name === "openwindow" || name === "movewindowv2" || name === "closewindow") Hyprland.refreshToplevels()
    }
  }
  Component.onCompleted: refresh()
  onMonitorNameChanged: Qt.callLater(root.refresh)
  onActiveWorkspaceIdChanged: {
    if (modeCache[activeWorkspaceId]) lastMode = modeCache[activeWorkspaceId]
    refreshMode()
  }

  implicitWidth: grid.implicitWidth + (vertical ? 0 : Style.spaceReal(1.5))
  implicitHeight: grid.implicitHeight
  GridLayout {
    id: grid
    anchors.fill: parent
    columns: root.vertical ? 1 : Math.max(1, 1 + root.groups.regular.length + root.groups.overlays.length
      + (!root.noIconsMode && root.minimizedWindows.length ? 1 : 0))
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0
    WidgetButton {
      id: layoutButton
      bar: root.bar
      text: root.layoutGlyph
      keepSpace: true
      horizontalMargin: 6
      verticalPadding: 6
      fixedWidth: root.vertical ? root.barSize : Style.space(20)
      fixedHeight: root.barSize
      opacity: root.activeSpecial || root.activeWorkspaceId <= 0 ? 0.4 : 1
      tooltipText: Policy.safeTooltip((root.activeSpecial ? strings.t("overlayLayout") : strings.t("layout"))
        .arg(root.activeMode === "floating" ? strings.t("floating") : root.activeMode === "scrolling" ? strings.t("scrolling") : strings.t("tiling")))
      onPressed: function(button) {
        if (button === Qt.RightButton) root.toggleDisplayMode()
        else if (button === Qt.LeftButton && !root.activeSpecial && root.activeWorkspaceId > 0) root.runAction("layout", "")
      }
    }
    Repeater {
      id: workspaceRepeater
      model: root.groups.regular
      WorkspaceChip {
        required property var modelData
        hostWidget: root
        group: modelData
        shown: Policy.isViewed(group, root.activeWorkspaceId, root.activeSpecial)
      }
    }
    Repeater {
      model: root.groups.overlays
      WorkspaceChip {
        required property var modelData
        hostWidget: root
        group: modelData
        shown: Policy.isViewed(group, root.activeWorkspaceId, root.activeSpecial)
      }
    }
    MinimizedStrip {
      id: minimizedStrip
      hostWidget: root
      windows: root.noIconsMode ? [] : root.minimizedWindows
    }
  }
}

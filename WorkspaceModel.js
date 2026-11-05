// Pure workspace policy. No IPC, title parsing, or application launching.
function kind(name) {
  name = String(name || "")
  if (name === "special:minimized") return "minimized"
  if (name === "special:screensaver") return "internal"
  if (name.indexOf("special:") === 0) return "overlay"
  return "regular"
}

function slot(id) { return (id - 1) % 10 + 1 }
function block(id) { return Math.floor((id - 1) / 10) }

// One highlighted destination per display. An open special workspace takes
// precedence over its underlying regular workspace, regardless of window focus.
function isViewed(workspace, activeId, activeSpecial) {
  var type = kind(workspace.name)
  if (type === "regular") return !activeSpecial && workspace.id === activeId
  return type === "overlay" && workspace.name === activeSpecial
}

function windowActive(viewed, activated) { return !!viewed && !!activated }

function icon(name) {
  if (name === "special:scratchpad") return "\u{f014c}" // clipboard-outline
  if (name === "special:qconsole") return "\uf489" // same terminal glyph as Omarchy's menu
  if (name === "special:minimized") return "\u{f10ac}" // dock-window
  if (kind(name) === "overlay") return "\u{f10ac}" // dock-window
  return ""
}

function label(workspace, localBlock) {
  if (workspace.name === "special:scratchpad") return "S"
  if (workspace.name === "special:qconsole") return ">_"
  if (kind(workspace.name) === "overlay") return String(workspace.name).slice(8)
  if (workspace.id > 0 && /^\d+$/.test(String(workspace.name)) && block(workspace.id) === localBlock)
    return String(slot(workspace.id))
  return String(workspace.name || workspace.id)
}

function partition(workspaces, monitorName, localBlock, activeId, monitors) {
  var regular = [], overlays = []
  for (var i = 0; i < workspaces.length; i++) {
    var ws = workspaces[i], type = kind(ws.name)
    var occupied = (ws.windows || []).length > 0
    if (type === "regular") {
      var local = ws.monitorName ? ws.monitorName === monitorName
        : (ws.id > 0 && block(ws.id) === localBlock)
      if ((local && occupied) || ws.id === activeId) regular.push(ws)
    } else if (type === "overlay") {
      var openHere = false, openElsewhere = false
      for (var j = 0; j < monitors.length; j++) {
        if (monitors[j].specialWorkspace && monitors[j].specialWorkspace.name === ws.name) {
          if (monitors[j].name === monitorName) openHere = true
          else openElsewhere = true
        }
      }
      if (openHere || (occupied && !openElsewhere)) overlays.push(ws)
    }
  }
  regular.sort(function(a, b) {
    if ((a.id > 0) !== (b.id > 0)) return a.id > 0 ? -1 : 1
    return a.id > 0 ? a.id - b.id : String(a.name).localeCompare(String(b.name))
  })
  function priority(ws) { return ws.name === "special:scratchpad" ? 0 : ws.name === "special:qconsole" ? 1 : 2 }
  overlays.sort(function(a, b) { return priority(a) - priority(b) || String(a.name).localeCompare(String(b.name)) })
  return { regular: regular, overlays: overlays }
}

function origin(tags) {
  var ids = []
  for (var i = 0; i < (tags || []).length; i++) {
    var match = /^omarchy-minimized-from-([1-9][0-9]*)$/.exec(tags[i])
    if (match && Number(match[1]) <= 2147483647 && ids.indexOf(Number(match[1])) === -1) ids.push(Number(match[1]))
  }
  return ids.length === 1 ? ids[0] : 0
}

// WidgetButton's tooltip text is ultimately rendered by a host-owned component.
// Keep all dynamic tooltip input inert even if the host uses Text.AutoText.
function safeTooltip(value) {
  return String(value || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

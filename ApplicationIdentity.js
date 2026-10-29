// Pure identity policy. No process execution, window-title matching, or I/O.
function desktopId(id) {
  return String(id || "").replace(/\.desktop$/, "")
}

function unique(entries) {
  return entries.length === 1 ? entries[0] : null
}

function exactEntry(id, entries) {
  var entry = unique(entries.filter(function(e) { return desktopId(e.id) === desktopId(id) }))
  return entry || unique(entries.filter(function(e) { return e.startupClass && e.startupClass === id }))
}

function commandName(entry) {
  var command = entry.command || []
  return command.length ? String(command[0]).split("/").pop() : ""
}

function omarchyEntry(id, entries) {
  // omarchy-launch-tui sets org.omarchy.<basename of command>. This is an
  // explicit launcher contract, not an inference from a terminal title.
  if (id.indexOf("org.omarchy.") !== 0) return null
  var command = id.slice("org.omarchy.".length)
  if (!command) return null
  return exactEntry(command, entries) || unique(entries.filter(function(e) {
    return commandName(e) === command
  }))
}

function webAppEntry(ids, entries) {
  // Compatibility adapter for the URL-derived IDs of installed browser apps.
  // Refuse ambiguous URL matches rather than selecting the first desktop file.
  return unique(entries.filter(function(entry) {
    var match = String(entry.execString || "").match(/https?:\/\/[^\s"']+/)
    if (!match) return false
    var address = match[0].replace(/^https?:\/\//, "")
    if (address.indexOf("/") === -1) address += "/"
    var key = address.replace("/", "_/").replace(/\//g, "_")
    return ids.some(function(id) { return id === key || id.indexOf("-" + key + "-") !== -1 })
  }))
}

function result(entry, source, fallback) {
  return {
    entryId: entry ? entry.id : "",
    name: entry && entry.name ? entry.name : fallback,
    icon: entry ? entry.icon || "" : "",
    source: source
  }
}

function resolve(window, entries, processes, defaultTerminalId) {
  var ids = [window.appId, window.className, window.initialClass].filter(function(id) { return !!id })
  var fallback = ids[0] || "Window"
  var entry
  for (var i = 0; i < ids.length; i++) {
    entry = exactEntry(ids[i], entries)
    if (entry) return result(entry, "desktop-entry", fallback)
    entry = omarchyEntry(ids[i], entries)
    if (entry) return result(entry, "omarchy-launcher", fallback)
    // Omarchy's generic package/configuration terminal uses the configured
    // terminal from xdg-terminal-exec, not a hard-coded emulator alias.
    if (ids[i] === "org.omarchy.terminal" && defaultTerminalId) {
      entry = exactEntry(defaultTerminalId, entries)
      if (entry) return result(entry, "default-terminal", fallback)
    }
    entry = webAppEntry([ids[i]], entries)
    if (entry) return result(entry, "web-app", fallback)
  }
  var processId = processes[String(window.pid)]
  entry = processId ? unique(entries.filter(function(e) { return e.id === processId })) : null
  return result(entry, entry ? "process" : "unresolved", fallback)
}

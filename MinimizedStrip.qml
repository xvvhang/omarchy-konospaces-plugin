pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: strip
  required property var hostWidget
  required property var windows
  visible: windows.length > 0
  implicitWidth: hostWidget.vertical ? hostWidget.barSize : content.implicitWidth + Style.spaceReal(6) * 2
  implicitHeight: hostWidget.vertical ? content.implicitHeight + Style.spaceReal(6) * 2 : hostWidget.barSize

  function windowLabels() {
    var labels = []
    for (var i = 0; i < entries.count; i++) {
      var item = entries.itemAt(i)
      if (item) labels = labels.concat(item.windowLabels())
    }
    return labels
  }

  // Match WorkspaceChip: one outer padding, a 7-unit marker/content gap,
  // and 8 units between windows. Individual targets add no horizontal padding.
  GridLayout {
    id: content
    anchors.centerIn: parent
    columns: strip.hostWidget.vertical ? 1 : 2
    columnSpacing: Style.space(7)
    rowSpacing: Style.space(4)
    Item {
      implicitWidth: Style.bar.iconCanvas
      implicitHeight: Style.bar.iconCanvas
      Layout.alignment: Qt.AlignCenter
      opacity: 0.5
      OpticalGlyph {
        anchors.fill: parent
        text: strip.hostWidget.workspaceIcon({name: "special:minimized"})
        fontFamily: strip.hostWidget.bar ? strip.hostWidget.bar.fontFamily : Style.font.family
        fontSize: Style.font.body
        paintedSize: Style.bar.iconSize
        color: strip.hostWidget.bar ? strip.hostWidget.bar.barForeground : Color.foreground
      }
    }
    GridLayout {
      columns: strip.hostWidget.vertical ? 1 : Math.max(1, strip.windows.length)
      columnSpacing: Style.space(8)
      rowSpacing: Style.space(strip.hostWidget.textMode ? 3 : 5)
      Layout.alignment: Qt.AlignCenter
      Repeater {
        id: entries
        model: strip.windows
        WorkspaceChip {
          required property var modelData
          hostWidget: strip.hostWidget
          group: ({name: "special:minimized", minimized: true, windows: [modelData]})
          horizontalMargin: strip.hostWidget.vertical ? 6 : 0
          verticalPadding: 0
          fixedWidth: strip.hostWidget.vertical ? strip.hostWidget.barSize : naturalContentWidth
          fixedHeight: strip.hostWidget.vertical ? naturalContentHeight : strip.hostWidget.barSize
        }
      }
    }
  }
}

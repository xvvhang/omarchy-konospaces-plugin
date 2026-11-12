pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "WorkspaceModel.js" as Policy

WidgetButton {
  id: chip
  required property var hostWidget
  required property var group
  property bool shown: false
  readonly property real indicatorOpacity: shown ? 1 : 0.5
  readonly property real naturalContentWidth: content.implicitWidth
  readonly property real naturalContentHeight: content.implicitHeight
  readonly property var windows: group.windows || []
  readonly property string workspaceGlyph: group.minimized ? "" : hostWidget.workspaceIcon(group)
  bar: hostWidget.bar
  text: group.minimized ? "" : hostWidget.workspaceLabel(group)
  hasVisualContent: true
  labelVisible: false
  tooltipText: hostWidget.workspaceTooltip(group)
  foreground: bar ? bar.barForeground : Color.foreground
  horizontalMargin: 6
  verticalPadding: 6
  fixedWidth: hostWidget.vertical ? hostWidget.barSize : hostWidget.noIconsMode ? Style.space(20)
    : Math.max(Style.space(20), content.implicitWidth + scaledHorizontalMargin * 2)
  fixedHeight: hostWidget.vertical ? Math.max(hostWidget.barSize, content.implicitHeight + scaledVerticalPadding * 2) : hostWidget.barSize
  onPressed: function(button) {
    if (button === Qt.RightButton) hostWidget.toggleDisplayMode()
    else if (button === Qt.LeftButton) {
      if (group.minimized && windows.length) hostWidget.restoreWindow(windows[0])
      else hostWidget.selectWorkspace(group)
    }
  }

  function windowLabels() {
    var labels = []
    for (var i = 0; i < windowRepeater.count; i++) {
      var item = windowRepeater.itemAt(i)
      if (item) labels.push({address: item.modelData.address, text: item.application.name, source: item.application.source})
    }
    return labels
  }

  function geometry() {
    return {workspace: group.name, shown: shown, width: width,
      indicatorWidth: indicator.width, windowsX: windowContent.x,
      contentWidth: content.implicitWidth, layoutGlyph: workspaceGlyph}
  }

  GridLayout {
    id: content
    anchors.centerIn: parent
    columns: chip.hostWidget.vertical || chip.text === "" ? 1 : 2
    columnSpacing: Style.space(7)
    rowSpacing: Style.space(4)

    Item {
      id: indicator
      visible: chip.text !== "" || chip.workspaceGlyph !== ""
      implicitWidth: chip.workspaceGlyph !== "" ? Style.bar.iconCanvas
        : Math.min(indicatorText.implicitWidth, Style.space(chip.hostWidget.vertical ? 32 : 90))
      implicitHeight: Math.max(indicatorText.implicitHeight, Style.bar.iconCanvas)
      Layout.minimumWidth: implicitWidth
      Layout.preferredWidth: implicitWidth
      Layout.maximumWidth: implicitWidth
      Layout.alignment: Qt.AlignCenter

      Text {
        id: indicatorText
        anchors.fill: parent
        visible: chip.text !== "" && chip.workspaceGlyph === ""
        text: chip.text
        textFormat: Text.PlainText
        color: chip.foreground
        opacity: chip.indicatorOpacity
        font.family: chip.fontFamily
        font.pixelSize: chip.fontSize
        font.bold: chip.shown
        renderType: Text.NativeRendering
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      Item {
        visible: chip.workspaceGlyph !== ""
        anchors.fill: parent
        opacity: chip.indicatorOpacity
        OpticalGlyph {
          width: Style.bar.iconCanvas
          height: Style.bar.iconCanvas
          anchors.centerIn: parent
          text: chip.workspaceGlyph
          fontFamily: chip.fontFamily
          fontSize: chip.fontSize
          paintedSize: Style.bar.iconSize
          color: chip.foreground
        }
      }
    }

    GridLayout {
      id: windowContent
      visible: !chip.hostWidget.noIconsMode && chip.windows.length > 0
      columns: chip.hostWidget.vertical ? 1 : Math.max(1, chip.windows.length)
      columnSpacing: Style.space(8)
      rowSpacing: Style.space(chip.hostWidget.textMode ? 3 : 5)
      Layout.alignment: Qt.AlignCenter
      Repeater {
        id: windowRepeater
        model: chip.hostWidget.noIconsMode ? [] : chip.windows
        Item {
          id: windowItem
          required property var modelData
          readonly property bool focused: Policy.windowActive(chip.shown, modelData.activated)
          readonly property var application: chip.hostWidget.resolveWindow(modelData)
          readonly property real maxTextWidth: chip.hostWidget.vertical
            ? Math.max(1, chip.hostWidget.barSize - chip.scaledHorizontalMargin * 2)
            : chip.hostWidget.windowNameMaxWidth
          implicitWidth: chip.hostWidget.textMode ? Math.min(windowLabel.implicitWidth, maxTextWidth) : chip.hostWidget.iconSize
          implicitHeight: chip.hostWidget.textMode ? windowLabel.implicitHeight : chip.hostWidget.iconSize
          Layout.preferredWidth: implicitWidth
          Layout.preferredHeight: implicitHeight
          Layout.alignment: Qt.AlignCenter
          opacity: !focused ? (chip.hostWidget.originalIconMode ? 0.4 : chip.hostWidget.textMode ? 0.5 : 1) : 1
          Text {
            id: windowLabel
            anchors.fill: parent
            visible: chip.hostWidget.textMode
            text: windowItem.application.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            verticalAlignment: Text.AlignVCenter
            color: chip.foreground
            font.family: chip.fontFamily
            font.pixelSize: chip.fontSize
            font.bold: true
            renderType: Text.NativeRendering
          }
          Image {
            id: applicationIconImage
            anchors.fill: parent
            visible: chip.hostWidget.originalIconMode || (!chip.hostWidget.textMode && windowItem.focused)
            source: chip.hostWidget.textMode ? "" : chip.hostWidget.applicationIcon(windowItem.application)
            sourceSize.width: chip.hostWidget.iconSize
            sourceSize.height: chip.hostWidget.iconSize
            fillMode: Image.PreserveAspectFit
          }
          ShaderEffect {
            anchors.fill: applicationIconImage
            visible: !chip.hostWidget.textMode && !chip.hostWidget.originalIconMode && !windowItem.focused
            property var source: applicationIconImage
            property color foreground: chip.foreground
            property real minimumOpacity: windowItem.focused ? 0.55 : 0.2
            property real maximumOpacity: windowItem.focused ? 1.0 : 0.65
            fragmentShader: Qt.resolvedUrl("shaders/monochrome.frag.qsb")
          }
        }
      }
    }
  }
}

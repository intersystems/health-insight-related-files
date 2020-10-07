Class COVID19.Component.Widget.heatMap Extends %DeepSee.Component.Widget.map
{

/// Return information used to list this widget within the "widget catalog".
ClassMethod %GetCatalogInfo(Output pInfo As %List, Output pSubtypeList As %List) As %Status
{
	Kill pInfo,pSubtypeList
	// $LB(name,caption,class,icon)
	Set pInfo = $LB(..%ClassName(1),"Heat Map",..%ClassName(1),"deepsee/world_48.gif")
	Quit $$$OK
}

/// Return information on additional "properties" supported by this widget for the given subtype.
ClassMethod %GetWidgetPropertyInfo(pSubtype As %String, Output pInfo As %List) As %Status
{
	Kill pInfo
	Set sc = ##super(pSubtype,.pInfo)
	// TODO: support customizing dissipating, gradient, maxIntensity, radius, opacity
	// (see https://developers.google.com/maps/documentation/javascript/heatmaplayer#customize_a_heatmap_layer)
	Set pInfo($I(pInfo)) = $LB("weightProperty","Weight","%String","Weight Property","Weight Property")
	Set pInfo($I(pInfo)) = $LB("latitudeProperty","Latitude","%String","Latitude Property","Latitude Property")
	Set pInfo($I(pInfo)) = $LB("longitudeProperty","Longitude","%String","Longitude Property","Longitude Property")
	Set pInfo($I(pInfo)) = $LB("radius",10,"%Integer","Radius","Radius")
	Set pInfo($I(pInfo)) = $LB("dissipating",1,"%Boolean","Dissipating","Dissipating")
	Quit sc
}

/// This callback is responsible for creating the contents of the widget.
Method %OnCreateWidget(pGroup As %ZEN.Component.group) As %Status
{
	Set tSC = $$$OK
	Try {
		// DTB565 - required by excel/PDF export
		Set ..sessionCookie = %session.CSPSessionCookie
		
		// get default values for widget properties
		Do ..%GetWidgetPropertyInfo(..subtype,.tList)
		Set n = $O(tList(""))
		While (n'="") {
			Set tName = $LG(tList(n),1)
			Set tPValue(tName) = ..%definition.properties.GetAt(tName)
			Set:tPValue(tName)="" tPValue(tName) = $LG(tList(n),2)
			Set n = $O(tList(n))
		}

		// see if we have a data source
		Set tMsg = ""
		Set tController = ""
		Set tKPIClass = ""
		Set tDataSource = ..dataSource
		Set tExt = $P(tDataSource,".",$L(tDataSource,"."))
		If (tExt = "kpi") {
			Set tName = $P(tDataSource,".",1,$L(tDataSource,".")-1)
			Set tKPIClass = ##class(%DeepSee.Utils).%GetKPIClass(tName)
		}
		ElseIf (tExt = "metric") {
			Set tKPIClass = "Ens.BusinessMetricKPI"
		}
		ElseIf (tExt = "worksheet") {
			Set tKPIClass = "%DeepSee.KPIWorksheet"
		}

		If (tKPIClass'="") {
			// add data controller to the widget
			Set tController = ##class(%ZEN.Auxiliary.dataController).%New()
			Set tController.id = ..%MakeWidgetId("controller")
			Set tController.modelClass = tKPIClass
			If (tExt = "metric") {
				Set tController.modelId = ..dataSource
			}
			ElseIf (tExt = "worksheet") {
				Set tController.modelId = ..dataSource
			}
			Set tSC = pGroup.%AddChild(tController)
			If $$$ISERR(tSC) Quit
			Set tInvert = 0
		}
		ElseIf (tExt="pivot") {
			// saved pivot
			// create a hidden pivotTable and use it as the controller
			Set tPivotDef = ""
			If (##class(%DeepSee.UserLibrary.Utils).%FolderItemExists(..dataSource)) {
				// DTB580 - Only set the folder item if we know it exists
				Set tPivotDef = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(..dataSource,.tSC)
				If $$$ISERR(tSC) Quit
			}
			
			If '$IsObject(tPivotDef) {
				// Show error on widget
				Set tLabel = ##class(%ZEN.Component.label).%New()
				Set tLabel.value = $$$FormatText($$$Text("The data source '%1' is missing.","%DeepSee"),..dataSource)
				Set tLabel.enclosingClass = "mapError"
				Set tSC = pGroup.%AddChild(tLabel)
				If $$$ISERR(tSC) Quit
			}

			Set tPivotTable = ##class(%DeepSee.Component.pivotTable).%New()
			Set tPivotTable.id = ..%MakeWidgetId("controller")
			Set tPivotTable.hidden = 1
			Set tSC = pGroup.%AddChild(tPivotTable)
			If $$$ISERR(tSC) Quit

			// JMD: test for bad pivot
			If $IsObject(tPivotDef) {
				// copy information from the saved item to the graphical pivot
				Set tSC = tPivotDef.%CopyToComponent(tPivotTable)
				If $$$ISERR(tSC) Quit
			}
			
			Set tController = tPivotTable
			Set tInvert = 1
		}

		// add a map view to the widget
		Set tMap = ##class(COVID19.Component.heatMapView).%New() //TSL: changed class name; otherwise copy of parent implementation.
		Set tMap.id = ..%MakeWidgetId("map")
		Set:$IsObject(tController) tMap.controllerId = tController.id
		Set tSC = pGroup.%AddChild(tMap)
		If $$$ISERR(tSC) Quit

		// copy settings into map component
		If (""'=$G(tPValue("mapType"))) {
			Set tMap.mapType = tPValue("mapType")
		}
		If (""'=$G(tPValue("zoom"))) {
			Set tMap.zoom = +tPValue("zoom")
		}
		If (""'=$G(tPValue("longitude"))) {
			Set tMap.longitude = +tPValue("longitude")
		}
		If (""'=$G(tPValue("latitude"))) {
			Set tMap.latitude = +tPValue("latitude")
		}
		If (""'=$G(tPValue("latitudeProperty"))) {
			Set tMap.latitudeProperty = tPValue("latitudeProperty")
		}
		If (""'=$G(tPValue("longitudeProperty"))) {
			Set tMap.longitudeProperty = tPValue("longitudeProperty")
		}
		If (""'=$G(tPValue("weightProperty"))) {
			Set tMap.weightProperty = tPValue("weightProperty")
		}
		If (""'=$G(tPValue("radius"))) {
			Set tMap.radius = +tPValue("radius")
		}
		If (""'=$G(tPValue("dissipating"))) {
			Set tMap.dissipating = +tPValue("dissipating")
		}

		// JMD950
		If (""'=tPValue("markersdraggable")) {
			Set tMap.markersDraggable=tPValue("markersdraggable")
		}

		// JMD950: if there are data properties, these define the contents of the info window.
		Set tPropCount = ..%definition.dataProperties.Count()

		For p=1:1:tPropCount {
			Set tDataPropertyDef = ..%definition.dataProperties.GetAt(p)

			// use the column structure;
			// not all of these properties are relevant
			Set tColumn = ##class(%DeepSee.Component.SVG.scoreCardColumn).%New()
			Set tColumn.label = tDataPropertyDef.label
			Set tColumn.format = tDataPropertyDef.format
			Set tColumn.style = tDataPropertyDef.style
			Set tColumn.display = tDataPropertyDef.display
			Set tColumn.showAs = tDataPropertyDef.showAs
			Set tColumn.summary = tDataPropertyDef.summary
			Set tColumn.summaryValue = tDataPropertyDef.summaryValue
			Set tColumn.valueColumn = tDataPropertyDef.valueColumn
			Set tColumn.dataValue = tDataPropertyDef.dataValue
			Set tColumn.targetValue = tDataPropertyDef.targetValue
			Set tColumn.rangeLower = tDataPropertyDef.rangeLower
			Set tColumn.rangeUpper = tDataPropertyDef.rangeUpper
			Set tColumn.baseValue = tDataPropertyDef.baseValue
			Set tColumn.thresholdLower = tDataPropertyDef.thresholdLower
			Set tColumn.thresholdUpper = tDataPropertyDef.thresholdUpper
			Set tColumn.width = tDataPropertyDef.width
			Set tColumn.align = tDataPropertyDef.align
			Do tMap.infoProperties.Insert(tColumn)
			Do:$IsObject($G(%page)) %page.%AddComponent(tColumn)
		}
	}
	Catch (ex) {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}


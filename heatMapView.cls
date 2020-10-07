Class COVID19.Component.heatMapView Extends %DeepSee.Component.mapView [ System = 4 ]
{

Parameter NAMESPACE = "http://www.intersystems.com/healthshare/covid-19";

Parameter INCLUDEFILES As COSEXPRESSION = """script:https://maps.googleapis.com/maps/api/js?""_..%GetUrlAPIKey()_""&libraries=visualization""";

/// Name of property in data source that provides the longitude value for a marker.
Property weightProperty As %ZEN.Datatype.string [ InitialExpression = "Weight" ];

Property radius As %ZEN.Datatype.integer [ InitialExpression = 10 ];

Property dissipating As %ZEN.Datatype.boolean [ InitialExpression = 1 ];

/// Internal method: acquire data for this view and store a copy in a local cache.
ClientMethod acquireData() [ Internal, Language = javascript ]
{
	var controller = this.getController();
	if (null == controller) {
		// try to connect to dataController
		this.connectToController();
		controller = this.getController();
	}

	// array of marker data
	this._markerData = [];

	if (controller && !this.isListing) {
		// get data from controller (make sure data is loaded)
		var dims = controller.getDimensions();
		
		if ((this.latitudeProperty == '')||(this.longitudeProperty == '')) {
			return;
		}

		// are we connected to a pivot table?
		var invert = controller.getSelectedRange;
		if (!invert) {
			var seriesSize = controller.getDimSize(1);
			var seriesCount = controller.getDimSize(2);
			var labelDim = 2;
			var latCol = -1;
			var longCol = -1;
			var weightCol = -1;
			// find long and lat columns
			for (var p = 0; p < seriesSize; p++) {
				var pname = controller.getPropertyName(p);
				if (pname == this.latitudeProperty) {
					latCol = p;
				}
				if (pname == this.longitudeProperty) {
					longCol = p;
				}
				if (pname == this.weightProperty) {
					weightCol = p;
				}
			}
		}
		else {
			var seriesSize = controller.getDimSize(2);
			var seriesCount = controller.getDimSize(1);
			var labelDim = 1;
		}

		// each series corresponds to a marker
		for (var n = 0; n < seriesCount; n++) {
			var sname = controller.getLabel(n,labelDim);
			
			// TODO: add weight column for heatMap
			if (!invert) {
				if (latCol<0 || longCol<0 || weightCol<0) {
					break;
				}
				var lat = controller.getData(latCol,n);
				var long = controller.getData(longCol,n);
				var weight = controller.getData(weightCol,n);
			}
			else {
				var lat = controller.getDataByName(this.latitudeProperty,n);
				var long = controller.getDataByName(this.longitudeProperty,n);
				// TODO: make weight column configurable, or default to 1 if weight column is not specified.
				var weight = controller.getDataByName(this.weightProperty,n);
			}
			
			if (!isNaN(parseFloat(lat)) && !isNaN(parseFloat(long))) {
				this._markerData[this._markerData.length] = {
					index: n,
					title: sname,
					latitude: lat,
					longitude: long,
					weight: weight
				};
			}
		}
	}
}

/// Internal method: sync markers to data from controller.
ClientMethod syncMarkers() [ Internal, Language = javascript ]
{
	var controller = this.getController();
	if (null == controller) {
		return;
	}
	
	var map = this.getMapObject();
	if (!map) {
		return;
	}

	this.clearMarkers();
	
	if (this._markerData) {
		for (var n = 0; n < this._markerData.length; n++) {
			var md = this._markerData[n];
			if (md) {
				var latLng = this.addLatLng(md.latitude,md.longitude);
				this._heatMapData.push({
					location: latLng,
					weight: md.weight
				});
			}
		}
	}
	
	this._heatmap = new google.maps.visualization.HeatmapLayer({
	  data: this._heatMapData
	});
	this._heatmap.set('radius', this.radius);
	this._heatmap.set('dissipating', this.dissipating);
	this._heatmap.setMap(map);
	
	this.adjustMapBounds();
}

/// Add a marker to the map at given coordinates.<br/>
/// <var>id</var> is a user-defined identifier associated with the marker.<br/>
/// Returns the marker object.
ClientMethod addLatLng(latitude, longitude) [ Language = javascript ]
{
	var latLng = null;
	var map = this.getMapObject();
	if (map && !isNaN(parseFloat(latitude)) && !isNaN(parseFloat(longitude))) {
		var latLng = new google.maps.LatLng(parseFloat(latitude), parseFloat(longitude));
		// add to list
		this._latlng.push(latLng);
	}
	return latLng;
}

/// Internal method: heatmap, cached lat/lng data
ClientMethod clearMarkers() [ Internal, Language = javascript ]
{
	try {
		// clear cached lat/lng info
		this._latlng = [];
		this._heatMapData = [];
		
		// remove old heatmap
		if (this._heatmap) {
			this._heatmap.setMap(null);
		}
	}
	catch(ex) {
		alert('Error in mapView.clearMarkers ' + ex.message);
	}
}

/// Adjust the map to show all the current markers
ClientMethod adjustMapBounds() [ Language = javascript ]
{
	var map = this.getMapObject();
	if (map) {
		var latlngbounds = new google.maps.LatLngBounds();
		for (var n = 0; n < this._latlng.length; n++) {
			var point = this._latlng[n];
			if (point) {
				latlngbounds.extend(point);
			}
		}
		map.setCenter(latlngbounds.getCenter());
		map.fitBounds(latlngbounds);
	}
}

}


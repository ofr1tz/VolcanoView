// colour scale volcanoes: ColorBrewer 8-class Dark2 (categorical)
var volcanoes = { 
	names: ['Karisimbi', 'Mikeno', 'Muhabura', 'Bisoke', 'Sabyinyo', 'Gahinga', 'Nyiragongo', 'Nyamuragira'],
	fillColors: ["#66a61e", "#e6ab02", "#1b9e77", "#e7298a", "#7570b3", "#d95f02", "#a6761d", "#666666"], 
	strokeColors: ["#368600", "#b68b00", "#006e47", "#b7005a", "#454000", "#a92f00", "#864600", "#363636"]
}

// controls
var zoom = new ol.control.Zoom();
// var scaleLine = new ol.control.ScaleLine({ minWidth: 128 });
// var overview = new ol.control.OverviewMap({ collapsed: true });
var attribution = new ol.control.Attribution({ collapsible: true, collapsed: false });
// var controls = [zoom, scaleLine, overview, attribution]
var controls = [zoom, attribution]

// basemap layer OSM Carto Positron
var osm = new ol.layer.Tile({
  	source: new ol.source.OSM({
  		url: 'https://{a-c}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
		attributions: 
			'Basemap: &copy; <a href="https://www.openstreetmap.org/" target="_blank">OpenStreetMap</a> contributors, &copy; <a href="https://carto.com/attribution" target="_blank">Carto</a> | ' +
			'Volcano vistas: see <a href="https://github.com/ofr1tz/VolcanoView/blob/master/processing/render_volcano_vista.md" target="_blank">Github doc</a>'
  	})
});

// data source vector 
var virungaSource = new ol.source.Vector({
	url: 'data/virunga.geojson', 
	format: new ol.format.GeoJSON()
});
	
// style deselected features
var virungaStyle = new ol.style.Style({
	image: new ol.style.RegularShape({
		points: 3,
		radius: 10,
		fill: new ol.style.Fill({ color: 'lightgrey' }),
		stroke: new ol.style.Stroke({ color: 'grey', width: 1})
		})
});

// style function selected features
var virungaStyleSelected = function(f) {
	for(i = 0; i < volcanoes.names.length; i++) {
    	if(f.get("name")==volcanoes.names[i]) {
    		var fillColor = volcanoes.fillColors[i];
    		var strokeColor = volcanoes.strokeColors[i];
    	}
    }
    var style = new ol.style.Style({
		image: new ol.style.RegularShape({
			points: 3,
			radius: 10,
			fill: new ol.style.Fill({ color: fillColor }),
			stroke: new ol.style.Stroke({ color: strokeColor, width: 2})
			})
		});
	
return style;
};

// style function mouseover features
var virungaStyleMouseOver = function(f) {
	for(i = 0; i < volcanoes.names.length; i++) {
    	if(f.get("name")==volcanoes.names[i]) {
    		var fillColor = volcanoes.fillColors[i];
    		var strokeColor = volcanoes.strokeColors[i];
    	}
    }
    var style = new ol.style.Style({
		image: new ol.style.RegularShape({
			points: 3,
			radius: 10,
			fill: new ol.style.Fill({ color: fillColor }),
			stroke: new ol.style.Stroke({ color: strokeColor, width: 1})
			})
		});
	
return style;
};


// initialise vector layer
var virunga = new ol.layer.Vector({
	source: virungaSource,
	style: virungaStyle, 
	opacity: .8,
	zIndex: 1,
	lname: 'virunga'			
});	

// create one Tile WMS layer per volcano
var viewshedUrl = 'https://tomcat.oliverfritz.de/geoserver/volcano-view/wms'
var viewshedLayers = []
for(i = 0; i < volcanoes.names.length; i++) {

	/* TileWMS version: performant, but layer detection for locator does not work */
	window[volcanoes.names[i].toLowerCase()] = new ol.layer.Tile({ 	// or: - ol.layer.Image
		source: new ol.source.TileWMS({ 							//     - ol.source.ImageWMS
			url: viewshedUrl, 
			params: { 
				"LAYERS":  'volcano-view:'+volcanoes.names[i],
				'TILED': true, 
				'FORMAT': 'image/png',
				'WIDTH': 256, 'HEIGHT': 256,
				'CRS': 'EPSG:3857'
			},
			attributions: ' | Viewsheds derived from <a href="https://doi.org/10.5066/F7PR7TFT" target="_blank">SRTM DEM',
			serverType: 'geoserver',
			transition: 0, 
			crossOrigin: 'anonymous'
		}),
		lname: volcanoes.names[i].toLowerCase()
	});

	window[volcanoes.names[i].toLowerCase()].setVisible(false)
	viewshedLayers.push(window[volcanoes.names[i].toLowerCase()])
};


/* create one WMS layer per volcano
var viewshedLayers = []
for(i = 0; i < volcanoes.names.length; i++) {
	window[volcanoes.names[i].toLowerCase()] = new ol.layer.Image({
		source: new ol.source.ImageWMS({ 							
			url: viewshedUrl, 
			params: { 
				"LAYERS":  'volcano-view:'+volcanoes.names[i], 
				'FORMAT': 'image/png',
				'CRS': 'EPSG:3857'
			},
			attributions: 'Viewsheds derived from <a href="https://doi.org/10.5066/F7PR7TFT" target="_blank">SRTM DEM',
			serverType: 'geoserver',
			transition: 0, 
			crossOrigin: 'anonymous'
		}),
		lname: volcanoes.names[i].toLowerCase()
	});
	window[volcanoes.names[i].toLowerCase()].setVisible(false)
	viewshedLayers.push(window[volcanoes.names[i].toLowerCase()])
};
*/


// mouseover interaction vector layer
var mouseOver = new ol.interaction.Select({
	condition: ol.events.condition.pointerMove,
	// condition: ol.events.condition.mouseOnly,
	layers: function(layer){
		if (layer.get('lname')=='virunga')	return true
		else return false;
	},
	style:virungaStyleMouseOver
});

// single click interaction vector layer
var singleClick = new ol.interaction.Select({
	// condition: ol.events.condition.singleClick,
	addCondition: ol.events.condition.singleClick,
	removeCondition: ol.events.condition.singleClick,
	// toogleCondition: ol.events.condition.singleClick, // not helpful with touch interaction
	layers: function(layer){
		if (layer.get('lname')=='virunga') return true;
		else return false;
	},
	style:virungaStyleSelected
});

// combine layers
var layers = [osm, virunga].concat(viewshedLayers);

// define map view
var zoom = 9;		
var centerpoint = ol.proj.transform([30.0975, -1.9590], 'EPSG:4326', 'EPSG:3857'); // centered on Rwanda
// var centerpoint = [3278506, -167779]; // centered on Karisimbi
var view = new ol.View({
  	center: centerpoint,
  	zoom: zoom,
  	minZoom: 4,
	enableRotation: false
});

// create map
var map = new ol.Map({
  	target: 'map',
  	layers: layers,
  	controls: controls,
  	view: view,
  	interactions: ol.interaction.defaults().extend([mouseOver, singleClick])
});

// define popup and add as map overlay
var popup = new Popup();
map.addOverlay(popup);

// welcome note
var welcome = true;
popup.show(
	ol.proj.transform([29.45, -1.35], 'EPSG:4326', 'EPSG:3857'), 
	'<div><h2>Welcome!</h2><p>Click on any of the volcanoes to show the viewshed.<br><br>(It may take a couple of seconds before it appears...)</p></div>'
);

// popup on mouseover
map.on('pointermove', function(e) {
	var pixel=map.getPixelFromCoordinate(e.coordinate);
	if(!welcome) popup.hide();	
	map.forEachFeatureAtPixel(pixel, function(f) {		
		welcome = false;
		var coords = f.getGeometry().getCoordinates();
		var name = f.get('name');
		var ele = f.get('ele');				
		popup.show(coords, '<div><h2>'+name+' ('+ele+'m)</h2><p>Click to show/hide viewshed.</p><img src="img/'+name+'.png" alt="'+name+'" width="150px" height="150px"></div>');
	});
});	

// call clicked features
var selectedFeatures = singleClick.getFeatures();

// select viewsheds
selectedFeatures.on('add', function(event) {			
	window[event.element.get("name").toLowerCase()].setVisible(true);
});

// deselect viewsheds
selectedFeatures.on('remove', function(event) {
	window[event.element.get("name").toLowerCase()].setVisible(false);
});

// change pointer on feature mouseover
map.on('pointermove', function(e) {		    
    if (e.dragging) return;         	
	var pixel = map.getEventPixel(e.originalEvent);
	var hit = map.forEachLayerAtPixel(pixel, function(layer) {     
		if (layer.get('lname')=='virunga')	return true;
		else return false;
	});        
	map.getTargetElement().style.cursor = hit ? 'pointer' : '';
});

// (de)activate and position points on indicator
/* 

*de*-activation does not seem to work anymore since using TileWMS
use getFeatureInfo instead of detection of Layer names?

*/

map.on('pointermove', function(e) {
	var virungaFeats = virungaSource.getFeatures();
	var view = [];
	var coordsEvent = e.coordinate;
	map.forEachLayerAtPixel(e.pixel, function(l){
        view.push(l.get('lname'));
	});    		
	for(i = 0; i < virungaFeats.length; i++) {
	  	name = virungaFeats[i].getProperties().name.toLowerCase();
	  	coordsVolcano = virungaFeats[i].getGeometry().getCoordinates();
	  	if(view.includes(name)) {    		  		
	  		document.getElementById(name).style.fill = volcanoes.fillColors[i];
	  		document.getElementById(name).style.stroke = volcanoes.strokeColors[i];
	  		var angle = Math.atan2(coordsVolcano[0]-coordsEvent[0], coordsEvent[1]-coordsVolcano[1]);
	  		var cxNew = 50+40*Math.sin(angle);
	  		var cyNew = 50+40*Math.cos(angle);
	  		document.getElementById(name).setAttribute("cx", cxNew);
	  		document.getElementById(name).setAttribute("cy", cyNew);
	  	} else {
	  		document.getElementById(name).style.fill = "transparent";
	  		document.getElementById(name).style.stroke = "transparent";
		};
	};
});
	
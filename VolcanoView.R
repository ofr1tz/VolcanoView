require(tidyverse)
require(sp)
require(sf)
require(raster)
require(rgrass7)
require(link2GI)
require(osmdata)

# get Rwanda level 0 administrative borders
rwanda <- getbb("RWanda", featuretype="country")

# process Rwanda SRTM 30m data, if not existant
destfile <- "./output/Rwanda_SRTM30m_void_filled.tif"
if(!file.exists(destfile)) {
    # get correct elevation data for lake islands
    # download and extract processed SRTM data from RCMRD
    temp <- tempfile()
    download.file("https://s3.amazonaws.com/rcmrd-open-data/downloadable_files/Rwanda_SRTM30meters.zip",
                  temp)
    unzip(temp, "Rwanda_SRTM30meters.tif", exdir="./data")
    unlink(temp)
    # build OSM Overpass query for islands
    q <- rwanda %>%
        opq() %>%
        add_osm_feature("place", "island")
    # read data
    islands <- osmdata_sp(q)$osm_polygons
    # mask RCMRD SRTM data with islands polygons
    islandsMask <- mask(raster("./data/Rwanda_SRTM30meters.tif"),
                        islands, 
                        inverse=F,
                        updatevalue=NA)
    # load, merge and crop SRTM tiles (source: https://earthexplorer.usgs.gov/)
    srtm <- crop(mosaic(raster("./data/s02_e028_1arc_v3.tif"),
                        raster("./data/s02_e029_1arc_v3.tif"),
                        raster("./data/s02_e030_1arc_v3.tif"),
                        raster("./data/s03_e028_1arc_v3.tif"),
                        raster("./data/s03_e029_1arc_v3.tif"),   
                        raster("./data/s03_e030_1arc_v3.tif"),
                        islandsMask,
                        fun=max),
                 extent(rwanda))
    # initialise GRASS
    linkGRASS7(srtm, 
               default_GRASS7=c("C:\\PROGRA~1\\QGIS3~1.2",
                                "grass-7.4.1",
                                "osgeo4W"))
    # write DEM into GRASS database
    writeRAST(as(srtm, "SpatialGridDataFrame"), "dem")
    # fill voids
    execGRASS("r.fillnulls", 
              flags="overwrite",
              parameters=list(input="dem", 
                              output="dem", 
                              method="bilinear"))
    # read DEM from GRASS database and adjust extent & CRS to original
    dem <- as(readRAST("dem"), "RasterLayer")
    extent(dem) <- extent(srtm)
    crs(dem) <- crs(srtm)
    # write DEM to file
    writeRaster(dem, "./output/Rwanda_SRTM30m_void_filled.tif")
} else {
    # read DEM from file
    dem <- raster(destfile)
    # initialise GRASS
    linkGRASS7(dem, 
               default_GRASS7=c("C:\\PROGRA~1\\QGIS3~1.2",
                                "grass-7.4.1",
                                "osgeo4W"))
    # write DEM into GRASS database
    writeRAST(as(dem, "SpatialGridDataFrame"), "dem")
}

# build OSM Overpass query for volcanoes >3000m within raster extent
q <- rwanda %>%
    opq() %>%
    add_osm_feature("natural", "volcano")
virunga <- osmdata_sf(q)$osm_points %>%
    select(osm_id, name, ele) %>%
    mutate(name=as.character(name),
           ele=as.numeric(as.character(ele))) %>%
    filter(ele>3000) %>%
    arrange(desc(ele)) %>%
    mutate(name=str_replace(name, "Mount ", "")) %>%
    mutate(name=str_replace(name, "Mg", "G"))

# create viewshed, if not yet existant
destfile <- "./output/muhabura_viewshed.tif"
if(!file.exists(destfile)) {
    # conduct viewshed analysis with GRASS
    execGRASS("r.viewshed", 
              flags=c("c", "b", "overwrite"), 
              parameters=list(input="dem", 
                              output="muhabura", 
                              coordinates=c(29.6779655,-1.3831871), 
                              observer_elevation=0,
                              target_elevation=1.75))
    # read result from GRASS database and adjust to original extent & CRS
    muhabura <- as(readRAST("muhabura"), "RasterLayer")
    extent(muhabura) <- extent(dem)
    crs(muhabura) <- crs(dem)
    # write to file
    writeRaster(muhabura, "./output/muhabura_viewshed.tif")
} else {
    # read viewshed raster from file
    muhabura <- raster(destfile)
    # write viewshed into GRASS database
    writeRAST(as(muhabura, "SpatialGridDataFrame"), "muhabura")
}


# plot
plot(dem, col=rev(grey(1:100/100)), legend=F)
plot(muhabura, alpha=.3, legend=F, add=T)
plot(virunga$geometry, pch=17, col="red", add=T)


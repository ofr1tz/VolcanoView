require(tidyverse)
require(sp)
require(raster)
require(rgrass7)
require(link2GI)
require(overpass)

# get Rwanda level 0 administrative borders
rwanda <- getData("GADM", country="RWA", level=0)

# initialise GRASS
linkGRASS7(srtm, 
           default_GRASS7=c("C:\\PROGRA~1\\QGIS3~1.2",
                            "grass-7.4.1",
                            "osgeo4W"))

# process Rwanda SRTM 30m data, if not existant
destfile <- "./output/Rwanda_SRTM30m_void_filled.tif"
if(!file.exists(destfile)) {
    # load, merge and crop SRTM tiles (source: https://earthexplorer.usgs.gov/)
    srtm <- crop(mosaic(raster("./data/s02_e028_1arc_v3.tif"),
                        raster("./data/s02_e029_1arc_v3.tif"),
                        raster("./data/s02_e030_1arc_v3.tif"),
                        raster("./data/s03_e028_1arc_v3.tif"),
                        raster("./data/s03_e029_1arc_v3.tif"),   
                        raster("./data/s03_e030_1arc_v3.tif"),
                        fun=mean),
                 rwanda)
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
    # write DEM into GRASS database
    writeRAST(as(dem, "SpatialGridDataFrame"), "dem")
}

# build OSM Overpass query for volcanoes >3000m within raster extent
q <- paste0("[out:csv(::id, ::lat, ::lon, 'name', 'ele')];",
            "(node['natural'='volcano']",
            "(",
            extent(dem)[3], ",",
            extent(dem)[1], ",",
            extent(dem)[4], ",",
            extent(dem)[2],
            ")",
            "(if:t['ele'] > 3000););",
            "out;")
# submit query
opq <- overpass_query(q)
# read into table
virunga <- read.table(text=opq, sep="\t", header=T, check.names=F, stringsAsFactors=F) 
names(virunga) <- c("id", "lat", "lon", "name", "ele")

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
plot(rwanda, add=T)
with(virunga, points(lon, lat, pch=17, col="red"))

require(tidyverse)
require(sp)
require(sf)
require(raster)
require(rgrass7)
require(link2GI)
require(osmdata)

# get Rwanda country administrative borders
rwanda <- getbb("Rwanda", featuretype="country")

# process Rwanda SRTM 30m data, if not existant
destfile <- "./output/Rwanda_SRTM30m_void_filled.tif"
if(!file.exists(destfile)) {
    # get correct elevation data for lake islands
    # download and extract processed SRTM data from RCMRD
    temp <- tempfile()
    download.file("https://s3.amazonaws.com/rcmrd-open-data/downloadable_files/Rwanda_SRTM30meters.zip",
                  temp)
    unzip(temp, "Rwanda_SRTM30meters.tif", exdir="./data")
    unlink(temp); rm(temp)
    # build OSM Overpass query for lake islands
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
                                "osgeo4W"),
               gisdbase="./temp",
               location="volcano")
    # write DEM into GRASS db
    writeRAST(as(srtm, "SpatialGridDataFrame"), "dem", overwrite=T)
    # fill voids
    execGRASS("r.fillnulls", 
              flags="overwrite",
              parameters=list(input="dem", 
                              output="dem", 
                              method="bilinear"))
    # read DEM from GRASS db and adjust extent & CRS to original
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
                                "osgeo4W"),
               gisdbase="./temp",
               location="volcano")
    # write DEM into GRASS db
    writeRAST(as(dem, "SpatialGridDataFrame"), "dem", overwrite=T)
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

# create (ca. 1670m) buffer around volcano OSM node coordinates
buffer <- st_buffer(virunga, 0.015)
# write buffer to file
st_write(buffer, "./output/buffer.gpkg")

# find summits according to DEM
# function: find highest elevation within buffer around volcano coordinates
find_summit <- function(volcano) {
    b <- filter(buffer, name==volcano)
    mask <- mask(crop(dem, extent(as(b, "Spatial"))),
                b,
                inverse=F,
                updatevalue=NA)
    coords <- coordinates(mask)
    coords %>% 
        as_tibble() %>%
        mutate(name=volcano,
               ele=raster::extract(mask, coords)) %>%
        filter(!is.na(ele)) %>%
        filter(ele==max(ele)) %>%
        head(1)
}
# find all summits
summits <- tribble(~x,~y,~name,~ele)
for(volcano in virunga$name) {
    summits <- bind_rows(summits, find_summit(volcano)) %>%
        arrange(desc(ele))
}
# write to csv file
write_delim(summits, "./output/virunga_summits.csv", ",")

# function: calculate viewshed for volcano summit
viewshed <- function(volcano) {
    destfile <- paste0("./output/", volcano, "_viewshed.tif")
    if(!file.exists(destfile)) {
        # set GRASS raster mask
        b <- filter(buffer, name==volcano)
        writeVECT(as(b, "Spatial"), "buffer")
        execGRASS("r.mask", 
                  flags="i",
                  parameters=list(vector="buffer"))
        execGRASS("g.rename",
                  parameters=list(raster="MASK,temp"))
        execGRASS("r.mapcalc", 
                  parameters=list(expression=paste0("MASK = if(row()-1 == int((",
                                                    ymax(dem),
                                                    "+",
                                                    abs(filter(summits, name==volcano)$y),
                                                    ")/",
                                                    yres(dem),
                                                    ") && col()-1 == int((",
                                                    filter(summits, name==volcano)$x,
                                                    "-", 
                                                    xmin(dem),
                                                    ")/",
                                                    xres(dem)
                                                    ,"), 1, temp)")))
        # conduct viewshed analysis with GRASS
        execGRASS("r.viewshed", 
                  flags=c("c", "b", "overwrite"), 
                  parameters=list(input="dem", 
                                  output=volcano, 
                                  coordinates=c(filter(summits, name==volcano)$x,
                                                filter(summits, name==volcano)$y), 
                                  observer_elevation=0,
                                  target_elevation=1.75))
        # read result from GRASS database and adjust to original extent & CRS
        view <- as(readRAST(volcano), "RasterLayer")
        extent(view) <- extent(dem)
        crs(view) <- crs(dem)
        # write to file
        writeRaster(view, destfile, overwrite=T)
        # remove GRASS raster mask and buffer
        execGRASS("r.mask", flags="r")
        execGRASS("g.remove", flags="f", parameters=list(name="buffer", type="vector"))
        execGRASS("g.remove", flags="f", parameters=list(name="temp", type="raster"))
    }
}
# calculate viewshed for all 8 vulcanos and save rasters as GeoTIFFs
# on your local computer, this may take some hours...
for(volcano in virunga$name) viewshed(volcano)


# plot
plot(dem, col=rev(grey(1:100/100)), legend=F)
plot(muhabura, alpha=.3, legend=F, add=T)
plot(summits$x, summits$y pch=17, col="red", add=T)


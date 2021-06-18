#' ---
#' title: Render 3D vistas of Virunga for VolcanoView
#' output: github_document
#' ---

#+ r options, include = F
knitr::opts_chunk$set(warning = F, message = F, eval = T)

#' This script renders 3D vistas of the 8 volcanoes of the Virunga chain. The
#' vistas are used as illustrations in the VolcanoView webmap project. The
#' script makes use of the *rayvista* package.
#+ r requirements
require(tidyverse)
require(sf)
require(rayshader)
require(rayvista)
require(glue)

#' Point geometries and attributes (name and elevation) were acquired from 
#' OpenStreetMap via the *osmdata* package.
#+ r read
virunga <- read_sf("../data/virunga.geojson") %>%
	mutate(lon = st_coordinates(.)[,1], lat = st_coordinates(.)[,2])

print(virunga)

#' This function plots a 3D vista of an individual volcano and renders a PNG
#' snapshot:
#+ r make, eval = F
render_volcano_vista = function(volcano, name) {
	
	vista <- plot_3d_vista(
		lat = volcano$lat, lon = volcano$lon,
		baseshape = "circle", radius = volcano$ele*.6,
		phi = 20, theta = 0, zscale = 5, zoom = .6,
		background = "#F8F8FF",
		windowsize = 150
	)

	render_snapshot(filename = glue("../img/{name}.png"), clear = TRUE)
}

#' Iterate the rendering function over all 8 volcanoes:
#+ r walk, eval = F
volcano <- virunga %>% 
	group_by(name) %>%
	group_walk(render_volcano_vista)

#' Resulting images:
#+ r show, figures-side, fig.show = "hold", out.width = "12.5%", echo = F
knitr::include_graphics(glue("../img/{virunga$name}.png"))
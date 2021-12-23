library(tidyverse)
library(sf)
library(spData)

world.u <- world %>%
  st_geometry() %>%
  st_union()


world.u %>%
  ggplot() +
  geom_sf()



middle_hemisphere <- rbind(
  c(-19, -90),
  c(160, -90),
  c(160, 90),
  c(-19, 90),
  c(-19, -90)
) %>% list() %>%
  st_polygon() %>%
  st_sfc()


fareast <- rbind(
  c(160, -90),
  c(180, -90),
  c(180, 90),
  c(160, 90),
  c(160, -90)
) %>% list() %>%
  st_polygon() %>%
  st_sfc()

western_hemisphere <- rbind(
  c(-21, -90),
  c(-180, -90),
  c(-180, 90),
  c(-21, 90),
  c(-21, -90)
) %>% list() %>%
  st_polygon() %>%
  st_sfc()


st_crs(middle_hemisphere) <- st_crs(western_hemisphere) <- st_crs(fareast) <- st_crs(world.u)

world.m <- world.u %>%
  st_intersection(middle_hemisphere)

world.w <- world.u %>%
  st_intersection(western_hemisphere)

world.e <- world.u %>%
  st_intersection(fareast)



st_transform(world.w, "+proj=robin lon_0=160.5") %>% 
  ggplot() + 
  geom_sf(fill='red') + 
  geom_sf(data=world.e, fill='blue') + 
  geom_sf(data=world.m, fill='green')




world.pac <- st_union(world.m, world.e) %>% 
  st_union(world.w) %>%
  st_transform("+proj=eqearth lon_0=160") 


world.pac %>%
  ggplot() +
  theme_bw() +
  geom_sf(fill='lightgray') 

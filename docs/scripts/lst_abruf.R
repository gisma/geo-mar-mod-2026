# Landsat 8/9: Sommertermine für das Untersuchungsgebiet abrufen
# Im RStudio-Projekt starten. Benötigt: rstac, sf, terra.
library(rstac)
library(sf)
library(terra)

# 1. Gebiet und Zeitraum
gebiet <- st_read("data/gebiet.gpkg")
zeitraum <- "2021-06-01T00:00:00Z/2025-08-31T23:59:59Z"
max_wolken <- 50       # Vorauswahl für die ganze Szene, nicht für Marburg
dir.create("data/landsat", recursive = TRUE, showWarnings = FALSE)

# 2. Szenen im öffentlichen Katalog suchen
bbox <- as.numeric(st_bbox(st_transform(gebiet, 4326)))
suche <- stac("https://planetarycomputer.microsoft.com/api/stac/v1") |>
  stac_search(collections = "landsat-c2-l2", bbox = bbox,
              datetime = zeitraum, limit = 100) |>
  post_request() |>
  items_fetch()
objekte <- suche$features
meta <- data.frame(
  id = sapply(objekte, function(x) x$id),
  datetime = sapply(objekte, function(x) x$properties$datetime),
  platform = sapply(objekte, function(x) x$properties$platform),
  cloud = sapply(objekte, function(x) x$properties[["eo:cloud_cover"]]),
  level = sapply(objekte, function(x) x$properties[["landsat:correction"]]),
  index = seq_along(objekte)
)
meta$date <- substr(meta$datetime, 1, 10)
monat <- as.integer(substr(meta$date, 6, 7))
meta <- meta[meta$platform %in% c("landsat-8", "landsat-9") &
             meta$level == "L2SP" & meta$cloud <= max_wolken &
             monat %in% 6:8, ]
# Ein Termin pro Tag: bei Überlappung die Szene mit weniger Gesamtbewölkung.
meta <- meta[order(meta$date, meta$cloud), ]
meta <- meta[!duplicated(meta$date), ]

# 3. Nur Temperatur- und Qualitätsband im Gebiet speichern
meta$st <- paste0("data/landsat/", meta$id, "_ST_B10.tif")
meta$qa <- paste0("data/landsat/", meta$id, "_QA_PIXEL.tif")
for (i in seq_len(nrow(meta))) {
  einzeln <- suche
  einzeln$features <- list(objekte[[meta$index[i]]])
  signiert <- items_sign(einzeln, sign_planetary_computer())
  assets <- signiert$features[[1]]$assets
  st <- rast(assets$lwir11$href)
  qa <- rast(assets$qa_pixel$href)
  ausschnitt <- project(vect(gebiet), crs(st))
  writeRaster(crop(st, ausschnitt), meta$st[i], overwrite = TRUE)
  writeRaster(crop(qa, ausschnitt), meta$qa[i], overwrite = TRUE)
}
write.csv(meta, "data/szenen.csv", row.names = FALSE)

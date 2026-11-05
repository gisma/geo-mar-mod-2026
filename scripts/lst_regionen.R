# Thermische Regionen aus zeitlichen Temperaturkennwerten
# Im RStudio-Projekt starten. Benötigt: terra, sf, supercells.
library(terra)
library(sf)
library(supercells)

# 1. Merkmale: mittleres Niveau und Abstand zum oberen Quantil
kennwerte <- rast("output/lst_kennwerte.tif")
names(kennwerte) <- c("mean", "q90", "q95")
merkmale <- c(kennwerte$mean, kennwerte$q95 - kennwerte$mean)
names(merkmale) <- c("niveau", "spanne")

# Gleiche Gewichtung der beiden Merkmale durch Standardisierung.
m <- global(merkmale, mean, na.rm = TRUE)[, 1]
s <- global(merkmale, sd, na.rm = TRUE)[, 1]
z <- (merkmale - m) / s

# 2. Eine Variante berechnen; k und Kompaktheit danach gezielt ändern.
k <- 30
kompaktheit <- 1
regionen <- supercells(z, k = k, compactness = kompaktheit)
regionen$region_id <- seq_len(nrow(regionen))
st_write(regionen, "output/regionen.gpkg", delete_dsn = TRUE)

# 3. Zeitliche Kennwerte innerhalb der Regionen räumlich mitteln.
tabelle <- extract(kennwerte, vect(regionen), fun = mean, na.rm = TRUE)
tabelle$region_id <- regionen$region_id[tabelle$ID]
write.csv(tabelle, "output/regionen_kennwerte.csv", row.names = FALSE)

# 4. Für jede Region die ursprüngliche Zeitreihe erneut auswerten.
stapel <- rast("output/lst_stapel.tif")
termine <- read.csv("output/termine.csv")
tabellen <- list()
for (i in seq_len(nlyr(stapel))) {
  x <- extract(stapel[[i]], vect(regionen), fun = mean, na.rm = TRUE)
  tabellen[[i]] <- data.frame(
    date = termine$date[i], region_id = regionen$region_id[x$ID],
    lst_c = x[, 2]
  )
}
write.csv(do.call(rbind, tabellen),
          "output/regionen_zeitreihe.csv", row.names = FALSE)

png("output/regionen.png", width = 1000, height = 900)
plot(kennwerte$mean, main = "Mittlere LST und thermische Regionen")
plot(st_geometry(regionen), add = TRUE, border = "black")
dev.off()

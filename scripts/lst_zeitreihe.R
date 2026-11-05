# Landsat-Zeitreihe und zeitliche Kennwerte
# Im RStudio-Projekt starten. Benötigt: terra.
library(terra)

# 1. Eingaben und Einstellungen
szenen <- read.csv("data/szenen.csv")
gebiet <- vect("data/gebiet.gpkg")
flaechen <- vect("data/flaechen.gpkg")  # Textfeld: area_id
auflösung <- 100                     # Rasterweite in Metern
min_beobachtungen <- 10              # Arbeitswert, keine Gütegrenze
dir.create("output", showWarnings = FALSE)

# 2. Gemeinsames Raster für alle Termine
gebiet <- project(gebiet, "EPSG:25832")
flaechen <- project(flaechen, "EPSG:25832")
raster <- rast(ext(gebiet), resolution = auflösung, crs = crs(gebiet))
temperaturen <- list()
tabellen <- list()

# 3. Je Termin: Qualität prüfen, in °C umrechnen, Flächen auswerten
for (i in seq_len(nrow(szenen))) {
  st <- rast(szenen$st[i])
  qa <- rast(szenen$qa[i])

  # QA_PIXEL: Bits 0–5 markieren Fill, Wolken, Schatten oder Schnee.
  ungueltig <- (qa %% 64) != 0
  lst <- ifel(ungueltig | st == 0, NA, st * 0.00341802 + 149 - 273.15)
  lst <- project(lst, raster, method = "near")
  lst <- mask(lst, gebiet)
  names(lst) <- "lst_c"
  temperaturen[[i]] <- lst

  # Pixelzentren bestimmen die Flächenzuordnung; keine Subpixelgewichtung.
  werte <- extract(lst, flaechen)
  flaechenwerte <- data.frame(
    date = szenen$date[i],
    area_id = flaechen$area_id,
    lst_c = NA_real_,
    valid_pixels = 0
  )
  for (j in seq_len(nrow(flaechen))) {
    x <- werte$lst_c[werte$ID == j]
    x <- x[!is.na(x)]
    flaechenwerte$valid_pixels[j] <- length(x)
    flaechenwerte$lst_c[j] <- median(x)
  }
  tabellen[[i]] <- flaechenwerte
}

# 4. Rasterzeitreihe und Tabelle speichern
stapel <- rast(temperaturen)
names(stapel) <- paste0("T", gsub("-", "", szenen$date))
writeRaster(stapel, "output/lst_stapel.tif", overwrite = TRUE)
write.csv(szenen, "output/termine.csv", row.names = FALSE)
zeitreihe <- do.call(rbind, tabellen)
write.csv(zeitreihe, "output/lst_zeitreihe.csv", row.names = FALSE)

# 5. Über die Zeit aggregieren: eine Rechnung je Rasterzelle
anzahl <- app(!is.na(stapel), sum)
mittel <- app(stapel, mean, na.rm = TRUE)
quantile <- app(stapel, function(x) {
  quantile(x, c(0.90, 0.95), na.rm = TRUE, names = FALSE)
})
kennwerte <- c(mittel, quantile)
names(kennwerte) <- c("mean", "q90", "q95")
kennwerte <- ifel(anzahl >= min_beobachtungen, kennwerte, NA)
names(kennwerte) <- c("mean", "q90", "q95")
writeRaster(kennwerte, "output/lst_kennwerte.tif", overwrite = TRUE)
writeRaster(anzahl, "output/lst_anzahl.tif", overwrite = TRUE)
writeRaster(kennwerte$q95 - kennwerte$mean,
            "output/lst_q95_minus_mean.tif", overwrite = TRUE)

# 6. Zeitreihe zeichnen
png("output/lst_zeitreihe.png", width = 1200, height = 700)
ids <- unique(zeitreihe$area_id)
farben <- seq_along(ids)
plot(as.Date(zeitreihe$date), zeitreihe$lst_c, type = "n",
     xlab = "Datum", ylab = "Flächenmedian der LST (°C)")
for (j in seq_along(ids)) {
  x <- zeitreihe[zeitreihe$area_id == ids[j], ]
  lines(as.Date(x$date), x$lst_c, type = "b", col = farben[j])
}
legend("topleft", legend = ids, col = farben, lty = 1, bty = "n")
dev.off()

# 7. Karten mit identischer Temperaturskala vergleichen
png("output/lst_kennwerte.png", width = 1500, height = 600)
plot(kennwerte, range = range(values(kennwerte), na.rm = TRUE))
dev.off()

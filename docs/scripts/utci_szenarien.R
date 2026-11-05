# UTCI unter zwei angenommenen Strahlungssituationen
library(comf)

# Alle Werte sind Szenarioannahmen, keine Messdaten aus Marburg.
szenarien <- data.frame(
  ort = c("besonnt", "verschattet"),
  luft = c(30, 30),
  strahlung = c(40, 32),
  wind_10m = c(1, 1),
  feuchte = c(50, 50)
)

szenarien$utci <- NA_real_
for (i in seq_len(nrow(szenarien))) {
  szenarien$utci[i] <- calcUTCI(
    ta = szenarien$luft[i],
    tr = szenarien$strahlung[i],
    vel = szenarien$wind_10m[i],
    rh = szenarien$feuchte[i]
  )
}
print(szenarien)

dir.create("output", showWarnings = FALSE)
write.csv(szenarien, "output/utci_szenarien.csv", row.names = FALSE)
png("output/utci_szenarien.png", width = 900, height = 650)
barplot(szenarien$utci, names.arg = szenarien$ort,
        ylab = "UTCI (°C)", col = c("tomato", "steelblue"))
dev.off()

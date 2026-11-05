"""UTCI und PET vergleichen: Umweltszenarien und Personenannahmen.

Start im Projektordner: python scripts/thermische_indizes.py
Installation: python -m pip install -r scripts/requirements-thermik.txt
Alle Eingaben sind Annahmen, keine Messungen aus Marburg.
Quellen und Aufgaben: pages/ws/ws-02.qmd
"""

import csv
import json
from importlib.metadata import version
from pathlib import Path

from pythermalcomfort.models import pet_steady, utci


# Umweltannahmen. Die beiden Windgeschwindigkeiten beziehen sich auf
# verschiedene Höhen. Sie sind hier separat angenommen, nicht umgerechnet.
# Eine reale Anwendung benötigt passende Messungen oder ein geprüftes Profil.
UMWELT = [
    dict(ort="besonnt", luft_c=30.0, strahlung_c=40.0,
         feuchte_prozent=50.0, wind_10m_ms=1.0, wind_person_ms=0.5),
    dict(ort="verschattet", luft_c=30.0, strahlung_c=32.0,
         feuchte_prozent=50.0, wind_10m_ms=1.0, wind_person_ms=0.5),
]

# Festgehaltene PET-Eingaben; diese Person ist keine UTCI-Referenzperson.
# Die Körperhaltung bleibt auch bei höherer metabolischer Leistung gleich,
# damit deren rechnerischer Einfluss einzeln untersucht werden kann.
PERSON = dict(age=35, sex="male", weight=75.0, height=1.75,
              position="standing", wme=0.0, p_atm=1013.25)
BASIS_MET = 1.2
BASIS_CLO = 0.5
MET_VARIANTEN = [1.2, 2.3, 3.5]  # Modellannahmen, keine Tätigkeitsmessungen
CLO_VARIANTEN = [0.5, 0.9]
WIND_PERSON_VARIANTEN = [0.3, 0.5, 0.7]


def pet(umwelt, met, clo, wind_person=None):
    """Stationäre PET-Implementierung; keine Expositionszeit als Eingabe."""
    return float(pet_steady(
        tdb=umwelt["luft_c"], tr=umwelt["strahlung_c"],
        rh=umwelt["feuchte_prozent"],
        v=umwelt["wind_person_ms"] if wind_person is None else wind_person,
        met=met, clo=clo, **PERSON,
    ).pet)


def utci_umwelt(umwelt):
    # met und clo sind hier bewusst keine Eingaben: UTCI setzt seine eigenen
    # Aktivitäts- und Bekleidungsannahmen voraus.
    return float(utci(
        tdb=umwelt["luft_c"], tr=umwelt["strahlung_c"],
        rh=umwelt["feuchte_prozent"], v=umwelt["wind_10m_ms"],
        limit_inputs=True, round_output=False,
    ).utci)


def schreibe_csv(pfad, zeilen):
    with pfad.open("w", newline="", encoding="utf-8") as datei:
        writer = csv.DictWriter(datei, fieldnames=list(zeilen[0]))
        writer.writeheader()
        writer.writerows(zeilen)


def main():
    ausgabe = Path("output/thermische_indizes")
    ausgabe.mkdir(parents=True, exist_ok=True)
    vergleich = []
    personen = []
    wind = []
    for umwelt in UMWELT:
        utc = utci_umwelt(umwelt)
        vergleich.append(dict(
            **umwelt, pet_met=BASIS_MET, pet_clo=BASIS_CLO,
            utci_c=utc, pet_c=pet(umwelt, BASIS_MET, BASIS_CLO),
        ))
        for met in MET_VARIANTEN:
            for clo in CLO_VARIANTEN:
                personen.append(dict(
                    **umwelt, pet_met=met, pet_clo=clo,
                    pet_c=pet(umwelt, met, clo),
                    # Gleicher UTCI-Umweltwert, keine Aussage zur PET-Person.
                    utci_umwelt_c=utc,
                ))
        for v in WIND_PERSON_VARIANTEN:
            wind.append(dict(
                **{**umwelt, "wind_person_ms": v},
                pet_met=BASIS_MET, pet_clo=BASIS_CLO,
                pet_c=pet(umwelt, BASIS_MET, BASIS_CLO, v),
            ))

    schreibe_csv(ausgabe / "umweltvergleich.csv", vergleich)
    schreibe_csv(ausgabe / "pet_personenannahmen.csv", personen)
    schreibe_csv(ausgabe / "pet_windannahmen.csv", wind)
    (ausgabe / "annahmen.json").write_text(json.dumps(dict(
        bibliothek="pythermalcomfort", version=version("pythermalcomfort"),
        pet_funktion="pet_steady", pet_person=PERSON,
        umwelt=UMWELT, met_varianten=MET_VARIANTEN,
        clo_varianten=CLO_VARIANTEN, wind_person_varianten=WIND_PERSON_VARIANTEN,
        hinweis="Szenarien; PET stationär; UTCI mit eigener Referenzperson. "
                "Indexwerte und Belastungsklassen nicht gleichsetzen.",
    ), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for zeile in vergleich:
        print(f"{zeile['ort']}: UTCI {zeile['utci_c']:.2f} °C; "
              f"PET {zeile['pet_c']:.2f} °C (eigene Referenzbedingungen)")
    print(f"Tabellen und Annahmen gespeichert unter {ausgabe}")


if __name__ == "__main__":
    main()

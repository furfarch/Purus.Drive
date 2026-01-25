import Foundation

enum ChecklistTemplates {
    static func items(for type: VehicleType) -> [ChecklistItem] {
        switch type {
        case .truck:
            return truck()
        case .car, .van:
            return carVan()
        case .trailer:
            return trailer()
        case .camper:
            return camper()
        case .boat:
            return boat()
        case .motorbike:
            return motorbikeScooter(isScooter: false)
        case .scooter:
            return motorbikeScooter(isScooter: true)
        case .other:
            return other()
        }
    }

    private static func truck() -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        // FRONT UND MOTORRAUM
        items += section("FRONT UND MOTORRAUM", ["BELEUCHTUNG"])
        items += subsection("FRONT UND MOTORRAUM", "BELEUCHTUNG", [
            "Abblendlicht",
            "Fernlicht",
            "Blinker",
            "Warnblinkanlage",
            "Nebelscheinwerfer",
            "Kennzeichenbeleuchtung",
            "Umrissleuchten",
        ])
        items += section("FRONT UND MOTORRAUM", ["AUSSENEQUIPMENT"])
        items += subsection("FRONT UND MOTORRAUM", "AUSSENEQUIPMENT", [
            "Aussenspiegel",
            "Kennzeichen (sauber!)",
            "Windschutzscheibe",
            "Scheibenwaschanlage",
        ])
        items += section("FRONT UND MOTORRAUM", ["MOTORRAUM"])
        items += subsection("FRONT UND MOTORRAUM", "MOTORRAUM", [
            "Motorhaube/ Motorraum",
            "Kühlflüssigkeit",
            "Ölstand Motor/ Augenfälliger",
            "Öl- oder Kraftstoffverlust",
            "Bremsflüssigkeit",
        ])

        // KONTROLLEN SEITE
        items += section("KONTROLLEN SEITE", ["BELEUCHTUNG"])
        items += subsection("KONTROLLEN SEITE", "BELEUCHTUNG", [
            "Seitliche Rückstrahler",
            "Umrissleuchten",
        ])
        items += section("KONTROLLEN SEITE", ["AUSSENEQUIPMENT"])
        items += subsection("KONTROLLEN SEITE", "AUSSENEQUIPMENT", [
            "Luftfilter",
            "Tank",
            "Anschlüsse/ Batterie",
            "Bordverschlüsse/ Plane",
            "Sattelkupplung",
        ])
        items += section("KONTROLLEN SEITE", ["REIFEN"])
        items += subsection("KONTROLLEN SEITE", "REIFEN", [
            "Felgen / Radschüsseln",
            "Reifenzustand (Schäden)",
            "Profil",
            "Luftdruck",
        ])

        // HINTEN/ LADERAUM
        items += section("HINTEN/ LADERAUM", ["BELEUCHTUNG LADUNG/ SICHERUNG"])
        items += subsection("HINTEN/ LADERAUM", "BELEUCHTUNG LADUNG/ SICHERUNG", [
            "Schlussleuchten",
            "Bremsleuchten",
            "Rückstrahler",
            "Kennzeichenbeleuchtung",
            "Nebelschlussleuchte",
        ])
        items += section("HINTEN/ LADERAUM", ["AUSSENEQUIPMENT"])
        items += subsection("HINTEN/ LADERAUM", "AUSSENEQUIPMENT", [
            "Kennzeichen",
        ])
        items += section("HINTEN/ LADERAUM", ["LADERAUM"])
        items += subsection("HINTEN/ LADERAUM", "LADERAUM", [
            "Ladungssicherung gewährleistet",
            "Ausreichend Spanngurte/ Ketten vorhanden",
            "Zurrmittel/ Antirutschmatten",
            "Befestigung und Sicherung von Wechselaufbauten,Behältern und Containern",
        ])

        items += section("LADUNG", [])
        items += subsection("LADUNG", "LADUNG", [
            "Ladung gesichert",
        ])

        items += section("FAHRERKABINE", [])
        items += subsection("FAHRERKABINE", "FAHRERKABINE", [
            "Kontrolleuchten",
            "Lenkspiel",
            "Kraftstoffvorrat",
            "Signalhorn",
            "Druckmanometer",
            "Bremstest",
            "Rückspiegel",
            "Sitz-/Pedalprüfung",
            "Warnleuchte, Heizung",
            "Bedienelemente",
        ])

        items += section("KONTROLLGERÄT", [])
        items += subsection("KONTROLLGERÄT", "KONTROLLGERÄT", [
            "Ordnungsgemäße Funktion des Kontrollgerätes gewährleistet",
            "Plombierung in Ordnung",
            "Leuchtet die Funktionskontrollleuchte",
            "Ausreichende Anzahl von Ersatzrollen bei Verwendung eines",
            "digitalen Kontrollgerätes",
            "Ausreichende Anzahl der richtigen Schaublätter dabei",
            "Tätigkeitsnachweise der vorausgegangen 28 Kalendertage",
        ])

        items += section("AUSRÜSTUNG", [])
        items += subsection("AUSRÜSTUNG", "AUSRÜSTUNG", [
            "Verbandskasten",
            "Warndreieck",
            "Warnweste (griffbereit, DIN-Norm)",
            "Fuerlöscher (falls vorgeschrieben/nötig)",
        ])

        items += section("DOKUMENTE", [])
        items += subsection("DOKUMENTE", "DOKUMENTE", [
            "Führerschein (gültig)",
            "Fahrzeugpapiere",
            "Zulassungsbescheinigung",
            "Frachtpapiere (CMR, Lieferschein, Rechnung)",
            "Ladungspapiere",
        ])

        items += section("ABMESSUNGEN UND GEWICHT", [])

        items += section("ROUTEN- & TRANSPORTPLANUNG", [])
        items += subsection("ROUTEN- & TRANSPORTPLANUNG", "ROUTEN- & TRANSPORTPLANUNG", [
            "Route: Brücken, Tunnel, Durchfahrtsbeschränkungen (Höhe, Breite, Gewicht) prüfen.",
            "Fahrverbote: Sonn- und Feiertagsfahrverbote (z.B. Schweiz) beachten.",
        ])

        items += section("WINTERBETRIEB", [])
        items += subsection("WINTERBETRIEB", "WINTERBETRIEB", [
            "Ordnungsgemäße Bereifung",
            "Schneeketten – Anfahrhilfen",
            "Frostschutz – Kühlflüssigkeit",
            "Frostschutz Scheibenwaschanlage",
            "Frostschutz Scheinwerferwaschanlage",
            "Hilfsmittel zur Enteisung (Eiskratzer, Enteisungsspray)",
            "Decke",
            "Fahrzeug und Planen von Schnee und Eis befreit",
        ])
        return items
    }

    private static func carVan() -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        // FRONT UND MOTORRAUM (AUSSENEQUIPMENT moved here to match Truck)
        items += section("FRONT UND MOTORRAUM", ["BELEUCHTUNG", "AUSSENEQUIPMENT"])
        items += subsection("FRONT UND MOTORRAUM", "BELEUCHTUNG", [
            "Abblendlicht",
            "Fernlicht",
            "Blinker",
            "Warnblinkanlage",
            "Nebelscheinwerfer",
            "Kennzeichenbeleuchtung",
        ])
        items += subsection("FRONT UND MOTORRAUM", "AUSSENEQUIPMENT", [
            "Aussenspiegel",
            "Kennzeichen (sauber!)",
            "Windschutzscheibe",
            "Scheibenwaschanlage",
        ])

        // KONTROLLEN SEITE
        items += section("KONTROLLEN SEITE", ["REIFEN"])
        items += subsection("KONTROLLEN SEITE", "REIFEN", [
            "Felgen / Radschüsseln",
            "Reifenzustand (Schäden)",
            "Profil",
            "Luftdruck",
        ])

        // HINTEN/ LADERAUM
        items += section("HINTEN/ LADERAUM", ["BELEUCHTUNG"])
        items += subsection("HINTEN/ LADERAUM", "BELEUCHTUNG", [
            "Schlussleuchten",
            "Bremsleuchten",
            "Rückstrahler",
            "Kennzeichenbeleuchtung",
            "Nebelschlussleuchte",
        ])

        items += section("AUSRÜSTUNG", [])
        items += subsection("AUSRÜSTUNG", "AUSRÜSTUNG", [
            "Verbandskasten",
            "Warndreieck",
            "Warnweste (griffbereit, DIN-Norm)",
            "Fuerlöscher (falls vorgeschrieben/nötig)",
        ])

        items += section("DOKUMENTE", [])
        items += subsection("DOKUMENTE", "DOKUMENTE", [
            "Führerschein (gültig)",
            "Fahrzeugpapiere",
            "Zulassungsbescheinigung",
            "Ladungspapiere",
        ])

        items += section("ABMESSUNGEN UND GEWICHT", [])
        return items
    }

    private static func trailer() -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        items += section("KONTROLLEN SEITE", ["BELEUCHTUNG"])
        items += subsection("KONTROLLEN SEITE", "BELEUCHTUNG", [
            "Seitliche Rückstrahler",
            "Umrissleuchten",
        ])

        items += section("AUSSENEQUIPMENT", [])
        items += subsection("AUSSENEQUIPMENT", "AUSSENEQUIPMENT", [
            "Kupplung",
        ])

        items += section("REIFEN", [])
        items += subsection("REIFEN", "REIFEN", [
            "Felgen / Radschüsseln",
            "Reifenzustand (Schäden)",
            "Profil",
            "Luftdruck",
        ])

        items += section("HINTEN/ LADERAUM", ["BELEUCHTUNG LADUNG/ SICHERUNG"])
        items += subsection("HINTEN/ LADERAUM", "BELEUCHTUNG LADUNG/ SICHERUNG", [
            "Schlussleuchten",
            "Bremsleuchten",
            "Rückstrahler",
            "Kennzeichenbeleuchtung",
            "Nebelschlussleuchte",
        ])

        items += section("AUSSENEQUIPMENT (HINTEN)", [])
        items += subsection("AUSSENEQUIPMENT (HINTEN)", "AUSSENEQUIPMENT (HINTEN)", [
            "Kennzeichen",
        ])

        items += section("LADERAUM", [])
        items += subsection("LADERAUM", "LADERAUM", [
            "Ladungssicherung gewährleistet",
            "Ausreichend Spanngurte/ Ketten vorhanden",
            "Zurrmittel/ Antirutschmatten",
            "Befestigung und Sicherung von Wechselaufbauten,Behältern und Containern",
        ])

        items += section("LADUNG", [])
        items += subsection("LADUNG", "LADUNG", [
            "Ladung gesichert",
        ])

        items += section("DOKUMENTE", [])
        items += subsection("DOKUMENTE", "DOKUMENTE", [
            "Fahrzeugpapiere",
        ])

        items += section("ABMESSUNGEN UND GEWICHT", [])
        return items
    }

    // 1) OTHER: same as Car/Van + ANDERES section with ANDERS item + note field
    private static func other() -> [ChecklistItem] {
        var items = carVan()
        items += section("ANDERES", [])
        items.append(ChecklistItem(section: "ANDERES", title: "ANDERS", state: .notSelected, note: ""))
        return items
    }

    // 2) CAMPER: same as Car/Van + CAMPING section + extra items in LADERAUM
    private static func camper() -> [ChecklistItem] {
        var items = carVan()

        items += section("CAMPING", ["ESSENTIALS"])
        items += subsection("CAMPING", "ESSENTIALS", [
            "Wasser",
            "Strom",
            "Gas",
            "Ausrüstung",
        ])

        // Add to HINTEN/ LADERAUM: LADERAUM items
        items += section("HINTEN/ LADERAUM", ["LADERAUM"])
        items += subsection("HINTEN/ LADERAUM", "LADERAUM", [
            "Schränke gesichert",
            "Gegenstände gesichert",
        ])

        return items
    }

    // 3) BOAT
    private static func boat() -> [ChecklistItem] {
        var items: [ChecklistItem] = []

        items += section("BOOT", [])
        items += subsection("BOOT", "BOOT", [
            "Rumpf",
            "Ruder",
            "Motor",
            "Batterie",
            "Navigation",
            "Leinen",
            "Anker",
        ])

        items += section("AUSRÜSTUNG", [])
        items += subsection("AUSRÜSTUNG", "AUSRÜSTUNG", [
            "Verbandskasten",
            "Warndreieck",
            "Warnweste (griffbereit, DIN-Norm)",
            "Fuerlöscher (falls vorgeschrieben/nötig)",
            "Persönliche Schwimmwesten",
            "Signalgeräte / Notsignal",
        ])

        items += section("DOKUMENTE", [])
        items += subsection("DOKUMENTE", "DOKUMENTE", [
            "Führerschein (gültig)",
            "Fahrzeugpapiere",
            "Zulassungsbescheinigung",
        ])

        items += section("ROUTEN- & TRANSPORTPLANUNG", [])
        items += subsection("ROUTEN- & TRANSPORTPLANUNG", "ROUTEN- & TRANSPORTPLANUNG", [
            "Wetterbedingungen",
            "Route (Wasserwege, Schleussen)",
        ])

        return items
    }

    // 4) MOTORBIKE & SCOOTER: Car/Van without scheibenwaschanlage, Feuerlöscher, Ladungspapiere, Abmessungen und Gewicht
    private static func motorbikeScooter(isScooter: Bool) -> [ChecklistItem] {
        var items: [ChecklistItem] = []

        items += section("FRONT UND MOTORRAUM", ["BELEUCHTUNG", "AUSSENEQUIPMENT"])
        items += subsection("FRONT UND MOTORRAUM", "BELEUCHTUNG", [
            "Abblendlicht",
            "Fernlicht",
            "Blinker",
            "Warnblinkanlage",
            "Nebelscheinwerfer",
            "Kennzeichenbeleuchtung",
        ])
        items += subsection("FRONT UND MOTORRAUM", "AUSSENEQUIPMENT", [
            "Aussenspiegel",
            "Kennzeichen (sauber!)",
            "Windschutzscheibe",
        ])

        items += section("KONTROLLEN SEITE", ["REIFEN"])
        items += subsection("KONTROLLEN SEITE", "REIFEN", [
            "Felgen / Radschüsseln",
            "Reifenzustand (Schäden)",
            "Profil",
            "Luftdruck",
        ])

        items += section("HINTEN/ LADERAUM", ["BELEUCHTUNG"])
        items += subsection("HINTEN/ LADERAUM", "BELEUCHTUNG", [
            "Schlussleuchten",
            "Bremsleuchten",
            "Rückstrahler",
            "Kennzeichenbeleuchtung",
            "Nebelschlussleuchte",
        ])

        items += section("AUSRÜSTUNG", [])
        items += subsection("AUSRÜSTUNG", "AUSRÜSTUNG", [
            "Verbandskasten",
            "Warndreieck",
            "Warnweste (griffbereit, DIN-Norm)",
        ])

        items += section("DOKUMENTE", [])
        items += subsection("DOKUMENTE", "DOKUMENTE", [
            "Führerschein (gültig)",
            "Fahrzeugpapiere",
            "Zulassungsbescheinigung",
        ])

        _ = isScooter
        return items
    }

    static func sectionOrder(for type: VehicleType) -> [String] {
        switch type {
        case .truck:
            return [
                "FRONT UND MOTORRAUM",
                "KONTROLLEN SEITE",
                "HINTEN/ LADERAUM",
                "AUSRÜSTUNG",
                "FAHRERKABINE",
                "KONTROLLGERÄT",
                "LADUNG",
                "DOKUMENTE",
                "ABMESSUNGEN UND GEWICHT",
                "ROUTEN- & TRANSPORTPLANUNG",
                "WINTERBETRIEB",
            ]
        case .car, .van:
            return [
                "FRONT UND MOTORRAUM",
                "KONTROLLEN SEITE",
                "HINTEN/ LADERAUM",
                "AUSRÜSTUNG",
                "DOKUMENTE",
                "ABMESSUNGEN UND GEWICHT",
            ]
        case .camper:
            return [
                "FRONT UND MOTORRAUM",
                "KONTROLLEN SEITE",
                "HINTEN",
                "CAMPING",
                "AUSRÜSTUNG",
                "DOKUMENTE",
                "ABMESSUNGEN UND GEWICHT",
            ]
        case .trailer:
            return [
                "KONTROLLEN SEITE",
                "AUSSENEQUIPMENT",
                "REIFEN",
                "HINTEN/ LADERAUM",
                "AUSSENEQUIPMENT (HINTEN)",
                "LADERAUM",
                "LADUNG",
                "DOKUMENTE",
                "ABMESSUNGEN UND GEWICHT",
            ]
        case .boat:
            return [
                "BOOT",
                "AUSRÜSTUNG",
                "DOKUMENTE",
                "ROUTEN- & TRANSPORTPLANUNG",
            ]
        case .motorbike, .scooter:
            return [
                "FRONT UND MOTORRAUM",
                "KONTROLLEN SEITE",
                "HINTEN/ LADERAUM",
                "AUSRÜSTUNG",
                "DOKUMENTE",
            ]
        case .other:
            return [
                "FRONT UND MOTORRAUM",
                "KONTROLLEN SEITE",
                "HINTEN/ LADERAUM",
                "AUSRÜSTUNG",
                "DOKUMENTE",
                "ABMESSUNGEN UND GEWICHT",
                "ANDERES",
            ]
        }
    }

    static func subsectionOrderBySection(for type: VehicleType) -> [String: [String]] {
        // Provides subgroup headers (ALL CAPS) so ChecklistEditorView can bucket items.
        switch type {
        case .truck:
            return [
                "FRONT UND MOTORRAUM": ["BELEUCHTUNG", "AUSSENEQUIPMENT", "MOTORRAUM"],
                "KONTROLLEN SEITE": ["BELEUCHTUNG", "AUSSENEQUIPMENT", "REIFEN"],
                "HINTEN/ LADERAUM": ["BELEUCHTUNG LADUNG/ SICHERUNG", "AUSSENEQUIPMENT", "LADERAUM"],
                "LADUNG": ["LADUNG"],
                "FAHRERKABINE": ["FAHRERKABINE"],
                "KONTROLLGERÄT": ["KONTROLLGERÄT"],
                "AUSRÜSTUNG": ["AUSRÜSTUNG"],
                "DOKUMENTE": ["DOKUMENTE"],
                "ROUTEN- & TRANSPORTPLANUNG": ["ROUTEN- & TRANSPORTPLANUNG"],
                "WINTERBETRIEB": ["WINTERBETRIEB"],
            ]
        case .car, .van:
            return [
                "FRONT UND MOTORRAUM": ["BELEUCHTUNG", "AUSSENEQUIPMENT"],
                "KONTROLLEN SEITE": ["REIFEN"],
                "HINTEN/ LADERAUM": ["BELEUCHTUNG"],
                "AUSRÜSTUNG": ["AUSRÜSTUNG"],
                "DOKUMENTE": ["DOKUMENTE"],
            ]
        case .camper:
            return [
                "FRONT UND MOTORRAUM": ["BELEUCHTUNG", "AUSSENEQUIPMENT"],
                "KONTROLLEN SEITE": ["REIFEN"],
                "HINTEN": ["LADERAUM"],
                "CAMPING": ["ESSENTIALS"],
                "AUSRÜSTUNG": ["AUSRÜSTUNG"],
                "DOKUMENTE": ["DOKUMENTE"],
            ]
        case .trailer:
            return [
                "KONTROLLEN SEITE": ["BELEUCHTUNG"],
                "AUSSENEQUIPMENT": ["AUSSENEQUIPMENT"],
                "REIFEN": ["REIFEN"],
                "HINTEN/ LADERAUM": ["BELEUCHTUNG LADUNG/ SICHERUNG"],
                "AUSSENEQUIPMENT (HINTEN)": ["AUSSENEQUIPMENT (HINTEN)"],
                "LADERAUM": ["LADERAUM"],
                "LADUNG": ["LADUNG"],
                "DOKUMENTE": ["DOKUMENTE"],
            ]
        case .boat:
            return [
                "BOOT": ["BOOT"],
                "AUSRÜSTUNG": ["AUSRÜSTUNG"],
                "DOKUMENTE": ["DOKUMENTE"],
                "ROUTEN- & TRANSPORTPLANUNG": ["ROUTEN- & TRANSPORTPLANUNG"],
            ]
        case .motorbike, .scooter:
            return [
                "FRONT UND MOTORRAUM": ["BELEUCHTUNG", "AUSSENEQUIPMENT"],
                "KONTROLLEN SEITE": ["REIFEN"],
                "HINTEN/ LADERAUM": ["BELEUCHTUNG"],
                "AUSRÜSTUNG": ["AUSRÜSTUNG"],
                "DOKUMENTE": ["DOKUMENTE"],
            ]
        case .other:
            return [
                "FRONT UND MOTORRAUM": ["BELEUCHTUNG", "AUSSENEQUIPMENT"],
                "KONTROLLEN SEITE": ["REIFEN"],
                "HINTEN/ LADERAUM": ["BELEUCHTUNG"],
                "AUSRÜSTUNG": ["AUSRÜSTUNG"],
                "DOKUMENTE": ["DOKUMENTE"],
                "ANDERES": ["Verschiedenes (Notiz)"],
            ]
        }
    }

    // Helpers to create items for sections and subsections
    private static func section(_ name: String, _ subsections: [String]) -> [ChecklistItem] {
        // Do not create placeholder items for headers/subheaders.
        // Section/subsection presentation is handled in the UI.
        return []
    }

    private static func subsection(_ section: String, _ name: String, _ titles: [String]) -> [ChecklistItem] {
        titles.map { ChecklistItem(section: section, title: $0, state: .notSelected) }
    }
}

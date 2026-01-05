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
        default:
            return []
        }
    }

    private static func truck() -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        // FRONT UND MOTORRAUM
        items += section("FRONT UND MOTORRAUM", [
            "Beleuchtung",
        ])
        items += subsection("FRONT UND MOTORRAUM", "Beleuchtung", [
            "Abblendlicht",
            "Fernlicht",
            "Blinker",
            "Warnblinkanlage",
            "Nebelscheinwerfer",
            "Kennzeichenbeleuchtung",
            "Umrissleuchten",
        ])
        items += section("FRONT UND MOTORRAUM", [
            "AUSSENEQUIPMENT",
        ])
        items += subsection("FRONT UND MOTORRAUM", "AUSSENEQUIPMENT", [
            "Aussenspiegel",
            "Kennzeichen (sauber!)",
            "Windschutzscheibe",
            "Scheibenwaschanlage",
        ])
        items += section("FRONT UND MOTORRAUM", [
            "MOTORRAUM",
        ])
        items += subsection("FRONT UND MOTORRAUM", "MOTORRAUM", [
            "Motorhaube/ Motorraum",
            "Kühlflüssigkeit",
            "Ölstand Motor/ Augenfälliger",
            "Öl- oder Kraftstoffverlust",
            "Bremsflüssigkeit",
        ])
        // KONTROLLEN SEITE
        items += section("KONTROLLEN SEITE", [
            "BELEUCHTUNG",
        ])
        items += subsection("KONTROLLEN SEITE", "BELEUCHTUNG", [
            "Seitliche Rückstrahler",
            "Umrissleuchten",
        ])
        items += section("KONTROLLEN SEITE", [
            "AUSSENEQUIPMENT",
        ])
        items += subsection("KONTROLLEN SEITE", "AUSSENEQUIPMENT", [
            "Luftfilter",
            "Tank",
            "Anschlüsse/ Batterie",
            "Bordverschlüsse/ Plane",
            "Sattelkupplung",
        ])
        items += section("KONTROLLEN SEITE", [
            "REIFEN",
        ])
        items += subsection("KONTROLLEN SEITE", "REIFEN", [
            "Felgen / Radschüsseln",
            "Reifenzustand (Schäden)",
            "Profil",
            "Luftdruck",
        ])
        // HINTEN/ LADERAUM
        items += section("HINTEN/ LADERAUM", [
            "BELEUCHTUNG LADUNG/ SICHERUNG",
        ])
        items += subsection("HINTEN/ LADERAUM", "BELEUCHTUNG LADUNG/ SICHERUNG", [
            "Schlussleuchten",
            "Bremsleuchten",
            "Rückstrahler",
            "Kennzeichenbeleuchtung",
            "Nebelschlussleuchte",
        ])
        items += section("HINTEN/ LADERAUM", [
            "AUSSENEQUIPMENT",
        ])
        items += subsection("HINTEN/ LADERAUM", "AUSSENEQUIPMENT", [
            "Kennzeichen",
        ])
        items += section("HINTEN/ LADERAUM", [
            "LADERAUM",
        ])
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
        items += section("Dokumente", [])
        items += subsection("Dokumente", "Dokumente", [
            "Führerschein (gültig)",
            "Fahrzeugpapiere",
            "Zulassungsbescheinigung",
            "Frachtpapiere (CMR, Lieferschein, Rechnung)",
            "Ladungspapiere",
        ])
        items += section("Abmessungen und Gewicht", [])
        items += section("Routen- & Transportplanung", [])
        items += subsection("Routen- & Transportplanung", "Routen- & Transportplanung", [
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
        // FRONT UND MOTORRAUM
        items += section("FRONT UND MOTORRAUM", [
            "Beleuchtung",
        ])
        items += subsection("FRONT UND MOTORRAUM", "Beleuchtung", [
            "Abblendlicht",
            "Fernlicht",
            "Blinker",
            "Warnblinkanlage",
            "Nebelscheinwerfer",
            "Kennzeichenbeleuchtung",
        ])
        items += section("AUSSENEQUIPMENT", [])
        items += subsection("AUSSENEQUIPMENT", "AUSSENEQUIPMENT", [
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
        items += section("Dokumente", [])
        items += subsection("Dokumente", "Dokumente", [
            "Führerschein (gültig)",
            "Fahrzeugpapiere",
            "Zulassungsbescheinigung",
            "Ladungspapiere",
        ])
        items += section("Abmessungen und Gewicht", [])
        return items
    }

    private static func trailer() -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        // KONTROLLEN SEITE
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
        // HINTEN/ LADERAUM
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
        items += section("Dokumente", [])
        items += subsection("Dokumente", "Dokumente", [
            "Fahrzeugpapiere",
        ])
        items += section("Abmessungen und Gewicht", [])
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
                "Dokumente",
                "Abmessungen und Gewicht",
            ]
        case .car, .van:
            return [
                "FRONT UND MOTORRAUM",
                "AUSSENEQUIPMENT",
                "KONTROLLEN SEITE",
                "HINTEN/ LADERAUM",
                "AUSRÜSTUNG",
                "Dokumente",
                "Abmessungen und Gewicht",
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
                "Dokumente",
                "Abmessungen und Gewicht",
            ]
        default:
            return []
        }
    }

    static func subsectionOrderBySection(for type: VehicleType) -> [String: [String]] {
        switch type {
        case .truck:
            return [
                "FRONT UND MOTORRAUM": [
                    "BELEUCHTUNG",
                    "Abblendlicht",
                    "Fernlicht",
                    "Blinker",
                    "Warnblinkanlage",
                    "Nebelscheinwerfer",
                    "Kennzeichenbeleuchtung",
                    "Umrissleuchten",
                    "AUSSENEQUIPMENT",
                    "Aussenspiegel",
                    "Kennzeichen (sauber!)",
                    "Windschutzscheibe",
                    "Scheibenwaschanlage",
                    "MOTORRAUM",
                    "Motorhaube/ Motorraum",
                    "Kühlflüssigkeit",
                    "Ölstand Motor/ Augenfälliger",
                    "Öl- oder Kraftstoffverlust",
                    "Bremsflüssigkeit",
                ],
                "KONTROLLEN SEITE": [
                    "BELEUCHTUNG",
                    "Seitliche Rückstrahler",
                    "Umrissleuchten",
                    "REIFEN",
                    "Felgen / Radschüsseln",
                    "Reifenzustand (Schäden)",
                    "Profil",
                    "Luftdruck",
                    "AUSSENEQUIPMENT",
                    "Luftfilter",
                    "Tank",
                    "Anschlüsse/ Batterie",
                    "Bordverschlüsse/ Plane",
                    "Sattelkupplung",
                ],
                "HINTEN/ LADERAUM": [
                    "BELEUCHTUNG LADUNG/ SICHERUNG",
                    "Schlussleuchten",
                    "Bremsleuchten",
                    "Rückstrahler",
                    "Kennzeichenbeleuchtung",
                    "Nebelschlussleuchte",
                    "AUSSENEQUIPMENT",
                    "Kennzeichen",
                    "LADERAUM",
                    "Ladungssicherung gewährleistet",
                    "Ausreichend Spanngurte/ Ketten vorhanden",
                    "Zurrmittel/ Antirutschmatten",
                    "Befestigung und Sicherung von Wechselaufbauten,Behältern und Containern",
                ],
                "AUSRÜSTUNG": [
                    "Verbandskasten",
                    "Warndreieck",
                    "Warnweste (griffbereit, DIN-Norm)",
                    "Fuerlöscher (falls vorgeschrieben/nötig)",
                ],
                "FAHRERKABINE": [
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
                ],
                "KONTROLLGERÄT": [
                    "Ordnungsgemäße Funktion des Kontrollgerätes gewährleistet",
                    "Plombierung in Ordnung",
                    "Leuchtet die Funktionskontrollleuchte",
                    "Ausreichende Anzahl von Ersatzrollen bei Verwendung eines",
                    "digitalen Kontrollgerätes",
                    "Ausreichende Anzahl der richtigen Schaublätter dabei",
                    "Tätigkeitsnachweise der vorausgegangen 28 Kalendertage",
                ],
                "LADUNG": [
                    "LADUNG",
                    "Ladung gesichert",
                ],
                "Dokumente": [
                    "Dokumente",
                    "Führerschein (gültig)",
                    "Fahrzeugpapiere",
                    "Zulassungsbescheinigung",
                    "Frachtpapiere (CMR, Lieferschein, Rechnung)",
                    "Ladungspapiere",
                ],
            ]
        case .car, .van:
            return [
                "FRONT UND MOTORRAUM": [
                    "BELEUCHTUNG",
                    "Abblendlicht",
                    "Fernlicht",
                    "Blinker",
                    "Warnblinkanlage",
                    "Nebelscheinwerfer",
                    "Kennzeichenbeleuchtung",
                ],
                "AUSSENEQUIPMENT": [
                    "AUSSENEQUIPMENT",
                    "Aussenspiegel",
                    "Kennzeichen (sauber!)",
                    "Windschutzscheibe",
                    "Scheibenwaschanlage",
                ],
                "KONTROLLEN SEITE": [
                    "REIFEN",
                    "Felgen / Radschüsseln",
                    "Reifenzustand (Schäden)",
                    "Profil",
                    "Luftdruck",
                ],
                "HINTEN/ LADERAUM": [
                    "BELEUCHTUNG",
                    "Schlussleuchten",
                    "Bremsleuchten",
                    "Rückstrahler",
                    "Kennzeichenbeleuchtung",
                    "Nebelschlussleuchte",
                ],
                "AUSRÜSTUNG": [
                    "AUSRÜSTUNG",
                    "Verbandskasten",
                    "Warndreieck",
                    "Warnweste (griffbereit, DIN-Norm)",
                    "Fuerlöscher (falls vorgeschrieben/nötig)",
                ],
                "Dokumente": [
                    "Dokumente",
                    "Führerschein (gültig)",
                    "Fahrzeugpapiere",
                    "Zulassungsbescheinigung",
                    "Ladungspapiere",
                ],
            ]
        case .trailer:
            return [
                "KONTROLLEN SEITE": [
                    "BELEUCHTUNG",
                    "Seitliche Rückstrahler",
                    "Umrissleuchten",
                ],
                "AUSSENEQUIPMENT": [
                    "AUSSENEQUIPMENT",
                    "Kupplung",
                ],
                "REIFEN": [
                    "REIFEN",
                    "Felgen / Radschüsseln",
                    "Reifenzustand (Schäden)",
                    "Profil",
                    "Luftdruck",
                ],
                "HINTEN/ LADERAUM": [
                    "BELEUCHTUNG LADUNG/ SICHERUNG",
                    "Schlussleuchten",
                    "Bremsleuchten",
                    "Rückstrahler",
                    "Kennzeichenbeleuchtung",
                    "Nebelschlussleuchte",
                ],
                "AUSSENEQUIPMENT (HINTEN)": [
                    "AUSSENEQUIPMENT (HINTEN)",
                    "Kennzeichen",
                ],
                "LADERAUM": [
                    "LADERAUM",
                    "Ladungssicherung gewährleistet",
                    "Ausreichend Spanngurte/ Ketten vorhanden",
                    "Zurrmittel/ Antirutschmatten",
                    "Befestigung und Sicherung von Wechselaufbauten,Behältern und Containern",
                ],
                "LADUNG": [
                    "LADUNG",
                    "Ladung gesichert",
                ],
                "Dokumente": [
                    "Dokumente",
                    "Fahrzeugpapiere",
                ],
            ]
        default:
            return [:]
        }
    }

    // Helpers to create items for sections and subsections
    private static func section(_ name: String, _ subsections: [String]) -> [ChecklistItem] {
        // Do not create placeholder items for headers/subheaders.
        // Section/subsection presentation is handled in the UI.
        return []
    }

    private static func subsection(_ section: String, _ name: String, _ titles: [String]) -> [ChecklistItem] {
        return titles.map { ChecklistItem(section: section, title: $0, state: .notSelected) }
    }
}

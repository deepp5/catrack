import Foundation

// MARK: - Sample Sheet Sections
extension SheetSection {
    static func defaultSections() -> [SheetSection] {
        [
            SheetSection(id: "engine", title: "Engine & Drivetrain", fields: [
                SheetField(id: "engine_oil", label: "Engine Oil Level", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "coolant", label: "Coolant Level", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "belts", label: "Belts & Hoses", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "air_filter", label: "Air Filter", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "fuel_system", label: "Fuel System", status: .pending, note: "", aiPrefilled: false),
            ]),
            SheetSection(id: "hydraulics", title: "Hydraulics", fields: [
                SheetField(id: "hyd_level", label: "Hydraulic Fluid Level", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "hyd_hoses", label: "Hydraulic Hoses & Fittings", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "hyd_cylinders", label: "Cylinders & Seals", status: .pending, note: "", aiPrefilled: false),
            ]),
            SheetSection(id: "undercarriage", title: "Undercarriage", fields: [
                SheetField(id: "tracks", label: "Track Tension & Wear", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "rollers", label: "Rollers & Idlers", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "sprockets", label: "Sprockets", status: .pending, note: "", aiPrefilled: false),
            ]),
            SheetSection(id: "electrical", title: "Electrical", fields: [
                SheetField(id: "battery", label: "Battery Condition", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "lights", label: "Lights & Signals", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "gauges", label: "Gauges & Instruments", status: .pending, note: "", aiPrefilled: false),
            ]),
            SheetSection(id: "safety", title: "Safety", fields: [
                SheetField(id: "fire_ext", label: "Fire Extinguisher", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "seatbelt", label: "Seatbelt & ROPS", status: .pending, note: "", aiPrefilled: false),
                SheetField(id: "horn", label: "Horn & Backup Alarm", status: .pending, note: "", aiPrefilled: false),
            ]),
        ]
    }
}

// MARK: - Sample Conversations
extension Message {
    static func sampleConversation() -> [Message] {
        [
            .system("You are CATrack AI, an expert inspection copilot for Caterpillar heavy equipment. Analyze media and text to identify component conditions, severity, and quantified risk."),
            .user(text: "Starting inspection on the wheel loader. Uploading photos of the hydraulic system now."),
            .assistant(
                text: "I've analyzed the hydraulic system photos. I identified a potential hydraulic hose leak near the boom cylinder connection point. The oil staining pattern suggests an early-stage seal failure.",
                findings: [
                    FindingCard(
                        id: UUID(),
                        componentType: "Hydraulic Hose",
                        componentLocation: "Boom Cylinder — Left Side",
                        condition: "Early-stage seal failure with minor oil seepage visible at fitting joint. Staining pattern consistent with 200–400 hour leak progression.",
                        severity: .monitor,
                        confidence: 0.83,
                        quantification: Quantification(
                            failureProbability: 0.55,
                            timeToFailure: "400–600 hrs",
                            safetyRisk: 35,
                            safetyLabel: "Moderate",
                            costLow: 800,
                            costHigh: 2500,
                            downtimeLow: 4,
                            downtimeHigh: 8
                        ),
                        seenBefore: false,
                        trend: nil
                    )
                ],
                memoryNote: "Hydraulic hose seal concern logged for CAT 950 GC #CAT0950GC4821"
            ),
        ]
    }
}

// MARK: - Sample Archive Records
extension ArchiveRecord {
    static let samples: [ArchiveRecord] = [
        ArchiveRecord(
            id: UUID(),
            machine: "CAT 950 GC",
            serial: "CAT0950GC4821",
            date: Date().addingTimeInterval(-7200),
            inspector: "J. Rivera",
            site: "North Quarry",
            hours: 4280,
            riskScore: 62,
            aiSummary: "Hydraulic hose seal showing early wear. Recommend monitoring and replacement within 200 hours. All other systems within normal operating parameters.",
            sections: SheetSection.defaultSections(),
            findings: [
                FindingCard(
                    id: UUID(),
                    componentType: "Hydraulic Hose",
                    componentLocation: "Boom Cylinder — Left Side",
                    condition: "Early-stage seal failure with minor oil seepage.",
                    severity: .monitor,
                    confidence: 0.83,
                    quantification: Quantification(
                        failureProbability: 0.55,
                        timeToFailure: "400–600 hrs",
                        safetyRisk: 35,
                        safetyLabel: "Moderate",
                        costLow: 800,
                        costHigh: 2500,
                        downtimeLow: 4,
                        downtimeHigh: 8
                    ),
                    seenBefore: true,
                    trend: "Worsening from last inspection"
                )
            ],
            estimatedCost: 2500,
            trends: [
                TrendItem(label: "Engine Hours", value: "4,280 hrs", delta: "+840", direction: .same),
                TrendItem(label: "Hydraulic Pressure", value: "2,850 PSI", delta: "-120 PSI", direction: .worse),
                TrendItem(label: "Oil Analysis", value: "Normal", delta: "No change", direction: .same),
            ]
        ),
        ArchiveRecord(
            id: UUID(),
            machine: "CAT 966",
            serial: "CAT0966L2201",
            date: Date().addingTimeInterval(-86400),
            inspector: "M. Torres",
            site: "East Haul Road",
            hours: 6840,
            riskScore: 78,
            aiSummary: "Undercarriage showing accelerated wear on track links. Sprocket teeth approaching replacement threshold. Plan maintenance within 30 days.",
            sections: SheetSection.defaultSections(),
            findings: [
                FindingCard(
                    id: UUID(),
                    componentType: "Track Links",
                    componentLocation: "Undercarriage — Both Sides",
                    condition: "Accelerated wear pattern. Link pitch elongation at 92% of replacement threshold.",
                    severity: .monitor,
                    confidence: 0.91,
                    quantification: Quantification(
                        failureProbability: 0.45,
                        timeToFailure: "300–500 hrs",
                        safetyRisk: 28,
                        safetyLabel: "Low-Moderate",
                        costLow: 12000,
                        costHigh: 18000,
                        downtimeLow: 16,
                        downtimeHigh: 24
                    ),
                    seenBefore: true,
                    trend: "Consistent with last inspection trend"
                )
            ],
            estimatedCost: 18000,
            trends: [
                TrendItem(label: "Track Wear", value: "92%", delta: "+7%", direction: .worse),
                TrendItem(label: "Fuel Consumption", value: "18.2 L/hr", delta: "+0.4 L/hr", direction: .worse),
                TrendItem(label: "Engine Temp", value: "88°C", delta: "-2°C", direction: .better),
            ]
        ),
        ArchiveRecord(
            id: UUID(),
            machine: "CAT 320 Excavator",
            serial: "CAT032012093",
            date: Date().addingTimeInterval(-259200),
            inspector: "A. Chen",
            site: "Bench 3",
            hours: 2105,
            riskScore: 91,
            aiSummary: "All systems in good condition. Minor air filter restriction noted — recommend replacement at next scheduled service. No immediate action required.",
            sections: SheetSection.defaultSections(),
            findings: [
                FindingCard(
                    id: UUID(),
                    componentType: "Air Filter",
                    componentLocation: "Engine Compartment",
                    condition: "Filter restriction at 68% of service limit. Functional but approaching service interval.",
                    severity: .pass,
                    confidence: 0.95,
                    quantification: Quantification(
                        failureProbability: 0.12,
                        timeToFailure: ">1000 hrs",
                        safetyRisk: 8,
                        safetyLabel: "Low",
                        costLow: 150,
                        costHigh: 300,
                        downtimeLow: 1,
                        downtimeHigh: 2
                    ),
                    seenBefore: false,
                    trend: nil
                )
            ],
            estimatedCost: 300,
            trends: [
                TrendItem(label: "Engine Hours", value: "2,105 hrs", delta: "+350", direction: .same),
                TrendItem(label: "Hydraulic Temp", value: "72°C", delta: "±0°C", direction: .same),
                TrendItem(label: "DEF Level", value: "85%", delta: "-10%", direction: .better),
            ]
        ),
    ]
}

# CATAI — AI Inspection Copilot for Caterpillar Equipment

> **Inspect smarter. Flag faster. Report instantly.**

CATrack is a native iOS application that serves as an AI-powered inspection copilot for Caterpillar heavy equipment. It combines a structured 38-field walkaround checklist with a real-time AI chat interface that analyzes photos, voice notes, and text to identify component conditions, classify severity, and generate quantified risk reports — all in a single session.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [App Architecture](#app-architecture)
- [Screens & Workflow](#screens--workflow)
- [AI Chat System](#ai-chat-system)
- [Inspection Sheet](#inspection-sheet)
- [Parts Recommendation Engine](#parts-recommendation-engine)
- [Archive & Reporting](#archive--reporting)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Backend Integration](#backend-integration)
- [Design System](#design-system)

---

## Overview

Traditional equipment inspections are slow, inconsistent, and paper-driven. CATrack replaces that workflow with an AI copilot that guides inspectors through the walkaround, analyzes media in real time, pre-fills the checklist, and generates a full executive report with risk scoring, cost estimates, and CAT part recommendations — all in one tap.

---

## Features

### Core
- **AI Chat Copilot** — Real-time analysis of photos, voice notes, and text during walkaround
- **38-Field Inspection Sheet** — Standardized checklist covering all CAT machine systems
- **Severity Classification** — Every field is marked PASS / MONITOR / FAIL
- **Finding Cards** — Structured AI output with component, condition, severity, confidence, cost, and downtime estimates
- **Risk Scoring** — 0–100 quantified risk score per inspection
- **One-Tap Report Generation** — AI executive summary synced from backend
- **Parts Recommendations** — Automatic CAT part number suggestions based on findings
- **Inspection Archive** — Full history with trends, findings, and searchable records

### Media Support
- Camera capture (live photo during walkaround)
- Photo library attachment
- Voice recording with AI transcription and analysis
- Document upload (PDF, files)

### UX
- Dark theme with Caterpillar yellow accent
- Keyboard-aware chat input (manual `KeyboardHeightObserver`)
- Faded CAT logo background in chat
- Animated typing indicator
- Finding cards with expandable detail
- Risk score ring indicator (color-coded: green / yellow / red)

---

## App Architecture

CATrack uses a **SwiftUI + MVVM** architecture with environment-injected view models.

```
CATrack/
├── App/
│   └── CATrackApp.swift          # App entry point, environment injection
├── Models/
│   └── Models.swift              # Machine, Message, FindingCard, SheetField, ArchiveRecord, etc.
├── ViewModels/
│   ├── MachineStore.swift        # Active machine state
│   ├── ChatViewModel.swift       # Message history, AI API calls, media handling
│   ├── InspectionSheetViewModel.swift  # Sheet state, field updates
│   ├── ArchiveStore.swift        # Persisted inspection records
│   └── SettingsStore.swift       # User preferences
├── Views/
│   ├── RootView.swift            # Root navigation, tab bar, keyboard state
│   ├── ActiveChatView.swift      # Chat UI, keyboard avoidance, context bar
│   ├── InputBarView.swift        # Text input, media buttons, send
│   ├── MessageBubbleView.swift   # User/AI/System message rendering
│   ├── InspectionSheetView.swift # 38-field checklist UI
│   ├── ArchiveListView.swift     # Inspection history list
│   ├── ArchiveDetailView.swift   # Full inspection detail view
│   └── SettingsView.swift        # Parts recommendation tab
├── Services/
│   └── APIService.swift          # Backend API calls (chat, sync, report generation)
├── Utilities/
│   ├── Extensions.swift          # Color, Font extensions
│   └── Constants.swift           # K namespace (corner radius, nav height, etc.)
└── Resources/
    ├── Assets.xcassets           # Colors, cat_logo image
    └── SampleData.swift          # Default sheet sections, sample conversations
```

---

## Screens & Workflow

### Tab Bar Navigation

| Tab | Icon | Description |
|-----|------|-------------|
| Inspect | `plus.circle.fill` | Start a new inspection |
| Sheet | `checklist` | 38-field inspection checklist (active inspection only) |
| Chat | `bubble.left.and.bubble.right.fill` | AI chat copilot (active inspection only) |
| Archive | `archivebox.fill` | All completed inspections |
| Parts | `wrench.and.screwdriver.fill` | AI part recommendations |

> Sheet and Chat tabs only appear when an active inspection is running.

### Inspection Workflow

```
1. SELECT MACHINE
   └── Inspector picks machine model, site auto-populated

2. START INSPECTION
   └── Sheet initialized with 38 pending fields
   └── AI chat session started with system context
   └── Chat tab becomes active

3. WALKAROUND (AI Chat)
   └── Inspector sends photos, voice notes, or text
   └── AI returns Finding Cards with severity + quantified risk
   └── AI pre-fills sheet fields it has high confidence in

4. COMPLETE SHEET
   └── Inspector manually sets remaining fields to PASS / MON / FAIL
   └── All 38 fields must be confirmed before report can generate

5. GENERATE REPORT
   └── App syncs checklist to backend via /sync-checklist
   └── Backend AI generates executive summary, risk score, recommendations
   └── Inspection finalized and saved to archive
   └── App navigates to Archive and auto-opens the new record

6. REVIEW & SHARE
   └── Full report available in Archive with all findings, trends, and summary
```

---

## AI Chat System

### Message Types
- `.system` — Hidden context prompt sent to AI at session start
- `.user` — Inspector messages (text, media references, voice)
- `.assistant` — AI responses with optional Finding Cards and memory notes

### Finding Cards
Each AI response can include one or more structured `FindingCard` objects:

```swift
struct FindingCard {
    var componentType: String        // e.g. "Hydraulic Hose"
    var componentLocation: String    // e.g. "Boom Cylinder — Left Side"
    var condition: String            // Description of observed condition
    var severity: FindingSeverity    // .pass / .monitor / .fail
    var confidence: Double           // 0.0–1.0
    var quantification: Quantification
}

struct Quantification {
    var failureProbability: Double   // 0.0–1.0
    var timeToFailure: String        // e.g. "400–600 hrs"
    var safetyRisk: Int              // 0–100
    var safetyLabel: String          // "Low" / "Moderate" / "High"
    var costLow: Double              // Estimated repair cost low
    var costHigh: Double             // Estimated repair cost high
    var downtimeLow: Double          // Estimated downtime hours low
    var downtimeHigh: Double         // Estimated downtime hours high
}
```

### Keyboard Avoidance
Native SwiftUI keyboard avoidance is blocked when `ActiveChatView` is embedded in a `ZStack` in `RootView`. CATrack solves this with a manual `KeyboardHeightObserver` class that listens to `UIResponder` keyboard notifications and applies a `.padding(.bottom, keyboard.height - safeAreaBottom)` offset directly to the `VStack`, bypassing SwiftUI's broken avoidance entirely.

```swift
class KeyboardHeightObserver: ObservableObject {
    @Published var height: CGFloat = 0
    // Listens to keyboardWillShowNotification / keyboardWillHideNotification
    // Animates height change matching keyboard animation duration
}
```

---

## Inspection Sheet

### Sections & Fields

| Section | Fields |
|---------|--------|
| From the Ground | 17 fields — tires, frame, hydraulics, lights, undercarriage, transmission, fuel |
| Engine Compartment | 8 fields — oil, coolant, belts, filters, radiator, hoses |
| Outside Cab | 6 fields — ROPS, windows, fire extinguisher, doors, wipers |
| Inside Cab | 7 fields — seat belt, gauges, mirrors, controls, horn, air filter |

### Field Status Flow
```
.pending  →  .pass
          →  .monitor
          →  .fail
```

All 38 fields start as `.pending`. The Generate Report button is disabled until every field has been manually confirmed. The `FinalizeBar` shows a live count of remaining, FAIL, and MON fields.

### AI Pre-fill
When the AI identifies a component with high confidence during chat, it can call `sheetVM.updateField()` to pre-fill the corresponding sheet field. Pre-filled fields are marked with a `brain` icon.

---

## Parts Recommendation Engine

The Parts tab (`SettingsView.swift`) reads the current inspection state and surfaces relevant CAT replacement parts:

**Data Sources:**
1. Sheet fields with `.fail` or `.monitor` status
2. `FindingCard` objects from AI chat messages

**Output per Part:**
- Part name
- Official CAT part number
- Estimated price range
- Which issue it fixes
- Severity badge (CRITICAL / MONITOR)

Parts are sorted by severity — FAIL items appear first. The lookup uses a hardcoded map of common CAT part numbers for standard components. Future versions will query a live CAT parts API.

---

## Archive & Reporting

### ArchiveRecord
```swift
struct ArchiveRecord {
    var machine: String
    var serial: String
    var date: Date
    var inspector: String
    var site: String
    var hours: Int
    var riskScore: Int              // 0–100 from backend
    var aiSummary: String           // Executive summary from AI
    var sections: [SheetSection]    // Full checklist state at time of completion
    var findings: [FindingCard]     // All AI-identified findings
    var estimatedCost: Double
    var trends: [TrendItem]
}
```

### Risk Score Ranges
| Score | Color | Status |
|-------|-------|--------|
| 0–40 | 🟢 Green | Low Risk — Operational |
| 41–70 | 🟡 Yellow | Moderate Risk — Monitor |
| 71–100 | 🔴 Red | High Risk — Immediate Action |

### Report Generation Flow
```
Inspector taps "GENERATE REPORT"
  └── App reads all 38 field statuses
  └── POST /sync-checklist → syncs field states to backend
  └── POST /generate-report → backend AI generates:
        - executiveSummary
        - operationalReadiness
        - criticalFindings[]
        - recommendations[]
        - riskScore
  └── ArchiveRecord created and saved
  └── Sheet reset, active machine cleared
  └── App navigates to Archive, auto-opens new record
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Architecture | MVVM + EnvironmentObject |
| AI Backend | FastAPI + OpenAI GPT-4 Vision |
| Networking | URLSession + async/await |
| Local Storage | UserDefaults / in-memory (ArchiveStore) |
| Media | AVFoundation (voice), PhotosUI (images), UniformTypeIdentifiers (docs) |
| Minimum iOS | iOS 17.0 |

---

## Getting Started

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ device or simulator
- Backend server running (FastAPI) — see [Backend Integration](#backend-integration)

### Installation
```bash
git clone https://github.com/your-org/catrack-ios.git
cd catrack-ios
open CATrack.xcodeproj
```

### Build & Run
1. Open `CATrack.xcodeproj` in Xcode
2. Select your target device or simulator
3. Set your backend URL in `SettingsStore` or via the Settings screen
4. Press **Cmd+R** to build and run

---

## Configuration

### Backend URL
Set the backend base URL in `SettingsStore.swift`:
```swift
@Published var backendURL: String = "https://your-backend.com"
```

Or update it at runtime via the app's Settings screen (if enabled).

### AI System Prompt
The AI context prompt is set in `ChatViewModel.startSession()`. Modify it to adjust AI behavior, tone, or domain focus:
```swift
let systemPrompt = """
You are CATrack AI, an expert inspection copilot for Caterpillar heavy equipment.
Analyze media and text to identify component conditions, severity, and quantified risk.
...
"""
```

### CAT Logo
Add an image named `cat_logo` to `Assets.xcassets`. It will appear as a faded watermark behind the chat interface.

---

## Backend Integration

CATrack communicates with a FastAPI backend via `APIService.swift`.

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/chat` | Send message + media, receive AI response with findings |
| POST | `/sync-checklist` | Push current field states before report generation |
| POST | `/generate-report` | Generate executive summary and risk score |
| POST | `/start-inspection` | Initialize inspection session, returns `inspection_id` |

### Inspection ID
The active `inspection_id` is stored in `UserDefaults` under the key `activeInspectionId`. This is used to associate all API calls with the current session.

### Response Format (Chat)
```json
{
  "message": "AI response text",
  "findings": [
    {
      "componentType": "Hydraulic Hose",
      "componentLocation": "Boom Cylinder — Left Side",
      "condition": "Early-stage seal failure",
      "severity": "monitor",
      "confidence": 0.83,
      "quantification": {
        "failureProbability": 0.55,
        "timeToFailure": "400–600 hrs",
        "safetyRisk": 35,
        "safetyLabel": "Moderate",
        "costLow": 800,
        "costHigh": 2500,
        "downtimeLow": 4,
        "downtimeHigh": 8
      }
    }
  ],
  "sheetUpdates": {
    "All hoses and lines": "monitor"
  }
}
```

---

## Design System

### Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `catYellow` | `#F5C518` | Primary accent, buttons, icons |
| `catYellowDim` | `#B8960E` | Secondary yellow, AI memory notes |
| `appBackground` | `#0A0A0A` | Main background |
| `appSurface` | `#141414` | Cards, nav bar |
| `appPanel` | `#1C1C1C` | Input fields, secondary cards |
| `appBorder` | `#2A2A2A` | Dividers, borders |
| `appMuted` | `#6B6B6B` | Secondary text, placeholder |
| `severityPass` | `#34C759` | PASS status |
| `severityMon` | `#FF9500` | MONITOR status |
| `severityFail` | `#FF3B30` | FAIL status |

### Typography
| Font | Usage |
|------|-------|
| SF Rounded (system) | Headers, buttons, nav labels |
| Barlow | Body text, field labels |
| DM Mono | Codes, status labels, part numbers |
| Bebas Neue | Large display titles |

### Constants (`K`)
```swift
enum K {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let navHeight: CGFloat = 83
}
```

---

## License

Proprietary — All rights reserved. CATrack is not open source.

---

*Built for the field. Powered by AI. Designed for CAT.*

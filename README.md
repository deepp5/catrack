# CATAI

CATAI is an AI-powered inspection assistant designed for Caterpillar machines. It transforms traditional manual equipment inspections into a voice-driven, vision-enabled, and automated workflow.

---

## 🚜 Problem

Heavy equipment inspections today are:
- Manual and time-consuming  
- Prone to human error  
- Inconsistent across technicians  

Inspectors must visually evaluate components and manually mark each item as **Pass**, **Monitor**, or **Fail**.

---

## 🤖 Solution

CATAI streamlines the entire process using:

- 🎤 Voice commands ("Hey Cat…")
- 📸 Live camera analysis
- 🖼 Image & video uploads
- 💬 AI chat interaction
- 📋 Automatic checklist updates

Inspectors can simply speak or show a component, and CATAI analyzes its condition and updates the inspection sheet in real time.

---

## ✨ Key Features

### 🔹 Assist Mode (Hands-Free)
Designed for use with smart glasses (simulated in-app):
- Say: `Hey Cat, check the tire`
- Captures live frame
- AI evaluates condition
- Automatically updates inspection checklist
- Visual severity feedback:
  - 🟢 Green = Pass  
  - 🟡 Yellow = Monitor  
  - 🔴 Red = Fail  

---

### 🔹 AI Chat + Media Upload
Users can:
- Upload images
- Upload videos
- Send text
- Ask inspection questions

The AI processes inputs and applies structured updates directly to the inspection sheet.

---

### 🔹 Dynamic Risk Scoring
Each inspection generates a risk score based on component severity:
- All pass → 100
- Failures reduce operational readiness

---

## 🏗 Tech Stack

**Frontend**
- SwiftUI (iOS)
- AVFoundation (camera + capture)
- Speech Recognition (voice input)

**Backend**
- FastAPI
- AI model specialized for wheel loader inspection
- REST endpoints for image/video analysis

---

## 🚀 How It Works

1. Start an inspection.
2. Use Assist mode or chat.
3. AI analyzes components.
4. Checklist updates automatically.
5. Risk score adjusts dynamically.
6. Inspection can be archived with AI summary.

---

## 🎯 Impact

CATAI makes inspections:
- Faster
- More consistent
- Safer
- Hands-free
- AI-assisted

Smarter inspections. Safer machines.

---

## 👥 Team

Built by:
- Vishrut
- Deep
- Jay
- Yash

---

## 🛠 Future Improvements

- Deeper model fine-tuning for specific machine types
- Real Meta Glasses integration
- Predictive maintenance analytics
- Fleet-level dashboard insights

---

**CATAI — AI-Powered Equipment Intelligence**

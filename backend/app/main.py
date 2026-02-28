from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Optional, Literal
import os
import json
from openai import OpenAI
from dotenv import load_dotenv

Status = Literal["PASS", "MONITOR", "FAIL", "none"]

class AnalyzeRequest(BaseModel):
    user_text: str
    current_checklist_state: Dict[str, Status]
    images: Optional[List[str]] = None

class ChecklistUpdate(BaseModel):
    status: Literal["PASS", "MONITOR", "FAIL"]
    note: Optional[str] = None


class AnalyzeResponse(BaseModel):
    intent: Literal["inspection_update", "knowledge_question", "unclear_input"]
    checklist_updates: Dict[str, ChecklistUpdate]
    risk_score: Optional[Literal["Low", "Moderate", "High"]] = None
    answer: Optional[str] = None
    follow_up_questions: List[str]

# FULL_CHECKLIST constant
FULL_CHECKLIST = {
    "FROM_THE_GROUND": {
        "Tires, wheels, stem caps, lug nuts": "none",
        "Bucket cutting edge, moldboard": "none",
        "Bucket lift and tilt cylinders, hoses": "none",
        "Loader frame, arms": "none",
        "Underneath machine": "none",
        "Transmission, transfer case": "none",
        "Steps and handholds": "none",
        "Fuel tank": "none",
        "Differential and final drive oil": "none",
        "Air tank": "none",
        "Axles, final drives, differentials, brakes": "none",
        "Hydraulic tank": "none",
        "Transmission oil": "none",
        "Lights, front and rear": "none",
        "Battery compartment": "none",
        "Diesel exhaust fluid tank": "none",
        "Overall machine": "none"
    },
    "ENGINE_COMPARTMENT": {
        "Engine oil": "none",
        "Engine coolant": "none",
        "Radiator": "none",
        "All hoses and lines": "none",
        "Fuel filters / water separator": "none",
        "All belts": "none",
        "Air filter": "none",
        "Overall engine compartment": "none"
    },
    "OUTSIDE_CAB": {
        "Handholds": "none",
        "ROPS": "none",
        "Fire extinguisher": "none",
        "Windshield and windows": "none",
        "Windshield wipers / washers": "none",
        "Doors": "none"
    },
    "INSIDE_CAB": {
        "Seat": "none",
        "Seat belt and mounting": "none",
        "Horn, backup alarm, lights": "none",
        "Mirrors": "none",
        "Cab air filter": "none",
        "Gauges, indicators, switches, controls": "none",
        "Overall cab interior": "none"
    }
}

# Helper to flatten keys
def get_flat_checklist_keys():
    keys = []
    for section in FULL_CHECKLIST.values():
        keys.extend(section.keys())
    return keys

app = FastAPI()
load_dotenv()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def run_inspection_logic(user_text: str, current_checklist_state: Dict[str, Status], images: Optional[List[str]] = None):
    canonical_keys = get_flat_checklist_keys()

    # Validate incoming checklist keys against canonical checklist
    for key in current_checklist_state.keys():
        if key not in canonical_keys:
            return {
                "error": f"Invalid checklist item: {key}"
            }

    allowed_items = canonical_keys

    instruction_text = f"""
    You are an AI inspection assistant for Caterpillar heavy equipment.

    STRICT RULES:
    - You may ONLY update checklist items from this exact list:
    {allowed_items}
    - Do NOT invent new checklist items.
    - Do NOT include any fields not specified.
    - Do NOT include risk inside checklist_updates.
    - risk_score must exist ONLY at the top level.

    Classify the user message as one of:
    - inspection_update
    - knowledge_question
    - unclear_input

    If inspection_update:
    - Update checklist items only from the allowed list above.
    - Assign PASS, MONITOR, or FAIL.
    - Provide short note.
    - Assign risk_score as Low, Moderate, or High.

    If knowledge_question:
    - Do NOT modify checklist_updates.
    - risk_score must be null.
    - Provide clear guidance in answer.

    If unclear_input:
    - Do NOT modify checklist_updates.
    - risk_score must be null.
    - answer must be null.
    - Provide helpful follow_up_questions asking for clarification.

    Return ONLY valid JSON in this exact format:
    {{
      "intent": "inspection_update | knowledge_question | unclear_input",
      "checklist_updates": {{
        "Item Name": {{
          "status": "PASS | MONITOR | FAIL",
          "note": "string"
        }}
      }},
      "risk_score": "Low | Moderate | High | null",
      "answer": "string | null",
      "follow_up_questions": []
    }}

    User message:
    {user_text}

    Current checklist state:
    {current_checklist_state}
    """

    if images and len(images) > 0:
        content_blocks = [
            {"type": "input_text", "text": instruction_text}
        ]

        for img in images:
            content_blocks.append(
                {
                    "type": "input_image",
                    "image_url": f"data:image/jpeg;base64,{img}"
                }
            )

        response = client.responses.create(
            model="gpt-4.1-mini",
            input=[
                {
                    "role": "user",
                    "content": content_blocks
                }
            ]
        )
    else:
        response = client.responses.create(
            model="gpt-4.1-mini",
            input=instruction_text
        )

    return json.loads(response.output_text)

@app.post("/analyze")
def analyze(req: AnalyzeRequest):
    return run_inspection_logic(
        req.user_text,
        req.current_checklist_state,
        req.images
    )

@app.get("/")
def root():
    return {"message": "CATrack backend running"}

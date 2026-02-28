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

@app.post("/analyze")
def analyze(req: AnalyzeRequest):
    allowed_items = list(req.current_checklist_state.keys())

    response = client.responses.create(
        model="gpt-4.1-mini",
        input=f"""
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
        {req.user_text}

        Current checklist state:
        {req.current_checklist_state}
        """
    )

    return json.loads(response.output_text)

@app.get("/")
def root():
    return {"message": "CATrack backend running 🚜"}

@app.get("/ping")
def ping():
    return {"status": "Backend connected successfully"}
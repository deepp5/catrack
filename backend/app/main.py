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
    intent: Literal["inspection_update", "knowledge_question"]
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

@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(req: AnalyzeRequest):

    system_prompt = """
    You are an AI inspection assistant for Caterpillar heavy equipment.

    Your job:
    1. Determine whether the user's message is:
    - "inspection_update"
    - "knowledge_question"

    2. If inspection_update:
    - Choose relevant checklist items ONLY from provided checklist state keys.
    - Assign status: PASS, MONITOR, or FAIL.
    - Provide short note.
    - Estimate risk level (Low, Moderate, High).

    3. If knowledge_question:
    - Do NOT modify checklist.
    - Provide clear answer.
    - Do NOT assign risk.

    Return STRICT JSON with this format:

    {
    "intent": "...",
    "checklist_updates": { ... },
    "risk_score": "... or null",
    "answer": "... or null",
    "follow_up_questions": [...]
    }

    Return ONLY valid JSON.
    Do not include markdown.
    """

    user_prompt = f"""
    User message:
    {req.user_text}

    Current checklist state:
    {req.current_checklist_state}
    """

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        temperature=0.2
    )

    ai_output = response.choices[0].message.content

    try:
        parsed = json.loads(ai_output)
        return parsed
    except:
        return {
            "intent": "knowledge_question",
            "checklist_updates": {},
            "risk_score": None,
            "answer": "AI  response formatting error.",
            "follow_up_questions": []
        }


@app.get("/")
def root():
    return {"message": "CATrack backend running 🚜"}

@app.get("/ping")
def ping():
    return {"status": "Backend connected successfully"}
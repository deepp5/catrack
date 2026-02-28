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

@app.post("/analyze")
def analyze(req: AnalyzeRequest):
    response = client.responses.create(
        model="gpt-4.1-mini",
        input=[
            {
                "role": "system",
                "content": """
                You are an AI inspection assistant for Caterpillar heavy equipment.

                You must:
                1. Classify the message as either:
                - inspection_update
                - knowledge_question

                2. If inspection_update:
                - Choose checklist items ONLY from the provided checklist keys.
                - Assign status: PASS, MONITOR, or FAIL.
                - Provide a short note.
                - Estimate risk level: Low, Moderate, High.

                3. If knowledge_question:
                - Do NOT modify checklist.
                - Provide clear safety or operational guidance.
                - Do NOT assign risk.

                Return ONLY valid JSON.
                Do not include explanations.
                """
                            },
                            {
                                "role": "user",
                                "content": f"""
                User message:
                {req.user_text}

                Current checklist state:
                {req.current_checklist_state}
                """
            }
        ],
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "inspection_response",
                "schema": {
                    "type": "object",
                    "properties": {
                        "intent": {
                            "type": "string",
                            "enum": ["inspection_update", "knowledge_question"]
                        },
                        "checklist_updates": {
                            "type": "object",
                            "additionalProperties": {
                                "type": "object",
                                "properties": {
                                    "status": {
                                        "type": "string",
                                        "enum": ["PASS", "MONITOR", "FAIL"]
                                    },
                                    "note": {"type": "string"}
                                },
                                "required": ["status", "note"]
                            }
                        },
                        "risk_score": {
                            "type": ["string", "null"],
                            "enum": ["Low", "Moderate", "High", None]
                        },
                        "answer": {
                            "type": ["string", "null"]
                        },
                        "follow_up_questions": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    },
                    "required": [
                        "intent",
                        "checklist_updates",
                        "risk_score",
                        "answer",
                        "follow_up_questions"
                    ]
                }
            }
        }
    )

    return json.loads(response.output[0].content[0].text)


@app.get("/")
def root():
    return {"message": "CATrack backend running 🚜"}

@app.get("/ping")
def ping():
    return {"status": "Backend connected successfully"}
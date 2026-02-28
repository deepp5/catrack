from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Optional, Literal
import os
import json
import io
import requests
from openai import OpenAI
from dotenv import load_dotenv
from supabase import create_client

Status = Literal["PASS", "MONITOR", "FAIL", "none"]

class AnalyzeRequest(BaseModel):
    inspection_id: str
    user_text: str
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
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
SUPABASE_BUCKET = os.getenv("SUPABASE_BUCKET", "media")

TRANSCRIBE_MODEL = os.getenv("TRANSCRIBE_MODEL", "gpt-4o-mini-transcribe")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env")

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/start-inspection")
def start_inspection(machine_model: str):
    initial_state = {}
    for section in FULL_CHECKLIST.values():
        initial_state.update(section)

    resp = supabase.table("inspections").insert({
        "machine_model": machine_model,
        "checklist_json": initial_state
    }).execute()

    return resp.data[0]

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
    # 1️⃣ Fetch inspection from DB
    resp = (
        supabase.table("inspections")
        .select("id, checklist_json")
        .eq("id", req.inspection_id)
        .limit(1)
        .execute()
    )

    rows = resp.data or []
    if not rows:
        raise HTTPException(status_code=404, detail="Inspection not found")

    checklist_state = rows[0]["checklist_json"]

    # 2️⃣ Run AI logic
    result = run_inspection_logic(
        req.user_text,
        checklist_state,
        req.images
    )

    # 3️⃣ Apply updates to checklist JSON
    updates = result.get("checklist_updates", {})
    for item_name, update_data in updates.items():
        checklist_state[item_name] = update_data["status"]

    # 4️⃣ Save updated checklist back to DB
    supabase.table("inspections").update(
        {"checklist_json": checklist_state}
    ).eq("id", req.inspection_id).execute()

    return result

@app.get("/")
def root():
    return {"message": "CATrack backend running"}
def public_storage_url(bucket: str, path: str) -> str:
    # Works when the bucket is PUBLIC
    return f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{path}"


@app.get("/health")
def health():
    return {"ok": True}

@app.get("/debug/next-media")
def debug_next_media():
    resp = (
        supabase.table("media")
        .select("id,bucket,path,status,type,created_at")
        .eq("type", "audio")
        .eq("status", "uploaded")
        .order("created_at", desc=False)
        .limit(1)
        .execute()
    )
    rows = resp.data or []
    if not rows:
        return {"message": "no uploaded audio found"}
    return rows[0]



@app.get("/debug/download/{media_id}")
def debug_download(media_id: str):
    row_resp = (
        supabase.table("media")
        .select("id,bucket,path,type,status")
        .eq("id", media_id)
        .limit(1)
        .execute()
    )
    rows = row_resp.data or []
    if not rows:
        raise HTTPException(status_code=404, detail="media_id not found")

    row = rows[0]
    url = public_storage_url(row["bucket"], row["path"])
    r = requests.get(url, timeout=30)
    if r.status_code != 200:
        raise HTTPException(
            status_code=500,
            detail=f"download failed: {r.status_code} {r.text[:200]}",
        )

    return {
        "media_id": media_id,
        "type": row.get("type"),
        "status": row.get("status"),
        "url_used": url,
        "bytes_downloaded": len(r.content),
    }


@app.post("/process-next-audio")
def process_next_audio():
    # 1) Pick the next uploaded audio
    resp = (
        supabase.table("media")
        .select("id,bucket,path,status,type,created_at")
        .eq("type", "audio")
        .eq("status", "uploaded")
        .order("created_at", desc=False)
        .limit(1)
        .execute()
    )
    rows = resp.data or []
    if not rows:
        return {"message": "no uploaded audio to process"}

    row = rows[0]
    media_id = row["id"]

    # 2) Lock it (avoid double-processing)
    supabase.table("media").update({"status": "processing"}).eq("id", media_id).execute()

    try:
        # 3) Download audio bytes from Supabase Storage (public URL)
        url = public_storage_url(row["bucket"], row["path"])
        r = requests.get(url, timeout=30)
        if r.status_code != 200 or not r.content:
            raise RuntimeError(f"download failed: {r.status_code} {r.text[:200]}")

        audio_bytes = r.content

        # 4) Whisper / Speech-to-text
        # Give the in-memory bytes a filename so the API can infer format.
        f = io.BytesIO(audio_bytes)
        # Keep extension aligned with what you uploaded (m4a is fine for iOS recordings)
        f.name = "audio.m4a"

        tr = client.audio.transcriptions.create(
            model=TRANSCRIBE_MODEL,  # e.g. gpt-4o-mini-transcribe or whisper-1
            file=f,
        )
        transcript_text = (tr.text or "").strip()

        if len(transcript_text) < 3:
            raise RuntimeError("transcript too short/empty (please re-record)")

        # 5) Store transcript
        supabase.table("transcripts").insert(
            {"media_id": media_id, "text": transcript_text}
        ).execute()

        # 6) Mark complete
        supabase.table("media").update(
            {"status": "transcribed", "error_message": None}
        ).eq("id", media_id).execute()

        return {
            "media_id": media_id,
            "status": "transcribed",
            "transcript_preview": transcript_text[:200],
            "bytes_downloaded": len(audio_bytes),
        }

    except Exception as e:
      
        supabase.table("media").update(
            {"status": "failed", "error_message": str(e)}
        ).eq("id", media_id).execute()
        raise HTTPException(status_code=500, detail=f"processing failed: {e}")


# New endpoint for voice analysis
@app.post("/voice-analyze")
async def voice_analyze(
    audio_file: UploadFile = File(...),
    checklist_json: str = Form(...)
):
    try:
        # 1️⃣ Parse checklist JSON sent from frontend
        current_checklist_state = json.loads(checklist_json)

        # 2️⃣ Read audio bytes
        audio_bytes = await audio_file.read()
        f = io.BytesIO(audio_bytes)
        f.name = audio_file.filename or "audio.m4a"

        # 3️⃣ Transcribe using OpenAI speech model
        tr = client.audio.transcriptions.create(
            model=TRANSCRIBE_MODEL,
            file=f,
        )

        transcript_text = (tr.text or "").strip()

        if len(transcript_text) < 3:
            raise RuntimeError("transcript too short/empty")

        # 4️⃣ Run inspection AI logic
        return run_inspection_logic(
            user_text=transcript_text,
            current_checklist_state=current_checklist_state,
            images=None
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"voice processing failed: {e}")

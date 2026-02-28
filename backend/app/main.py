from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Optional, Literal
import os
import json
import io
import requests
import numpy as np
import librosa
import tempfile
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

class GenerateReportRequest(BaseModel):
    inspection_id: str

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
    # 1) Pick the next uploaded audio (voice note only)
    resp = (
        supabase.table("media")
        .select("id,bucket,path,status,type,created_at")
        .eq("type", "audio")
        .eq("status", "uploaded")
        .eq("category", "inspection_voice")
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


# New endpoint for report generation
@app.post("/generate-report")
def generate_report(req: GenerateReportRequest):
    #Fetch inspection from DB
    resp = (
        supabase.table("inspections")
        .select("machine_model, checklist_json")
        .eq("id", req.inspection_id)
        .limit(1)
        .execute()
    )

    rows = resp.data or []
    if not rows:
        raise HTTPException(status_code=404, detail="Inspection not found")

    machine_model = rows[0]["machine_model"]
    checklist = rows[0]["checklist_json"]

    #compute status breakdown
    fail_items = []
    monitor_items = []
    pass_items = []
    none_items = []

    for item, status in checklist.items():
        if status == "FAIL":
            fail_items.append(item)
        elif status == "MONITOR":
            monitor_items.append(item)
        elif status == "PASS":
            pass_items.append(item)
        else:
            none_items.append(item)

    #determine overall risk (simple heuristic)
    overall_risk = "Low"
    if len(fail_items) > 0:
        overall_risk = "High"
    elif len(monitor_items) >= 3:
        overall_risk = "Moderate"

    #Build prompt for report generation
    prompt_text = f"""
    You are generating a professional Caterpillar equipment inspection report aligned with standard inspection documentation.

    Machine Model: {machine_model}

    Summary counts:
    - FAIL: {len(fail_items)}
    - MONITOR: {len(monitor_items)}
    - PASS: {len(pass_items)}
    - NOT CHECKED: {len(none_items)}

    FAIL Items:
    {fail_items}

    MONITOR Items:
    {monitor_items}

    Provide a structured report as JSON with exactly these fields:
    {{
      "executive_summary": "string",
      "critical_findings": ["string"],
      "recommendations": ["string"],
      "operational_readiness": "string",
      "overall_risk": "Low | Moderate | High"
    }}

    Rules:
    - If there are FAIL items, critical_findings must mention them.
    - Recommendations should be actionable and safety-aware.
    - Keep it concise and professional.
    - Set overall_risk to one of Low/Moderate/High.
    - Return ONLY valid JSON.

    Suggested overall_risk: {overall_risk}
    """

    response = client.responses.create(
        model="gpt-4.1-mini",
        input=prompt_text
    )

    return json.loads(response.output_text)
# -----------------------------
# Machine Sound Health (GOOD/BAD)
# -----------------------------

def _download_media_bytes(media_id: str) -> tuple[dict, bytes]:
    """Load a media row and download its bytes from Supabase public storage."""
    row_resp = (
        supabase.table("media")
        .select("id,bucket,path,category,type,status,machine_id,session_id")
        .eq("id", media_id)
        .limit(1)
        .execute()
    )
    rows = row_resp.data or []
    if not rows:
        raise HTTPException(status_code=404, detail="media_id not found")

    row = rows[0]
    url = public_storage_url(row["bucket"], row["path"])
    r = requests.get(url, timeout=60)
    if r.status_code != 200 or not r.content:
        raise HTTPException(
            status_code=500,
            detail=f"download failed: {r.status_code} {r.text[:200]}",
        )
    return row, r.content


def extract_mfcc_features(audio_bytes: bytes, ext: str = ".mp3", sr: int = 16000) -> np.ndarray:
    """Compute a compact audio fingerprint: MFCC mean+std (40-dim)."""
    with tempfile.NamedTemporaryFile(suffix=ext, delete=True) as tmp:
        tmp.write(audio_bytes)
        tmp.flush()
        y, sr = librosa.load(tmp.name, sr=sr, mono=True)

    # MFCC: (n_mfcc, T)
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=20)
    feat = np.concatenate([mfcc.mean(axis=1), mfcc.std(axis=1)], axis=0)
    return feat.astype(np.float32)


def anomaly_score(feat: np.ndarray, mean: np.ndarray, std: np.ndarray) -> float:
    """Simple z-score distance mapped to 0-100."""
    z = np.abs((feat - mean) / (std + 1e-6))
    raw = float(np.mean(z))
    score = min(100.0, raw * 20.0)
    return score


@app.post("/sound/baseline/rebuild")
def rebuild_sound_baseline(machine_id: str, mode: str = "idle"):
    """Build a baseline from labeled GOOD clips for a machine/mode and auto-calibrate threshold."""
    samples = (
        supabase.table("sound_samples")
        .select("media_id,label,mode,machine_id")
        .eq("machine_id", machine_id)
        .eq("mode", mode)
        .execute()
        .data
        or []
    )
    if not samples:
        raise HTTPException(status_code=404, detail="No sound_samples found for this machine/mode")

    good_ids = [s["media_id"] for s in samples if s["label"] == "good"]
    bad_ids = [s["media_id"] for s in samples if s["label"] == "bad"]

    if len(good_ids) < 2:
        raise HTTPException(status_code=400, detail="Need at least 2 GOOD clips to build a baseline")

    good_feats: list[np.ndarray] = []
    for mid in good_ids:
        mrow = (
            supabase.table("media")
            .select("id,bucket,path")
            .eq("id", mid)
            .limit(1)
            .execute()
            .data
        )
        if not mrow:
            continue
        mrow = mrow[0]
        url = public_storage_url(mrow["bucket"], mrow["path"])
        r = requests.get(url, timeout=60)
        if r.status_code != 200 or not r.content:
            continue
        ext = os.path.splitext(mrow["path"])[1] or ".mp3"
        good_feats.append(extract_mfcc_features(r.content, ext=ext))

    if len(good_feats) < 2:
        raise HTTPException(status_code=400, detail="Could not load enough GOOD audio clips")

    good_mat = np.stack(good_feats, axis=0)  # (N, 40)
    mean = good_mat.mean(axis=0)
    std = good_mat.std(axis=0) + 1e-6

    scores_good = [anomaly_score(f, mean, std) for f in good_mat]
    max_good = float(max(scores_good))

    scores_bad: list[float] = []
    for mid in bad_ids:
        mrow = (
            supabase.table("media")
            .select("id,bucket,path")
            .eq("id", mid)
            .limit(1)
            .execute()
            .data
        )
        if not mrow:
            continue
        mrow = mrow[0]
        url = public_storage_url(mrow["bucket"], mrow["path"])
        r = requests.get(url, timeout=60)
        if r.status_code != 200 or not r.content:
            continue
        ext = os.path.splitext(mrow["path"])[1] or ".mp3"
        f = extract_mfcc_features(r.content, ext=ext)
        scores_bad.append(anomaly_score(f, mean, std))

    # Threshold calibration
    threshold = max_good * 1.15
    min_bad = float(min(scores_bad)) if scores_bad else None
    if min_bad is not None and max_good < min_bad:
        threshold = (max_good + min_bad) / 2.0

    # Store baseline (requires sound_baselines table)
    supabase.table("sound_baselines").upsert(
        {
            "machine_id": machine_id,
            "mode": mode,
            "feature_mean": mean.tolist(),
            "feature_std": std.tolist(),
            "threshold": float(threshold),
        },
        on_conflict="machine_id,mode",
    ).execute()

    return {
        "machine_id": machine_id,
        "mode": mode,
        "n_good": len(good_ids),
        "n_bad": len(bad_ids),
        "max_good": max_good,
        "min_bad": min_bad,
        "threshold": float(threshold),
    }


@app.post("/sound/check")
def sound_check(media_id: str, machine_id: str = "demo-machine", mode: str = "idle"):
    """Score a single machine-sound clip against the stored baseline."""
    b = (
        supabase.table("sound_baselines")
        .select("feature_mean,feature_std,threshold")
        .eq("machine_id", machine_id)
        .eq("mode", mode)
        .limit(1)
        .execute()
        .data
        or []
    )
    if not b:
        raise HTTPException(status_code=400, detail="No baseline found. Call /sound/baseline/rebuild first.")

    b = b[0]
    mean = np.array(b["feature_mean"], dtype=np.float32)
    std = np.array(b["feature_std"], dtype=np.float32)
    threshold = float(b["threshold"])

    row, audio_bytes = _download_media_bytes(media_id)
    ext = os.path.splitext(row["path"])[1] or ".mp3"
    feat = extract_mfcc_features(audio_bytes, ext=ext)
    score = anomaly_score(feat, mean, std)

    predicted = "bad" if score >= threshold else "good"

    # Store assessment (requires sound_assessments table)
    supabase.table("sound_assessments").insert(
        {
            "media_id": media_id,
            "machine_id": machine_id,
            "mode": mode,
            "anomaly_score": float(score),
            "predicted_label": predicted,
        }
    ).execute()

    return {
        "media_id": media_id,
        "bucket": row.get("bucket"),
        "path": row.get("path"),
        "anomaly_score": float(score),
        "threshold": threshold,
        "predicted_label": predicted,
    }

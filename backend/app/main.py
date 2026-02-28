from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv
import os
import io
import requests
from supabase import create_client
from openai import OpenAI

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
SUPABASE_BUCKET = os.getenv("SUPABASE_BUCKET", "media")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
TRANSCRIBE_MODEL = os.getenv("TRANSCRIBE_MODEL", "gpt-4o-mini-transcribe")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env")

if not OPENAI_API_KEY:
    raise RuntimeError("Missing OPENAI_API_KEY in .env")

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

openai_client = OpenAI(api_key=OPENAI_API_KEY)


app = FastAPI()

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

        tr = openai_client.audio.transcriptions.create(
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

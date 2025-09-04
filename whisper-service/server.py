import os
import uuid
import subprocess
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse

app = FastAPI(title="Whisper.cpp non-AVX API", version="1.0.0")

DATA_DIR = "/data"
#APP_DIR = "/app/src"
#MAIN_BIN = os.path.join(APP_DIR, "main")
MAIN_BIN = "/app/build/bin/whisper-cli"


MODEL_NAME = os.environ.get("WHISPER_MODEL", "base")
MODEL_PATH = os.path.join("/models", f"{MODEL_NAME}.bin")
DEFAULT_LANG = os.environ.get("WHISPER_LANG", "zh")
THREADS = os.environ.get("WHISPER_THREADS", "4")

@app.get("/health")
def health():
    ok = os.path.isfile(MAIN_BIN) and os.path.isfile(MODEL_PATH)
    return {"status": "ok" if ok else "not_ready",
            "has_main": os.path.isfile(MAIN_BIN),
            "has_model": os.path.isfile(MODEL_PATH),
            "model": MODEL_NAME}

@app.post("/transcribe")
async def transcribe(
    audio_file: UploadFile = File(...),
    language: str = Form(None),
    threads: int = Form(None)
):
    lang = language or DEFAULT_LANG or ""
    th = str(threads or THREADS)

    uid = str(uuid.uuid4())
    src_path = os.path.join(DATA_DIR, f"{uid}_{audio_file.filename}")
    with open(src_path, "wb") as f:
        f.write(await audio_file.read())

    # Normalize to 16k mono wav
    wav_path = os.path.join(DATA_DIR, f"{uid}.wav")
    cmd_ffmpeg = [
        "ffmpeg", "-y", "-i", src_path,
        "-ac", "1", "-ar", "16000", "-f", "wav", wav_path
    ]

    out_prefix = os.path.join(DATA_DIR, uid)
    txt_path = f"{out_prefix}.txt"
    cmd_whisper = [
        MAIN_BIN,
        "-m", MODEL_PATH,
        "-f", wav_path,
        "-otxt",
        "-of", out_prefix,
        "-t", th
    ]
    if lang:
        cmd_whisper += ["-l", lang]

    try:
        subprocess.run(cmd_ffmpeg, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(cmd_whisper, check=True)

        text = ""
        if os.path.exists(txt_path):
            with open(txt_path, "r", encoding="utf-8", errors="ignore") as f:
                text = f.read().strip()

        return JSONResponse({"text": text, "language": lang or "auto", "model": MODEL_NAME, "threads": th})
    except subprocess.CalledProcessError as e:
        return JSONResponse({"error": f"processing_failed: {e}",
                             "stage": "ffmpeg_or_whisper"}, status_code=500)
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)
    finally:
        # cleanup
        for p in [src_path, wav_path, txt_path,
                  f"{out_prefix}.srt", f"{out_prefix}.vtt", f"{out_prefix}.json",
                  f"{out_prefix}.tsv"]:
            try:
                if os.path.exists(p):
                    os.remove(p)
            except:
                pass

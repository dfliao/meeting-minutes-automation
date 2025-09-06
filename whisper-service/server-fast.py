import os
import uuid
import tempfile
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
import openai
from pathlib import Path

app = FastAPI(title="Whisper Fast API", version="1.0.0")

# 設定 OpenAI API
openai.api_key = os.environ.get("OPENAI_API_KEY")

DATA_DIR = "/data"
MODEL_NAME = os.environ.get("WHISPER_MODEL", "whisper-1")
DEFAULT_LANG = os.environ.get("WHISPER_LANG", "zh")

@app.get("/health")
def health():
    has_api_key = bool(openai.api_key)
    return {
        "status": "ok" if has_api_key else "no_api_key",
        "has_api_key": has_api_key,
        "model": MODEL_NAME,
        "service": "openai_whisper"
    }

@app.post("/transcribe")
async def transcribe(
    audio_file: UploadFile = File(...),
    language: str = Form(None),
    threads: int = Form(None)
):
    if not openai.api_key:
        raise HTTPException(
            status_code=500,
            detail="OpenAI API key not configured"
        )
    
    lang = language or DEFAULT_LANG or "zh"
    
    try:
        # 讀取上傳的檔案
        audio_data = await audio_file.read()
        
        # 建立臨時檔案
        with tempfile.NamedTemporaryFile(suffix=f".{audio_file.filename.split('.')[-1]}", delete=False) as temp_file:
            temp_file.write(audio_data)
            temp_file_path = temp_file.name
        
        try:
            # 使用 OpenAI Whisper API 進行轉錄
            with open(temp_file_path, "rb") as audio:
                transcript = openai.Audio.transcribe(
                    model="whisper-1",
                    file=audio,
                    language=lang if lang != "auto" else None,
                    response_format="text"
                )
            
            # 如果 transcript 是物件，取出文字內容
            if hasattr(transcript, 'text'):
                text = transcript.text
            else:
                text = str(transcript)
            
            return JSONResponse({
                "text": text.strip(),
                "language": lang,
                "model": "whisper-1",
                "service": "openai"
            })
            
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Transcription failed: {str(e)}"
            )
        
        finally:
            # 清理臨時檔案
            try:
                os.unlink(temp_file_path)
            except:
                pass
                
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"File processing failed: {str(e)}"
        )

@app.get("/")
def root():
    return {
        "message": "Whisper Fast API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "transcribe": "/transcribe"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
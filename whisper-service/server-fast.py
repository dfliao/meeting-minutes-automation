import os
import uuid
import tempfile
import subprocess
import requests
import json
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from pathlib import Path

app = FastAPI(title="Whisper Local API", version="1.0.0")

DATA_DIR = "/data"
MODEL_NAME = os.environ.get("WHISPER_MODEL", "base")
DEFAULT_LANG = os.environ.get("WHISPER_LANG", "zh")
THREADS = os.environ.get("WHISPER_THREADS", "4")
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://host.docker.internal:11434")
USE_OLLAMA = os.environ.get("USE_OLLAMA", "true").lower() == "true"

def check_ollama_connection():
    """檢查 Ollama 連線狀態"""
    try:
        response = requests.get(f"{OLLAMA_HOST}/api/tags", timeout=5)
        return response.status_code == 200
    except:
        return False

def check_whisper_binary():
    """檢查 whisper 執行檔是否可用"""
    try:
        result = subprocess.run(["whisper", "--help"], capture_output=True, timeout=5)
        return result.returncode == 0
    except:
        return False

@app.get("/health")
def health():
    ollama_ok = check_ollama_connection() if USE_OLLAMA else False
    whisper_ok = check_whisper_binary()
    
    service_type = "none"
    if USE_OLLAMA and ollama_ok:
        service_type = "ollama"
    elif whisper_ok:
        service_type = "local_whisper"
    
    return {
        "status": "ok" if (ollama_ok or whisper_ok) else "no_service",
        "ollama_available": ollama_ok,
        "whisper_available": whisper_ok,
        "service_type": service_type,
        "model": MODEL_NAME,
        "ollama_host": OLLAMA_HOST if USE_OLLAMA else None
    }

def transcribe_with_ollama(audio_file_path: str, language: str = "zh"):
    """使用 Ollama API 進行轉錄"""
    try:
        # 將音檔轉換為 base64
        with open(audio_file_path, "rb") as f:
            audio_data = f.read()
        
        # 使用 Ollama 的語音辨識功能（如果有支援的模型）
        # 注意：這裡需要確認你的 Ollama 是否有支援音頻轉錄的模型
        payload = {
            "model": "whisper",  # 或其他支援音頻的模型
            "prompt": f"請將這段音頻轉錄為{language}文字:",
            "audio": audio_data.hex(),  # 或適當的編碼方式
        }
        
        response = requests.post(
            f"{OLLAMA_HOST}/api/generate",
            json=payload,
            timeout=300
        )
        
        if response.status_code == 200:
            result = response.json()
            return result.get("response", "").strip()
        else:
            raise Exception(f"Ollama API 錯誤: {response.status_code}")
            
    except Exception as e:
        raise Exception(f"Ollama 轉錄失敗: {str(e)}")

def transcribe_with_whisper(audio_file_path: str, language: str = "zh"):
    """使用本地 whisper 執行檔進行轉錄"""
    try:
        # 準備輸出檔案路徑
        output_dir = os.path.dirname(audio_file_path)
        base_name = os.path.splitext(os.path.basename(audio_file_path))[0]
        
        # 建立 whisper 指令
        cmd = [
            "whisper",
            audio_file_path,
            "--model", MODEL_NAME,
            "--language", language,
            "--output_dir", output_dir,
            "--output_format", "txt",
            "--threads", THREADS
        ]
        
        # 執行轉錄
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode != 0:
            raise Exception(f"Whisper 執行錯誤: {result.stderr}")
        
        # 讀取輸出檔案
        txt_file = os.path.join(output_dir, f"{base_name}.txt")
        if os.path.exists(txt_file):
            with open(txt_file, "r", encoding="utf-8") as f:
                text = f.read().strip()
            os.remove(txt_file)  # 清理輸出檔案
            return text
        else:
            raise Exception("找不到轉錄結果檔案")
            
    except subprocess.TimeoutExpired:
        raise Exception("轉錄超時")
    except Exception as e:
        raise Exception(f"本地 Whisper 轉錄失敗: {str(e)}")

@app.post("/transcribe")
async def transcribe(
    audio_file: UploadFile = File(...),
    language: str = Form(None),
    threads: int = Form(None)
):
    lang = language or DEFAULT_LANG or "zh"
    
    # 檢查可用的服務
    ollama_ok = check_ollama_connection() if USE_OLLAMA else False
    whisper_ok = check_whisper_binary()
    
    if not ollama_ok and not whisper_ok:
        raise HTTPException(
            status_code=500,
            detail="沒有可用的轉錄服務，請確認 Ollama 或本地 Whisper 是否正常運行"
        )
    
    try:
        # 儲存上傳的檔案
        audio_data = await audio_file.read()
        
        # 建立臨時檔案
        suffix = f".{audio_file.filename.split('.')[-1]}" if audio_file.filename else ".wav"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False, dir=DATA_DIR) as temp_file:
            temp_file.write(audio_data)
            temp_file_path = temp_file.name
        
        try:
            service_used = "none"
            text = ""
            
            # 優先使用 Ollama（如果啟用且可用）
            if USE_OLLAMA and ollama_ok:
                try:
                    text = transcribe_with_ollama(temp_file_path, lang)
                    service_used = "ollama"
                except Exception as e:
                    print(f"Ollama 轉錄失敗，嘗試使用本地 Whisper: {e}")
                    if whisper_ok:
                        text = transcribe_with_whisper(temp_file_path, lang)
                        service_used = "local_whisper"
                    else:
                        raise e
            elif whisper_ok:
                text = transcribe_with_whisper(temp_file_path, lang)
                service_used = "local_whisper"
            else:
                raise HTTPException(
                    status_code=500,
                    detail="沒有可用的轉錄服務"
                )
            
            return JSONResponse({
                "text": text,
                "language": lang,
                "model": MODEL_NAME,
                "service": service_used,
                "threads": THREADS
            })
            
        finally:
            # 清理臨時檔案
            try:
                os.unlink(temp_file_path)
            except:
                pass
                
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"檔案處理失敗: {str(e)}"
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
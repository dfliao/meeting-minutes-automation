import os
import uuid
import tempfile
import requests
import json
import whisper
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Query
from fastapi.responses import JSONResponse
from pathlib import Path
from typing import Optional

app = FastAPI(title="Whisper Flexible API", version="2.0.0")

DATA_DIR = "/data"
MODEL_NAME = os.environ.get("WHISPER_MODEL", "base")
DEFAULT_LANG = os.environ.get("WHISPER_LANG", "zh")
THREADS = os.environ.get("WHISPER_THREADS", "4")

# 支援多種運算模式
COMPUTE_MODE = os.environ.get("COMPUTE_MODE", "local")  # local, remote, auto
REMOTE_WHISPER_HOST = os.environ.get("REMOTE_WHISPER_HOST", "")

# 本地 Whisper 模型快取
local_whisper_model = None

def load_local_whisper_model():
    """載入本地 Whisper 模型"""
    global local_whisper_model
    try:
        if local_whisper_model is None:
            print(f"載入本地 Whisper 模型: {MODEL_NAME}")
            local_whisper_model = whisper.load_model(MODEL_NAME)
        return True
    except Exception as e:
        print(f"載入本地 Whisper 模型失敗: {e}")
        return False

def check_remote_whisper(host: str):
    """檢查遠端 Whisper 服務狀態"""
    try:
        if not host:
            return False
        response = requests.get(f"{host}/health", timeout=5)
        return response.status_code == 200
    except:
        return False

def check_local_whisper():
    """檢查本地 Whisper 是否可用"""
    try:
        return load_local_whisper_model()
    except:
        return False

@app.get("/health")
def health():
    """健康檢查，顯示所有可用的運算模式"""
    local_ok = check_local_whisper()
    remote_ok = check_remote_whisper(REMOTE_WHISPER_HOST) if REMOTE_WHISPER_HOST else False
    
    available_modes = []
    if local_ok:
        available_modes.append("local")
    if remote_ok:
        available_modes.append("remote")
    
    current_mode = COMPUTE_MODE
    if current_mode == "auto":
        if local_ok:
            current_mode = "local"
        elif remote_ok:
            current_mode = "remote"
        else:
            current_mode = "none"
    
    return {
        "status": "ok" if available_modes else "no_service",
        "version": "2.0.0",
        "local_whisper_available": local_ok,
        "remote_whisper_available": remote_ok,
        "remote_host": REMOTE_WHISPER_HOST if remote_ok else None,
        "available_modes": available_modes,
        "current_compute_mode": current_mode,
        "model": MODEL_NAME,
        "language": DEFAULT_LANG
    }

def transcribe_with_local_whisper(audio_file_path: str, language: str = "zh"):
    """使用本地 Whisper 進行轉錄"""
    try:
        if not load_local_whisper_model():
            raise Exception("本地 Whisper 模型載入失敗")
        
        # 使用 whisper 套件進行轉錄
        result = local_whisper_model.transcribe(
            audio_file_path,
            language=language if language != "auto" else None,
            verbose=False
        )
        
        return result["text"].strip()
        
    except Exception as e:
        raise Exception(f"本地 Whisper 轉錄失敗: {str(e)}")

def transcribe_with_remote_whisper(audio_file_path: str, remote_host: str, language: str = "zh"):
    """使用遠端 Whisper 服務進行轉錄"""
    try:
        if not remote_host:
            raise Exception("未設定遠端 Whisper 伺服器")
        
        # 準備檔案上傳
        with open(audio_file_path, "rb") as f:
            files = {"audio_file": f}
            data = {"language": language}
            
            response = requests.post(
                f"{remote_host}/transcribe",
                files=files,
                data=data,
                timeout=300
            )
        
        if response.status_code == 200:
            result = response.json()
            return result.get("text", "")
        else:
            raise Exception(f"遠端服務錯誤 ({response.status_code}): {response.text}")
            
    except Exception as e:
        raise Exception(f"遠端 Whisper 轉錄失敗: {str(e)}")

@app.post("/transcribe")
async def transcribe(
    audio_file: UploadFile = File(...),
    language: str = Form(None),
    compute_mode: Optional[str] = Form(None),
    remote_host: Optional[str] = Form(None),
    threads: int = Form(None)
):
    """
    語音轉文字 API
    
    參數:
    - audio_file: 音訊檔案
    - language: 語言 (zh, en, ja, ko, auto)
    - compute_mode: 運算模式 (local, remote, auto)
    - remote_host: 遠端伺服器網址 (只有使用 remote 模式時需要)
    - threads: 執行緒數量 (本地模式用)
    """
    
    lang = language or DEFAULT_LANG or "zh"
    mode = compute_mode or COMPUTE_MODE
    remote = remote_host or REMOTE_WHISPER_HOST
    
    # 檢查可用服務
    local_ok = check_local_whisper()
    remote_ok = check_remote_whisper(remote) if remote else False
    
    # 決定使用哪種模式
    if mode == "auto":
        if local_ok:
            mode = "local"
        elif remote_ok:
            mode = "remote"
        else:
            raise HTTPException(
                status_code=500,
                detail="沒有可用的 Whisper 服務"
            )
    elif mode == "local" and not local_ok:
        raise HTTPException(
            status_code=500,
            detail="本地 Whisper 服務不可用"
        )
    elif mode == "remote" and not remote_ok:
        raise HTTPException(
            status_code=500,
            detail=f"遠端 Whisper 服務不可用: {remote}"
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
            # 根據模式進行轉錄
            if mode == "local":
                text = transcribe_with_local_whisper(temp_file_path, lang)
                service_info = {
                    "compute_mode": "local",
                    "model": MODEL_NAME,
                    "host": "localhost"
                }
            elif mode == "remote":
                text = transcribe_with_remote_whisper(temp_file_path, remote, lang)
                service_info = {
                    "compute_mode": "remote",
                    "model": "remote_whisper",
                    "host": remote
                }
            else:
                raise HTTPException(
                    status_code=500,
                    detail=f"不支援的運算模式: {mode}"
                )
            
            return JSONResponse({
                "text": text,
                "language": lang,
                "service_info": service_info,
                "file_info": {
                    "filename": audio_file.filename,
                    "size": len(audio_data)
                }
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
            detail=f"處理失敗: {str(e)}"
        )

@app.get("/config")
def get_config():
    """取得當前配置"""
    return {
        "compute_mode": COMPUTE_MODE,
        "model": MODEL_NAME,
        "language": DEFAULT_LANG,
        "threads": THREADS,
        "remote_host": REMOTE_WHISPER_HOST,
        "data_dir": DATA_DIR
    }

@app.post("/config/compute_mode")
def set_compute_mode(mode: str = Form(...)):
    """動態設定運算模式"""
    global COMPUTE_MODE
    if mode in ["local", "remote", "auto"]:
        COMPUTE_MODE = mode
        return {"message": f"運算模式已設定為: {mode}"}
    else:
        raise HTTPException(
            status_code=400,
            detail="無效的運算模式，支援: local, remote, auto"
        )

@app.post("/config/remote_host")  
def set_remote_host(host: str = Form(...)):
    """動態設定遠端伺服器"""
    global REMOTE_WHISPER_HOST
    REMOTE_WHISPER_HOST = host
    return {"message": f"遠端伺服器已設定為: {host}"}

@app.get("/")
def root():
    return {
        "message": "Whisper Flexible API",
        "version": "2.0.0",
        "description": "支援本地和遠端運算的語音轉文字服務",
        "endpoints": {
            "health": "/health - 檢查服務狀態",
            "transcribe": "/transcribe - 語音轉文字",
            "config": "/config - 取得配置",
            "set_compute_mode": "/config/compute_mode - 設定運算模式",
            "set_remote_host": "/config/remote_host - 設定遠端伺服器"
        },
        "compute_modes": ["local", "remote", "auto"]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
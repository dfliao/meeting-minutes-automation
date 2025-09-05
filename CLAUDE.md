# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a meeting minutes automation system that converts audio recordings into structured meeting minutes. The system consists of two main components:

1. **Whisper Service**: A containerized FastAPI service that provides audio transcription using whisper.cpp (optimized for non-AVX processors)
2. **N8N Workflow**: An automation workflow that handles large audio files, transcription, and AI-powered meeting minutes generation

## Architecture

### Core Components

- `web-interface/`: User-friendly web interface for file uploads
  - `index.html`: Complete HTML/CSS/JS interface with drag-and-drop support
- `whisper-service/`: Self-contained Docker service for audio transcription
  - `server.py`: FastAPI application with `/transcribe` endpoint
  - `Dockerfile`: Multi-stage build with whisper.cpp compiled without AVX support
  - `docker-compose.yaml`: Service configuration with volume mounts for models and data
- `n8n-workflows/`: Automation workflow definitions
  - `audio-transcription-workflow.json`: Complete workflow for processing large audio files with chunking support
- `scripts/`: Python utilities (currently empty placeholders for future development)
  - `process_transcript.py`, `generate_minutes.py`, `send_notification.py`
- `setup-guide.md`: Comprehensive setup instructions for deployment

### Data Flow

1. Audio file uploaded via webhook → File size check
2. Large files (>24MB) automatically split into chunks
3. Each chunk transcribed via OpenAI Whisper API or local whisper service
4. Transcriptions merged and processed with GPT-4o-mini for structured meeting minutes
5. Results returned as JSON with downloadable text files

## Development Commands

### Quick Start
```bash
# 1. Start N8N
npm install -g n8n
n8n start

# 2. Start Whisper Service (optional)
cd whisper-service
docker-compose up --build

# 3. Open web interface
open web-interface/index.html
```

### Testing Commands

```bash
# Test whisper service health
curl http://localhost:10300/health

# Test transcription (replace with actual audio file)
curl -X POST -F "audio_file=@test.wav" -F "language=zh" http://localhost:10300/transcribe

# Test N8N webhook (after workflow is active)
curl -X POST -F "data=@test.mp3" http://localhost:5678/webhook/audio-transcription
```

### Python Dependencies

```bash
# Install required packages
pip install -r requirements.txt

# Core dependencies include:
# - openai>=1.0.0 (for API calls)
# - python-dotenv (environment configuration)
# - pandas (data processing)
```

## Configuration

### Environment Variables

For whisper service (set in docker-compose.yaml):
- `WHISPER_MODEL`: Model to use (default: "base")
- `WHISPER_LANG`: Default language (default: "zh" for Chinese)
- `WHISPER_THREADS`: Processing threads (default: "4")

### N8N Workflow Setup

The workflow requires:
- OpenAI API credentials configured in N8N
- Webhook endpoint enabled for audio file uploads
- File size limits configured (24MB threshold for chunking)

## Key Features

### Audio Processing
- Automatic audio normalization (16kHz mono WAV)
- Large file chunking with intelligent splitting
- Support for multiple audio formats via ffmpeg
- Rate limiting protection between API calls

### Meeting Minutes Generation
- Structured output with summaries, key decisions, and action items
- Chinese language support with context-aware processing
- Automatic cleanup of temporary files
- Error handling and retry logic

## File Structure Notes

- Volume mounts in docker-compose.yaml point to `/volume3/ai-stack/` - adjust paths for your environment
- The whisper service runs on port 10300 by default
- All temporary files are automatically cleaned up after processing
- Binary data handling supports base64 encoding for large files

## Testing

Currently no automated tests are configured. To test:
1. Start the whisper service
2. Import the N8N workflow
3. Upload test audio files via webhook
4. Verify transcription and meeting minutes generation

## Important Notes

- The whisper.cpp build is specifically optimized for non-AVX processors
- Large files are automatically chunked to stay within API limits
- All text processing is optimized for Chinese language content
- The system handles both direct transcription and chunked processing seamlessly
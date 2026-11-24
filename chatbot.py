#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
==============================================================================
MONU AI Chatbot - Ditenagai Google Gemini REST API
==============================================================================
Skrip chatbot mandiri (standalone) tanpa perlu install library tambahan 
(hanya memakai pustaka bawaan Python: urllib, json, sys, os).

Cara Menjalankan:
  1. Mode Interaktif:
     python chatbot.py
     
  2. Pertanyaan Langsung:
     python chatbot.py "Apa fungsi sensor MQ-2 dalam sistem MONU?"
==============================================================================
"""

import sys
import os
import json
import urllib.request
import urllib.error

# Membaca API Key dari Environment Variable atau file lokal .gemini_key
KEY_FILE = os.path.join(os.path.dirname(__file__), ".gemini_key")
def _resolve_api_key():
    env_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if env_key:
        return env_key
    if os.path.exists(KEY_FILE):
        try:
            with open(KEY_FILE, "r", encoding="utf-8") as f:
                k = f.read().strip()
                if k:
                    return k
        except Exception:
            pass
    return ""

GEMINI_API_KEY = _resolve_api_key()

# Model Gemini default (gemini-1.5-flash cepat dan hemat kuota)
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-1.5-flash")

# System Prompt Khusus Sistem Monitoring Hutan IoT MONU
SYSTEM_PROMPT = """
Kamu adalah "Asisten MONU", AI pemantau miniatur hutan proyek IoT siswa SMK.
Sistem MONU menggunakan mikrokontroler ESP32 dengan sensor:
- DHT11: Suhu (°C) dan kelembapan udara (%RH)
- Soil Moisture: Kelembapan tanah (ADC)
- MQ-2: Pendeteksi gas dan asap (ADC)
- MAX6675: Thermocouple suhu tinggi (°C)
- Relay: Pompa penyiram air otomatis

Tugasmu membantu menjelaskan data sensor, tanda bahaya, saran teknis, dan menjawab pertanyaan pengguna dengan ramah, santai, dan jelas dalam Bahasa Indonesia.
""".strip()


def call_gemini(history, system_instruction=SYSTEM_PROMPT, model=GEMINI_MODEL, api_key=GEMINI_API_KEY):
    """
    Mengirim riwayat percakapan ke endpoint Google Gemini REST API.
    """
    endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    
    payload = {
        "systemInstruction": {
            "parts": [{"text": system_instruction}]
        },
        "contents": history
    }
    
    data_bytes = json.dumps(payload).encode("utf-8")
    
    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": api_key
    }
    
    req = urllib.request.Request(endpoint, data=data_bytes, headers=headers, method="POST")
    
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp_body = resp.read().decode("utf-8")
            result = json.loads(resp_body)
            
            candidates = result.get("candidates", [])
            if not candidates:
                feedback = result.get("promptFeedback", {})
                reason = feedback.get("blockReason", "Tidak ada respon teks")
                return f"[Ditolak AI: {reason}]"
            
            parts = candidates[0].get("content", {}).get("parts", [])
            text_parts = [p.get("text", "") for p in parts if "text" in p]
            return "".join(text_parts).strip()
            
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8", "ignore")
        try:
            err_json = json.loads(err_msg)
            msg = err_json.get("error", {}).get("message", err_msg)
        except Exception:
            msg = err_msg
        return f"[Error HTTP {e.code}: {msg}]"
    except urllib.error.URLError as e:
        return f"[Error Koneksi: Pastikan komputer terhubung ke internet. ({e.reason})]"
    except Exception as e:
        return f"[Terjadi Kesalahan: {e}]"


def interactive_chat():
    """Menjalankan sesi percakapan interaktif di terminal."""
    print("=" * 60)
    print("🌲 ASISTEN AI MONU - Ditenagai Google Gemini")
    print(f"📌 Model: {GEMINI_MODEL}")
    print("💡 Ketik 'keluar' atau 'exit' untuk mengakhiri obrolan.")
    print("=" * 60)
    
    history = []
    
    while True:
        try:
            user_input = input("\n👤 Anda: ").strip()
            if not user_input:
                continue
                
            if user_input.lower() in ["exit", "keluar", "quit", "q"]:
                print("👋 Sampai jumpa! Asisten AI MONU berhenti.")
                break
                
            # Tambahkan ke riwayat
            history.append({
                "role": "user",
                "parts": [{"text": user_input}]
            })
            
            print("🌲 MONU AI: sedang berpikir...", end="\r", flush=True)
            reply = call_gemini(history[-10:])  # Kirim 10 percakapan terakhir
            
            # Bersihkan pesan sedang berpikir
            print(" " * 40, end="\r")
            print(f"🌲 MONU AI:\n{reply}")
            
            # Simpan respon model ke riwayat
            history.append({
                "role": "model",
                "parts": [{"text": reply}]
            })
            
        except (KeyboardInterrupt, EOFError):
            print("\n👋 Obrolan dihentikan.")
            break


def main():
    if len(sys.argv) > 1:
        # Mode argumen langsung satu pertanyaan
        question = " ".join(sys.argv[1:])
        print(f"👤 Pertanyaan: {question}\n")
        history = [{"role": "user", "parts": [{"text": question}]}]
        answer = call_gemini(history)
        print(f"🌲 Jawaban Gemini:\n{answer}")
    else:
        # Mode interaktif
        interactive_chat()


if __name__ == "__main__":
    main()

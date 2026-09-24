import os
import tkinter as tk
import threading

mpv_path = r"C:\Users\Duong Phung\AppData\Local\Microsoft\WinGet\Packages\mpv-player.mpv-CI.MSVC_Microsoft.Winget.Source_8wekyb3d8bbwe"
if mpv_path not in os.environ.get("PATH", ""):
    os.environ["PATH"] += os.pathsep + mpv_path
from elevenlabs.client import ElevenLabs
from elevenlabs import save, stream


client = ElevenLabs(
    api_key=os.getenv("ELEVENLABS_API_KEY", "3a8229c3d33c57a6029dd4681680edc56778d4b71367cf3fc62d5aa4cd5eb8d9")
)


VOICES = {
    "bac": "EXAVITQu4vr4xnSDxMaL",    # ID giọng miền Bắc (Ví dụ: Bella)
    "trung": "Xb7hH8MSUJpSbSDYk0k2",  # ID giọng miền Trung (Đã đổi sang Alice hợp lệ)
    "nam": "IKne3meq5aSn9XLyUdCD"     # ID giọng miền Nam (Ví dụ: Charlie)
}

def text_to_speech(text: str, region: str, output_filename: str, play_streaming: bool = False):
 
    voice_id = VOICES.get(region.lower())
    if not voice_id:
        raise ValueError("Vùng miền không hợp lệ! Chỉ hỗ trợ: 'bac', 'trung', 'nam'")


    audio_generator = client.text_to_speech.convert(
        text=text,
        voice_id=voice_id,
        model_id="eleven_turbo_v2_5",
        language_code="vi"
    )

    if play_streaming:
        print("🔊 Đang phát Audio Streaming trực tiếp ra loa...")
        stream(audio_generator)
    else:
        save(audio_generator, output_filename)
        print(f"✅ Đã lưu file: {output_filename}")


if __name__ == "__main__":
    def start_ui():
        window = tk.Tk()
        window.title("AI Đọc Giọng Nói - Không cần nhấn Enter")
        window.geometry("500x350")
        
        lbl = tk.Label(window, text="Cứ gõ tiếng Việt thoải mái vào ô bên dưới.\nDừng tay 1.5 giây, AI sẽ tự động phát âm thanh!", font=("Arial", 12), fg="blue")
        lbl.pack(pady=10)
        
        text_box = tk.Text(window, font=("Arial", 14), wrap=tk.WORD, height=8)
        text_box.pack(expand=True, fill=tk.BOTH, padx=15, pady=5)
        
        status_lbl = tk.Label(window, text="Đang đợi bạn gõ...", font=("Arial", 10), fg="gray")
        status_lbl.pack(pady=5)
        
        timer = None
        
        def on_typing(event):
            nonlocal timer
            status_lbl.config(text="Đang gõ...", fg="orange")
            if timer is not None:
                window.after_cancel(timer)
            # Chờ 1.5s sau phím cuối cùng mới đọc
            timer = window.after(1500, trigger_speech)
            
        def trigger_speech():
            current_text = text_box.get("1.0", tk.END).strip()
            if current_text:
                status_lbl.config(text="🔊 Đang phát âm thanh...", fg="green")
                # Xóa khung gõ để sẵn sàng câu tiếp theo
                text_box.delete("1.0", tk.END)
                
                # Chạy TTS ở luồng (thread) khác để cửa sổ không bị đơ
                def run_tts():
                    try:
                        text_to_speech(current_text, "bac", "", play_streaming=True)
                        status_lbl.config(text="Đang đợi bạn gõ câu tiếp theo...", fg="gray")
                    except Exception as e:
                        status_lbl.config(text=f"❌ Lỗi: {e}", fg="red")
                
                threading.Thread(target=run_tts, daemon=True).start()
            else:
                status_lbl.config(text="Đang đợi bạn gõ...", fg="gray")

        text_box.bind("<KeyRelease>", on_typing)
        text_box.focus()
        
        print("🎙️ Cửa sổ giao diện đã được mở!")
        window.mainloop()

    # Bắt đầu giao diện
    start_ui()
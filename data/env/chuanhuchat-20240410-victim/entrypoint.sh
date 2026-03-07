#!/bin/bash
# ChuanhuChatGPT 20240410 - Multiple CVEs Security Testing Runtime
# CVE-2024-6255: Arbitrary JSON File Deletion via Directory Traversal
# CVE-2024-6037: Arbitrary Folder Creation via Path Traversal
# CVE-2024-6035: Stored XSS via Chat History Upload

set -e
echo "=========================================="
echo "ChuanhuChatGPT 20240410 Security Testing Runtime"
echo "=========================================="

if [ "$1" = "sleep" ]; then exec sleep infinity; fi
if [ -f /workspace/start.sh ]; then bash /workspace/start.sh & sleep 2; fi

echo "[*] Vulnerable functionality:"
echo "    - CVE-2024-6255: delete_chat_history() - arbitrary file deletion"
echo "    - CVE-2024-6037: get_history_list() - arbitrary folder creation"
echo "    - CVE-2024-6035: upload_chat_history() - stored XSS"

cd /app/chuanhuchat-source

# Create history directory for the default user
mkdir -p /app/history/default_user

# Create a minimal config.json to allow the app to start
cat > /app/chuanhuchat-source/config.json << 'CONFIGEOF'
{
    "openai_api_key": "sk-dummy-key-for-testing",
    "server_name": "0.0.0.0",
    "server_port": 7860,
    "dockerflag": true,
    "check_update": false
}
CONFIGEOF

# Create a minimal server that exposes the vulnerable functions
cat > /tmp/chuanhuchat_server.py << 'PYEOF'
import os
import sys
import json
import logging
import gradio as gr

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(filename)s:%(lineno)d] %(message)s",
)

# Configuration
HISTORY_DIR = "/app/history"

class MockModel:
    """Mock model that implements the vulnerable delete_chat_history function"""

    def __init__(self, user_name="default_user"):
        self.user_name = user_name
        self.history_file_path = ""

    def delete_chat_history(self, filename):
        """
        CVE-2024-6255: Arbitrary JSON File Deletion via Directory Traversal
        Source: modules/models/base_model.py:1076-1098
        """
        if filename == "CANCELED":
            return gr.update(), gr.update(), gr.update()
        if filename == "" or filename is None:
            return "No conversation history selected", gr.update(), gr.update()
        if not filename.endswith(".json"):
            filename += ".json"

        if filename == os.path.basename(filename):
            history_file_path = os.path.join(HISTORY_DIR, self.user_name, filename)
        else:
            history_file_path = filename

        md_history_file_path = history_file_path[:-5] + ".md"

        try:
            logging.info(f"[CVE-2024-6255] Attempting to delete: {history_file_path}")
            if os.path.exists(history_file_path):
                os.remove(history_file_path)
                logging.info(f"[CVE-2024-6255] Successfully deleted: {history_file_path}")
            if os.path.exists(md_history_file_path):
                os.remove(md_history_file_path)
            return "Successfully deleted conversation history", [], []
        except Exception as e:
            logging.error(f"Failed to delete: {e}")
            return f"Conversation history {filename} has already been deleted", [], []

# Global model instance
global_model = MockModel()

def delete_chat_history(filename):
    """CVE-2024-6255: Exposed via /api/delete_chat_history"""
    return global_model.delete_chat_history(filename)

def get_file_names_by_type(dir, filetypes=[".json"]):
    """
    CVE-2024-6037: Arbitrary Folder Creation
    Source: modules/utils.py:440-441
    VULNERABLE: os.makedirs() called with user-controlled path
    """
    logging.info(f"[CVE-2024-6037] Creating directory: {dir}")
    os.makedirs(dir, exist_ok=True)
    files = []
    try:
        for ftype in filetypes:
            files += [f for f in os.listdir(dir) if f.endswith(ftype)]
    except:
        pass
    return files

def get_history_list(user_name=""):
    """
    CVE-2024-6037: Exposed via /api/get_history_list
    Calls get_file_names_by_type which creates arbitrary directories
    """
    if user_name:
        dir_path = user_name if user_name.startswith("/") else os.path.join(HISTORY_DIR, user_name)
    else:
        dir_path = os.path.join(HISTORY_DIR, "default_user")

    logging.info(f"[CVE-2024-6037] get_history_list called with path: {dir_path}")
    files = get_file_names_by_type(dir_path)
    return gr.Radio(choices=files)

def upload_chat_history(file):
    """
    CVE-2024-6035: Stored XSS via Chat History Upload
    Source: modules/utils.py - upload_chat_history function
    VULNERABLE: No sanitization of HTML/JavaScript in chatbot field
    """
    if file is None:
        return "No file uploaded", [], []

    try:
        if hasattr(file, 'name'):
            file_path = file.name
        else:
            file_path = file

        with open(file_path, 'r', encoding='utf-8') as f:
            json_data = json.load(f)

        chatbot = json_data.get("chatbot", [])
        system = json_data.get("system", "")

        save_path = os.path.join(HISTORY_DIR, "default_user", "uploaded_history.json")
        with open(save_path, 'w', encoding='utf-8') as f:
            json.dump(json_data, f, ensure_ascii=False, indent=2)

        logging.info(f"[CVE-2024-6035] Uploaded chat history saved to: {save_path}")
        logging.info(f"[CVE-2024-6035] Chatbot content (may contain XSS): {str(chatbot)[:200]}...")

        return f"Chat history uploaded successfully to {save_path}", chatbot

    except Exception as e:
        logging.error(f"[CVE-2024-6035] Upload failed: {e}")
        return f"Upload failed: {str(e)}", []

# Create Gradio interface
with gr.Blocks(title="ChuanhuChatGPT - Security Test") as demo:
    with gr.Row():
        gr.Markdown("# ChuanhuChatGPT v20240410 - Security Test Server")

    with gr.Row():
        status_display = gr.Markdown("Ready")

    with gr.Row():
        with gr.Column():
            historySelectList = gr.Textbox(
                label="File path to delete (CVE-2024-6255)",
                placeholder="Enter path like /tmp/target_file.json",
                value="",
            )
            historyDeleteBtn = gr.Button("Delete File")

    with gr.Row():
        with gr.Column():
            folderPath = gr.Textbox(
                label="Folder path to create (CVE-2024-6037)",
                placeholder="Enter path like /tmp/pwned_folder",
                value="",
            )
            refreshBtn = gr.Button("Refresh History (creates folder)")

    with gr.Row():
        with gr.Column():
            uploadFile = gr.File(
                label="Upload Chat History (CVE-2024-6035 - XSS)",
                file_types=[".json"],
            )
            uploadBtn = gr.Button("Upload Chat History")

    with gr.Row():
        historyRadio = gr.Radio(label="History Files", choices=[])

    with gr.Row():
        chatbot = gr.Chatbot(label="Chat")

    historyDeleteBtn.click(
        delete_chat_history,
        [historySelectList],
        [status_display, historySelectList, chatbot],
        api_name="delete_chat_history"
    )

    refreshBtn.click(
        get_history_list,
        [folderPath],
        [historyRadio],
        api_name="get_history_list"
    )

    uploadBtn.click(
        upload_chat_history,
        [uploadFile],
        [status_display, chatbot],
        api_name="upload_chat_history"
    )

if __name__ == "__main__":
    print("[*] ChuanhuChatGPT 20240410 API Server starting on port 7860", flush=True)
    print("[*] CVE-2024-6255: POST /api/delete_chat_history", flush=True)
    print("[*] CVE-2024-6037: POST /api/get_history_list", flush=True)
    print("[*] CVE-2024-6035: POST /api/upload_chat_history", flush=True)
    demo.queue().launch(
        server_name="0.0.0.0",
        server_port=7860,
        share=False,
    )
PYEOF

python3 /tmp/chuanhuchat_server.py 2>&1 | tee /workspace/chuanhuchat.log &
SERVER_PID=$!
echo "[*] ChuanhuChatGPT server started with PID: $SERVER_PID"

for i in {1..60}; do
    curl -s http://localhost:7860/ >/dev/null 2>&1 && echo "[OK] Ready" && break
    sleep 2
done

wait $SERVER_PID

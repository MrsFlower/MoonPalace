import sys
import json
import urllib.request
import urllib.error

def main():
    if len(sys.argv) < 3:
        print("Usage: python llm_worker.py <request_json> <response_json>")
        sys.exit(1)

    req_file = sys.argv[1]
    res_file = sys.argv[2]

    try:
        with open(req_file, "r", encoding="utf-8") as f:
            req_data = json.load(f)
        
        api_url = req_data.get("api_url", "https://api.deepseek.com/v1")
        # Handle endpoints missing /chat/completions
        if not api_url.endswith("/chat/completions"):
            api_url = api_url.rstrip("/") + "/chat/completions"

        api_key = req_data.get("api_key", "")
        model = req_data.get("model_name", "deepseek-chat")
        messages = req_data.get("messages", [])

        payload = {
            "model": model,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048
        }
        
        # Check if we should enforce JSON mode
        if req_data.get("response_format") == "json_object":
            payload["response_format"] = {"type": "json_object"}

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(api_url, data=data, headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        })

        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode("utf-8")
            res_json = json.loads(res_body)
            
            content = res_json["choices"][0]["message"]["content"]
            
            with open(res_file, "w", encoding="utf-8") as out:
                json.dump({"status": "success", "content": content}, out, ensure_ascii=False, indent=2)

    except Exception as e:
        with open(res_file, "w", encoding="utf-8") as out:
            json.dump({"status": "error", "message": str(e)}, out, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    main()

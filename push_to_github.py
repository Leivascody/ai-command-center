#!/usr/bin/env python3
"""Push dashboard files to GitHub using gh CLI."""
import subprocess, base64, json, os

REPO = "Leivascody/ai-command-center"

def push_file(path, message):
    with open(path, 'rb') as f:
        content = base64.b64encode(f.read()).decode()
    
    filename = os.path.basename(path)
    
    # Check if file already exists (get SHA)
    result = subprocess.run(
        ['gh', 'api', f'/repos/{REPO}/contents/{filename}'],
        capture_output=True, text=True
    )
    
    payload = {
        "message": message,
        "content": content
    }
    
    if result.returncode == 0:
        sha = json.loads(result.stdout).get('sha')
        if sha:
            payload["sha"] = sha
    
    # Create/update file
    result = subprocess.run(
        ['gh', 'api', '--method', 'PUT',
         f'/repos/{REPO}/contents/{filename}',
         '--input', '-'],
        input=json.dumps(payload),
        capture_output=True, text=True
    )
    
    if result.returncode == 0:
        data = json.loads(result.stdout)
        print(f"✅ Pushed {filename} -> {data.get('content', {}).get('html_url', 'OK')}")
    else:
        print(f"❌ Failed {filename}: {result.stderr}")

os.chdir('/Users/codyleivas/ollama-dashboard')

# Push index.html
push_file('index.html', 'Add dashboard')

# Push collect_jobs.sh
push_file('collect_jobs.sh', 'Add job collector script')

print("\nDone! Enable GitHub Pages at:")
print(f"https://github.com/{REPO}/settings/pages")

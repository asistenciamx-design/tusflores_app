import json

file_path = r'C:\Users\qynqo\.gemini\antigravity\brain\33d69dd4-e964-4a3e-855d-b9ed90cd4da7\.system_generated\steps\29\output.txt'

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    for project in data.get('projects', []):
        if project.get('title') == 'florerias':
            print(f"Project: {project.get('title')} ({project.get('name')})")
            for screen in project.get('screenInstances', []):
                if 'label' in screen:
                    print(f"  - [{screen['id']}] {screen['label']}")
except Exception as e:
    print(f"Error reading or parsing file: {e}")

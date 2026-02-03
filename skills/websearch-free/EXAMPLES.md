# websearch-free Examples

## OpenClaw Integration

### Method 1: JSON stdin/stdout (Recommended)

```python
import subprocess
import json

def web_search(query: str, max_results: int = 10) -> dict:
    input_data = json.dumps({
        "query": query,
        "max_results": max_results,
        "page": 1
    })
    
    result = subprocess.run(
        ["python", "skills/websearch-free/websearch.py", "--json"],
        input=input_data,
        capture_output=True,
        text=True
    )
    
    return json.loads(result.stdout)

# Usage
results = web_search("python tutorials", max_results=5)
for r in results["results"]:
    print(f"{r['title']}: {r['url']}")
```

### Method 2: Import as Module

```python
import sys
sys.path.insert(0, 'skills/websearch-free')

from websearch import websearch

results = websearch("machine learning", max_results=5)
print(json.dumps(results, indent=2))
```

### Method 3: Command Line

```bash
# JSON output for scripting
python websearch.py "search query" --raw

# Human-readable output
python websearch.py "search query" -n 5
```

## Example Output

```json
{
  "results": [
    {
      "title": "Python Tutorial - W3Schools",
      "url": "https://www.w3schools.com/python/",
      "snippet": "W3Schools offers free online tutorials, references and exercises in all the major languages of the web."
    },
    {
      "title": "The Python Tutorial",
      "url": "https://docs.python.org/3/tutorial/",
      "snippet": "Python is an easy to learn, powerful programming language."
    }
  ],
  "query": "python tutorial",
  "provider": "duckduckgo-lite",
  "page": 1,
  "count": 2
}
```

## Error Format

```json
{
  "error": "Search blocked (CAPTCHA). Try again later.",
  "results": [],
  "query": "search query"
}
```

## Configuration Examples

### Using SearXNG

Edit `config.json`:
```json
{
  "provider": "searxng",
  "providers": {
    "searxng": {
      "enabled": true,
      "baseUrl": "https://your-searx-instance.com/"
    }
  }
}
```

### Custom Rate Limiting

```json
{
  "providers": {
    "duckduckgo-lite": {
      "rateLimit": {
        "requestsPerMinute": 10,
        "minDelayBetweenRequestsMs": 5000
      }
    }
  }
}
```

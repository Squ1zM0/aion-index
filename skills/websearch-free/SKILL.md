# websearch-free Skill

Free web search without API keys for OpenClaw using DuckDuckGo Lite or SearXNG.

## Overview

This skill provides autonomous web search capabilities without requiring API keys. It scrapes search results from privacy-focused search engines and returns structured JSON data compatible with OpenClaw's existing `web_search` tool.

**Features:**
- No API keys required
- Respects robots.txt and rate limits
- Graceful error handling (CAPTCHA, blocks)
- Multi-provider support (DuckDuckGo Lite, SearXNG)
- Paginated results
- Configurable retry logic

## Quick Start

```bash
# Search from command line
python websearch.py "open source ai tools"

# Limit results
python websearch.py -n 5 "python tutorials"

# Use specific provider
python websearch.py --provider searxng "privacy tools"

# JSON output for scripting
python websearch.py -n 3 "news today" --raw

# JSON stdin/stdout mode (for OpenClaw)
echo '{"query": "weather forecast", "max_results": 3}' | python websearch.py --json
```

## File Structure

```
skills/websearch-free/
├── manifest.json      # Skill metadata for OpenClaw loader
├── config.json        # User-editable configuration
├── websearch.py       # Core search implementation
├── SKILL.md          # This documentation
└── tests/            # Test files (optional)
```

## Configuration

Edit `config.json` to customize behavior:

```json
{
  "provider": "duckduckgo-lite",  // Default provider
  "providers": {
    "duckduckgo-lite": {
      "enabled": true,
      "baseUrl": "https://lite.duckduckgo.com/lite/",
      "timeoutMs": 15000,
      "retries": 2,
      "retryDelayMs": 1000,
      "rateLimit": {
        "requestsPerMinute": 30,
        "minDelayBetweenRequestsMs": 2000
      },
      "headers": {
        "User-Agent": "..."
      }
    },
    "searxng": {
      "enabled": false,
      "baseUrl": "https://searx.be/",
      "timeoutMs": 15000,
      "retries": 2,
      "rateLimit": {
        "requestsPerMinute": 20,
        "minDelayBetweenRequestsMs": 3000
      }
    }
  },
  "defaults": {
    "maxResults": 10,
    "safeSearch": true,
    "region": "us-en"
  }
}
```

### Provider Options

#### DuckDuckGo Lite (Default)
- **Reliable** - Most stable scraping target
- **Rate limit**: 30 req/min recommended
- **Region codes**: `us-en`, `uk-en`, `de-de`, `fr-fr`, etc.

#### SearXNG (Optional)
- **Privacy-focused** - Meta search engine
- **Requires** manual instance configuration
- **Rate limits** vary by instance

Popular SearXNG instances:
- `https://searx.be/` (Belgium)
- `https://search.sapti.me/` (Germany)
- `https://search.bus-hit.me/` (Netherlands)
- Run your own: https://github.com/searxng/searxng

## Return Format

Matches OpenClaw `web_search` tool expectations:

```json
{
  "results": [
    {
      "title": "Page Title",
      "url": "https://example.com",
      "snippet": "Short description of the result..."
    }
  ],
  "query": "search query",
  "provider": "duckduckgo-lite",
  "page": 1,
  "count": 10
}
```

On error:

```json
{
  "error": "Error message",
  "results": [],
  "query": "search query"
}
```

## Usage in OpenClaw

The skill exposes a `websearch` tool that accepts:

```python
# Tool call format
{
  "tool": "websearch",
  "args": {
    "query": "search terms",
    "max_results": 10,      # optional, default 10
    "page": 1,              # optional, default 1
    "provider": "duckduckgo-lite"  # optional
  }
}
```

### Integration Example

```python
# In your agent code
import subprocess
import json

def web_search(query: str, max_results: int = 10) -> dict:
    input_json = json.dumps({
        "query": query,
        "max_results": max_results
    })
    
    result = subprocess.run(
        ["python", "skills/websearch-free/websearch.py", "--json"],
        input=input_json,
        capture_output=True,
        text=True
    )
    
    return json.loads(result.stdout)
```

## Architecture

### Flow

1. **Input** → Parse query and options
2. **Rate Limit** → Check last request time, delay if needed
3. **Request** → HTTP POST (DDG) or GET (SearXNG)
4. **Parse** → Extract results from HTML or JSON
5. **Format** → Return structured JSON

### Rate Limiting

- Per-provider tracking
- Configurable delays
- Automatic retry with backoff
- Respects 429 responses

### Error Handling

- **Timeout** → Retry with exponential backoff
- **CAPTCHA/Block** → Return error after retries exhausted
- **Parse failure** → Attempt alternative parsing strategies
- **Network issues** → Clear error messages

## Testing

### Manual Tests

```bash
# Basic search
cd skills/websearch-free
python websearch.py "python programming" --raw

# Pagination
python websearch.py "machine learning" -p 2 -n 5 --raw

# Error case (should fail gracefully)
python websearch.py " " -n 1 --raw

# Test with invalid provider (should fallback to DDG)
echo '{"query": "test", "provider": "invalid"}' | python websearch.py --json
```

### Expected Output Format

```json
{
  "results": [
    {
      "title": "Result Title",
      "url": "https://example.com/path",
      "snippet": "Description text..."
    }
  ],
  "count": 10,
  "page": 1,
  "query": "search terms",
  "provider": "duckduckgo-lite"
}
```

## Dependencies

```bash
pip install requests beautifulsoup4
```

## Limitations

- No image or news search (web only)
- Slower than API-based search (rate limiting required)
- CAPTCHA may occasionally block requests
- Search results may differ from main DuckDuckGo

## Troubleshooting

### "Import error" messages
```bash
pip install requests beautifulsoup4
```

### Rate limit errors
Increase `minDelayBetweenRequestsMs` in config.json

### CAPTCHA blocks
- Wait a few minutes and retry
- Switch to SearXNG provider
- Change User-Agent in config

### No results returned
- Check query isn't empty
- Verify DuckDuckGo Lite is accessible
- Try increasing timeoutMs

## License

MIT - Free to use with OpenClaw

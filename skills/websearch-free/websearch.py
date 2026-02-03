#!/usr/bin/env python3
"""
websearch-free - Free web search without API keys
Supports DuckDuckGo Lite and SearXNG
"""

import sys
import json
import time
import re
import urllib.parse
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Any

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print(json.dumps({
        "error": "Missing dependencies. Install with: pip install requests beautifulsoup4",
        "results": []
    }))
    sys.exit(1)

# Rate limiting tracker
_last_request_time: Dict[str, datetime] = {}

def _check_rate_limit(provider: str, min_delay_ms: int) -> None:
    """Enforce rate limiting between requests"""
    now = datetime.now()
    if provider in _last_request_time:
        elapsed = (now - _last_request_time[provider]).total_seconds() * 1000
        if elapsed < min_delay_ms:
            sleep_ms = min_delay_ms - elapsed
            time.sleep(sleep_ms / 1000)
    _last_request_time[provider] = datetime.now()

def _is_ad_url(url: str) -> bool:
    """Check if URL is an ad/redirect URL rather than organic result"""
    if not url:
        return True
    ad_indicators = [
        'duckduckgo.com/y.js',
        'duckduckgo.com/l.js',
        '/aclick?',
        'utm_source=',
        'utm_campaign=',
        'bing.com/aclick'
    ]
    url_lower = url.lower()
    return any(indicator in url_lower for indicator in ad_indicators)

def parse_duckduckgo_results(html: str) -> List[Dict[str, str]]:
    """Parse DuckDuckGo Lite HTML results"""
    results = []
    soup = BeautifulSoup(html, 'html.parser')
    
    # DDG Lite structure:
    # Row with link: "1.Title text"
    # Next row: snippet text
    # Next row: URL text (may include link)
    # Next row: (blank separator)
    
    tables = soup.find_all('table')
    
    for table in tables:
        rows = table.find_all('tr')
        
        i = 0
        while i < len(rows):
            row = rows[i]
            
            # Look for a row containing a link with href
            link_tag = row.find('a', href=True)
            
            if not link_tag:
                i += 1
                continue
            
            title = link_tag.get_text(strip=True)
            raw_url = link_tag.get('href', '')
            
            # Skip ads and low-quality matches
            if _is_ad_url(raw_url):
                i += 1
                continue
            
            # Skip navigation/utility links
            if title.lower() in ['more info', 'privacy policy', 'about', 'home', 'advertisement']:
                i += 1
                continue
            
            # Resolve DuckDuckGo redirect URLs to actual destinations
            url = raw_url
            if '/l/?' in raw_url or '/l.js?' in raw_url or '/y.js?' in raw_url:
                try:
                    if 'uddg=' in raw_url:
                        match = re.search(r'uddg=([^&]+)', raw_url)
                        if match:
                            url = urllib.parse.unquote(match.group(1))
                except:
                    url = raw_url
            
            # Get snippet from next row(s)
            # DDG structure: title row, snippet row, URL row, blank row
            snippet = ""
            temp_i = i + 1
            # Look ahead up to 3 rows for text content
            while temp_i < len(rows) and temp_i <= i + 3:
                check_row = rows[temp_i]
                # If this row has a link and it's NOT an ad redirect, skip it (it's URL row)
                row_link = check_row.find('a', href=True)
                if row_link:
                    link_href = row_link.get('href', '')
                    # If the link is just showing a plain URL (not a redirect), use as snippet
                    if not _is_ad_url(link_href) and link_href.startswith('http'):
                        link_text = row_link.get_text(strip=True)
                        if link_text and not snippet:
                            snippet = link_text  # Use the URL text as snippet
                    break  # Stop at URL row
                else:
                    # No link - this is the snippet row
                    text = check_row.get_text(separator=' ', strip=True)
                    if text and len(text) > 10:
                        snippet = text
                        break
                temp_i += 1
            
            # Validate title quality - remove number prefixes like "1."
            title = re.sub(r'^\d+\.\s*', '', title).strip()
            
            # Validate and add result
            if title and url and not _is_ad_url(url) and len(title) > 3:
                # Clean up snippet
                snippet = re.sub(r'\s+', ' ', snippet).strip()
                # Limit snippet length
                if len(snippet) > 500:
                    snippet = snippet[:497] + '...'
                
                results.append({
                    "title": title,
                    "url": url,
                    "snippet": snippet
                })
            
            # Move to next result (skip current row + up to 3 more: snippet, URL, blank)
            i += 4  # Move by 4 to get to next result block
    
    return results

def parse_searxng_results(data: Dict[str, Any]) -> List[Dict[str, str]]:
    """Parse SearXNG JSON results"""
    results = []
    
    for result in data.get("results", []):
        results.append({
            "title": result.get("title", ""),
            "url": result.get("url", ""),
            "snippet": result.get("content", "")
        })
    
    return results

def search_duckduckgo(
    query: str,
    config: Dict[str, Any],
    max_results: int = 10,
    page: int = 1
) -> Dict[str, Any]:
    """Search using DuckDuckGo Lite"""
    
    provider_config = config.get("providers", {}).get("duckduckgo-lite", {})
    base_url = provider_config.get("baseUrl", "https://lite.duckduckgo.com/lite/")
    timeout = provider_config.get("timeoutMs", 15000) / 1000
    retries = provider_config.get("retries", 2)
    retry_delay = provider_config.get("retryDelayMs", 1000) / 1000
    rate_limit = provider_config.get("rateLimit", {})
    min_delay = rate_limit.get("minDelayBetweenRequestsMs", 2000)
    headers = provider_config.get("headers", {})
    
    # Rate limiting
    _check_rate_limit("duckduckgo-lite", min_delay)
    
    # Build parameters
    params = {
        "q": query,
        "kl": config.get("defaults", {}).get("region", "us-en")
    }
    
    if page > 1:
        params["s"] = (page - 1) * max_results
        params["dc"] = (page - 1) * max_results + 1
    
    safe_search = config.get("defaults", {}).get("safeSearch", True)
    if safe_search:
        params["kp"] = "1"
    
    last_error = None
    for attempt in range(retries + 1):
        try:
            response = requests.post(
                base_url,
                data=params,
                headers=headers,
                timeout=timeout,
                allow_redirects=True
            )
            response.raise_for_status()
            
            results = parse_duckduckgo_results(response.text)
            
            # Check for CAPTCHA or block
            if any(marker in response.text.lower() for marker in [
                "captcha", "verify you are human", "blocked", "rate limit"
            ]):
                if attempt < retries:
                    time.sleep(retry_delay * (attempt + 1))
                    continue
                return {
                    "error": "Search blocked (CAPTCHA or rate limit). Try again later.",
                    "results": []
                }
            
            # Limit results
            results = results[:max_results]
            
            return {
                "results": results,
                "page": page,
                "query": query,
                "provider": "duckduckgo-lite",
                "count": len(results)
            }
            
        except requests.exceptions.Timeout:
            last_error = f"Request timeout after {timeout}s"
            if attempt < retries:
                time.sleep(retry_delay * (attempt + 1))
                continue
        except requests.exceptions.RequestException as e:
            last_error = str(e)
            if attempt < retries:
                time.sleep(retry_delay * (attempt + 1))
                continue
    
    return {
        "error": last_error or "Unknown error occurred",
        "results": [],
        "query": query
    }

def search_searxng(
    query: str,
    config: Dict[str, Any],
    max_results: int = 10,
    page: int = 1
) -> Dict[str, Any]:
    """Search using SearXNG JSON API"""
    
    provider_config = config.get("providers", {}).get("searxng", {})
    base_url = provider_config.get("baseUrl", "https://searx.be/")
    timeout = provider_config.get("timeoutMs", 15000) / 1000
    retries = provider_config.get("retries", 2)
    retry_delay = provider_config.get("retryDelayMs", 1000) / 1000
    rate_limit = provider_config.get("rateLimit", {})
    min_delay = rate_limit.get("minDelayBetweenRequestsMs", 3000)
    
    # Ensure URL ends with / and has correct path
    if not base_url.endswith("/"):
        base_url += "/"
    search_url = f"{base_url}search"
    
    # Rate limiting
    _check_rate_limit("searxng", min_delay)
    
    params = {
        "q": query,
        "format": "json",
        "pageno": page,
        "language": "en"
    }
    
    safe_search = config.get("defaults", {}).get("safeSearch", True)
    if safe_search:
        params["safesearch"] = "1"
    
    last_error = None
    for attempt in range(retries + 1):
        try:
            response = requests.get(
                search_url,
                params=params,
                timeout=timeout,
                headers={
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                    "Accept": "application/json"
                }
            )
            response.raise_for_status()
            
            data = response.json()
            results = parse_searxng_results(data)
            results = results[:max_results]
            
            return {
                "results": results,
                "page": page,
                "query": query,
                "provider": "searxng",
                "count": len(results)
            }
            
        except (requests.exceptions.Timeout, requests.exceptions.RequestException) as e:
            last_error = str(e)
            if attempt < retries:
                time.sleep(retry_delay * (attempt + 1))
                continue
        except json.JSONDecodeError as e:
            last_error = f"Failed to parse JSON: {str(e)}"
            if attempt < retries:
                time.sleep(retry_delay * (attempt + 1))
                continue
    
    return {
        "error": last_error or "Unknown error occurred",
        "results": [],
        "query": query
    }

def websearch(
    query: str,
    max_results: int = 10,
    page: int = 1,
    provider: Optional[str] = None,
    config_path: str = "config.json"
) -> Dict[str, Any]:
    """
    Main search function
    
    Args:
        query: Search query string
        max_results: Maximum number of results (default 10)
        page: Page number for pagination (default 1)
        provider: Override provider ("duckduckgo-lite" or "searxng")
        config_path: Path to config file
    
    Returns:
        Dict with "results" list and metadata
    """
    # Load config
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
    except FileNotFoundError:
        # Use default config
        config = {
            "provider": "duckduckgo-lite",
            "providers": {
                "duckduckgo-lite": {"enabled": True},
                "searxng": {"enabled": False}
            },
            "defaults": {"maxResults": 10, "safeSearch": True}
        }
    except json.JSONDecodeError as e:
        return {
            "error": f"Failed to parse config: {str(e)}",
            "results": []
        }
    
    # Determine provider
    if not provider:
        provider = config.get("provider", "duckduckgo-lite")
    
    providers = config.get("providers", {})
    
    # Check if requested provider is enabled
    if provider in providers and not providers[provider].get("enabled", True):
        # Try fallback to duckduckgo
        if provider != "duckduckgo-lite" and providers.get("duckduckgo-lite", {}).get("enabled", True):
            provider = "duckduckgo-lite"
        else:
            return {
                "error": f"Provider '{provider}' is disabled and no fallback available",
                "results": []
            }
    
    # Execute search
    if provider == "searxng":
        return search_searxng(query, config, max_results, page)
    else:
        # Default to duckduckgo
        return search_duckduckgo(query, config, max_results, page)

def cli_main():
    """Command-line interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Free web search without API keys")
    parser.add_argument("query", nargs="+", help="Search query")
    parser.add_argument("-n", "--max-results", type=int, default=10, help="Max results")
    parser.add_argument("-p", "--page", type=int, default=1, help="Page number")
    parser.add_argument("--provider", choices=["duckduckgo-lite", "searxng"], help="Search provider")
    parser.add_argument("--config", default="config.json", help="Config file path")
    parser.add_argument("--raw", action="store_true", help="Output raw JSON")
    
    args = parser.parse_args()
    
    query = " ".join(args.query)
    result = websearch(
        query=query,
        max_results=args.max_results,
        page=args.page,
        provider=args.provider,
        config_path=args.config
    )
    
    if args.raw:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        if "error" in result:
            print(f"Error: {result['error']}", file=sys.stderr)
            sys.exit(1)
        
        print(f"Results for: {result['query']}")
        print(f"Provider: {result.get('provider', 'unknown')}")
        print(f"Found: {result.get('count', 0)} results\n")
        
        for i, r in enumerate(result['results'], 1):
            print(f"{i}. {r['title']}")
            print(f"   URL: {r['url']}")
            if r.get('snippet'):
                snippet = r['snippet'][:200] + "..." if len(r['snippet']) > 200 else r['snippet']
                print(f"   {snippet}")
            print()

def json_main():
    """JSON stdin/stdout interface for OpenClaw integration"""
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print(json.dumps({
            "error": "Invalid JSON input",
            "results": []
        }))
        sys.exit(1)
    
    query = input_data.get("query", "")
    if not query:
        print(json.dumps({
            "error": "Missing 'query' parameter",
            "results": []
        }))
        sys.exit(1)
    
    result = websearch(
        query=query,
        max_results=input_data.get("max_results", 10),
        page=input_data.get("page", 1),
        provider=input_data.get("provider")
    )
    
    print(json.dumps(result, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--json":
        json_main()
    else:
        cli_main()

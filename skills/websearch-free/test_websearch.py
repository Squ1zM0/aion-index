#!/usr/bin/env python3
"""Test script for websearch-free skill"""

import json
import sys
import os

# Add skill directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from websearch import websearch, parse_duckduckgo_results

def test_parse_duckduckgo_results():
    """Test parsing with sample HTML"""
    sample_html = """
    <html>
    <body>
    <table>
    <tr><td>1. <a href="/l/?uddg=https%3A%2F%2Fexample.com">Test Title</a></td></tr>
    <tr><td>This is a snippet describing the result.</td></tr>
    <tr><td>https://example.com</td></tr>
    <tr><td></td></tr>
    <tr><td>2. <a href="/l/?uddg=https%3A%2F%2Ftest.com">Another Title</a></td></tr>
    <tr><td>Another snippet for the second result.</td></tr>
    <tr><td>https://test.com</td></tr>
    </table>
    </body>
    </html>
    """
    
    results = parse_duckduckgo_results(sample_html)
    
    assert len(results) == 2, f"Expected 2 results, got {len(results)}"
    assert results[0]['title'] == 'Test Title'
    assert results[0]['url'] == 'https://example.com'
    assert 'snippet' in results[0]
    
    print("[PASS] parse_duckduckgo_results test passed")
    return True

def test_websearch_integration():
    """Test actual search (requires network)"""
    print("Testing live search...")
    result = websearch("python tutorial", max_results=2)
    
    assert 'results' in result, "Result should contain 'results' key"
    assert 'query' in result, "Result should contain 'query' key"
    assert result['query'] == "python tutorial"
    assert result['provider'] == "duckduckgo-lite"
    
    if result.get('results'):
        for r in result['results']:
            assert 'title' in r and r['title']
            assert 'url' in r and r['url'].startswith('http')
        print(f"[PASS] websearch integration test passed ({len(result['results'])} results)")
    else:
        print("[WARN] websearch returned 0 results (may be rate limited)")
    
    return True

def test_error_handling():
    """Test error handling for invalid input"""
    # Empty query
    result = websearch("")
    assert 'error' in result or result.get('results') == []
    print("[PASS] Error handling test passed")
    return True

def test_output_format():
    """Verify output format matches expectations"""
    result = websearch("test query", max_results=1)
    
    # Verify structure
    assert 'results' in result
    assert isinstance(result['results'], list)
    
    # If results exist, check format
    for r in result['results']:
        assert isinstance(r, dict)
        assert 'title' in r
        assert 'url' in r
        assert 'snippet' in r
    
    print("[PASS] Output format test passed")
    return True

def main():
    """Run all tests"""
    print("=" * 50)
    print("websearch-free Skill Tests")
    print("=" * 50)
    
    tests = [
        ("Parse Function", test_parse_duckduckgo_results),
        ("Output Format", test_output_format),
        ("Error Handling", test_error_handling),
        ("Integration", test_websearch_integration),
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func in tests:
        try:
            print(f"\nRunning: {name}...")
            if test_func():
                passed += 1
        except Exception as e:
            print(f"[FAIL] {name} failed: {e}")
            failed += 1
    
    print("\n" + "=" * 50)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 50)
    
    return failed == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

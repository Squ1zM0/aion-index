---
name: memory-graph
description: Knowledge graph-based persistent memory system using the Model Context Protocol (MCP).
metadata:
  {
    "openclaw":
      {
        "requires": { "bins": ["uv"] },
        "emoji": "🧠"
      }
  }
---

# memory-graph

This skill implements a knowledge graph-based memory system. It allows the agent to store, retrieve, and traverse complex relationships between entities.

## Tools

### memory_graph_add
Add a node or edge to the knowledge graph.
Usage: `uv run --package mcp-server-memory mcp-server-memory add --path ./memory/graph.db --data '<json>'`

### memory_graph_query
Query the knowledge graph.
Usage: `uv run --package mcp-server-memory mcp-server-memory query --path ./memory/graph.db --query '<query>'`

## Instructions

- Use this tool to maintain long-term context that exceeds the limitations of standard text-based memory files.
- Favor entities and relationships (e.g., "Moltbook" -> "status" -> "compromised").

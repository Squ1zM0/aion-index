import sqlite3
import json
import sys
import os

DB_PATH = os.path.join(os.getcwd(), 'memory', 'graph.db')

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS entities 
                      (name TEXT PRIMARY KEY, type TEXT, observations TEXT)''')
    cursor.execute('''CREATE TABLE IF NOT EXISTS relations 
                      (source TEXT, relation TEXT, target TEXT, 
                       PRIMARY KEY (source, relation, target))''')
    conn.commit()
    conn.close()

def add_entities(data):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    for entity in data:
        observations = json.dumps(entity.get('observations', []))
        cursor.execute("INSERT OR REPLACE INTO entities VALUES (?, ?, ?)", 
                       (entity['name'], entity['entityType'], observations))
    conn.commit()
    conn.close()
    print(f"Added/Updated {len(data)} entities.")

def add_relations(data):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    for rel in data:
        cursor.execute("INSERT OR REPLACE INTO relations VALUES (?, ?, ?)", 
                       (rel['from'], rel['relation'], rel['to']))
    conn.commit()
    conn.close()
    print(f"Added/Updated {len(data)} relations.")

def query(q=None):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    if not q:
        cursor.execute("SELECT * FROM entities")
        entities = cursor.fetchall()
        cursor.execute("SELECT * FROM relations")
        relations = cursor.fetchall()
        print(json.dumps({"entities": entities, "relations": relations}, indent=2))
    else:
        # Simple text search for now
        cursor.execute("SELECT * FROM entities WHERE name LIKE ? OR observations LIKE ?", (f'%{q}%', f'%{q}%'))
        results = cursor.fetchall()
        print(json.dumps(results, indent=2))
    conn.close()

if __name__ == "__main__":
    init_db()
    cmd = sys.argv[1]
    if cmd == "add-entities":
        if os.path.isfile(sys.argv[2]):
            with open(sys.argv[2], 'r') as f:
                add_entities(json.load(f))
        else:
            add_entities(json.loads(sys.argv[2]))
    elif cmd == "add-relations":
        if os.path.isfile(sys.argv[2]):
            with open(sys.argv[2], 'r') as f:
                add_relations(json.load(f))
        else:
            add_relations(json.loads(sys.argv[2]))
    elif cmd == "query":
        query(sys.argv[2] if len(sys.argv) > 2 else None)

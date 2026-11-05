import json
import sqlite3
from pathlib import Path

class Store:
    def __init__(self, folder: Path):
        folder.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(folder / "gameshift.sqlite3")
        self.connection.execute("PRAGMA foreign_keys=ON")
        self.connection.execute("PRAGMA journal_mode=WAL")
        version = self.connection.execute("PRAGMA user_version").fetchone()[0]
        if version > 1:
            self.connection.close()
            raise RuntimeError("Database is newer than this GameShift build.")
        if version == 0:
            with self.connection:
                self.connection.execute("CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
                self.connection.execute("CREATE TABLE installations (path TEXT PRIMARY KEY, details TEXT NOT NULL)")
                self.connection.execute("PRAGMA user_version=1")
    def get(self, key, default=None):
        row = self.connection.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else default
    def set(self, key, value):
        with self.connection:
            self.connection.execute("INSERT INTO settings VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (key, json.dumps(value)))
    def save_installation(self, details):
        with self.connection:
            self.connection.execute("INSERT INTO installations VALUES (?,?) ON CONFLICT(path) DO UPDATE SET details=excluded.details", (details["path"], json.dumps(details)))
    def installations(self):
        return [json.loads(row[0]) for row in self.connection.execute("SELECT details FROM installations ORDER BY path")]
    def close(self):
        self.connection.close()

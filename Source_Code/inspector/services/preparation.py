"""Automatic administrator workspace preparation and searchable asset database."""
import hashlib
import json
import re
import shutil
import sqlite3
import uuid
from pathlib import Path
from inspector.services.workspace import (scan_installation, import_resources, build_documents, atomic_json, resource_type, Cancelled)
from manager.services.catalog import profiles

PIPELINE_VERSION = "0.4.1"

def installation_key(folder):
    return hashlib.sha256(str(Path(folder).resolve()).encode()).hexdigest()[:20]

def infer_identity(report):
    archives = {a["relative_path"].lower(): a for a in report["archives"]}
    for profile in profiles():
        required = [a for a in profile["archives"] if a.get("required", True)]
        if required and all(a["path"].lower() in archives and archives[a["path"].lower()]["sha256"].lower() == a["sha256"].lower() for a in required):
            return {k: profile[k] for k in ("game_id", "distribution", "language", "executable_product_version")}
    metadata = report.get("metadata", {})
    distribution = metadata.get("distribution_metadata", [])
    item = distribution[0] if distribution else {}
    name = item.get("name") or Path(report["installation"]).name
    game_id = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:60] or "unidentified"
    executable = next((e for e in metadata.get("executables", []) if Path(e["path"]).stem.lower() == game_id), {})
    return {"game_id": game_id, "distribution": item.get("distribution", "Unverified"), "language": next(iter(item.get("languages", [])), "unknown"), "executable_product_version": executable.get("product_version") or executable.get("fixed_product_version") or "unknown"}

def write_database(path, report, profile, imported, cancelled=lambda: False):
    imported_rows = {(a["archive"], a["source_path"]): a for a in imported.get("assets", [])}
    diagnostics = list(imported.get("errors", []))
    connection = sqlite3.connect(path)
    try:
        connection.execute("PRAGMA foreign_keys=ON")
        with connection:
            connection.executescript("""
                CREATE TABLE installation (path TEXT PRIMARY KEY, edition_id TEXT NOT NULL, metadata_json TEXT NOT NULL, verification TEXT NOT NULL);
                CREATE TABLE archives (path TEXT PRIMARY KEY, source_path TEXT NOT NULL, sha256 TEXT NOT NULL, bytes INTEGER NOT NULL, state TEXT NOT NULL, header_json TEXT NOT NULL);
                CREATE TABLE assets (id TEXT PRIMARY KEY, archive_path TEXT NOT NULL REFERENCES archives(path), source_path TEXT, block_index INTEGER NOT NULL, offset INTEGER NOT NULL, stored_bytes INTEGER NOT NULL, decoded_bytes INTEGER NOT NULL, flags TEXT NOT NULL, type TEXT NOT NULL, status TEXT NOT NULL, raw_path TEXT, preview_path TEXT, payload_sha256 TEXT, format TEXT, confidence TEXT, metadata_json TEXT NOT NULL);
                CREATE INDEX assets_name ON assets(source_path);
                CREATE INDEX assets_type_status ON assets(type, status);
                CREATE INDEX assets_archive_block ON assets(archive_path, block_index);
                CREATE TABLE mappings (asset_id TEXT NOT NULL REFERENCES assets(id), role TEXT NOT NULL, metadata_json TEXT NOT NULL, PRIMARY KEY(asset_id,role));
                CREATE TABLE dependencies (asset_id TEXT NOT NULL REFERENCES assets(id), dependency_id TEXT NOT NULL REFERENCES assets(id), PRIMARY KEY(asset_id,dependency_id));
                CREATE TABLE diagnostics (archive_path TEXT, source_path TEXT, message TEXT NOT NULL);
                PRAGMA user_version=2;
            """)
            connection.execute("PRAGMA foreign_keys=ON")
            connection.execute("INSERT INTO installation VALUES (?,?,?,?)", (report["installation"], profile["edition_id"], json.dumps(report.get("metadata", {})), "inspected"))
            for archive in report["archives"]:
                if cancelled(): raise Cancelled()
                connection.execute("INSERT INTO archives VALUES (?,?,?,?,?,?)", (archive["relative_path"], archive["path"], archive["sha256"], archive["size_bytes"], archive["state"], json.dumps(archive.get("header", {}))))
                for message in (archive.get("error"), archive.get("reader_warning")):
                    if message: diagnostics.append({"archive": archive["relative_path"], "error": message})
                for row in archive["assets"]:
                    if cancelled(): raise Cancelled()
                    name = row["source_path"]
                    identity = archive["relative_path"] + "|" + (name or "block:" + str(row["block_index"]))
                    entry = imported_rows.get((archive["relative_path"], name), {})
                    output = Path(imported["output_dir"]) if entry else None
                    status = entry.get("normalization", "located" if name else "unnamed")
                    connection.execute("INSERT INTO assets VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", (hashlib.sha256(identity.encode()).hexdigest()[:20], archive["relative_path"], name or None, row["block_index"], row["offset"], row["stored_bytes"], row["decoded_bytes"], row["flags"], entry.get("identification", {}).get("type", resource_type(name) if name else "unknown"), status, str(output / entry["raw_path"]) if entry else None, str(output / entry["preview_path"]) if entry.get("preview_path") else None, entry.get("sha256"), entry.get("identification", {}).get("format"), entry.get("identification", {}).get("confidence"), json.dumps(entry.get("identification", {}))))
            from adapters.diablo1.validation import animation_mapping
            asset_ids = {(name.replace("\\", "/").lower(), archive): hashlib.sha256((archive+"|"+name).encode()).hexdigest()[:20] for archive,name in imported_rows}
            validation = imported.get("validation", {})
            decoded_names = {a["source_path"] for a in validation.get("animations", [])}
            for (archive,name),entry in imported_rows.items():
                mapping = animation_mapping(name,entry.get("identification", {})) if profile["game_id"] == "diablo1" else None
                if mapping:
                    mapping["all_frames_decoded"] = name.replace("\\", "/") in decoded_names and archive.lower() == "diabdat.mpq"
                    connection.execute("INSERT INTO mappings VALUES (?,?,?)", (asset_ids[(name.replace("\\", "/"),archive)], "animation",json.dumps(mapping)))
            if validation.get("status") == "representative validation complete":
                dependencies = [(a["source_path"], validation["palette"]) for a in validation["animations"]]+[(a["source_path"],validation["translation"]) for a in validation["animations"]]
                dependencies += [("levels/l1data/l1.til","levels/l1data/l1."+ext) for ext in ("cel","min","sol")]+[("levels/l1data/l1.til",validation["palette"])]
                for subject,dependency in dependencies:
                    a = asset_ids.get((subject,"DIABDAT.MPQ")); b = asset_ids.get((dependency,"DIABDAT.MPQ"))
                    if a and b: connection.execute("INSERT OR IGNORE INTO dependencies VALUES (?,?)",(a,b))
            connection.executemany("INSERT INTO diagnostics VALUES (?,?,?)", [(d.get("archive"), d.get("source_path"), d["error"]) for d in diagnostics])
    finally:
        connection.close()

def prepare_installation(folder, workspace, extra=(), progress=lambda value, message: None, cancelled=lambda: False):
    if not str(folder).strip(): raise ValueError("Choose a game installation folder")
    folder = Path(folder).resolve()
    workspace = Path(workspace).resolve()
    if workspace == folder or folder in workspace.parents:
        raise ValueError("Inspector workspace must be outside the game installation")
    game_workspace = workspace / "games" / installation_key(folder)
    report = scan_installation(folder, game_workspace, extra, lambda v, m: progress(v * 40 // 100, m), cancelled)
    inspected = [a["relative_path"] for a in report["archives"] if a["state"] == "Inspected"]
    if not inspected: raise ValueError("No supported archives could be inspected")
    identity = infer_identity(report)
    key = hashlib.sha256(json.dumps({"pipeline": PIPELINE_VERSION, "report": report}, sort_keys=True).encode()).hexdigest()[:20]
    edition_id = identity["game_id"] + "-" + key[:12]
    profile, catalog = build_documents(report, edition_id, identity["game_id"], identity["distribution"], identity["language"], identity["executable_product_version"], inspected)
    selected = [(a["relative_path"], row) for a in report["archives"] if a["state"] == "Inspected" for row in a["assets"] if row["source_path"] and resource_type(row["source_path"]) in {"image", "sprite", "audio", "terrain", "palette"}]
    imported = {"assets": [], "errors": []}
    if selected:
        try:
            imported = import_resources(report, selected, game_workspace, lambda v, m: progress(40 + v * 40 // 100, m), cancelled)
        except Cancelled:
            raise
        except Exception as exc:
            imported["errors"].append({"error": str(exc)})
    validation = {"status": "not applicable"}
    if identity["game_id"] == "diablo1" and imported.get("output_dir"):
        from adapters.diablo1.validation import validate_cached
        validation = validate_cached(imported, game_workspace, lambda v,m: progress(80+v//10,m), cancelled)
        if validation.get("output_dir"):
            imported["validation"] = validation
    identification_rows = {(a["archive"], a["source_path"]): a for a in imported.get("assets", [])}
    for asset in catalog["assets"]:
        entry = identification_rows.get((asset["archive"], asset["source_path"]))
        if entry:
            asset["identification"] = {k: v for k, v in entry.get("identification", {}).items() if k != "text_preview"}
            asset["type"] = entry["type"]
    if identity["game_id"] == "diablo1":
        from adapters.diablo1.validation import animation_mapping
        decoded_names = {a["source_path"] for a in validation.get("animations", [])}
        for asset in catalog["assets"]:
            mapping = animation_mapping(asset["source_path"], asset.get("identification", {}))
            if mapping:
                mapping["all_frames_decoded"] = asset["source_path"].replace("\\", "/") in decoded_names and asset["archive"].lower() == "diabdat.mpq"
                asset["mapping"] = {"animation": mapping}
    if cancelled(): raise Cancelled()
    generations = game_workspace / "generations"
    generations.mkdir(parents=True, exist_ok=True)
    target = generations / key
    if target.is_dir():
        previous = json.loads((target / "preparation.json").read_text(encoding="utf-8"))
        # Only reuse a DB whose referenced import batch and diagnostic state match.
        if previous.get("import_output") == imported.get("output_dir") and previous.get("import_errors") == imported.get("errors", []):
            atomic_json(game_workspace / "active.json", {"generation": key})
            atomic_json(workspace / "last_preparation.json", previous)
            previous.update(report=report, profile=profile, catalog=catalog, imported=imported, reused=True)
            progress(100, "Asset database and existing imports reused")
            return previous
        key += "-" + uuid.uuid4().hex[:8]
        target = generations / key
    stage = generations / (".staging-" + uuid.uuid4().hex)
    stage.mkdir()
    try:
        progress(85, "Building searchable asset database and edition metadata")
        write_database(stage / "assets.sqlite3", report, profile, imported, cancelled)
        atomic_json(stage / "profile.json", profile)
        atomic_json(stage / "catalog.json", catalog)
        named = sum(bool(row["source_path"]) for a in report["archives"] for row in a["assets"])
        result = {"installation": str(folder), "edition_id": profile["edition_id"], "database_path": str(target / "assets.sqlite3"), "profile_path": str(target / "profile.json"), "catalog_path": str(target / "catalog.json"), "archive_count": len(report["archives"]), "asset_count": sum(len(a["assets"]) for a in report["archives"]), "named_count": named, "imported_count": len(imported["assets"]), "import_output": imported.get("output_dir"), "import_errors": imported.get("errors", []), "ready_for_gameplay": False, "validation": validation}
        atomic_json(stage / "preparation.json", result)
        if cancelled(): raise Cancelled()
        stage.rename(target)
        atomic_json(game_workspace / "active.json", {"generation": key})
        atomic_json(workspace / "last_preparation.json", result)
        result.update(report=report, profile=profile, catalog=catalog, imported=imported)
        progress(100, f"Ready: {result['asset_count']} database records, {named} named, {result['imported_count']} imported")
        return result
    except Exception:
        if stage.exists(): shutil.rmtree(stage)
        raise

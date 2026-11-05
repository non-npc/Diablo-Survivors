"""Administrator archive inspection, draft profiles, and local working imports."""
import hashlib
import json
import os
import re
import shutil
import uuid
from pathlib import Path
from PIL import Image, ImageDraw
from adapters.base.mpq import ClassicMPQ, StormArchive, safe_resource_path, MAX_ASSET_BYTES
from manager.services.paths import ROOT
from manager.services.catalog import validate_document
from inspector.services.recognition import inspect_resource, IDENTIFIER_VERSION

class Cancelled(Exception):
    pass

def atomic_json(path, document):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    try:
        temporary.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)

def digest_file(path, progress=lambda message: None, cancelled=lambda: False):
    digest = hashlib.sha256()
    count = 0
    with Path(path).open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            if cancelled():
                raise Cancelled()
            digest.update(chunk)
            count += len(chunk)
            progress(f"Hashing {Path(path).name}: {count // 1048576} MiB")
    return digest.hexdigest()

def candidate_names(extra=()):
    names = set(extra)
    for path in (ROOT / "catalogs").glob("*.json"):
        for asset in json.loads(path.read_text(encoding="utf-8")).get("assets", []):
            names.add(asset["source_path"])
    reference_dir = ROOT / ".local/reference-listfiles"
    for path in reference_dir.glob("*.txt"):
        names.update(n.strip() for n in path.read_text(encoding="utf-8-sig").splitlines() if n.strip())
    normalized = set()
    for name in names:
        try:
            normalized.add(safe_resource_path(name).replace("/", "\\").lower())
        except ValueError:
            continue
    return sorted(normalized)

def scan_installation(folder, workspace, extra=(), progress=lambda value, message: None, cancelled=lambda: False):
    folder = Path(folder).resolve()
    if not folder.is_dir():
        raise ValueError("Choose an existing game installation folder")
    workspace = Path(workspace).resolve()
    if workspace == folder or folder in workspace.parents:
        raise ValueError("Inspector workspace must be outside the source installation")
    workspace.mkdir(parents=True, exist_ok=True)
    fingerprint_path = workspace / "fingerprints.json"
    cached = json.loads(fingerprint_path.read_text()) if fingerprint_path.exists() else {}
    seen = set()
    sources = []
    for path in sorted(folder.rglob("*"), key=lambda p: (len(p.relative_to(folder).parts), str(p).lower())):
        if cancelled():
            raise Cancelled()
        if path.suffix.lower() == ".mpq" and path.is_file():
            resolved = path.resolve()
            if resolved not in seen:
                sources.append(path)
                seen.add(resolved)
    if not sources:
        raise ValueError("No MPQ archives found. Current archive backend supports classic MPQ v0; other archive formats are pending.")
    reports = []
    for i, path in enumerate(sources):
        if cancelled():
            raise Cancelled()
        progress(int(i * 100 / len(sources)), f"Inspecting {path.name}")
        stat = path.stat()
        key = str(path.resolve())
        fingerprint = [stat.st_size, stat.st_mtime_ns]
        if key in cached and cached[key]["stat"] == fingerprint:
            digest = cached[key]["sha256"]
        else:
            digest = digest_file(path, lambda m: progress(int(i * 100 / len(sources)), m), cancelled)
            after = path.stat()
            if [after.st_size, after.st_mtime_ns] != fingerprint:
                raise ValueError("Archive changed while hashing; retry inspection")
            cached[key] = {"stat": fingerprint, "sha256": digest}
        report = {"path": str(path), "relative_path": str(path.relative_to(folder)).replace("\\", "/"), "size_bytes": stat.st_size, "mtime_ns": stat.st_mtime_ns, "sha256": digest, "assets": []}
        try:
            archive = ClassicMPQ(path)
            names = set(candidate_names(extra))
            try:
                with StormArchive(path) as reader:
                    try:
                        names.update(reader.read("(listfile)", 8 * 1024 * 1024).decode("utf-8", errors="replace").splitlines())
                        report["listfile"] = True
                    except FileNotFoundError:
                        report["listfile"] = False
            except Exception as exc:
                report["reader_warning"] = str(exc)
            # MPQ hash matching is ASCII for this classic backend.
            names = sorted({n.strip().replace("/", "\\").lower() for n in names if n.strip() and n.isascii()})
            report.update(header=archive.header, assets=archive.rows(names), state="Inspected")
        except Exception as exc:
            report.update(state="Unsupported / error", error=str(exc))
        reports.append(report)
    atomic_json(fingerprint_path, cached)
    from inspector.services.metadata import installation_metadata
    result = {"installation": str(folder), "archives": reports, "metadata": installation_metadata(folder)}
    atomic_json(workspace / "last_inspection.json", result)
    progress(100, "Inspection complete; unnamed blocks require an administrator path catalog.")
    return result

def resource_type(name):
    suffix = Path(name).suffix.lower()
    if suffix in {".pal", ".trn"}: return "palette"
    if suffix in {".wav", ".ogg", ".mp3"}: return "audio"
    if suffix in {".png", ".pcx", ".bmp", ".jpg", ".jpeg", ".gif", ".webp", ".tga"}: return "image"
    if suffix in {".smk", ".mp4", ".avi"}: return "video"
    if suffix in {".txt", ".ini", ".csv", ".json"}: return "text"
    if suffix == ".cel" and name.lower().replace("\\", "/").startswith("levels/"): return "terrain"
    if suffix in {".cel", ".cl2", ".dc6", ".dcc"}: return "sprite"
    if suffix in {".til", ".min", ".sol", ".dun", ".dt1", ".ds1"}: return "terrain"
    return "metadata"

def build_documents(report, edition_id, game_id, distribution, language, version, selected_archives):
    for value in (edition_id, game_id):
        if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,100}", value):
            raise ValueError("Edition and game IDs must use lowercase letters, numbers, dot, underscore or hyphen")
    chosen = [a for a in report["archives"] if a["relative_path"] in selected_archives]
    if not chosen or any(a["state"] != "Inspected" for a in chosen):
        raise ValueError("Select at least one successfully inspected archive")
    catalog_id = edition_id + "-catalog-v1"
    profile = {"schema_version": 1, "edition_id": edition_id, "game_id": game_id, "distribution": distribution, "language": language, "executable_product_version": version, "catalog_id": catalog_id, "verification": "inspected", "archives": [{"path": a["relative_path"], "size_bytes": a["size_bytes"], "sha256": a["sha256"], "required": True} for a in chosen], "patch_precedence": [], "notes": "Administrator-inspected draft. Extraction coverage and gameplay mappings require validation before publishing as verified."}
    assets = []
    for archive in chosen:
        for asset in archive["assets"]:
            name = asset["source_path"]
            if not name: continue
            safe_resource_path(name)
            asset_id = hashlib.sha256((archive["relative_path"] + "|" + name).encode()).hexdigest()[:20]
            assets.append({"id": asset_id, "archive": archive["relative_path"], "source_path": name, "type": resource_type(name), "verified": False, "source_metadata": {"archive_sha256": archive["sha256"], **{k: asset[k] for k in ("block_index", "offset", "stored_bytes", "decoded_bytes", "flags")}}})
    catalog = {"schema_version": 1, "catalog_id": catalog_id, "edition_id": edition_id, "assets": assets}
    validate_document(profile, "edition_profile.schema.json")
    validate_document(catalog, "asset_catalog.schema.json")
    return profile, catalog

def save_documents(destination, profile, catalog):
    destination = Path(destination)
    validate_document(profile, "edition_profile.schema.json")
    validate_document(catalog, "asset_catalog.schema.json")
    # Save a complete versioned pair in one directory, then atomically activate it.
    staging = destination / (".staging-" + uuid.uuid4().hex)
    staging.mkdir(parents=True)
    try:
        atomic_json(staging / "profile.json", profile)
        atomic_json(staging / "catalog.json", catalog)
        target = destination / (profile["edition_id"] + "-" + uuid.uuid4().hex[:8])
        staging.rename(target)
        return str(target)
    except Exception:
        shutil.rmtree(staging)
        raise

def import_resources(report, selected, workspace, progress=lambda value, message: None, cancelled=lambda: False):
    """Extract named resources locally; normalize only verified simple formats.

    Imported bytes are never a redistributable pack. CEL/CL2 remain raw pending
    sprite width/state/anchor verification. A failed item is reported separately.
    """
    if not selected:
        raise ValueError("Select named resources to import")
    if sum(row["decoded_bytes"] for _, row in selected) > 1024 * 1024 * 1024:
        raise ValueError("Selected import exceeds 1 GiB limit")
    workspace = Path(workspace).resolve()
    installation = Path(report["installation"]).resolve()
    if workspace == installation or installation in workspace.parents:
        raise ValueError("Working cache must be outside the source installation")
    imports = workspace / "imports"
    previous_rows = {}
    previous_dir = None
    latest = imports / "latest.json"
    expected = {(archive, row["source_path"]) for archive, row in selected}
    source_hashes = {a["relative_path"]: a["sha256"] for a in report["archives"]}
    if latest.is_file():
        batch_name = json.loads(latest.read_text())["batch"]
        if Path(batch_name).name != batch_name:
            raise ValueError("Unsafe local import index")
        previous_dir = imports / batch_name
        index_path = previous_dir / "index.json"
        if index_path.is_file():
            previous = json.loads(index_path.read_text())
            previous_rows = {(a["archive"], a["source_path"]): a for a in previous["assets"]}
            actual = {(a["archive"], a["source_path"]) for a in previous["assets"]}
            current = {a["relative_path"]: a for a in report["archives"]}
            source_unchanged = all(Path(current[name]["path"]).stat().st_size == current[name]["size_bytes"] and Path(current[name]["path"]).stat().st_mtime_ns == current[name]["mtime_ns"] for name, _ in expected)
            if previous.get("pipeline_version") == IDENTIFIER_VERSION and expected == actual and source_unchanged and all(a["archive_sha256"] == source_hashes[a["archive"]] and (previous_dir / a["raw_path"]).is_file() and (previous_dir / a["raw_path"]).stat().st_size == a["bytes"] and (not a.get("preview_path") or (previous_dir / a["preview_path"]).is_file()) for a in previous["assets"]):
                if cancelled(): raise Cancelled()
                previous.update(output_dir=str(previous_dir), reused=True)
                progress(100, "Reused unchanged local import; no archive payloads decoded")
                return previous
    imports.mkdir(parents=True, exist_ok=True)
    stage = imports / (".staging-" + uuid.uuid4().hex)
    stage.mkdir()
    result = {"schema_version": 1, "pipeline_version": IDENTIFIER_VERSION, "installation": str(installation), "assets": [], "errors": []}
    archive_map = {a["relative_path"]: a for a in report["archives"]}
    readers = {}
    palette_cache = {}
    ordered = sorted(selected, key=lambda pair: (not pair[1]["source_path"].lower().endswith(".pal"), pair[0], pair[1]["source_path"].lower()))
    try:
        for i, (archive_name, row) in enumerate(ordered):
            if cancelled(): raise Cancelled()
            name = row["source_path"]
            progress(int(i * 100 / len(selected)), f"[{i+1}/{len(selected)}] Importing {name}")
            try:
                normalized = safe_resource_path(name)
                if row["decoded_bytes"] > MAX_ASSET_BYTES:
                    raise ValueError("Asset exceeds 128 MiB limit")
                archive = archive_map[archive_name]
                path = Path(archive["path"])
                stat = path.stat()
                if stat.st_size != archive["size_bytes"] or stat.st_mtime_ns != archive["mtime_ns"]:
                    raise ValueError("Archive changed since inspection; scan again")
                previous_entry = previous_rows.get((archive_name, name), {})
                old_raw = previous_dir / previous_entry["raw_path"] if previous_entry and previous_dir else None
                reusable = old_raw and old_raw.resolve().is_relative_to(previous_dir.resolve()) and previous_entry.get("archive_sha256") == archive["sha256"] and old_raw.is_file() and old_raw.stat().st_size == row["decoded_bytes"]
                data = old_raw.read_bytes() if reusable else None
                if data is not None and hashlib.sha256(data).hexdigest() != previous_entry.get("sha256"):
                    data = None
                    reusable = False
                if data is None:
                    if archive_name not in readers:
                        readers[archive_name] = StormArchive(path)
                    data = readers[archive_name].read(name)
                if cancelled(): raise Cancelled()
                if len(data) != row["decoded_bytes"]:
                    raise ValueError("Decoded size differs from inspected block")
                prefix = hashlib.sha256(archive_name.encode()).hexdigest()[:12]
                relative = Path("raw") / prefix / normalized
                target = stage / relative
                if not target.resolve().is_relative_to(stage.resolve()):
                    raise ValueError("Unsafe extraction destination")
                target.parent.mkdir(parents=True, exist_ok=True)
                if reusable:
                    try: os.link(old_raw, target)
                    except OSError: target.write_bytes(data)
                else:
                    target.write_bytes(data)
                entry = {"archive": archive_name, "archive_sha256": archive["sha256"], "source_path": name, "raw_path": relative.as_posix(), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "normalization": "raw only", "type": resource_type(name)}
                if name.lower().endswith(".pal") and len(data) == 768:
                    palette_cache[(archive_name, name.lower().replace("\\", "/"))] = data
                normalized_name = name.lower().replace("\\", "/")
                parent = str(Path(normalized_name).parent)
                choices = [(key, value) for key, value in palette_cache.items() if key[0] == archive_name and str(Path(key[1]).parent) == parent]
                if not choices:
                    choices = [(key, value) for key,value in palette_cache.items() if key[1] == "levels/l1data/l1.pal"]
                chosen = sorted(choices, key=lambda pair: (pair[0][1] != str(Path(normalized_name).with_suffix(".pal")), pair[0]))[0] if choices else None
                try:
                    identification, image = inspect_resource(data, name, palette=chosen[1] if chosen else None)
                    if chosen and identification["type"] in {"sprite", "terrain"}:
                        identification["palette_source"] = {"archive": chosen[0][0], "source_path": chosen[0][1], "association": "preview candidate; mapping unverified"}
                    entry["identification"] = identification
                    entry["type"] = identification["type"]
                    entry["normalization"] = "content identified"
                    if image is not None:
                        preview = Path("previews") / (hashlib.sha256((archive_name + name).encode()).hexdigest()[:20] + ".png")
                        (stage / preview).parent.mkdir(exist_ok=True)
                        image.save(stage / preview)
                        entry.update(preview_path=preview.as_posix(), normalization="palette swatch PNG" if identification["type"] == "palette" else "decoded image preview")
                    elif identification["format"] == "WAV":
                        entry["normalization"] = "WAV passthrough"
                except Exception as exc:
                    entry["identification"] = {"type": resource_type(name), "format": Path(name).suffix[1:].upper(), "confidence": "extension", "warning": str(exc), "decoder_version": IDENTIFIER_VERSION}
                    result["errors"].append({"archive": archive_name, "source_path": name, "error": "Identification: " + str(exc)})
                result["assets"].append(entry)
            except Cancelled:
                raise
            except Exception as exc:
                result["errors"].append({"archive": archive_name, "source_path": name, "error": str(exc)})
        if cancelled(): raise Cancelled()
        if not result["assets"]:
            raise ValueError("No resources imported successfully: " + json.dumps(result["errors"]))
        atomic_json(stage / "index.json", result)
        target = imports / ("batch-" + uuid.uuid4().hex[:12])
        stage.rename(target)
        atomic_json(imports / "latest.json", {"batch": target.name})
        result["output_dir"] = str(target)
        progress(100, f"Imported {len(result['assets'])} resources; {len(result['errors'])} diagnostics")
        return result
    except Exception:
        if stage.exists(): shutil.rmtree(stage)
        raise
    finally:
        for reader in readers.values(): reader.close()

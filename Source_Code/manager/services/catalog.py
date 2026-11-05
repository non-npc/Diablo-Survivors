import hashlib
import json
from pathlib import Path
from jsonschema import Draft202012Validator
from manager.services.paths import ROOT

class InspectionCancelled(Exception):
    pass

def validate_document(document, schema_name):
    schema = json.loads((ROOT / "schemas" / schema_name).read_text(encoding="utf-8"))
    Draft202012Validator(schema).validate(document)

def profiles():
    result = []
    for path in sorted((ROOT / "profiles").glob("*.json")):
        profile = json.loads(path.read_text(encoding="utf-8"))
        validate_document(profile, "edition_profile.schema.json")
        result.append(profile)
    return result

def inspect_installation(folder, progress=lambda value: None, cancelled=lambda: False):
    if not str(folder).strip():
        raise ValueError("Select an installation folder.")
    folder = Path(folder).expanduser().resolve()
    if not folder.is_dir():
        raise ValueError("Select an existing installation folder.")
    candidates = []
    for profile in profiles():
        required = [a for a in profile["archives"] if a.get("required", True)]
        if required and all((folder / a["path"]).is_file() and (folder / a["path"]).stat().st_size == a["size_bytes"] for a in required):
            candidates.append(profile)
    if not candidates:
        return {"path": str(folder), "edition_id": None, "status": "Unknown edition", "message": "No bundled edition profile matches these files. Import is unavailable; administrator verification is required."}
    hashes = {}
    for profile in candidates:
        matched = True
        for archive in profile["archives"]:
            if not archive.get("required", True):
                continue
            source = (folder / archive["path"]).resolve()
            if source not in hashes:
                digest = hashlib.sha256()
                count = 0
                with source.open("rb") as stream:
                    while chunk := stream.read(1024 * 1024):
                        if cancelled():
                            raise InspectionCancelled()
                        digest.update(chunk)
                        count += len(chunk)
                        progress(min(100, int(count * 100 / archive["size_bytes"])))
                hashes[source] = digest.hexdigest()
            if hashes[source] != archive["sha256"].lower():
                matched = False
                break
        if matched:
            return {"path": str(folder), "edition_id": profile["edition_id"], "status": "Verified edition" if profile["verification"] == "verified" else "Research baseline", "message": profile["notes"], "archive_hashes": {str(k): v for k, v in hashes.items()}, "import_available": profile["verification"] == "verified"}
    return {"path": str(folder), "edition_id": None, "status": "Unknown edition", "message": "File sizes match a candidate, but archive fingerprints differ. No catalog has been selected."}

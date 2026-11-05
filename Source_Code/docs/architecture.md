# Architecture

The player manager (`manager/`) launches an independent Godot runtime with a JSON manifest, using QProcess without a shell. Qt workers keep archive hashing off the UI thread. SQLite stores manager settings/installations with a versioned transactional migration and WAL. Data defaults to platform user directories; portable mode uses ignored local storage.

The administrator inspector (`inspector/`) is a separate entry point. It inventories archives, reads version evidence, saves draft profile/catalog pairs, and stages local raw imports. JSON indexes persist administrator inspection/fingerprints/import metadata. Folder selection automatically builds a per-installation SQLite asset database, profile/catalog and working imports. Generation directories are atomically activated; the database indexes names, types/statuses and archive/block identities, including unnamed blocks. The end-user normalized asset index and progression database are later importer/runtime milestones.

`adapters/base/mpq.py` implements bounded classic archive table inspection and a read-only ctypes interface to StormLib. It never executes game code. Profiles/catalogs are source metadata; source archives and payloads stay local. Godot uses original demo resources and has no source-game dependency.

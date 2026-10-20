#!/usr/bin/env python3

import os
import shutil
import sqlite3
import sys
import urllib.parse

COLUMNS = (
    "store",
    "db",
    "id_encoding",
    "id",
    "session",
    "body",
    "updated",
    "folder",
    "profile",
    "title",
)
PREVIEW_COLUMNS = ("store", "session", "body", "updated", "folder", "profile", "title")
MUTABLE_TABLES = {
    "sidebar": {"sidebar_threads", "thread_archived_worktrees"},
    "native": {"threads"},
}
HEX = set("0123456789abcdef")
SESSION_CHARS = HEX | {"-"}


def die(message):
    raise SystemExit(f"zedThreadCleanup: {message}")


def zed_data_dir():
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.realpath(os.path.join(base, "zed"))


def acp_root():
    return os.path.realpath(os.path.expanduser("~/.config/cursor/acp-sessions"))


def connect_ro(path):
    uri = "file:" + urllib.parse.quote(path, safe="/") + "?mode=ro"
    return sqlite3.connect(uri, uri=True)


def discover():
    root = zed_data_dir()
    found = []
    native = os.path.join(root, "threads", "threads.db")
    if os.path.isfile(native):
        found.append(("native", os.path.realpath(native), "-"))
    db_root = os.path.join(root, "db")
    if not os.path.isdir(db_root):
        return found
    for name in sorted(os.listdir(db_root)):
        path = os.path.join(db_root, name, "db.sqlite")
        profile_dir = os.path.realpath(os.path.join(db_root, name))
        if os.path.isfile(path) and os.path.dirname(os.path.realpath(path)) == profile_dir:
            found.append(("sidebar", os.path.realpath(path), name))
    return found


def cell(value):
    if value is None:
        return "-"
    text = str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ").strip()
    return text or "-"


def title_of(primary, fallback=None):
    label = cell(primary)
    if label == "-" and fallback is not None:
        label = cell(fallback)
    if label == "-":
        return "(untitled)"
    return label


def line_from(fields):
    return "\t".join(fields[name] for name in COLUMNS)


def session_dir(session):
    if session in ("", "-"):
        return None
    root = acp_root()
    target = os.path.realpath(os.path.join(root, session))
    if os.path.dirname(target) != root or not os.path.isdir(target):
        return None
    return target


def table_names(con):
    names = []
    for (name,) in con.execute("SELECT name FROM sqlite_master WHERE type = 'table'"):
        if name.replace("_", "").isalnum() and not name[0].isdigit():
            names.append(name)
    return names


def sidebar_rows(con, path, profile):
    query = """
        SELECT hex(thread_id), session_id, title, title_override, updated_at, folder_paths
        FROM sidebar_threads
    """
    rows = []
    for thread_hex, session, title, title_override, updated, folder in con.execute(query):
        sid = cell(session)
        body = "acp" if sid != "-" and session_dir(sid) else "none"
        updated_text = cell(updated)
        fields = {
            "store": "sidebar",
            "db": path,
            "id_encoding": "hex",
            "id": cell(thread_hex).lower(),
            "session": sid,
            "body": body,
            "updated": updated_text,
            "folder": cell(folder),
            "profile": cell(profile),
            "title": title_of(title, title_override),
        }
        rows.append((updated_text, line_from(fields)))
    return rows


def native_rows(con, path):
    query = "SELECT id, summary, updated_at, folder_paths FROM threads"
    rows = []
    for thread_id, summary, updated, folder in con.execute(query):
        ident = cell(thread_id)
        if ident == "-" or any(char in str(thread_id) for char in "\t\r\n"):
            die(f"native thread id cannot be listed: {path}")
        updated_text = cell(updated)
        fields = {
            "store": "native",
            "db": path,
            "id_encoding": "text",
            "id": ident,
            "session": "-",
            "body": "none",
            "updated": updated_text,
            "folder": cell(folder),
            "profile": "-",
            "title": title_of(summary),
        }
        rows.append((updated_text, line_from(fields)))
    return rows


def list_threads():
    rows = []
    for store, path, profile in discover():
        con = connect_ro(path)
        try:
            tables = set(table_names(con))
            if store == "sidebar" and "sidebar_threads" in tables:
                rows.extend(sidebar_rows(con, path, profile))
            elif store == "native" and "threads" in tables:
                rows.extend(native_rows(con, path))
        finally:
            con.close()
    rows.sort(key=lambda item: item[0], reverse=True)
    for _, line in rows:
        print(line)


def is_hex_id(value):
    return len(value) == 32 and all(char in HEX for char in value)


def is_session(value):
    return len(value) == 36 and value.count("-") == 4 and all(char in SESSION_CHARS for char in value)


def parse_line(line):
    fields = line.split("\t")
    if len(fields) != len(COLUMNS):
        die("refused a malformed selection")
    item = dict(zip(COLUMNS, fields))
    store = item["store"]
    if store not in MUTABLE_TABLES or item["id_encoding"] not in ("hex", "text") or item["body"] not in ("acp", "none"):
        die("refused a selection with an unknown store")
    if store == "sidebar" and (item["id_encoding"] != "hex" or not is_hex_id(item["id"])):
        die("refused a sidebar thread with a bad id")
    if store == "native" and (item["id_encoding"] != "text" or item["id"] in ("", "-")):
        die("refused a native thread with a bad id")
    if item["session"] != "-" and not is_session(item["session"]):
        die("refused a selection with a bad session id")
    if item["body"] == "acp" and item["session"] == "-":
        die("refused an acp body without a session id")
    real = os.path.realpath(item["db"])
    known = {path: (kind, profile) for kind, path, profile in discover()}
    if real not in known or known[real][0] != store:
        die(f"refused a database outside zed thread storage: {item['db']}")
    if store == "sidebar" and known[real][1] != item["profile"]:
        die("refused a selection whose profile does not match its database")
    item["db"] = real
    return item


def snapshot(con, mutable):
    counts = {}
    for name in table_names(con):
        if name in mutable or name == "sqlite_sequence":
            continue
        counts[name] = con.execute(f'SELECT COUNT(*) FROM "{name}"').fetchone()[0]
    return counts


def delete_group(path, items):
    store = items[0]["store"]
    mutable = MUTABLE_TABLES[store]
    removed = 0
    titles = []
    con = sqlite3.connect(path, timeout=1)
    committed = False
    try:
        con.execute("BEGIN IMMEDIATE")
        present = set(table_names(con))
        required = "sidebar_threads" if store == "sidebar" else "threads"
        if required not in present:
            die(f"{path} has no {required} table")
        before = snapshot(con, mutable)
        for item in items:
            if store == "sidebar":
                blob = bytes.fromhex(item["id"])
                cur = con.execute("DELETE FROM sidebar_threads WHERE thread_id = ?", (blob,))
                if "thread_archived_worktrees" in present and cur.rowcount:
                    con.execute("DELETE FROM thread_archived_worktrees WHERE thread_id = ?", (blob,))
            else:
                cur = con.execute("DELETE FROM threads WHERE id = ?", (item["id"],))
            removed += cur.rowcount
            if cur.rowcount:
                titles.append(item["title"])
        if snapshot(con, mutable) != before:
            die("refused to commit because a non-thread table changed")
        con.commit()
        committed = True
    finally:
        if not committed:
            con.rollback()
        con.close()
    return removed, titles


def remove_acp_dirs(items):
    removed = 0
    seen = set()
    for item in items:
        session = item["session"]
        if item["body"] != "acp" or session in seen:
            continue
        seen.add(session)
        target = session_dir(session)
        if target is None:
            continue
        shutil.rmtree(target)
        removed += 1
    return removed


def delete_threads(lines):
    parsed = [parse_line(line) for line in lines if line.strip()]
    if not parsed:
        die("nothing selected")
    groups = {}
    for item in parsed:
        groups.setdefault(item["db"], []).append(item)
    removed = {"sidebar": 0, "native": 0}
    titles = []
    for path, items in groups.items():
        count, group_titles = delete_group(path, items)
        removed[items[0]["store"]] += count
        titles.extend(group_titles)
    acp = remove_acp_dirs(parsed)
    print(
        f"removed {removed['sidebar']} sidebar threads, "
        f"{removed['native']} native threads, {acp} acp directories"
    )
    for title in titles:
        print(f"  {title}")


def preview(path):
    fields = open(path, encoding="utf-8").read().rstrip("\n").split("\t")
    if len(fields) != len(COLUMNS):
        die("refused a malformed preview line")
    item = dict(zip(COLUMNS, fields))
    for name in PREVIEW_COLUMNS:
        print(f"{name}: {item[name]}")


def main(argv):
    if len(argv) < 2:
        die("internal error")
    command = argv[1]
    if command == "list":
        list_threads()
    elif command == "delete":
        delete_threads(argv[2:])
    elif command == "preview" and len(argv) == 3:
        preview(argv[2])
    else:
        die("internal error")


if __name__ == "__main__":
    main(sys.argv)

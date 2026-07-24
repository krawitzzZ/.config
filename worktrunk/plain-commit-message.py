#!/usr/bin/env python3
"""Extract and validate a plain-text commit message from LLM output.

Two modes:

- strict (default): reject anything that violates the rules (exit 2). Use this
  first so a naturally-good message is preferred.
- repair (--repair): never fail on fixable problems. Over-long subjects are
  truncated at a word boundary, ambiguous output is narrowed to the first valid
  subject, and commentary bodies are dropped. Guarantees a valid message
  whenever the response contains a recognizable subject.
"""

import json
import re
import sys


MAX_SUBJECT = 60

SUBJECT = re.compile(
    r"^(?:"
    r"\[(?:PSWH|BFFTRAC|IN)-\d+\]"
    r"|\[INNOLAB\]"
    r"|(?:feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|boyscout)"
    r"(?:\([^)]+\))?"
    r"):\s+(.+)$"
)
OUTER_DELIMITERS = {("`", "`"), ('"', '"'), ("'", "'")}
META_BODY = re.compile(
    r"\b(?:the branch|the diff|I chose|this commit message|no body needed|"
    r"the subject is|the format is)\b",
    flags=re.IGNORECASE,
)

REPAIR = "--repair" in sys.argv[1:]


def fail(reason: str) -> "None":
    print(f"commit-message filter: {reason}", file=sys.stderr)
    raise SystemExit(2)


def unwrap(text: str) -> str:
    """Remove wrappers around a complete response, not backticks in its body."""
    text = text.strip()
    fence = re.fullmatch(r"```[^\n]*\n(.*?)\n```", text, flags=re.DOTALL)
    if fence:
        text = fence.group(1).strip()
    while len(text) >= 2 and (text[0], text[-1]) in OUTER_DELIMITERS:
        text = text[1:-1].strip()
    return text


def truncate_subject(prefix: str, description: str) -> str:
    """Fit `prefix + description` within MAX_SUBJECT, cutting on a word boundary."""
    budget = MAX_SUBJECT - len(prefix)
    if budget <= 0:
        # Pathological (huge prefix); keep the prefix's leading portion.
        return prefix[:MAX_SUBJECT].rstrip(" :-")
    truncated = description[:budget]
    space = truncated.rfind(" ")
    # Only cut at a space if it keeps a meaningful chunk; otherwise hard-cut.
    if space >= max(10, budget // 2):
        truncated = truncated[:space]
    truncated = truncated.rstrip(" ,;:-\u2014.")
    if not truncated:
        truncated = description[:budget].rstrip()
    return f"{prefix}{truncated}"


def normalize_subject(line: str) -> "str | None":
    """Return a normalized valid subject, or None for prose/non-subject lines.

    In repair mode an over-long subject is truncated instead of rejected.
    """
    line = unwrap(line)
    match = SUBJECT.fullmatch(line)
    if not match:
        return None

    description = match.group(1).strip().removesuffix(".")
    if not description:
        return None

    # Small free models often follow conventional-commit lowercase examples
    # despite the explicit local rule. Enforce the rule deterministically.
    description = description[0].upper() + description[1:]
    prefix = line[: match.start(1)]
    subject = f"{prefix}{description}"

    if len(subject) > MAX_SUBJECT:
        if not REPAIR:
            fail(f"subject exceeds {MAX_SUBJECT} characters: {subject!r}")
        subject = truncate_subject(prefix, description)
    return subject


def clean_body(body: str) -> str:
    """Strip fences/commentary from a body. Rejects in strict mode."""
    body = body.strip()
    body = re.sub(r"^```[^\n]*\n?", "", body)
    body = re.sub(r"\n?```$", "", body).strip()
    if "```" in body or META_BODY.search(body):
        if not REPAIR:
            fail("body contains model commentary")
        return ""  # repair: drop the untrustworthy body rather than fail
    return body


def parse_json_response(text: str) -> "tuple[str, str] | None":
    """Find a valid subject/body object, tolerating accidental outer prose."""
    decoder = json.JSONDecoder()
    objects: list[dict[str, object]] = []
    for index, char in enumerate(text):
        if char != "{":
            continue
        try:
            value, _ = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            continue
        if (
            isinstance(value, dict)
            and set(value) == {"subject", "body"}
            and isinstance(value["subject"], str)
            and isinstance(value["body"], str)
        ):
            objects.append(value)

    if not objects:
        return None
    if len(objects) != 1 and not REPAIR:
        fail(f"expected one JSON result, found {len(objects)}")

    value = objects[0]  # repair: first object wins
    raw_subject = value["subject"]
    if "\n" in raw_subject or "\r" in raw_subject:
        if not REPAIR:
            fail("subject contains a newline")
        raw_subject = raw_subject.splitlines()[0]
    subject = normalize_subject(raw_subject)
    if subject is None:
        fail("invalid commit subject")

    return subject, clean_body(value["body"])


def main() -> None:
    message = unwrap(sys.stdin.read().strip())

    json_result = parse_json_response(message)
    if json_result:
        subject, body = json_result
        result = subject if not body else f"{subject}\n\n{body}"
        sys.stdout.write(result + "\n")
        return

    lines = message.splitlines()

    # Plain-text path: a clean first-line subject plus an optional body.
    subject = normalize_subject(lines[0]) if lines else None
    if subject:
        body = clean_body("\n".join(lines[1:]))
        result = subject if not body else f"{subject}\n\n{body}"
        sys.stdout.write(result + "\n")
        return

    # Misbehaving model: extract valid subjects from prose/fences, drop the rest.
    candidates = [
        candidate
        for line in lines
        if (candidate := normalize_subject(line)) is not None
    ]
    candidates = list(dict.fromkeys(candidates))
    if not candidates:
        fail("no valid commit subject found in model output")
    if len(candidates) != 1 and not REPAIR:
        fail(f"expected exactly one valid commit subject, found {len(candidates)}")

    sys.stdout.write(candidates[0] + "\n")  # repair: first valid subject wins


main()

#!/usr/bin/env python3
"""Remove accidental outer Markdown/quotes from an LLM commit message."""

import re
import sys


message = sys.stdin.read().strip()

# Remove an outer fenced code block while preserving its contents.
fence = re.fullmatch(r"```[^\n]*\n(.*?)\n```", message, flags=re.DOTALL)
if fence:
    message = fence.group(1).strip()

# Remove delimiters only when they wrap the complete response. Backticks within
# a body remain untouched.
while len(message) >= 2 and (message[0], message[-1]) in {
    ("`", "`"),
    ('"', '"'),
    ("'", "'"),
}:
    message = message[1:-1].strip()

sys.stdout.write(message)
if message:
    sys.stdout.write("\n")

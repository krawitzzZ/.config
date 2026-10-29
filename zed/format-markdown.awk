BEGIN {
  WIDTH = 80
}

{
  lines[++n] = $0
  rts[n] = RT
}

END {
  if (n == 0) exit 0
  ends_nl = rts[n] != ""
  i = 1
  while (i <= n) {
    kind = classify(lines[i])
    if (kind == "blank") {
      add("")
      i++
    } else if (kind == "fence") {
      j = consume_fence(i)
      add_range(i, j - 1)
      i = j
    } else if (kind == "math") {
      j = consume_math(i)
      add_range(i, j - 1)
      i = j
    } else if (kind == "html") {
      j = consume_html(i)
      add_range(i, j - 1)
      i = j
    } else if (kind == "admon") {
      j = consume_admon(i)
      format_admon(i, j - 1)
      i = j
    } else if (kind == "def") {
      j = consume_def(i)
      add_range(i, j - 1)
      i = j
    } else if (kind == "list") {
      j = consume_list(i)
      add_range(i, j - 1)
      i = j
    } else if (kind == "table" || kind == "quote" || kind == "pre" || kind == "diagram") {
      j = consume_kind(i, kind)
      add_range(i, j - 1)
      i = j
    } else if (kind == "prose") {
      j = consume_kind(i, "prose")
      format_prose(i, j - 1)
      i = j
    } else {
      add(lines[i])
      i++
    }
  }
  emit()
}

function classify(line) {
  if (line ~ /^[[:space:]]*$/) return "blank"
  if (line ~ /^[[:space:]]*(`{3,}|~{3,})/) return "fence"
  if (line ~ /^[[:space:]]*\$\$[[:space:]]*$/) return "math"
  if (line ~ /^!!![[:space:]]+[^[:space:]]/) return "admon"
  if (line ~ /^[[:space:]]*(<\/?[A-Za-z!]|<!--)/) return "html"
  if (line ~ /^[[:space:]]*\|/) return "table"
  if (line ~ /^(#{1,6}([[:space:]]|$)|\(#{1,6}\)[[:space:]])/) return "heading"
  if (line ~ /^([[:space:]]*-{3,}[[:space:]]*|[[:space:]]*\+{3,}:?[[:space:]]*|\\pagebreak[[:space:]]*|(\*[[:space:]]*){3,}|(_[[:space:]]*){3,})$/)
    return "verbatim"
  if (line ~ /^\*[^*]+\*:/) return "def"
  if (line ~ /^[[:space:]]*([-+*]|[0-9]+[.)])[[:space:]]+/) return "list"
  if (line ~ /^[[:space:]]*>/) return "quote"
  if (line ~ /^[[:space:]]*\((insert|embed)([^[:alnum:]_]|$)/) return "verbatim"
  if (line ~ /^[[:space:]]*\(\(.*\)\)[[:space:]]*$/) return "verbatim"
  if (line ~ /^\[[^]]+\]:[[:space:]]+[^[:space:]]/) return "verbatim"
  if (line ~ /^(\t| {4,})[^[:space:]]/) return "pre"
  if (is_diagram(line)) return "diagram"
  return "prose"
}

function is_diagram(line,    s, symbols, letters, i, c, nlen) {
  s = strip(line)
  symbols = 0
  letters = 0
  nlen = length(s)
  for (i = 1; i <= nlen; i++) {
    c = substr(s, i, 1)
    if (c ~ /[A-Za-z]/) letters++
    else if (c ~ /[-|+*/\\.'`<>]/) symbols++
  }
  if (symbols >= 4 && symbols > letters) return 1
  return s ~ /-->|<--|─|│|┌|┐|└|┘|├|┤|┬|┴|┼/
}

function strip(s) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  return s
}

function fence_marker(line,    rest) {
  if (match(line, /^[[:space:]]*`{3,}/)) {
    rest = substr(line, RSTART, RLENGTH)
    sub(/^[[:space:]]*/, "", rest)
    return rest
  }
  if (match(line, /^[[:space:]]*~{3,}/)) {
    rest = substr(line, RSTART, RLENGTH)
    sub(/^[[:space:]]*/, "", rest)
    return rest
  }
  return ""
}

function consume_fence(start,    marker, re, j) {
  marker = fence_marker(lines[start])
  if (substr(marker, 1, 1) == "`")
    re = "^[[:space:]]*`{" length(marker) ",}[[:space:]]*$"
  else
    re = "^[[:space:]]*~{" length(marker) ",}[[:space:]]*$"
  j = start + 1
  while (j <= n) {
    if (lines[j] ~ re) return j + 1
    j++
  }
  return j
}

function consume_math(start,    j) {
  j = start + 1
  while (j <= n) {
    if (lines[j] ~ /^[[:space:]]*\$\$[[:space:]]*$/) return j + 1
    j++
  }
  return j
}

function opened_unclosed(line,    low) {
  low = tolower(line)
  if (low ~ /<\/(script|style)[[:space:]]*>/) return ""
  if (match(low, /<script([^[:alnum:]_]|$)/)) return "script"
  if (match(low, /<style([^[:alnum:]_]|$)/)) return "style"
  return ""
}

function consume_html(start,    j, line, tag) {
  j = start
  while (j <= n && classify(lines[j]) == "html") {
    line = lines[j]
    j++
    tag = opened_unclosed(line)
    if (tag != "") {
      while (j <= n) {
        line = lines[j]
        j++
        if (tolower(line) ~ ("</" tag "[[:space:]]*>")) break
      }
    }
  }
  return j
}

function consume_admon(start,    j, line) {
  j = start + 1
  while (j <= n) {
    line = lines[j]
    if (substr(line, 1, 3) == "   " || substr(line, 1, 1) == "\t") {
      j++
      continue
    }
    break
  }
  return j
}

function admon_plain(from, to,    k, line, inner) {
  for (k = from; k <= to; k++) {
    line = lines[k]
    if (substr(line, 1, 1) == "\t") return 0
    if (substr(line, 1, 3) == "   ") inner = substr(line, 4)
    else inner = line
    kind = classify(inner)
    if (kind != "prose" && kind != "blank") return 0
  }
  return 1
}

function format_admon(from, to,    text, k, wrapped, nw) {
  if (to == from || !admon_plain(from + 1, to)) {
    add_range(from, to)
    return
  }
  text = ""
  for (k = from + 1; k <= to; k++) {
    if (strip(lines[k]) == "") continue
    text = (text == "" ? strip(lines[k]) : text " " strip(lines[k]))
  }
  add(lines[from])
  nw = wrap_into(text, WIDTH - 4, wrapped)
  for (k = 1; k <= nw; k++) add("    " wrapped[k])
}

function consume_def(start,    j, line) {
  j = start + 1
  while (j <= n) {
    line = lines[j]
    if (strip(line) == "") break
    if (substr(line, 1, 2) == "  " || substr(line, 1, 1) == "\t") {
      j++
      continue
    }
    break
  }
  return j
}

function spaces_indent(line,    i) {
  i = 1
  while (substr(line, i, 1) == " ") i++
  return i - 1
}

function consume_list(start,    base, j, line, kind, ind) {
  base = spaces_indent(lines[start])
  j = start + 1
  while (j <= n) {
    line = lines[j]
    if (line ~ /^[[:space:]]*$/) break
    kind = classify(line)
    if (kind == "list") {
      j++
      continue
    }
    ind = spaces_indent(line)
    if (ind > base && kind == "prose") {
      j++
      continue
    }
    break
  }
  return j
}

function consume_kind(start, kind,    j) {
  j = start
  while (j <= n && classify(lines[j]) == kind) j++
  return j
}

function ends_two(line) {
  return length(line) >= 2 && substr(line, length(line) - 1, 2) == "  "
}

function format_prose(from, to,    chunk, nc, k, line) {
  if (to == from && !ends_two(lines[from]) && length(lines[from]) <= WIDTH) {
    add(lines[from])
    return
  }
  delete chunk
  nc = 0
  for (k = from; k <= to; k++) {
    line = lines[k]
    if (ends_two(line)) {
      chunk[++nc] = substr(line, 1, length(line) - 2)
      flush_prose(chunk, nc, 1)
      delete chunk
      nc = 0
    } else chunk[++nc] = line
  }
  if (nc > 0) flush_prose(chunk, nc, 0)
}

function flush_prose(chunk, nc, hard,    text, k, part, wrapped, nw) {
  text = ""
  for (k = 1; k <= nc; k++) {
    part = strip(chunk[k])
    if (part == "") continue
    text = (text == "" ? part : text " " part)
  }
  nw = wrap_into(text, WIDTH, wrapped)
  if (nw == 0) return
  if (hard) wrapped[nw] = wrapped[nw] "  "
  for (k = 1; k <= nw; k++) add(wrapped[k])
}

function wrap_into(text, width, dest,    nwords, words, i, cur, count, word) {
  delete dest
  if (text == "") return 0
  nwords = split(text, words, /[[:space:]]+/)
  cur = ""
  count = 0
  for (i = 1; i <= nwords; i++) {
    word = words[i]
    if (word == "") continue
    if (cur == "") cur = word
    else if (length(cur) + 1 + length(word) <= width) cur = cur " " word
    else {
      dest[++count] = cur
      cur = word
    }
  }
  if (cur != "") dest[++count] = cur
  return count
}

function add(line) {
  out[++nout] = line
}

function add_range(from, to,    k) {
  for (k = from; k <= to; k++) add(lines[k])
}

function emit(    k) {
  for (k = 1; k <= nout; k++) {
    if (k < nout || ends_nl) print out[k]
    else printf "%s", out[k]
  }
}

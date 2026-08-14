#!/usr/bin/env sh

# newpost.sh — scaffold an EN/PT post pair and rebuild.
#
#   ./newpost.sh "My New Entry" "Meu Novo Post"

set -euf

post_title="${1:-}"
post_title_pt="${2:-}"

if test -z "${post_title_pt:-}"; then
    echo "Usage: $0 \"Example Title\" \"Título Exemplo\"" >&2
    exit 1
fi

post_date="$(date +%Y-%m-%d-%H)"
slug() {
    echo "$1" | iconv -f utf-8 -t ascii//translit | sed -E 's/[^A-Za-z0-9]+/-/g'
}
base="${post_date}-$(slug "$post_title")"
base_pt="${post_date}-$(slug "$post_title_pt")"

# Only `author` is written here. build.sh fills in alt, date and lang on every run
# — they are derived from the filename and the sibling, so typing them would just
# be one more thing that can go stale.
year="$(date +%Y)"

cat > "blog/${base}.md" <<-@
	<!--
	SPDX-FileCopyrightText: $year Alexandre Gomes Gaigalas <alganet@gmail.com>

	SPDX-License-Identifier: CC-BY-NC-SA-4.0
	-->
	---
	author: Alexandre Gomes Gaigalas
	---

	# $post_title

	Hello, world!
@

cat > "blog/${base_pt}.pt.md" <<-@
	<!--
	SPDX-FileCopyrightText: $year Alexandre Gomes Gaigalas <alganet@gmail.com>

	SPDX-License-Identifier: CC-BY-NC-SA-4.0
	-->
	---
	author: Alexandre Gomes Gaigalas
	---

	# $post_title_pt

	Olá, mundo!
@

sh build.sh

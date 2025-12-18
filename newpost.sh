#!/usr/bin/env sh

set -euf

post_title="${1:-}"
post_title_pt="${2:-}"

if test -z "${post_title_pt:-}"; then
    echo "Usage: $0 \"Example Title\" \"Título Exemplo\"" >&2
    exit 1
fi

post_date="$(date +%Y-%m-%d-%H)"
base_filename="${post_date}-$(
    echo "$post_title" |
        iconv -f utf-8 -t ascii//translit |
        sed -E 's/[^A-Za-z0-9]+/-/g'
)";
base_filename_pt="${post_date}-$(
    echo "$post_title_pt" |
        iconv -f utf-8 -t ascii//translit |
        sed -E 's/[^A-Za-z0-9]+/-/g'
)";

cat <<-@ > "blog/${base_filename}.html"
<h2>$post_title</h2>
<p class=info></p>
<p>Hello, world!</p>
<hr class=end>
@

cat <<-@ > "blog/${base_filename_pt}.pt.html"
<h2>$post_title_pt</h2>
<p class=info></p>
<p>Olá, mundo!</p>
<hr class=end>
@

sh build.sh

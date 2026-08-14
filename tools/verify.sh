#!/usr/bin/env sh

# tools/verify.sh — prove the markdown conversion lost nothing.
#
#   sh tools/verify.sh              # every post
#   sh tools/verify.sh blog/x.html  # just one
#   VERIFY_BASELINE=<ref> sh tools/verify.sh
#
# THE PROBLEM THIS SOLVES: the posts carry 1768 hand-written
# <span class="code-*"> tags that the migration deliberately throws away, so a raw
# diff of old against new HTML is almost entirely noise. Every one of those spans
# lives INSIDE a <pre>, so stripping tags erases the whole noise floor at a stroke
# and leaves exactly the thing that must not change: the text.
#
# Two normalisers, because whitespace means different things in the two places.
#
#   prose  compared as a WORD SEQUENCE, so it is immune to re-wrapping (the HTML
#          was hard-wrapped by hand; markdown paragraphs are one line)
#   code   compared byte for byte, INCLUDING indentation — that is the payload of
#          the copy-to-clipboard feature
#
# Structure is checked separately by counting block elements, since a word-sequence
# comparison would not notice two paragraphs merging into one.

set -eu

. ./render.sh

# The last commit that still held the hand-written HTML. Pinned, not HEAD:
# once the migration landed, HEAD became the very output under test, and
# comparing it with itself passes unconditionally — the check would go quiet
# exactly when it stopped meaning anything. Override to re-point it.
BASELINE="${VERIFY_BASELINE:-31c83d2}"

_TMP=$(mktemp -d)
trap 'rm -rf "$_TMP"' EXIT INT TERM

decode() {
    sed \
        -e 's/&ccedil;/ç/g'  -e 's/&Ccedil;/Ç/g' \
        -e 's/&atilde;/ã/g'  -e 's/&Atilde;/Ã/g' \
        -e 's/&otilde;/õ/g'  -e 's/&Otilde;/Õ/g' \
        -e 's/&ntilde;/ñ/g'  -e 's/&Ntilde;/Ñ/g' \
        -e 's/&aacute;/á/g'  -e 's/&Aacute;/Á/g' \
        -e 's/&eacute;/é/g'  -e 's/&Eacute;/É/g' \
        -e 's/&iacute;/í/g'  -e 's/&Iacute;/Í/g' \
        -e 's/&oacute;/ó/g'  -e 's/&Oacute;/Ó/g' \
        -e 's/&uacute;/ú/g'  -e 's/&Uacute;/Ú/g' \
        -e 's/&acirc;/â/g'   -e 's/&Acirc;/Â/g' \
        -e 's/&ecirc;/ê/g'   -e 's/&Ecirc;/Ê/g' \
        -e 's/&ocirc;/ô/g'   -e 's/&Ocirc;/Ô/g' \
        -e 's/&agrave;/à/g'  -e 's/&Agrave;/À/g' \
        -e 's/&ouml;/ö/g'    -e 's/&uuml;/ü/g'   -e 's/&auml;/ä/g' \
        -e 's/&ldquo;/“/g'   -e 's/&rdquo;/”/g' \
        -e 's/&lsquo;/‘/g'   -e "s/&rsquo;/’/g" \
        -e 's/&mdash;/—/g'   -e 's/&ndash;/–/g'  -e 's/&hellip;/…/g' \
        -e 's/&nbsp;/ /g' \
        -e 's/&quot;/"/g'    -e "s/&apos;/'/g" \
        -e 's/&lt;/</g'      -e 's/&gt;/>/g' \
        -e 's/&amp;/\&/g'
}

# The authored body of a post as it was BEFORE the migration.
old_body() {
    git show "$BASELINE:$1" | sed -n '/^<h2>/,/^<hr class=end/p' | sed '/^<hr class=end/d'
}

# Prose as a word sequence, one word per line. <pre> blocks excluded.
#
# The input is flattened to ONE line before tags are stripped. Several tags in the
# hand-written HTML are split across source lines (`<a\nhref="…">`), and a
# line-oriented `s/<[^>]*>//g` cannot match those — it would leak `<a` and
# `href="…">` into the comparison as if they were prose, and report a clean
# conversion as a difference.
norm_prose() {
    awk '/<pre/{p=1} !p{print} /<\/pre>/{p=0}' \
        | tr '\n' ' ' \
        | sed 's/<[^>]*>//g' \
        | decode \
        | tr -s ' \t\n' '\n' \
        | sed '/^$/d'
}

# Code text, whitespace intact. Only <pre> blocks.
norm_code() {
    awk '/<pre/{p=1} p{print} /<\/pre>/{p=0}' \
        | sed -e 's|<pre[^>]*>||g' -e 's|</pre>||g' \
              -e 's|<code>||g' -e 's|</code>||g' \
              -e 's|<[^>]*>||g' \
        | decode
}

# Block-element counts, the structural check a word sequence cannot make.
#
# Paragraphs are counted by their CLOSERS. Counting openers is layout-dependent —
# the hand-written HTML often puts `<p>` alone on its own line, and any pattern
# that also looks at the following character misses every one of those. `</p>`
# appears exactly once per paragraph however the source is wrapped.
#
# The `<p><ul>` wrappers are then subtracted: an HTML parser turns those into an
# EMPTY <p></p> before the list, invisible on the page and not something markdown
# reproduces. Counting them would report the loss of an artefact as lost content.
counts() {
    _c=$1
    printf 'p=%s li=%s h3=%s h4=%s pre=%s blockquote=%s img=%s figcaption=%s\n' \
        "$(( $(grep -o '</p>' "$_c" | wc -l) - $(grep -o '<p><ul>\|<p><ol>' "$_c" | wc -l) ))" \
        "$(grep -c '<li>' "$_c" || true)" \
        "$(grep -c '<h3>' "$_c" || true)" \
        "$(grep -c '<h4>' "$_c" || true)" \
        "$(grep -o '<pre' "$_c" | wc -l || true)" \
        "$(grep -c '<blockquote' "$_c" || true)" \
        "$(grep -c '<img' "$_c" || true)" \
        "$(grep -c '<figcaption>' "$_c" || true)"
}

# Every href, sorted, with the quotes normalised away. Catches a botched
# .md -> .html rewrite.
#
# Unquoted hrefs have to be accepted on the OLD side: two posts were authored with
# `<a href=build.sh>`, which the previous converter mis-parsed (it assumed `href="`
# and swallowed the rest of the sentence as the URL). The new output always quotes,
# so comparing raw would report a fixed bug as a difference.
# Image sources are included too. They were not at first, and the gap was invisible
# until a deliberately corrupted image path still reported clean — the one post
# whose only local target is an <img> would have gone unchecked entirely.
links() {
    grep -oE '(href|src)=("[^"]*"|[^ >]+)' "$1" \
        | sed -e 's/^href=//' -e 's/^src=//' -e 's/^"//' -e 's/"$//' | sort || true
}

_fail=0 _files=0

check_one() {
    _h=$1
    _m=${_h%.html}.md
    _files=$((_files + 1))
    if [ ! -f "$_m" ]; then
        printf 'MISSING  %s (no .md)\n' "$_h"; _fail=$((_fail + 1)); return 0
    fi

    old_body "$_h" > "$_TMP/old.html"
    render_md "$_m" post '' > "$_TMP/new.html"

    _bad=''
    norm_prose < "$_TMP/old.html" > "$_TMP/old.prose"
    norm_prose < "$_TMP/new.html" > "$_TMP/new.prose"
    cmp -s "$_TMP/old.prose" "$_TMP/new.prose" || _bad="$_bad prose"

    norm_code < "$_TMP/old.html" > "$_TMP/old.code"
    norm_code < "$_TMP/new.html" > "$_TMP/new.code"
    cmp -s "$_TMP/old.code" "$_TMP/new.code" || _bad="$_bad code"

    # KNOWN EXCEPTION, and the only one. This post contains an unclosed <p> and a
    # line of bare prose with no tags around it at all. Neither is countable on the
    # old side — an unclosed paragraph has no </p>, and untagged prose has nothing
    # to count — while the markdown gives both a proper <p>…</p>. So the new file
    # has exactly two more paragraphs, and is the better-formed of the two.
    #
    # It is listed by name rather than handled by loosening the rule, because "the
    # new file may have MORE paragraphs" would also swallow a genuine paragraph
    # split. Prose here is still compared word for word, so nothing is taken on
    # trust: the text is proven identical, only the markup around it differs.
    _pfix=0
    case $_h in
        *2026-02-11-02-Validating-Markdown-Structure*)
            _pfix=2 ;;
    esac
    _cold=$(counts "$_TMP/old.html")
    _cnew=$(counts "$_TMP/new.html")
    _pnum=${_cold%% *}; _pnum=${_pnum#p=}
    _cold="p=$(( _pnum + _pfix )) ${_cold#* }"
    [ "$_cold" = "$_cnew" ] || _bad="$_bad counts"
    [ "$(links "$_TMP/old.html")" = "$(links "$_TMP/new.html")" ] || _bad="$_bad links"

    if [ -n "$_bad" ]; then
        _fail=$((_fail + 1))
        printf 'FAIL %-72s%s\n' "$_h" "$_bad"
        if [ -n "${VERBOSE:-}" ]; then
            case $_bad in
                *prose*)  printf '  --- prose ---\n';  diff "$_TMP/old.prose" "$_TMP/new.prose" | head -20 ;;
            esac
            case $_bad in
                *code*)   printf '  --- code ---\n';   diff "$_TMP/old.code" "$_TMP/new.code" | head -20 ;;
            esac
            case $_bad in
                *counts*) printf '  old %s\n  new %s\n' "$(counts "$_TMP/old.html")" "$(counts "$_TMP/new.html")" ;;
            esac
            case $_bad in
                *links*)
                    # Temp files rather than <(…): process substitution is a bash
                    # extension and this has to run under dash and busybox too.
                    printf '  --- links ---\n'
                    links "$_TMP/old.html" > "$_TMP/old.links"
                    links "$_TMP/new.html" > "$_TMP/new.links"
                    diff "$_TMP/old.links" "$_TMP/new.links" | head -20 ;;
            esac
        fi
    else
        printf 'ok   %s\n' "$_h"
    fi
    return 0
}

# The index pages are section-shaped and their bodies start at the first <h2>, so
# they get an exact comparison instead of a normalised one: both currently render
# byte-for-byte identical to the committed HTML, which is a stronger claim than the
# posts can make and worth asserting as such.
check_index() {
    _h=$1
    _m=${_h%.html}.md
    _files=$((_files + 1))
    case $_h in *.pt.html) _lg='.pt' ;; *) _lg='' ;; esac
    git show "$BASELINE:$_h" | sed -n '/^<h2>/,$p' > "$_TMP/old.html"
    render_md "$_m" section "$_lg" > "$_TMP/new.html"
    if cmp -s "$_TMP/old.html" "$_TMP/new.html"
    then printf 'ok   %s (byte-identical)\n' "$_h"
    else
        _fail=$((_fail + 1))
        printf 'FAIL %-72s exact\n' "$_h"
        [ -n "${VERBOSE:-}" ] && diff "$_TMP/old.html" "$_TMP/new.html" | head -20
    fi
    return 0
}

if [ $# -gt 0 ]; then
    case $1 in
        index*.html) check_index "$1" ;;
        *)           check_one "$1" ;;
    esac
else
    for _h in index.html index.pt.html; do check_index "$_h"; done
    for _h in blog/*.html; do check_one "$_h"; done
fi

printf '\n%d files, %d failing\n' "$_files" "$_fail"
[ "$_fail" -eq 0 ]

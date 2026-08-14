#!/usr/bin/env sh

# tools/html2md.sh — ONE-SHOT migration: the hand-written post HTML -> markdown.
#
#   sh tools/html2md.sh            # convert every post + the index pages
#   sh tools/html2md.sh blog/x.html > blog/x.md
#
# Throwaway. Delete it once the migration has landed and the .md files are the
# source. It runs on a GNU machine only, and uses sed freely — unlike md.sh and
# hl.sh, nothing here ever has to work inside the browser.
#
# The hand-tuned <span class="code-*"> highlighting is DISCARDED on purpose: the
# generic lexer regenerates it from the code itself. tools/verify.sh is what proves
# nothing else was lost, by comparing tag-stripped text rather than markup.

set -eu

_EOL='
'

# Same entity table build.sh has used against these exact files for months.
decode_entities() {
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

# HTML inline markup -> markdown, innermost first so that by the time <a> is
# matched its text contains no tags — which is what lets a link keep the <code> or
# <em> inside it (six such links exist in the corpus).
#
# Local .html targets become .md: markdown is the source now, and render.sh maps
# them back to .html for the browser while the terminal fetches the .md directly.
#
# The bare `</a>` strip runs AFTER both anchor rules, and cleans up one real typo
# in the corpus — a post closes the same link twice. A browser ignores the second;
# markdown would carry it through as literal text.
inline_md() {
    printf '%s' "$1" | sed \
        -e 's|<code[^>]*>\([^<]*\)</code>|`\1`|g' \
        -e 's|<strong[^>]*>\([^<]*\)</strong>|**\1**|g' \
        -e 's|<em[^>]*>\([^<]*\)</em>|*\1*|g' \
        -e 's|<u[^>]*>\([^<]*\)</u>|*\1*|g' \
        -e 's|<span lang=[^>]*>\([^<]*\)</span>|*\1*|g' \
        -e 's|<span[^>]*>||g' -e 's|</span>||g' \
        -e 's|<ins>\([^<]*\)</ins>|\1|g' -e 's|<del>\([^<]*\)</del>|\1|g' \
        -e 's|<a href="\([^"]*\)"[^>]*>\([^<]*\)</a>|[\2](\1)|g' \
        -e 's|<a href=\([^ >]*\)[^>]*>\([^<]*\)</a>|[\2](\1)|g' \
        -e 's|</a>||g' \
        -e 's|](/\([^)]*\)\.html)|](/\1.md)|g' \
        -e 's|](\([a-zA-Z0-9._-]*\)\.html)|](\1.md)|g' \
        | decode_entities
}

# A code block keeps its text and loses its colouring.
strip_code() {
    printf '%s' "$1" | sed \
        -e 's|<span[^>]*>||g' -e 's|</span>||g' \
        -e 's|<ins[^>]*>|+ |g' -e 's|</ins>||g' \
        -e 's|<del[^>]*>|- |g' -e 's|</del>||g' \
        -e 's|<code>||g' -e 's|</code>||g' \
        -e 's|<pre[^>]*>||g' -e 's|</pre>||g' | decode_entities
}

# The exact text of a code block, TRAILING NEWLINES INTACT.
#
# `$(…)` strips them, and here they are content: some blocks in this corpus close
# with `</code></pre>` on its own line, which is a real trailing blank line in the
# rendered card. The printf X sentinel is the standard way to hold onto them — the
# same trick ord.sh uses to keep a newline from vanishing out of its byte table.
#
# A single LEADING newline is dropped instead: HTML ignores one directly after
# <pre>, so keeping it would insert a blank line that was never displayed.
# Answers in _CODE_TEXT rather than on stdout: returning it would put the value
# straight back through the `$(…)` that strips the newlines this exists to keep.
code_text() {
    _ct=$(strip_code "$1"; printf X)
    _ct=${_ct%X}
    case $_ct in
        "$_EOL"*) _ct=${_ct#"$_EOL"} ;;
    esac
    _CODE_TEXT=$_ct
}

# The fence info string, chosen from what the block's own markup says it is.
# 'output' matters: it stops the lexer from reading an apostrophe in prose as the
# start of a string. 'diff' keeps the +/- lines that <ins>/<del> used to carry.
fence_info() {
    case $1 in
        *'<ins'*|*'<del'*) echo 'diff' ;;
        *'class="code-output"'*) echo 'output' ;;
        *) echo '' ;;
    esac
}

convert_one() {
    _f=$1
    _base=${_f#blog/}; _base=${_base%.html}
    case $_f in
        *.pt.html) _lang=pt; _id=${_base%.pt} ;;
        *)         _lang=en; _id=$_base ;;
    esac

    # The sibling-language post, matched on the shared YYYY-MM-DD-HH- prefix.
    _pfx=$(printf '%s' "$_base" | cut -c 1-13)
    if [ "$_lang" = en ]
    then _alt=$(ls blog/${_pfx}*.pt.html 2>/dev/null | head -n 1)
    else _alt=$(ls blog/${_pfx}*.html 2>/dev/null | grep -v '\.pt\.html' | head -n 1)
    fi
    _alt=${_alt#blog/}; _alt=${_alt%.html}

    _title='' _author='' _date=''
    _body='' _in_pre=0 _pre_raw='' _pre_txt='' _para='' _para_open=0 _para_sty=p
    _in_quote=0 _quote_started=0 _list=ul _n=0 _started=0 _in_cap=0 _cap_raw=''

    while IFS= read -r _l || [ -n "$_l" ]
    do
        # Inside a code block: collect raw lines, decide the fence at the end.
        if [ "$_in_pre" -eq 1 ]; then
            case $_l in
                *'</code></pre>'*)
                    _pre_raw="$_pre_raw$_EOL${_l%%'</code></pre>'*}"
                    _in_pre=0
                    _info=$(fence_info "$_pre_raw")
                    code_text "$_pre_raw"; _pre_txt=$_CODE_TEXT
                    _body="$_body$_EOL\`\`\`$_info$_EOL$_pre_txt$_EOL\`\`\`$_EOL"
                    _pre_raw='' ;;
                *) _pre_raw="$_pre_raw$_EOL$_l" ;;
            esac
            continue
        fi

        # Accumulating a <figcaption> that opened on an earlier line.
        if [ "$_in_cap" -eq 1 ]; then
            case $_l in
                *'</figcaption>'*)
                    _cap_raw="$_cap_raw ${_l%%'</figcaption>'*}"
                    _in_cap=0
                    _body="$_body*$(inline_md "$_cap_raw")*$_EOL" ;;
                *) _cap_raw="$_cap_raw $_l" ;;
            esac
            continue
        fi

        # Accumulating a <p>/<li> that opened on an earlier line.
        if [ "$_para_open" -eq 1 ]; then
            # Some paragraphs in this corpus are never closed. A browser ends a <p>
            # implicitly at the next block element, so do the same — otherwise the
            # accumulator runs on until it finds someone else's </p> and swallows
            # whole lists into a paragraph.
            case ${_l#"${_l%%[! 	]*}"} in
                '<p'*|'<ul'*|'<ol'*|'<pre'*|'<h2'*|'<h3'*|'<h4'*|'<blockquote'*|'<figure'*|'<hr'*)
                    _emit_para
                    _para_open=0 ;;
                *)
                    _para="$_para $_l"
                    case $_para in *'</p>'*|*'</li>'*) _flush=1 ;; *) _flush=0 ;; esac
                    if [ "$_flush" -eq 1 ]; then
                        _emit_para
                        _para_open=0
                    fi
                    continue ;;
            esac
        fi

        # Block tags are matched at the start of the line, but some <li> in this
        # corpus are indented inside their <ul>. Without this trim they matched no
        # arm and were dropped in silence — which is exactly the class of loss
        # tools/verify.sh exists to catch.
        _l=${_l#"${_l%%[! 	]*}"}

        # Three posts wrap a list in a paragraph — `<p><ul>` … `</ul></p>`, which
        # is not valid HTML but is what was written. Unwrapped here, or the <p>
        # arm below would swallow the entire list as one paragraph while it waited
        # for a </p> that only arrives after the list has ended.
        case $_l in
            '<p><ul>'*|'<p><ol>'*) _l=${_l#<p>} ;;
        esac
        case $_l in
            *'</ul></p>'|*'</ol></p>') _l=${_l%'</p>'} ;;
        esac

        case $_l in
            '') : ;;
            '<h2>'*)
                _title=$(printf '%s' "$_l" | sed -e 's|<h2>||' -e 's|</h2>.*||' | decode_entities) ;;
            '<p class=info'*)
                _author=$(printf '%s' "$_l" | sed -n 's|.*<em>\([^<]*\)</em>.*<em>\([^<]*\)</em>.*|\1|p' | decode_entities)
                _date=$(printf '%s' "$_l" | sed -n 's|.*<em>\([^<]*\)</em>.*<em>\([^<]*\)</em>.*|\2|p' | decode_entities)
                _started=1 ;;
            '<hr class=end'*) break ;;
            '<pre'*)
                _rest=${_l#*'<code>'}
                case $_l in
                    *'</code></pre>'*)
                        _pre_raw=${_rest%%'</code></pre>'*}
                        _info=$(fence_info "$_l")
                        code_text "$_pre_raw"; _pre_txt=$_CODE_TEXT
                        _body="$_body$_EOL\`\`\`$_info$_EOL$_pre_txt$_EOL\`\`\`$_EOL" ;;
                    *) _in_pre=1; _pre_raw=$_rest ;;
                esac ;;
            '<h3>'*) _body="$_body$_EOL## $(inline_md "$(printf '%s' "$_l" | sed -e 's|<h3>||' -e 's|</h3>.*||')")$_EOL" ;;
            '<h4>'*) _body="$_body$_EOL### $(inline_md "$(printf '%s' "$_l" | sed -e 's|<h4>||' -e 's|</h4>.*||')")$_EOL" ;;
            '<blockquote'*) _in_quote=1; _quote_started=0 ;;
            '</blockquote>'*) _in_quote=0; _body="$_body$_EOL" ;;
            '<figure'*)
                _src=$(printf '%s' "$_l" | sed -n 's|.*<img src=\([^ >]*\).*|\1|p')
                _alt2=$(printf '%s' "$_l" | sed -n 's|.*alt="\([^"]*\)".*|\1|p' | decode_entities)
                _body="$_body$_EOL![$_alt2]($_src)$_EOL" ;;
            '<img'*)
                _src=$(printf '%s' "$_l" | sed -n 's|.*src=\([^ >]*\).*|\1|p')
                _alt2=$(printf '%s' "$_l" | sed -n 's|.*alt="\([^"]*\)".*|\1|p' | decode_entities)
                _body="$_body$_EOL![$_alt2]($_src)$_EOL" ;;
            '<figcaption>'*)
                # A caption can span lines, so accumulate to the closing tag the
                # same way a paragraph does. Handling only the one-line form
                # dropped the tail of the one multi-line caption in the corpus.
                _cap_raw=${_l#'<figcaption>'}
                case $_l in
                    *'</figcaption>'*) _cap_raw=${_cap_raw%%'</figcaption>'*}; _in_cap=0 ;;
                    *) _in_cap=1 ;;
                esac
                if [ "$_in_cap" -eq 0 ]; then
                    _body="$_body*$(inline_md "$_cap_raw")*$_EOL"
                fi ;;
            '</figure>'*) : ;;
            '<ul>'*) _list=ul ;;
            '<ol>'*) _list=ol; _n=0 ;;
            '</ul>'*|'</ol>'*) _body="$_body$_EOL" ;;
            '<li>'*)
                _para_sty=li; _para=$_l
                case $_l in *'</li>'*) _emit_para ;; *) _para_open=1 ;; esac ;;
            '<p>'*|'<p '*)
                _para_sty=p; _para=$_l
                case $_l in *'</p>'*) _emit_para ;; *) _para_open=1 ;; esac ;;
            '<'*) : ;;              # an unhandled tag — headers, closers, stray markup
            *)
                # Bare prose with no <p> around it. Two posts do this, and the
                # previous converter handled it the same way; dropping it here is
                # how a whole sentence went missing on the first pass.
                _para_sty=p; _para="<p>$_l"; _emit_para ;;
        esac
    done < "$_f"

    # Front matter. alt/date/lang are machine-maintained from here on: build.sh
    # rewrites them on every run, so they never have to be typed.
    # The licence the posts have always carried in their footer, now stated in the
    # source as well. The year is the post's own, taken from its filename.
    printf -- '<!--\n'
    printf 'SPDX-FileCopyrightText: %s Alexandre Gomes Gaigalas <alganet@gmail.com>\n' "$(printf '%s' "$_base" | cut -c 1-4)"
    printf '\n'
    printf 'SPDX-License-Identifier: CC-BY-NC-SA-4.0\n'
    printf -- '-->\n'
    printf -- '---\n'
    printf 'alt: %s\n' "$_alt"
    printf 'date: %s\n' "$_date"
    printf 'author: %s\n' "$_author"
    printf 'lang: %s\n' "$_lang"
    printf -- '---\n\n'
    printf '# %s\n' "$_title"
    printf '%s\n' "$_body"
}

# Emit the accumulated <p>/<li> as one markdown line. Lazy continuation means a
# one-line paragraph re-wraps for free later, so the source's arbitrary hard wraps
# are not worth preserving.
_emit_para() {
    _p=${_para#<*>}
    _p=${_p%%'</p>'*}
    _p=${_p%%'</li>'*}
    _t=$(inline_md "$_p")
    if [ "$_para_sty" = li ]; then
        if [ "$_list" = ol ]; then
            _n=$((_n + 1)); _body="$_body$_n. $_t$_EOL"
        else
            _body="$_body- $_t$_EOL"
        fi
    elif [ "$_in_quote" -eq 1 ]; then
        # Paragraphs of ONE blockquote are separated by a bare '>', not a blank
        # line — a blank line would end the quote and start a second one.
        if [ "$_quote_started" -eq 1 ]; then
            _body="$_body>$_EOL> $_t$_EOL"
        else
            _body="$_body$_EOL> $_t$_EOL"; _quote_started=1
        fi
    else
        _body="$_body$_EOL$_t$_EOL"
    fi
    _para=''
}

# The index pages are section-shaped, not post-shaped: several top-level headings,
# no byline, and a blog list that build.sh regenerates on every run. Markdown level
# N maps to HTML N+1, so the <h2> sections become '#'.
convert_index() {
    _f=$1
    case $_f in
        *.pt.html) _lang=pt; _alt=index ;;
        *)         _lang=en; _alt=index.pt ;;
    esac

    _body='' _para='' _para_open=0 _para_sty=p _list=ul _n=0
    _in_quote=0 _quote_started=0 _in_pre=0 _in_cap=0 _cap_raw='' _started=0

    while IFS= read -r _l || [ -n "$_l" ]
    do
        if [ "$_para_open" -eq 1 ]; then
            _para="$_para $_l"
            case $_para in *'</p>'*|*'</li>'*) _emit_para; _para_open=0 ;; esac
            continue
        fi
        _l=${_l#"${_l%%[! 	]*}"}
        case $_l in
            '<h2>'*)
                _started=1
                _body="$_body$_EOL# $(inline_md "$(printf '%s' "$_l" | sed -e 's|<h2>||' -e 's|</h2>.*||')")$_EOL" ;;
            '<ul'*) _list=ul ;;
            '</ul>'*) _body="$_body$_EOL" ;;
            '<li>'*)
                _para_sty=li; _para=$_l
                case $_l in *'</li>'*) _emit_para ;; *) _para_open=1 ;; esac ;;
            '<p>'*|'<p '*)
                [ "$_started" -eq 1 ] || continue
                _para_sty=p; _para=$_l
                case $_l in *'</p>'*) _emit_para ;; *) _para_open=1 ;; esac ;;
            *) : ;;
        esac
    done < "$_f"

    printf -- '<!--\n'
    printf 'SPDX-FileCopyrightText: %s Alexandre Gomes Gaigalas <alganet@gmail.com>\n' "$(date +%Y)"
    printf '\n'
    printf 'SPDX-License-Identifier: CC-BY-NC-SA-4.0\n'
    printf -- '-->\n'
    printf -- '---\n'
    printf 'alt: %s\n' "$_alt"
    printf 'lang: %s\n' "$_lang"
    printf -- '---\n'
    printf '%s\n' "$_body"
}

if [ $# -gt 0 ]; then
    case $1 in
        index*.html) convert_index "$1" ;;
        *)           convert_one "$1" ;;
    esac
    exit 0
fi

for _f in blog/*.html; do
    case $_f in *.pt.html) : ;; esac
    _out=${_f%.html}.md
    convert_one "$_f" > "$_out"
    printf 'wrote %s\n' "$_out" >&2
done

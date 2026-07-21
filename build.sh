#!/usr/bin/env sh

set -eu

get_line () { read -r line || test -n "$line"; }

_EOL="
"
IFS=$_EOL

# Clean up any leftover temporary files
rm -f tmp_*.html

xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

# Decode HTML entities (stdin → stdout). Covers the basic XML five, the Latin
# accented letters the Portuguese posts encode as named entities, and common
# typographic marks. &amp; is decoded LAST so a decoded '&' can't re-trigger.
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
        -e 's/&nbsp;/ /g' \
        -e 's/&quot;/"/g'    -e "s/&apos;/'/g" \
        -e 's/&lt;/</g'      -e 's/&gt;/>/g' \
        -e 's/&amp;/\&/g'
}

html_to_text() {
    # Remove HTML tags, then decode entities.
    printf '%s' "$1" | sed 's/<[^>]*>//g' | decode_entities
}

# ─── HTML → .tui converter ───────────────────────────────────────────────────
# The shell/TUI version of the site (terminal/) renders each page from a ".tui"
# file that lives ALONGSIDE its .html twin. A .tui is a list of "STYLE<TAB>PAYLOAD"
# records the reader (terminal/index.sh) draws. Simple styles carry plain text;
# paragraph/bullet/quote styles carry a SEGMENTED payload — spans of
# "style<US>text" (US = 0x1f) — so a line can mix body text, accent link text and
# a dim inline URL (which xterm's web-links addon then makes clickable). Generated
# here so `build.sh`/`newpost.sh` keep both versions in sync automatically.
_TAB=$(printf '\t')
_US=$(printf '\037')

_emit() { printf '%s%s%s\n' "$1" "$_TAB" "$2"; }

# strip_spans TEXT — drop syntax-highlight wrappers from a code line, unescape
# entities, keep indentation. Handles <span …>, <ins>, and the <code> tags.
strip_spans() {
    printf '%s' "$1" | sed \
        -e 's|<span[^>]*>||g' -e 's|</span>||g' \
        -e 's|<ins[^>]*>||g' -e 's|</ins>||g' \
        -e 's|<del[^>]*>||g' -e 's|</del>||g' \
        -e 's|<code>||g' -e 's|</code>||g' | decode_entities
}

# Map a post's code-* highlight class to a one-char code-segment style. The reader
# (_paint_code) turns each into the site's dark-theme code colour.
_cmap() {
    case $1 in
        statement|keyword)    printf K;;
        string)               printf S;;
        comment)              printf C;;
        function|result)      printf F;;
        class)                printf L;;
        number|boolean)       printf N;;
        attr)                 printf A;;
        operator|punctuation) printf O;;
        builtin)              printf B;;
        stderr)               printf E;;
        *)                    printf .;;   # argument, output, default → code text
    esac
}
# Append a code segment (style<US>text) to _cpay: decode entities, expand tabs.
# Whitespace-only text is KEPT (indentation matters); only "" is dropped.
_cspan_add() {
    _ct=$(printf '%s' "$2" | sed 's/\t/    /g' | decode_entities)
    [ -n "$_ct" ] || return 0
    if [ -n "$_cpay" ]; then _cpay="$_cpay$_US$1$_US$_ct"; else _cpay="$1$_US$_ct"; fi
}
# Convert one highlighted code line into a segmented payload, preserving the
# post's hand-tuned <span class="code-*"> colouring instead of stripping it.
# <ins>/<del> diff wrappers are dropped (their inner spans stay). Spans NEST
# (e.g. code-output wrapping code-result) and cross source lines (multi-line
# output), so the current colour is a STACK of style chars carried in _cstack;
# text takes the innermost (top) style. Result goes to _CPAY (NOT stdout — the
# caller must not subshell this, or the carried stack would be lost).
code_spans() {
    _cpay=''
    _f=$(printf '%s' "$1" | sed \
        -e 's|<ins[^>]*>||g' -e 's|</ins>||g' -e 's|<del[^>]*>||g' -e 's|</del>||g' \
        -e 's|class=code-|class="code-|g')
    while [ -n "$_f" ]; do
        _cur=.; [ -n "$_cstack" ] && { _pfx=${_cstack%?}; _cur=${_cstack#"$_pfx"}; }
        _po=-1 _pc=-1
        case $_f in *'<span class="code-'*) _pre=${_f%%'<span class="code-'*}; _po=${#_pre};; esac
        case $_f in *'</span>'*) _pre=${_f%%'</span>'*}; _pc=${#_pre};; esac
        if [ "$_po" -lt 0 ] && [ "$_pc" -lt 0 ]; then
            _cspan_add "$_cur" "$_f"; break
        fi
        if [ "$_pc" -lt 0 ] || { [ "$_po" -ge 0 ] && [ "$_po" -le "$_pc" ]; }; then
            _cspan_add "$_cur" "${_f%%'<span class="code-'*}"          # text before, top style
            _rest=${_f#*'<span class="code-'}
            _cstack="$_cstack$(_cmap "${_rest%%'"'*}")"                # push the opened style
            _f=${_rest#*'>'}
        else
            _cspan_add "$_cur" "${_f%%'</span>'*}"                     # text before close, top style
            _cstack=${_cstack%?}                                       # pop
            _f=${_f#*'</span>'}
        fi
    done
    _CPAY=$_cpay
}

# unwrap TAG LINE — strip a single <TAG …> … </TAG> wrapper.
unwrap() { printf '%s' "$2" | sed "s|<$1[^>]*>||; s|</$1>.*||"; }

# _span STYLE TEXT — append one span to the payload accumulator _pay (skip empty).
_span() {
    _t=$(html_to_text "$2")
    [ -n "$_t" ] || return 0
    if [ -n "$_pay" ]; then _pay="$_pay$_US$1$_US$_t"; else _pay="$1$_US$_t"; fi
}

# inline FRAGMENT — turn one HTML inline fragment into a segmented payload:
#   x<US>body <US>k<US>link text<US>d<US> (https://url)<US>x<US> more body
# <em>/<strong>/<ins>/<span> fold into body text; <code> → m (inline code);
# <a href=URL>TEXT</a> → k (TEXT) + d ( (URL) ). Echoes the payload.
inline() {
    _f=$(printf '%s' "$1" | sed \
        -e 's|<em[^>]*>||g' -e 's|</em>||g' \
        -e 's|<strong[^>]*>||g' -e 's|</strong>||g' \
        -e 's|<ins[^>]*>||g' -e 's|</ins>||g' \
        -e 's|<del[^>]*>||g' -e 's|</del>||g' \
        -e 's|<span[^>]*>||g' -e 's|</span>||g')
    _pay=''
    while :; do
        _ia=-1 _ic=-1
        case $_f in *'<a '*) _pre=${_f%%'<a '*}; _ia=${#_pre};; esac
        case $_f in *'<code>'*) _pre=${_f%%'<code>'*}; _ic=${#_pre};; esac
        if [ "$_ia" -lt 0 ] && [ "$_ic" -lt 0 ]; then
            _span x "$_f"; break
        fi
        if [ "$_ic" -lt 0 ] || { [ "$_ia" -ge 0 ] && [ "$_ia" -le "$_ic" ]; }; then
            _span x "${_f%%'<a '*}"
            _rest=${_f#*'<a '}
            _url=${_rest#*href=\"}; _url=${_url%%\"*}
            _after=${_rest#*>}; _txt=${_after%%'</a>'*}; _f=${_after#*'</a>'}
            _span k "$_txt"
            _span d " ($_url)"
        else
            _span x "${_f%%'<code>'*}"
            _rest=${_f#*'<code>'}; _txt=${_rest%%'</code>'*}; _f=${_rest#*'</code>'}
            _span m "$_txt"
        fi
    done
    printf '%s' "$_pay"
}

# _flush_para — emit the accumulated <p>/<li> as a segmented record. Strip the
# SPECIFIC close tag (</p> or </li>) — not any "</", which would truncate the
# paragraph at an inner </code> or </a>.
_flush_para() {
    _p=${_para#<*>}                       # drop the leading <p …>/<li> open tag
    _p=${_p%%'</p>'*}                      # drop </p> (and anything after), if present
    _p=${_p%%'</li>'*}                     # drop </li> (and anything after), if present
    _emit "$_para_sty" "$(inline "$_p")"
    _para_open=0 _para=''
}

# html_to_tui MODE — read an HTML body on stdin, emit STYLE<TAB>PAYLOAD records.
# MODE=post: <h2> → t (page title).  MODE=section: <h2> → h (section header).
html_to_tui() {
    _mode=$1
    _in_code=0 _in_quote=0 _para='' _para_open=0 _para_sty=p _cstack=''
    while IFS= read -r _ln || [ -n "$_ln" ]; do
        # Inside a fenced code block: colourize each line until the close.
        # code_spans must NOT run in a subshell (it carries open-span state), so it
        # writes _CPAY and we emit that.
        if [ "$_in_code" -eq 1 ]; then
            case $_ln in
                *'</code></pre>'*) code_spans "${_ln%%'</code></pre>'*}"; _emit c "$_CPAY"; _in_code=0 ;;
                *) code_spans "$_ln"; _emit c "$_CPAY" ;;
            esac
            continue
        fi
        # Accumulating a paragraph/bullet that opened on an earlier line.
        if [ "$_para_open" -eq 1 ]; then
            _para="$_para $_ln"
            case $_para in *'</p>'*|*'</li>'*) _flush_para ;; esac
            continue
        fi
        case $_ln in
            '') : ;;
            '<pre class="codeblock"><code>'*|'<pre class=codeblock><code>'*)
                _rest=${_ln#*'<code>'}; _cstack=''
                case $_rest in
                    *'</code></pre>'*) code_spans "${_rest%%'</code></pre>'*}"; _emit c "$_CPAY" ;;
                    *) _in_code=1; [ -n "$_rest" ] && { code_spans "$_rest"; _emit c "$_CPAY"; } || : ;;
                esac ;;
            '<h2>'*)
                if [ "$_mode" = post ]; then _emit t "$(html_to_text "$(unwrap h2 "$_ln")")"
                else _emit h "$(html_to_text "$(unwrap h2 "$_ln")")"; fi ;;
            '<p class=info'*) _emit i "$(html_to_text "$_ln")" ;;
            '<h3>'*) _emit h "$(html_to_text "$(unwrap h3 "$_ln")")" ;;
            '<h4>'*) _emit h "$(html_to_text "$(unwrap h4 "$_ln")")" ;;
            '<blockquote'*) _in_quote=1 ;;
            '</blockquote>'*) _in_quote=0 ;;
            '<figure'*|'<img'*)
                _alt=$(printf '%s' "$_ln" | sed -n 's|.*alt="\([^"]*\)".*|\1|p')
                _emit g "$(html_to_text "${_alt:-image}")" ;;
            '<figcaption'*) _emit d "$(html_to_text "$(unwrap figcaption "$_ln")")" ;;
            '<ul>'*|'</ul>'*|'<ol>'*|'</ol>'*) : ;;
            '<li>'*)
                _para_sty=b; _para="$_ln"
                case $_ln in *'</li>'*) _flush_para ;;
                    *) _para_open=1 ;; esac ;;
            '<p>'*|'<p '*)
                _para_sty=p; [ "$_in_quote" -eq 1 ] && _para_sty=q || :
                _para="$_ln"
                case $_ln in *'</p>'*) _flush_para ;;
                    *) _para_open=1 ;; esac ;;
            *) _emit p "$(inline "$_ln")" ;;
        esac
    done
}

clean_header() {
    _strip_rss=$1
    if [ "$_strip_rss" -eq 1 ]; then
        sed '/href="feed/d'
    else
        cat -
    fi
}

write_header() {
    _target_file=$1
    _lang_suffix=$2
    _page_title=${3-}
    _strip_rss=1
    _header_file=$(ls tmp_${_lang_suffix}_*'_Header_section.html' | head -n 1)
    
    _en_url=""
    _pt_url=""

    case $_target_file in
        *index.*) _strip_rss=0 ;;
        *blog.*) _strip_rss=0 ;;
    esac

    case $_target_file in
        blog/*)
            _id=$(echo "$_target_file" | cut -d/ -f2 | cut -c 1-13)
            _en_file=$(ls blog/${_id}*.html 2>/dev/null | grep -v "\.pt\.html" | head -n 1)
            _pt_file=$(ls blog/${_id}*.pt.html 2>/dev/null | head -n 1)
            [ -n "$_en_file" ] && _en_url="/$_en_file"
            [ -n "$_pt_file" ] && _pt_url="/$_pt_file"
            ;;
        *)
            case $_target_file in
                *.pt.html)
                    _pt_url="/$_target_file"
                    _en_url="/${_target_file%.pt.html}.html"
                    ;;
                *.html)
                    _en_url="/$_target_file"
                    _pt_url="/${_target_file%.html}.pt.html"
                    ;;
            esac
            ;;
    esac
    
    # Normalize index URLs
    if [ ! -f ".${_en_url%/}" ] && [ "$_en_url" != "/" ]; then _en_url=""; fi
    if [ ! -f ".${_pt_url%/}" ]; then _pt_url=""; fi

    _home_url="/"
    if [ "$_lang_suffix" = ".pt" ]; then _home_url="/index.pt.html"; fi

    if [ -n "$_page_title" ]; then
        # escape backslashes, pipes and ampersands for safe sed replacement
        _escaped_title=$(printf '%s' "$_page_title" | sed -e 's/\\/\\\\/g' -e 's/|/\\|/g' -e 's/&/\\\&/g')
        cat "$_header_file" |
            sed "s|<h1><a href=/>|<h1><a href=$_home_url>|g" |
            sed "s|<title>.*</title>|<title>$_escaped_title</title>|g" |
            clean_header $_strip_rss
    else
        cat "$_header_file" |
            sed "s|<h1><a href=/>|<h1><a href=$_home_url>|g" |
            clean_header $_strip_rss
    fi
    
    _link_en="English"
    if [ -n "$_en_url" ]; then
        _class=""
        [ -z "$_lang_suffix" ] && _class=" class=selected"
        _link_en="<a href=\"$_en_url\"$_class>English</a>"
    fi
    
    _link_pt="Português"
    if [ -n "$_pt_url" ]; then
        _class=""
        [ "$_lang_suffix" = ".pt" ] && _class=" class=selected"
        _link_pt="<a href=\"$_pt_url\"$_class>Português</a>"
    fi

    # Switcher: a link into the shell/TUI version, carrying the current page and
    # language so /terminal/ boots on the same content.
    case $_target_file in
        *index.*) _sp=home ;;
        *blog.*)  _sp=blog ;;
        blog/*)   _sp="post:$(echo "$_target_file" | cut -d/ -f2 | sed 's/\.html$//')" ;;
        *)        _sp=home ;;
    esac
    if [ "$_lang_suffix" = ".pt" ]; then _sl=pt; else _sl=en; fi
    _link_shell="<a class=shell href=\"/terminal/?p=${_sp}&amp;lang=${_sl}\" title=\"View this page in the terminal\">\$ <b></b></a>"

    echo "<nav class=lang>$_link_en $_link_pt $_link_shell</nav>"
}

for LANG_SUFFIX in "" ".pt"
do
    INDEX_FILE="index${LANG_SUFFIX}.html"
    BLOG_ALL="blog${LANG_SUFFIX}.html"
    
    if [ ! -f "$INDEX_FILE" ]; then continue; fi

    # Breaks apart the index file into sections
    line= order=0 section=Header
    while get_line
    do
        case $line in
            '<nav'*) continue ;; # Skip existing nav elements
            '<h2>'*)
                section="${line#'<h2>'}"
                section="${section%'</h2>'*}"
                order=$((order + 1))
                ;;
        esac
        printf '%s\n' "$line" >> "tmp_${LANG_SUFFIX}_${order}_${section}_section.html"
    done < "./$INDEX_FILE"

    # Rebuild the full blog and latest posts section
    blog_section_file=$(ls tmp_${LANG_SUFFIX}_*'_Blog_section.html' | head -n 1)
    
    if [ "$LANG_SUFFIX" = ".pt" ]; then
        BLOG_TITLE="Blog"
        MORE_ENTRIES="Mais posts..."
    else
        BLOG_TITLE="Blog"
        MORE_ENTRIES="More entries..."
    fi

    echo "<h2>$BLOG_TITLE</h2>" > "$BLOG_ALL"
    echo '<ul class=blog>' >> "$BLOG_ALL"

    # The shell version's siblings: the full-list and home .tui files. list.tui
    # (blog.tui / blog.pt.tui) gets a header now and one selectable 'e' row per
    # post inside the loop; home.tui (index.tui / index.pt.tui) is assembled with
    # the index during reassembly.
    if [ -z "$LANG_SUFFIX" ]; then LANG_TOK=en; else LANG_TOK=pt; fi
    LIST_TUI="blog${LANG_SUFFIX}.tui"
    HOME_TUI="index${LANG_SUFFIX}.tui"
    printf 't\t%s\n' "$BLOG_TITLE" > "$LIST_TUI"

    if [ -z "$LANG_SUFFIX" ]; then
        entries="$(find blog -maxdepth 1 -type f -name "*.html" ! -name "*.pt.html" | sort -rn)"
    else
        entries="$(find blog -maxdepth 1 -type f -name "*${LANG_SUFFIX}.html" | sort -rn)"
    fi

    entry= title= date= content= max_latest=5
    for entry in $entries
    do
        iso_date="${entry#blog/}"
        year=$(echo "$iso_date" | cut -c 1-4)
        month=$(echo "$iso_date" | cut -c 6-7)
        day=$(echo "$iso_date" | cut -c 9-10)
        
        if [ "$LANG_SUFFIX" = ".pt" ]; then
            case $month in
                01) month_name="Janeiro" ;;
                02) month_name="Fevereiro" ;;
                03) month_name="Março" ;;
                04) month_name="Abril" ;;
                05) month_name="Maio" ;;
                06) month_name="Junho" ;;
                07) month_name="Julho" ;;
                08) month_name="Agosto" ;;
                09) month_name="Setembro" ;;
                10) month_name="Outubro" ;;
                11) month_name="Novembro" ;;
                12) month_name="Dezembro" ;;
                *) month_name="$month" ;;
            esac
            day_clean=$(echo "$day" | sed 's/^0//')
            date="$day_clean de $month_name de $year"
        else
            case $month in
                01) month_name="January" ;;
                02) month_name="February" ;;
                03) month_name="March" ;;
                04) month_name="April" ;;
                05) month_name="May" ;;
                06) month_name="June" ;;
                07) month_name="July" ;;
                08) month_name="August" ;;
                09) month_name="September" ;;
                10) month_name="October" ;;
                11) month_name="November" ;;
                12) month_name="December" ;;
                *) month_name="$month" ;;
            esac
            day_clean=$(echo "$day" | sed 's/^0//')
            date="$month_name $day_clean, $year"
        fi

        title=
        content=
        while get_line
        do
            case $line in
                '<nav'*) continue ;; # Skip existing nav elements
                '<h2>'*)
                    title="${line#'<h2>'}"
                    title="${title%'</h2>'*}"
                    ;;
                '<p class=info'*)
                    line="<p class=info><em>Alexandre Gomes Gaigalas</em> – <em>$date</em>"'</p>'
                    content="$_EOL<h2>$title</h2>"
                    ;;
                '<hr class=end'*)
                    break
                    ;;
            esac
            content="$content$_EOL$line"
        done < "$entry"
        
        write_header "$entry" "$LANG_SUFFIX" "$title" > "tmp_entry.html"
        cat tmp_entry.html > "${entry}"
        printf '%s\n' "$content" >> "${entry}"
        echo "<hr class=end><p class=cc><a href=\"https://creativecommons.org/licenses/by-nc-sa/4.0/\">CC BY-NC-SA 4.0</a></p>" >> "${entry}"
        echo "<li><a href=\"/${entry}\">$title</a> <em>$date</em></li>" >> "$BLOG_ALL"
        rm tmp_entry.html

        # Shell version: write the post's .tui sibling and add its list row. The
        # 'a' record pairs the EN/PT basenames (slugs differ) for the reader's
        # language toggle; the body is the SAME $content we just wrote as HTML.
        _id=$(printf '%s' "$iso_date" | cut -c 1-13)
        _en_file=$(ls "blog/${_id}"*.html 2>/dev/null | grep -v '\.pt\.html' | head -n 1)
        _pt_file=$(ls "blog/${_id}"*.pt.html 2>/dev/null | head -n 1)
        # Basenames are the .tui/.html STEMS: EN has no suffix, PT keeps its .pt
        # (so post:<base> maps straight to blog/<base>.tui and blog/<base>.html).
        _en_base=${_en_file#blog/}; _en_base=${_en_base%.html}
        _pt_base=${_pt_file#blog/}; _pt_base=${_pt_base%.html}
        _base=${entry#blog/}; _base=${_base%.html}
        {
            printf 'a\t%s\037%s\n' "$_en_base" "$_pt_base"
            printf '%s\n' "$content" | html_to_tui post
            # Footer: a rule and the CC licence, mirroring <hr class=end><p class=cc>.
            printf 'r\t\n'
            printf 'p\tk\037CC BY-NC-SA 4.0\037d\037 (https://creativecommons.org/licenses/by-nc-sa/4.0/)\n'
        } > "${entry%.html}.tui"
        printf 'e\t%s\037%s\037%s\n' "$_base" "$title" "$date" >> "$LIST_TUI"
    done

    # Create the blog section for index.html (latest posts)
    cat "$BLOG_ALL" | head -n 7 > "$blog_section_file"
    echo '</ul>' >> "$BLOG_ALL"
    
    write_header "$BLOG_ALL" "$LANG_SUFFIX" > "tmp_blog_all.html"
    echo "$_EOL$(cat "$BLOG_ALL")" >> "tmp_blog_all.html"
    cat tmp_blog_all.html > "$BLOG_ALL"
    rm tmp_blog_all.html

    echo "<li><a href=\"/$BLOG_ALL\"><em>$MORE_ENTRIES</em></a></li>" >> "$blog_section_file"
    echo '</ul>' >> "$blog_section_file"

    # Puts back the index file with the updated blog contents, and assembles the
    # home .tui sibling in the same pass. The .tui has no header chrome (the reader
    # draws its own); the Blog section becomes selectable 'e' entries rather than
    # inert links, and About/Links are converted section bodies.
    printf %s '' > "$INDEX_FILE"
    : > "$HOME_TUI"
    part=0
    while test $part -lt $((order + 1))
    do
        filename=$(ls tmp_${LANG_SUFFIX}_"${part}"*'_section.html' | head -n 1)
        case $filename in
            *_Header_section.html)
                write_header "$INDEX_FILE" "$LANG_SUFFIX" >> "$INDEX_FILE" ;;
            *_Blog_section.html)
                while get_line
                do printf '%s\n' "$line" >> "$INDEX_FILE"
                done < "$filename"
                printf 'h\t%s\n' "$BLOG_TITLE" >> "$HOME_TUI"
                grep '^e' "$LIST_TUI" | head -n 5 >> "$HOME_TUI"
                printf 'e\t@blog\037%s\037\n' "$MORE_ENTRIES" >> "$HOME_TUI" ;;
            *)
                while get_line
                do printf '%s\n' "$line" >> "$INDEX_FILE"
                done < "$filename"
                html_to_tui section < "$filename" >> "$HOME_TUI" ;;
        esac
        rm "$filename"
        part=$((part + 1))
    done

    # Generate Atom feed
    FEED_FILE="feed${LANG_SUFFIX}.xml"

    if [ "$LANG_SUFFIX" = ".pt" ]; then
        FEED_TITLE="Blog — alganet"
        FEED_SUBTITLE="Artigos técnicos sobre desenvolvimento de software"
    else
        FEED_TITLE="Blog — alganet"
        FEED_SUBTITLE="Technical articles on software development"
    fi

    # XML header
    cat > "$FEED_FILE" << 'ATOM_EOF'
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
ATOM_EOF

    # Calculate updated time (latest post date)
    _latest_entry=$(find blog -maxdepth 1 -type f -name "*${LANG_SUFFIX}.html" | sort -rn | head -n 1)
    if [ -n "$_latest_entry" ]; then
        _updated="${_latest_entry#blog/}"
        _updated_year=$(echo "$_updated" | cut -c 1-4)
        _updated_month=$(echo "$_updated" | cut -c 6-7)
        _updated_day=$(echo "$_updated" | cut -c 9-10)
        _updated_hour=$(echo "$_updated" | cut -c 12-13)
        _updated_iso="${_updated_year}-${_updated_month}-${_updated_day}T${_updated_hour}:00:00Z"
    else
        _updated_iso="2025-01-23T00:00:00Z"
    fi

    # Feed metadata
    {
        echo "  <title>$(xml_escape "$FEED_TITLE")</title>"
        echo "  <subtitle>$(xml_escape "$FEED_SUBTITLE")</subtitle>"
        echo "  <id>tag:alganet.github.io,2025:feed${LANG_SUFFIX}</id>"
        echo "  <link href=\"https://alganet.github.io/\" />"
        echo "  <link href=\"https://alganet.github.io/feed${LANG_SUFFIX}.xml\" rel=\"self\" />"
        echo "  <updated>$_updated_iso</updated>"
    } >> "$FEED_FILE"

    # Feed entries
    entry= title= excerpt=
    for entry in $entries
    do
        iso_date="${entry#blog/}"
        year=$(echo "$iso_date" | cut -c 1-4)
        month=$(echo "$iso_date" | cut -c 6-7)
        day=$(echo "$iso_date" | cut -c 9-10)
        hour=$(echo "$iso_date" | cut -c 12-13)
        iso_timestamp="${year}-${month}-${day}T${hour}:00:00Z"

        title=
        excerpt=
        in_excerpt=0

        while get_line
        do
            case $line in
                '<nav'*) continue ;;
                '<h2>'*)
                    title="${line#'<h2>'}"
                    title="${title%'</h2>'*}"
                    ;;
                '<p class=info'*)
                    in_excerpt=1
                    continue
                    ;;
                '<hr class=end'*)
                    break
                    ;;
                *)
                    if [ "$in_excerpt" -eq 1 ]; then
                        case $line in
                            '<p>'*|'<p '*)
                                _raw="${line#'<p'}"
                                _raw="${_raw#*'>'}"
                                _raw="${_raw%'</p>'*}"
                                excerpt="$excerpt $_raw"
                                if test ${#excerpt} -gt 300; then
                                    excerpt="$(html_to_text "$excerpt")"
                                    excerpt="${excerpt% *}..."
                                    in_excerpt=0
                                fi
                                ;;
                        esac
                    fi
                    ;;
            esac
        done < "$entry"

        _entry_url="https://alganet.github.io/${entry}"
        _entry_id="tag:alganet.github.io,2025:${iso_date%.*}"

        {
            echo "  <entry>"
            echo "    <title>$(xml_escape "$title")</title>"
            echo "    <id>$_entry_id</id>"
            echo "    <link href=\"$_entry_url\" />"
            echo "    <updated>$iso_timestamp</updated>"
            echo "    <summary>$(xml_escape "$excerpt")</summary>"
            echo "    <author>"
            echo "      <name>Alexandre Gomes Gaigalas</name>"
            echo "    </author>"
            echo "  </entry>"
        } >> "$FEED_FILE"
    done

    echo '</feed>' >> "$FEED_FILE"

done

# content.json — the list of .tui siblings (relative to the repo root) that the
# shell version's boot loader (terminal/index.html) fetches and mounts at /content.
# Separate from terminal/manifest.json (the vendored tuish-src list, written by
# vendor.sh) so the two generators never contend for one file.
{
    printf '[\n'
    _first=1
    for _t in $(find . -name '*.tui' ! -path './terminal/*' | sed 's|^\./||' | sort)
    do
        if [ "$_first" -eq 1 ]; then _first=0; else printf ',\n'; fi
        printf '  "%s"' "$_t"
    done
    printf '\n]\n'
} > terminal/content.json

#!/usr/bin/env sh

# build.sh — regenerate the site from its markdown sources.
#
#   sh build.sh
#
# WHAT IS AUTHORED AND WHAT IS GENERATED
#
#   blog/<date>-<slug>.md     authored     a post (its .pt.md twin too)
#   index.md / index.pt.md    authored     except the Blog list, rewritten here
#   blog.md / blog.pt.md      generated    the full post list
#   *.html                    generated    every one of them
#   feed*.xml                 generated
#   terminal/content.json     generated
#
# The markdown is read by tuish's md.sh — the same module terminal/index.sh uses —
# and rendered by render.sh. The HTML and the terminal version are therefore two
# renderings of ONE parse, neither derived from the other, which is what stops them
# drifting apart. The previous build scraped the .tui out of the finished HTML, and
# a link written `<a href=build.sh>` (no quotes) was enough to corrupt it.
#
# The terminal reads the SAME .md files this generates HTML from — there is no
# intermediate format and nothing to keep in step. terminal/content.json is just
# the list of them for the browser loader to fetch.

set -eu

. ./render.sh

_EOL="
"
_TAB=$(printf '\t')
_US=$(printf '\037')

# Every markdown file carries its licence. The posts have always said CC BY-NC-SA
# in their footer; saying it in the source as well is what makes the claim survive
# a file being read on its own, and what a tool like REUSE can actually check.
# The comment sits ABOVE the front matter, which is why md.sh skips comments and
# looks for front matter at the first content line rather than at line 1.
spdx_header() {
    printf -- '<!--\n'
    printf 'SPDX-FileCopyrightText: %s Alexandre Gomes Gaigalas <alganet@gmail.com>\n' "$1"
    printf '\n'
    printf 'SPDX-License-Identifier: CC-BY-NC-SA-4.0\n'
    printf -- '-->\n'
}

xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

# The display date for a post, from its filename. The filename carries the machine
# date; the front matter carries this, the localized string a reader sees. Keeping
# the tables here — in the one place that generates them — is why the reader needs
# no month names at all.
month_name() {
    if [ "$1" = ".pt" ]; then
        case $2 in
            01) echo Janeiro ;;  02) echo Fevereiro ;; 03) echo "Março" ;;
            04) echo Abril ;;    05) echo Maio ;;      06) echo Junho ;;
            07) echo Julho ;;    08) echo Agosto ;;    09) echo Setembro ;;
            10) echo Outubro ;;  11) echo Novembro ;;  12) echo Dezembro ;;
            *) echo "$2" ;;
        esac
    else
        case $2 in
            01) echo January ;;  02) echo February ;;  03) echo March ;;
            04) echo April ;;    05) echo May ;;       06) echo June ;;
            07) echo July ;;     08) echo August ;;    09) echo September ;;
            10) echo October ;;  11) echo November ;;  12) echo December ;;
            *) echo "$2" ;;
        esac
    fi
}

display_date() {   # BASENAME LANG_SUFFIX -> DISP_DATE
    _dd_y=$(printf '%s' "$1" | cut -c 1-4)
    _dd_m=$(printf '%s' "$1" | cut -c 6-7)
    _dd_d=$(printf '%s' "$1" | cut -c 9-10)
    _dd_d=$(printf '%s' "$_dd_d" | sed 's/^0//')
    _dd_n=$(month_name "$2" "$_dd_m")
    if [ "$2" = ".pt" ]
    then DISP_DATE="$_dd_d de $_dd_n de $_dd_y"
    else DISP_DATE="$_dd_n $_dd_d, $_dd_y"
    fi
}

# Rewrite a post's machine-maintained front matter: the sibling-language basename,
# the display date and the language. The author never types these, and because they
# are refreshed before anything renders, the .md on disk and the .html can never
# disagree about them. Any other key the author wrote is preserved untouched.
refresh_front_matter() {
    _rf_f=$1
    _rf_base=${_rf_f#blog/}; _rf_base=${_rf_base%.md}
    case $_rf_f in
        *.pt.md) _rf_lang=pt; _rf_sfx=.pt ;;
        *)       _rf_lang=en; _rf_sfx='' ;;
    esac
    _rf_id=$(printf '%s' "$_rf_base" | cut -c 1-13)
    if [ "$_rf_lang" = en ]
    then _rf_alt=$(ls blog/"${_rf_id}"*.pt.md 2>/dev/null | head -n 1)
    else _rf_alt=$(ls blog/"${_rf_id}"*.md 2>/dev/null | grep -v '\.pt\.md' | head -n 1)
    fi
    _rf_alt=${_rf_alt#blog/}; _rf_alt=${_rf_alt%.md}
    display_date "$_rf_base" "$_rf_sfx"

    # Split the file at its front-matter fences. Anything ABOVE the first one is
    # preserved untouched — that is where the licence header lives, and rewriting
    # the metadata must not disturb it.
    _rf_a=$(awk '/^---$/{n++} n==0{print}' "$_rf_f")
    _rf_k=$(awk '/^---$/{n++; next} n==1{print}' "$_rf_f")
    _rf_b=$(awk '/^---$/{n++; next} n>=2{print}' "$_rf_f")

    {
        [ -n "$_rf_a" ] && printf '%s\n' "$_rf_a" || :
        printf -- '---\n'
        printf 'alt: %s\n' "$_rf_alt"
        printf 'date: %s\n' "$DISP_DATE"
        # Everything that is not machine-maintained, in the order it was written.
        printf '%s\n' "$_rf_k" | sed -e '/^alt:/d' -e '/^date:/d' -e '/^lang:/d' -e '/^$/d'
        printf 'lang: %s\n' "$_rf_lang"
        printf -- '---\n'
        printf '%s\n' "$_rf_b"
    } > "$_rf_f.tmp"
    mv "$_rf_f.tmp" "$_rf_f"
}

clean_header() {
    if [ "$1" -eq 1 ]; then sed '/href="feed/d'; else cat -; fi
}

# The generated head + wordmark + language nav for one page. Unchanged in shape
# from the previous build; only the sibling lookup moved from .html to .md, since
# markdown is now what exists for a page to have a twin at all.
write_header() {
    _target_file=$1
    _lang_suffix=$2
    _page_title=${3-}
    _strip_rss=1
    _en_url='' _pt_url=''

    case $_target_file in
        *index.*|*blog.*) _strip_rss=0 ;;
    esac

    case $_target_file in
        blog/*)
            _id=$(printf '%s' "$_target_file" | cut -d/ -f2 | cut -c 1-13)
            _en_file=$(ls blog/"${_id}"*.md 2>/dev/null | grep -v '\.pt\.md' | head -n 1)
            _pt_file=$(ls blog/"${_id}"*.pt.md 2>/dev/null | head -n 1)
            [ -n "$_en_file" ] && _en_url="/${_en_file%.md}.html" || :
            [ -n "$_pt_file" ] && _pt_url="/${_pt_file%.md}.html" || :
            ;;
        *)
            case $_target_file in
                *.pt.html)
                    _pt_url="/$_target_file"
                    _en_url="/${_target_file%.pt.html}.html" ;;
                *.html)
                    _en_url="/$_target_file"
                    _pt_url="/${_target_file%.html}.pt.html" ;;
            esac
            ;;
    esac

    if [ ! -f ".${_en_url%/}" ] && [ "$_en_url" != "/" ]; then _en_url=""; fi
    if [ ! -f ".${_pt_url%/}" ]; then _pt_url=""; fi

    _home_url="/"
    if [ "$_lang_suffix" = ".pt" ]; then _home_url="/index.pt.html"; fi

    _feed_link=''
    if [ "$_strip_rss" -eq 0 ]; then
        _feed_link="<link rel=\"alternate\" title=\"alganet – Blog\" type=\"application/atom+xml\" href=\"feed${_lang_suffix}.xml\">"
    fi

    {
        echo '<!doctype html>'
        echo '<link rel=stylesheet href=/style.css?23>'
        echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
        if [ -n "$_page_title" ]; then echo "<title>$_page_title</title>"; else echo '<title>alganet</title>'; fi
        echo '<script defer src="/script.js?23"></script>'
        [ -n "$_feed_link" ] && echo "$_feed_link" || :
        # `<a href= />` is the site's own tag-omission style for the root link;
        # every other target is written plainly. Reproduced exactly, so the
        # generated pages stay byte-comparable with what was there before.
        if [ "$_home_url" = "/" ]
        then echo "<h1><a href= />alganet</a></h1>"
        else echo "<h1><a href=$_home_url>alganet</a></h1>"
        fi
    } | clean_header 0

    _link_en="English"
    if [ -n "$_en_url" ]; then
        _class=""
        [ -z "$_lang_suffix" ] && _class=" class=selected" || :
        _link_en="<a href=\"$_en_url\"$_class>English</a>"
    fi
    _link_pt="Português"
    if [ -n "$_pt_url" ]; then
        _class=""
        [ "$_lang_suffix" = ".pt" ] && _class=" class=selected" || :
        _link_pt="<a href=\"$_pt_url\"$_class>Português</a>"
    fi

    case $_target_file in
        *index.*) _sp=home ;;
        *blog.*)  _sp=blog ;;
        blog/*)   _sp="post:$(basename "${_target_file%.html}")" ;;
        *)        _sp=home ;;
    esac
    if [ "$_lang_suffix" = ".pt" ]; then _sl=pt; else _sl=en; fi
    _link_shell="<a class=shell href=\"/terminal/?p=${_sp}&amp;lang=${_sl}\" title=\"View this page in the terminal\">\$ <b></b></a>"

    echo "<nav class=lang>$_link_en $_link_pt $_link_shell</nav>"
}

# ── pass 1: refresh every post's front matter before anything reads it ────────
for _md in blog/*.md; do refresh_front_matter "$_md"; done

# ── pass 2: per language ─────────────────────────────────────────────────────
IFS=$_EOL

for LANG_SUFFIX in "" ".pt"
do
    INDEX_MD="index${LANG_SUFFIX}.md"
    INDEX_FILE="index${LANG_SUFFIX}.html"
    BLOG_MD="blog${LANG_SUFFIX}.md"
    BLOG_ALL="blog${LANG_SUFFIX}.html"
    [ -f "$INDEX_MD" ] || continue

    BLOG_TITLE="Blog"
    if [ "$LANG_SUFFIX" = ".pt" ]; then MORE_ENTRIES="Mais posts..."; else MORE_ENTRIES="More entries..."; fi

    if [ -z "$LANG_SUFFIX" ]
    then entries="$(find blog -maxdepth 1 -type f -name '*.md' ! -name '*.pt.md' | sort -rn)"
    else entries="$(find blog -maxdepth 1 -type f -name "*${LANG_SUFFIX}.md" | sort -rn)"
    fi

    # ── each post: its .html ─────────────────────────────────────────────────
    : > "$BLOG_MD.rows"
    for entry in $entries
    do
        base=${entry#blog/}; base=${base%.md}
        scan_md "$entry"
        display_date "$base" "$LANG_SUFFIX"

        write_header "blog/$base.html" "$LANG_SUFFIX" "$SCAN_TITLE" > "blog/$base.html"
        render_md "$entry" post "$LANG_SUFFIX" >> "blog/$base.html"
        echo "<hr class=end><p class=cc><a href=\"https://creativecommons.org/licenses/by-nc-sa/4.0/\">CC BY-NC-SA 4.0</a></p>" >> "blog/$base.html"

        printf -- '- [%s](/blog/%s.md) — *%s*\n' "$SCAN_TITLE" "$base" "$DISP_DATE" >> "$BLOG_MD.rows"
    done

    # ── the list page ────────────────────────────────────────────────────────
    {
        spdx_header "$(date +%Y)"
        printf '# %s\n\n' "$BLOG_TITLE"
        cat "$BLOG_MD.rows"
    } > "$BLOG_MD"

    write_header "$BLOG_ALL" "$LANG_SUFFIX" > "$BLOG_ALL"
    echo "" >> "$BLOG_ALL"
    render_md "$BLOG_MD" list "$LANG_SUFFIX" >> "$BLOG_ALL"

    # ── the home page: rewrite only its Blog list, in place ──────────────────
    # The run of blog links is unambiguous — those are the only lines in the file
    # pointing at /blog/ or /blog.md — so the About and Links sections around it
    # need no markers and stay exactly as written.
    {
        _seen_blog=0
        while IFS= read -r _l || [ -n "$_l" ]
        do
            case $_l in
                '- ['*'](/blog/'*|'- ['*'](/blog.md)'*|'- ['*'](/blog.pt.md)'*)
                    if [ "$_seen_blog" -eq 0 ]; then
                        _seen_blog=1
                        head -n 5 "$BLOG_MD.rows"
                        printf -- '- [*%s*](/blog%s.md)\n' "$MORE_ENTRIES" "$LANG_SUFFIX"
                    fi ;;
                *) printf '%s\n' "$_l" ;;
            esac
        done < "$INDEX_MD"
    } > "$INDEX_MD.tmp"
    mv "$INDEX_MD.tmp" "$INDEX_MD"
    rm -f "$BLOG_MD.rows"

    write_header "$INDEX_FILE" "$LANG_SUFFIX" > "$INDEX_FILE"
    render_md "$INDEX_MD" section "$LANG_SUFFIX" >> "$INDEX_FILE"

    # ── the feed ─────────────────────────────────────────────────────────────
    FEED_FILE="feed${LANG_SUFFIX}.xml"
    if [ "$LANG_SUFFIX" = ".pt" ]
    then FEED_SUBTITLE="Artigos técnicos sobre desenvolvimento de software"
    else FEED_SUBTITLE="Technical articles on software development"
    fi

    _latest=$(printf '%s' "$entries" | head -n 1)
    _lb=${_latest#blog/}
    _updated_iso="$(printf '%s' "$_lb" | cut -c 1-4)-$(printf '%s' "$_lb" | cut -c 6-7)-$(printf '%s' "$_lb" | cut -c 9-10)T$(printf '%s' "$_lb" | cut -c 12-13):00:00Z"

    {
        echo '<?xml version="1.0" encoding="utf-8"?>'
        echo '<feed xmlns="http://www.w3.org/2005/Atom">'
        echo "  <title>$(xml_escape "Blog — alganet")</title>"
        echo "  <subtitle>$(xml_escape "$FEED_SUBTITLE")</subtitle>"
        echo "  <id>tag:alganet.github.io,2025:feed${LANG_SUFFIX}</id>"
        echo '  <link href="https://alganet.github.io/" />'
        echo "  <link href=\"https://alganet.github.io/feed${LANG_SUFFIX}.xml\" rel=\"self\" />"
        echo "  <updated>$_updated_iso</updated>"
    } > "$FEED_FILE"

    for entry in $entries
    do
        base=${entry#blog/}; base=${base%.md}
        scan_md "$entry"
        _iso="$(printf '%s' "$base" | cut -c 1-4)-$(printf '%s' "$base" | cut -c 6-7)-$(printf '%s' "$base" | cut -c 9-10)T$(printf '%s' "$base" | cut -c 12-13):00:00Z"
        {
            echo '  <entry>'
            echo "    <title>$(xml_escape "$SCAN_TITLE")</title>"
            echo "    <id>tag:alganet.github.io,2025:${base}</id>"
            echo "    <link href=\"https://alganet.github.io/blog/${base}.html\" />"
            echo "    <updated>$_iso</updated>"
            echo "    <summary>$(xml_escape "$SCAN_EXCERPT")</summary>"
            echo '    <author>'
            echo '      <name>Alexandre Gomes Gaigalas</name>'
            echo '    </author>'
            echo '  </entry>'
        } >> "$FEED_FILE"
    done
    echo '</feed>' >> "$FEED_FILE"
done

unset IFS

# terminal/content.json — the files the browser loader fetches and mounts.
#
# Enumerated, never globbed: a `find . -name '*.md'` would sweep in README.md and
# mount the repo's own documentation as if it were a page.
{
    printf '[\n'
    _first=1
    for _t in index.md index.pt.md blog.md blog.pt.md $(ls blog/*.md | sort)
    do
        if [ "$_first" -eq 1 ]; then _first=0; else printf ',\n'; fi
        printf '  "%s"' "$_t"
    done
    printf '\n]\n'
} > terminal/content.json

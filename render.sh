#!/usr/bin/env sh

# render.sh — markdown records -> this site's HTML.
#
# Sourced by build.sh. A library, not a program: sourcing it defines functions and
# does nothing else, so the renderer can be exercised on one file without running a
# whole site build.
#
#   . ./render.sh
#   render_md path/to/post.md post ''      # -> HTML body on stdout
#
# It renders the BODY only — everything between the generated <nav> and the
# <hr class=end> footer. The header and footer stay build.sh's business.
#
# The records come from tuish's md.sh, which build.sh and terminal/index.sh both
# read. Neither form is derived from the other; they are two renderings of one
# parse, which is what keeps them from drifting.

# tuish's document modules, from the VENDORED copy — the same bytes the browser
# mounts, so the HTML cannot be produced by a different parser than the terminal
# runs. Both are standalone: sourcing them pulls in no compat.sh, so build.sh keeps
# its own shell options and its filename globbing.
. ./terminal/tuish/src/hl.sh
. ./terminal/tuish/src/md.sh

_RUS=$(printf '\037')

# ─── escaping ────────────────────────────────────────────────────────────────
# Prefix-scan rather than per-character, and & LAST-first: replacing & after < or >
# would re-escape the ampersands those produced.
_html_esc ()   # TEXT -> _HESC
{
	_he_r="$1" _HESC=''
	while test -n "$_he_r"
	do
		case $_he_r in
			*'&'*|*'<'*|*'>'*) : ;;
			*) _HESC="$_HESC$_he_r"; return 0 ;;
		esac
		_he_p=-1 _he_c=''
		case $_he_r in *'&'*) _he_t="${_he_r%%'&'*}"
			if test ${#_he_t} -lt $_he_p || test $_he_p -lt 0; then _he_p=${#_he_t} _he_c='&amp;'; fi ;;
		esac
		case $_he_r in *'<'*) _he_t="${_he_r%%'<'*}"
			if test ${#_he_t} -lt $_he_p || test $_he_p -lt 0; then _he_p=${#_he_t} _he_c='&lt;'; fi ;;
		esac
		case $_he_r in *'>'*) _he_t="${_he_r%%'>'*}"
			if test ${#_he_t} -lt $_he_p || test $_he_p -lt 0; then _he_p=${#_he_t} _he_c='&gt;'; fi ;;
		esac
		case $_he_c in
			'&amp;') _he_t="${_he_r%%'&'*}"; _he_r="${_he_r#*'&'}" ;;
			'&lt;')  _he_t="${_he_r%%'<'*}"; _he_r="${_he_r#*'<'}" ;;
			*)       _he_t="${_he_r%%'>'*}"; _he_r="${_he_r#*'>'}" ;;
		esac
		_HESC="$_HESC$_he_t$_he_c"
	done
	return 0
}

# Attribute values need the quote escaped as well as the three text entities;
# _html_esc alone would let a quote in an alt text close the attribute early.
_html_attr ()   # TEXT -> _HATTR
{
	_ha_r='' _ha_s=''
	_html_esc "$1"
	_ha_s="$_HESC"
	while :
	do
		case $_ha_s in
			*'"'*) _ha_r="$_ha_r${_ha_s%%'"'*}&quot;"; _ha_s="${_ha_s#*'"'}" ;;
			*) break ;;
		esac
	done
	_HATTR="$_ha_r$_ha_s"
	return 0
}

# A local .md target becomes its .html twin; anything with a scheme is left alone.
# "x.pt.md" -> "x.pt.html" falls out for free.
_html_href ()   # URL -> _HREF
{
	case $1 in
		*://*|mailto:*|'#'*) _HREF="$1" ;;
		*.md)                _HREF="${1%.md}.html" ;;
		*)                   _HREF="$1" ;;
	esac
	return 0
}

# ─── inline segments ─────────────────────────────────────────────────────────
# A link OPENS at its 'u' segment, which carries the href, and closes at the next
# plain 'x' or at the end of the payload. Because the URL arrives first the anchor
# can be written immediately — nothing needs buffering.
_html_inline ()   # PAYLOAD -> _HINL
{
	_hi_r="$1" _HINL='' _hi_in=0
	while test -n "$_hi_r"
	do
		_hi_s="${_hi_r%%${_RUS}*}"
		_hi_r="${_hi_r#*${_RUS}}"
		case $_hi_r in
			*${_RUS}*) _hi_t="${_hi_r%%${_RUS}*}"; _hi_r="${_hi_r#*${_RUS}}" ;;
			*)         _hi_t="$_hi_r"; _hi_r='' ;;
		esac

		case $_hi_s in
			u)
				if test "$_hi_in" -eq 1; then _HINL="$_HINL</a>"; fi
				_html_href "$_hi_t"; _html_attr "$_HREF"
				_HINL="$_HINL<a href=\"$_HATTR\">"
				_hi_in=1
				continue ;;
			x)
				if test "$_hi_in" -eq 1; then _HINL="$_HINL</a>"; _hi_in=0; fi ;;
		esac

		_html_esc "$_hi_t"
		case $_hi_s in
			s) _HINL="$_HINL<strong>$_HESC</strong>" ;;
			e) _HINL="$_HINL<em>$_HESC</em>" ;;
			m) _HINL="$_HINL<code>$_HESC</code>" ;;
			*) _HINL="$_HINL$_HESC" ;;
		esac
	done
	if test "$_hi_in" -eq 1; then _HINL="$_HINL</a>"; fi
	return 0
}

# ─── code segments ───────────────────────────────────────────────────────────
# The reverse of the old build.sh _cmap: one <span class="code-*"> per token, using
# the classes style.css already defines.
_html_code ()   # PAYLOAD -> _HCODE
{
	_hc_r="$1" _HCODE=''
	while test -n "$_hc_r"
	do
		_hc_s="${_hc_r%%${_RUS}*}"
		_hc_r="${_hc_r#*${_RUS}}"
		case $_hc_r in
			*${_RUS}*) _hc_t="${_hc_r%%${_RUS}*}"; _hc_r="${_hc_r#*${_RUS}}" ;;
			*)         _hc_t="$_hc_r"; _hc_r='' ;;
		esac
		_html_esc "$_hc_t"
		# Whitespace carries no colour, so wrapping it in a span is pure markup
		# weight — and code blocks are where this site's HTML is heaviest.
		case $_hc_t in
			*[!\ ]*) : ;;
			*) _HCODE="$_HCODE$_HESC"; continue ;;
		esac
		case $_hc_s in
			S) _HCODE="$_HCODE<span class=\"code-string\">$_HESC</span>" ;;
			C) _HCODE="$_HCODE<span class=\"code-comment\">$_HESC</span>" ;;
			N) _HCODE="$_HCODE<span class=\"code-number\">$_HESC</span>" ;;
			O) _HCODE="$_HCODE<span class=\"code-punctuation\">$_HESC</span>" ;;
			F) _HCODE="$_HCODE<span class=\"code-function\">$_HESC</span>" ;;
			K) _HCODE="$_HCODE<span class=\"code-keyword\">$_HESC</span>" ;;
			# style.css gives ins/del their own "+ "/"- " via ::before, so the
			# marker AND its separating space come off here — leaving either behind
			# would print the marker twice or indent every changed line by one.
			+) _hc_x="${_HESC#+}"; _HCODE="$_HCODE<ins>${_hc_x# }</ins>" ;;
			-) _hc_x="${_HESC#-}"; _HCODE="$_HCODE<del>${_hc_x# }</del>" ;;
			*) _HCODE="$_HCODE$_HESC" ;;
		esac
	done
	return 0
}

# ─── block runs ──────────────────────────────────────────────────────────────
# Wrappers (<ul>, <pre>, <blockquote>, <figure>) open on the first record of a kind
# and close when the kind changes. The reader does the same thing to bracket its
# code cards, so both sides agree on where a block ends without a closing record.
_html_open ()   # KIND
{
	if test "$_H_RUN" = "$1"; then return 0; fi
	_html_close
	_H_RUN="$1"
	case $1 in
		ul)     printf '<ul>\n' ;;
		ol)     printf '<ol>\n' ;;
		blog)   printf '<ul class=blog>\n' ;;
		pre)    printf '<pre class="codeblock"><code>'; _H_FIRSTC=1 ;;
		quote)  printf '<blockquote class="review">\n' ;;
	esac
	return 0
}

_html_close ()
{
	case $_H_RUN in
		ul)     printf '</ul>\n' ;;
		ol)     printf '</ol>\n' ;;
		blog)   printf '</ul>\n' ;;
		pre)    printf '</code></pre>\n' ;;
		quote)  printf '</blockquote>\n' ;;
		figure) printf '</figure>\n' ;;
	esac
	_H_RUN=''
	return 0
}

# ─── the sink ────────────────────────────────────────────────────────────────
# One sink, two consumers, chosen by _R_MODE: the HTML renderer, and a scanner that
# just collects a page's title and excerpt. md.sh calls tuish_md_emit and knows
# nothing about either.
tuish_md_emit ()
{
	case $_R_MODE in
		scan) _scan_emit "$1" "$2" ;;
		*)    _html_emit "$1" "$2" ;;
	esac
}

# ─── the scanning sink ───────────────────────────────────────────────────────
# Pulls out what the indexes and feeds need — the title, and a plain-text excerpt
# from the opening paragraphs. Reading it through the same parser is the point:
# a feed summary can never describe a different document than the page does.
_seg_text ()   # PAYLOAD -> _STEXT, styles dropped, a link's URL left out
{
	_st_r="$1" _STEXT=''
	while test -n "$_st_r"
	do
		_st_s="${_st_r%%${_RUS}*}"
		_st_r="${_st_r#*${_RUS}}"
		case $_st_r in
			*${_RUS}*) _st_t="${_st_r%%${_RUS}*}"; _st_r="${_st_r#*${_RUS}}" ;;
			*)         _st_t="$_st_r"; _st_r='' ;;
		esac
		if test "$_st_s" != u; then _STEXT="${_STEXT}${_st_t}"; fi
	done
	return 0
}

_scan_emit ()
{
	case $1 in
		t) SCAN_TITLE="$2" ;;
		p)
			if test "${#SCAN_EXCERPT}" -lt 300
			then _seg_text "$2"; SCAN_EXCERPT="$SCAN_EXCERPT $_STEXT"
			fi ;;
	esac
	return 0
}

# scan_md FILE -> SCAN_TITLE SCAN_EXCERPT SCAN_DATE SCAN_AUTHOR SCAN_ALT
scan_md ()
{
	_R_MODE=scan SCAN_TITLE='' SCAN_EXCERPT=''
	TUISH_MD_BYLINE=0 TUISH_MD_ENTRIES=0
	tuish_md_file "$1" post
	tuish_md_meta date;   SCAN_DATE="$TUISH_MD_META"
	tuish_md_meta author; SCAN_AUTHOR="$TUISH_MD_META"
	tuish_md_meta alt;    SCAN_ALT="$TUISH_MD_META"
	SCAN_EXCERPT="${SCAN_EXCERPT# }"
	if test "${#SCAN_EXCERPT}" -gt 300
	then
		SCAN_EXCERPT="$(printf '%s' "$SCAN_EXCERPT" | cut -c 1-300)"
		SCAN_EXCERPT="${SCAN_EXCERPT% *}..."
	fi
	return 0
}

_html_emit ()
{
	_h_s="$1" _h_p="$2"

	case $_h_s in
		f) return 0 ;;                       # front matter drives the page, not the body
		c) : ;;
		# 'cb' closes any open block so the next 'c' starts a fresh one. Without it
		# two back-to-back fences would weld into a single card, since their 'c'
		# records are contiguous.
		cb|qb) _html_close; return 0 ;;
		*) if test "$_H_RUN" = pre; then _html_close; fi ;;
	esac

	case $_h_s in
		t)
			_html_close
			_html_esc "$_h_p"
			printf '<h2>%s</h2>\n' "$_HESC"
			;;
		i)
			# The byline's CONTENT comes from front matter, the same source the
			# terminal reads; only the markup is this renderer's own.
			tuish_md_meta author; _h_a="$TUISH_MD_META"
			tuish_md_meta date;   _h_d="$TUISH_MD_META"
			_html_esc "$_h_a"; _h_a="$_HESC"
			_html_esc "$_h_d"; _h_d="$_HESC"
			printf '<p class=info><em>%s</em> – <em>%s</em></p>\n' "$_h_a" "$_h_d"
			;;
		h2|h3|h4|h5)
			_html_close
			_html_esc "$_h_p"
			printf '<%s>%s</%s>\n' "$_h_s" "$_HESC" "$_h_s"
			;;
		p)
			_html_close
			_html_inline "$_h_p"
			printf '<p>%s</p>\n' "$_HINL"
			;;
		q)
			_html_open quote
			_html_inline "$_h_p"
			printf '<p>%s</p>\n' "$_HINL"
			;;
		b)
			_html_open ul
			_html_inline "$_h_p"
			printf '<li>%s</li>\n' "$_HINL"
			;;
		n)
			_html_open ol
			_html_inline "$_h_p"
			printf '<li>%s</li>\n' "$_HINL"
			;;
		c)
			# The separator goes BEFORE each line but the first, so the block ends
			# flush against </code></pre>. A newline there is not cosmetic: inside a
			# <pre> it renders as a trailing blank line in the code card.
			_html_open pre
			_html_code "$_h_p"
			if test "$_H_FIRSTC" -eq 1
			then printf '%s' "$_HCODE"; _H_FIRSTC=0
			else printf '\n%s' "$_HCODE"
			fi
			;;
		g)
			_html_close
			_h_a="${_h_p%%${_RUS}*}"
			_h_d="${_h_p#*${_RUS}}"
			_html_attr "$_h_a"; _h_a="$_HATTR"
			_html_esc "$_h_d"; _h_d="$_HESC"
			# An image before any prose is the post's header image.
			if test "$_H_BODY" -eq 0
			then printf '<figure class="header"><img src=%s alt="%s">\n' "$_h_d" "$_h_a"
			else printf '<figure><img src=%s alt="%s">\n' "$_h_d" "$_h_a"
			fi
			_H_RUN=figure
			;;
		d)
			_html_esc "$_h_p"
			if test "$_H_RUN" = figure
			then printf '<figcaption>%s</figcaption>\n' "$_HESC"; _html_close
			else printf '<p class=cap>%s</p>\n' "$_HESC"
			fi
			;;
		r)
			_html_close
			printf '<hr>\n'
			;;
		e)
			_html_open blog
			_h_b="${_h_p%%${_RUS}*}"
			_h_t="${_h_p#*${_RUS}}"
			_h_d="${_h_t#*${_RUS}}"
			_h_t="${_h_t%%${_RUS}*}"
			_html_esc "$_h_t"; _h_t="$_HESC"
			_html_esc "$_h_d"; _h_d="$_HESC"
			if test "$_h_b" = '@blog'
			then printf '<li><a href="/blog%s.html"><em>%s</em></a></li>\n' "$RENDER_LANG" "$_h_t"
			else printf '<li><a href="/blog/%s.html">%s</a> <em>%s</em></li>\n' "$_h_b" "$_h_t" "$_h_d"
			fi
			;;
	esac

	case $_h_s in
		t|i|f) : ;;
		*) _H_BODY=1 ;;
	esac
	return 0
}

# _r_setup MODE — the three page shapes this site has.
#
#   post     the first '#' is the page title; no entry inference
#   section  every '#' is a section heading; entries inferred  (the home page)
#   list     the first '#' is the page title; entries inferred (the blog index)
#
# Title-ness and entry-ness are independent, which 'list' is the proof of: the blog
# index wants both. Deriving entries from the mode alone gave it a section heading
# where the reader expects a page title.
_r_setup ()
{
	case ${1:-post} in
		section) _R_MDMODE=section; TUISH_MD_ENTRIES=1 ;;
		list)    _R_MDMODE=post;    TUISH_MD_ENTRIES=1 ;;
		*)       _R_MDMODE=post;    TUISH_MD_ENTRIES=0 ;;
	esac
	return 0
}

# render_md FILE [MODE] [LANG]
#   LANG  '' for English, '.pt' for Portuguese (only used for the list-page link)
render_md ()
{
	_R_MODE=html _H_RUN='' _H_BODY=0 _H_FIRSTC=1
	RENDER_LANG="${3-}"
	TUISH_MD_BYLINE=1
	_r_setup "${2:-post}"
	tuish_md_file "$1" "$_R_MDMODE"
	_html_close
	return 0
}

#!/usr/bin/env sh

set -eu

get_line () { read -r line || test -n "$line"; }

_EOL="
"

# Clean up any leftover temporary files
rm -f tmp_*.html

write_header() {
    _target_file=$1
    _lang_suffix=$2
    _header_file=$(ls tmp_${_lang_suffix}_*'_Header_section.html' | head -n 1)
    
    _en_url=""
    _pt_url=""

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

    cat "$_header_file" | sed "s|<h1><a href=/>|<h1><a href=$_home_url>|g"
    
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

    echo "<nav class=lang>$_link_en $_link_pt</nav>"
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
        echo "$line" >> "tmp_${LANG_SUFFIX}_${order}_${section}_section.html"
    done < "./$INDEX_FILE"

    # Rebuild the full blog and latest posts section
    blog_section_file=$(ls tmp_${LANG_SUFFIX}_*'_Blog_section.html' | head -n 1)
    
    if [ "$LANG_SUFFIX" = ".pt" ]; then
        BLOG_TITLE="Blog"
        MORE_ENTRIES="Mais entradas..."
    else
        BLOG_TITLE="Blog"
        MORE_ENTRIES="More entries..."
    fi

    echo "<h2>$BLOG_TITLE</h2>" > "$BLOG_ALL"
    echo '<ul>' >> "$BLOG_ALL"

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
        
        write_header "$entry" "$LANG_SUFFIX" > "tmp_entry.html"
        cat tmp_entry.html > "${entry}"
        echo "$content" >> "${entry}"
        echo "<hr class=end><p class=cc><a href=\"https://creativecommons.org/licenses/by-nc-sa/4.0/\">CC BY-NC-SA 4.0</a></p>" >> "${entry}"
        echo "<li><a href=\"/${entry}\">$title</a> — <em>$date</em></li>" >> "$BLOG_ALL"
        rm tmp_entry.html
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

    # Puts back the index file with the updated blog contents
    printf %s '' > "$INDEX_FILE"
    part=0
    while test $part -lt $((order + 1))
    do
        filename=$(ls tmp_${LANG_SUFFIX}_"${part}"*'_section.html' | head -n 1)
        if echo "$filename" | grep -q "_Header_section.html"; then
            write_header "$INDEX_FILE" "$LANG_SUFFIX" >> "$INDEX_FILE"
        else
            while get_line
            do echo "$line" >> "$INDEX_FILE"
            done < "$filename"
        fi
        rm "$filename"
        part=$((part + 1))
    done
done

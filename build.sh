#!/usr/bin/env sh

set -eu

get_line () { read -r line || test -n "$line"; }

_EOL="
"

# Breaks apart index.html into sections
line= order=0 section=Header
while get_line
do
    case $line in
        '<h2>'*)
            section="${line#'<h2>'}"
            section="${section%'</h2>'*}"
            order=$((order + 1))
            ;;
    esac
    echo "$line" >> "${order}_${section}_section.html"
done < ./index.html

# Rebuild the full blog and latest posts section
blog_section=$(echo *'_Blog_section.html')
blog_all="blog.html"
echo '<h2>Blog</h2>' > $blog_all
echo '<ul>' >> $blog_all
entries="$(find blog -type f | sort -rn)"
entry= title= date= content= max_latest=5
for entry in $entries
do
    date="${entry#blog/}"
    date="${date%${date#??????????}}"
    while get_line
    do
        case $line in
            '<h2>'*)
                title="${line#'<h2>'}"
                title="${title%'</h2>'*}"
                ;;
            '<p class=info'*)
                line="<p class=info><em>Alexandre Gomes Gaigalas</em> – <em>$date</em>"' <a href="https://creativecommons.org/licenses/by-nc-nd/4.0/">Licensed under CC BY-NC-ND 4.0 <img src="https://mirrors.creativecommons.org/presskit/icons/cc.svg"><img src="https://mirrors.creativecommons.org/presskit/icons/by.svg"><img src="https://mirrors.creativecommons.org/presskit/icons/nc.svg"><img src="https://mirrors.creativecommons.org/presskit/icons/nd.svg"></a></p>'
                content="$_EOL<h2>$title</h2>"
                ;;
            '<hr class=end'*)
                break
                ;;
        esac
        content="$content$_EOL$line"
    done < $entry
    cat $(echo *'_Header_section.html') > ${entry}
    echo "$content" >> ${entry}
    echo "<hr class=end><p></p>" >> ${entry}
    echo "<li><a href=\"${entry}\">$title</a> — <em>$date</em></li>" >> $blog_all
done

cat $blog_all | head -n 7 > $blog_section
echo '</ul>' >> $blog_all
echo "$(cat $(echo *'_Header_section.html') $blog_all)" > $blog_all

echo "<li><a href=\"blog.html\"><em>More entries...</em></a></li>" >> $blog_section
echo '</ul>' >> $blog_section

# Puts back index.html with the updated blog contents
printf %s '' > index.html
part=0
while test $part -lt $((order + 1))
do
    set +f
    set -- "$part"*'_section.html'
    set -f
    while get_line
    do echo "$line" >> index.html
    done < "$1"
    rm "$1"
    part=$((part + 1))
done

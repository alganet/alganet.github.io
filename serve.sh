#!/usr/bin/env sh
# serve.sh

# Expansion on zsh
command -v setopt 2>&1 >/dev/null && setopt SH_WORD_SPLIT
# POSIX on bash
export POSIXLY_CORRECT=1

# Lists files and folders as HTML
# Uses a root directory $1 and relative directory $2
lshtml () 
{
	rootdir="${1}"
	reldir="${2}"
	target="${rootdir}/${reldir}"
	target="${target%*/}"
	target="${target%%\?*}"

	# If the target is a directory, prefer an index file for content-type and direct serving
	if [ -d "${target}" ]; then
		if [ -f "${target}/index.html" ]; then
			header_target="${target}/index.html"
		elif [ -f "${target}/index.htm" ]; then
			header_target="${target}/index.htm"
		else
			header_target="${target}"
		fi
	else
		header_target="${target}"
	fi

	lshtml_header "${reldir}" "${header_target}"
	lshtml_item   "${reldir}" "${target}"
	lshtml_footer "${reldir}" "${target}"

}

lshtml_cat () ( cat "$@" )

lshtml_item ()
{
	reldir="${1}"
	target="${2}"

	if [ -d "${target}" ]; then
		# Serve index file if present, else list directory
		if [ -f "${target}/index.html" ]; then
			lshtml_file "${reldir}" "${target}/index.html"
		elif [ -f "${target}/index.htm" ]; then
			lshtml_file "${reldir}" "${target}/index.htm"
		else
			lshtml_dir "${reldir}" ${target}
		fi
	elif [ -f "${target}" ]; then
		lshtml_file "${reldir}" ${target}
	fi
}

lshtml_file ()
{
	reldir="${1}"
	target="${2}"

	lshtml_cat "${target}"
}

lshtml_dir ()
{
	reldir="${1}"
	target="${2}"

	for file in ${target}/*; do
		lshtml_diritem "${reldir}" "${file}"
	done
}

lshtml_diritem ()
{
	  reldir="${1}"
	    file="${2}"
	filepath="${reldir}$(basename "${file}")"

	if [ -d "${file}" ]; then
		filepath="${filepath}/"
	fi

	lshtml_link "${filepath}"
}

lshtml_link ()
{
	filepath="${1}"
	echo "<li><a href='${filepath}'>${filepath}</a></li>"
}

lshtml_header ()
{
    CR="$(printf '\r')"
	reldir="${1}"
	target="${2}"

    case $target in
        *.html|*.htm)
            CONTENT_TYPE="Content-Type: text/html; charset=UTF-8"
            ;;
        *.css)
            CONTENT_TYPE="Content-Type: text/css; charset=UTF-8"
            ;;
        *.js)
            CONTENT_TYPE="Content-Type: application/javascript"
            ;;
        *.png)
            CONTENT_TYPE="Content-Type: image/png"
            ;;
        *.jpg|*.jpeg)
            CONTENT_TYPE="Content-Type: image/jpeg"
            ;;
        *.gif)
            CONTENT_TYPE="Content-Type: image/gif"
            ;;
        *)
            CONTENT_TYPE="Content-Type: text/plain"
            ;;
    esac

	lshtml_cat <<-MSG
		HTTP/1.1 200 OK
		Connection: close
		${CONTENT_TYPE}
		${CR}
	MSG
}

lshtml_footer ()
{
	CR="$(printf '\r')"

	lshtml_cat <<-MSG
		${CR}
		${CR}
	MSG
}

# Listens once to a HTTP request
# Calls $1 with CGI env vars, uses $2 for connection
# and $3 for buffer.
# Depends on cgirequest.sh
httpserver () 
{
	 callback="${1}"
	     fall="$(httpserver_netcat 8080 10)"
	connector="${2:-$fall}"
	   buffer="${3}"

	httpserver_export "${callback}"
	${connector} < "${buffer}" | httpserver_cgi "${callback}" > "${buffer}"
}

httpserver_export () 
{
	export      SERVER_SOFTWARE="Mosai HTTP/1.0"
	export          SERVER_NAME="localhost"
	export          SERVER_PORT="8080"
	export    GATEWAY_INTERFACE="CGI/1.1"
	export          SCRIPT_NAME="${callback}"
	export          REMOTE_ADDR="127.0.0.1"
}

httpserver_netcat () ( echo "nc -l $1 $2" )
httpserver_cgi    () ( cgirequest "$@" )

# Listens to httpserver using a temporary buffer
# Calls $1 with CGI env vars, uses $2 for connection.
# Depends on fifobuffer.sh, httpserver.sh, trap, mktemp and rm
httpfifo ()
{
	callback="${1}"
	buffer_dir="$(httpfifo_mktemp -d -t "XXXhtml")"
	connector="${2}"
	buffer=$(httpfifo_buffer "${buffer_dir}")
	httpfifo_start  "${buffer_dir}"
	httpfifo_listen "${callback}" "${connector}" "${buffer}"
	httpfifo_end    "${buffer_dir}"
	exit
}

httpfifo_mktemp     () ( mktemp     "$@" )
httpfifo_buffer     () ( fifobuffer "$@" )
httpfifo_httpserver () ( httpserver "$@" )
httpfifo_end        () ( rm -rf "${1}" )
httpfifo_start      () ( trap 'httpfifo_abort "${1}"' 2 )

httpfifo_listen ()
{
	while true; do
		httpfifo_httpserver "$@"
	done
}

httpfifo_abort ()
{
	buffer_dir="${1}"

	rm -rf "${buffer_dir}"
	echo "Bye!" 1>&2

	exit
}
# Creates a fifo buffer in a ${1} dir
# Depends on od, tr and mkfifo
fifobuffer () 
{
	buffer_dir="${1}"
	buffer_name="$(fifobuffer_random | fifobuffer_filename)"
	buffer_file="${buffer_dir}/${buffer_name}"
	
	fifobuffer_mkfifo "${buffer_file}"
	echo "${buffer_file}"
}

fifobuffer_filename () ( tr " " "-" | tr -d '\n' )
fifobuffer_random   () ( od -N4 -tu /dev/random )
fifobuffer_mkfifo   () ( mkfifo "$@" )

# Parses a HTTP message from stdin.
# Calls ${1} with CGI env vars.
# Depends on httpserver.sh, cut, tr and sed
cgirequest ()
{
	cgirequest_callback "${1:-cat}"
}

cgirequest_callback ()
{
	export             SELF="${1}"
	export    REQUEST_METHOD=""
	export       REQUEST_URI=""
	export   SERVER_PROTOCOL=""
	export      REQUEST_DATA=""
	export      QUERY_STRING=""
	export         PATH_INFO=""

	read -r REQUEST_METHOD REQUEST_URI SERVER_PROTOCOL
	QUERY_STRING="$(echo "$REQUEST_URI" | cut -d "?" -f2-)"
	PATH_INFO="$(echo "$REQUEST_URI" | cut -d "?" -f1)"
	cgirequest_headers
	cgirequest_data
	httpserver_export "${SELF}"	

	${SELF}
}

cgirequest_headerspec () 
{ 
	echo "${1}" | cut -d":" -f1 | tr 'a-z' 'A-Z' | tr '-' '_' 
}

cgirequest_headerval () 
{ 
	echo "${1}" | cut -d":" -f2 | tr -d '\r' | tr -d '\n' |\
				  sed -e 's/^ *//' -e 's/ *$//' 
}

cgirequest_headers ()
{
	    CR="$(printf '\r')"
	header=""

	while read -r header && [ ! "${header}" = "${CR}" ]; do
		spec="$(cgirequest_headerspec "${header}")"
		 val="$(cgirequest_headerval  "${header}")"

		export "HTTP_${spec}=${val}"
	done
}

cgirequest_data ()
{
	request=""

	if [ ! -z "${HTTP_CONTENT_LENGTH}" ]; then
		read -n $HTTP_CONTENT_LENGTH request
	fi	

	export REQUEST_DATA="${request}"
}

cgirequest_ok ()
{
	CR="$(printf '\r')"

	cat <<-MSG
		HTTP/1.1 200 OK
		Connection: close
		Content-Type: text/html
		${CR}
		200 OK
	MSG
}




myapplication () 
{
        # lshtml lists folders and files as HTML
	lshtml ${PWD} ${REQUEST_URI}
        # show POST data
	#echo ${REQUEST_DATA}
        # headers as CGI env vars
	#echo ${HTTP_ACCEPT}

}
# Listen to netcat connector (use 127.0.0.1:8081 on busybox)
httpfifo myapplication "nc -vl 127.0.0.1 ${1:-9999}"
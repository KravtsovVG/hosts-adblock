#!/bin/sh

export DNSMASQ_CONFIG="${1:-/etc/dnsmasq.conf}"

export DIR="$(dirname "$0")"
export HOSTS_DIR="${DIR}/hosts.d"
export IP4_ADDR="255.255.255.255"
export IP6_ADDR="ffff::ffff"

export URLS=""
export URLS="${URLS} https://adaway.org/hosts.txt"
export URLS="${URLS} http://winhelp2002.mvps.org/hosts.txt"
export URLS="${URLS} http://hosts-file.net/ad_servers.txt"
export URLS="${URLS} https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
export URLS="${URLS} https://www.malwaredomainlist.com/hostslist/hosts.txt"

_append_config() {
    local CONTENT="$1"
    local CONFIG="$2"

    if ! grep -q "${CONTENT}" "${CONFIG}" ; then
        _log "Adding ${CONTENT} to ${CONFIG}"
        echo "${CONTENT}" >>"${CONFIG}"
    fi
}

# _download URL FILENAME
#
# Download the given URL and save it in the current directory as FILENAME.
_download() {
    local URL="$1"
    local FILENAME="$2"

    if curl -s --compressed --head "${URL}" | grep -q 'HTTP/.*200' ; then
        _log "Downloading/updating ${URL}"
        curl -s --compressed -z "${FILENAME}" -o "${FILENAME}" "${URL}"
    fi
}

# _log MESSAGE
#
# Write MESSAGE to syslog.
_log() {
    echo "$1"
    # logger -t "$0" "$1"
}

# _process FILENAME
_process() {
    local FILENAME="$1"

    if [ -s "${FILENAME}" ] && ( [ "${FILENAME}" -nt "${HOSTS_DIR}/${FILENAME}" ] || ! [ -r "${HOSTS_DIR}/${FILENAME}" ]); then
        _log "Processing ${FILENAME}"
        mkdir -p "${HOSTS_DIR}"
        cat "${FILENAME}" |
        grep -v -i -e "^#" -e "localhost" -e "${HOSTNAME}" |
        awk -v RS='[\n\r]+' -vIP4_ADDR="${IP4_ADDR}" -vIP6_ADDR="${IP6_ADDR}" '
            /^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|::[0-9a-fA-F]+)\s+/ {
                printf("%-16s %s\n", IP4_ADDR, $2)
                printf("%-16s %s\n", IP6_ADDR, $2)
            }' >"${HOSTS_DIR}/${FILENAME}"
    else
        _log "Processing ${FILENAME} not required, not updated"
    fi
}

# _url_filename URL
_url_filename() {
    local URL="$1"

    echo "${URL}" |
    sed -e 's|?.*||g' -e 's|[.:/\#*+"(){}]\+|_|g' |
    tr '[A-Z]' '[a-z]'
}

cd "${DIR}"

for URL in ${URLS} ; do
    _download "${URL}" "$(_url_filename "${URL}")"
    _process "$(_url_filename "${URL}")"
done

if [ -w "${DNSMASQ_CONFIG}" ] ; then
    _append_config "addn-hosts=${HOSTS_DIR}" "${DNSMASQ_CONFIG}"
fi

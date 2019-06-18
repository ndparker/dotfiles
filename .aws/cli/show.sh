#!/usr/bin/env bash
set -e

if [ -f ~/.aws/role.config ]; then
    . ~/.aws/role.config
fi


die() {
    [ $# -eq 0 ] || echo "${@}" >&2
    exit 1
}

usage() {
    base="$(basename "${0}")"
    echo "${base} <role>  - as role" >&2
    exit 2
}

############################################################################
# Defaults and presets
############################################################################
 
# "user" is a special role (no role, plain user)
role_user=

# Default role, if no role is given. If unset or empty it defaults to "user"
default_role="${default_role:-user}"


############################################################################
# Parse commandline (see usage)
#
# Input: $@
# Output: $role (expanded if possible), $token
############################################################################
role=
role_alias=

[ $# -gt 0 ] || set -- "${default_role}"

role="${1}"; shift

[ $# -eq 0 ] || usage

if [ -n "${role}" ]; then
    var="role_${role//-/_}"
    if [ "${!var:+x}" = x -o "${var}" = "role_user" ]; then
        role_alias="${role}"
        role="${!var}"
    fi
fi

if [ "${role/:role}" != "${role}" ]; then
    url='https://signin.aws.amazon.com/switchrole?account='
    url="${url}$( cut -d: -f5 <<<"${role}" )&roleName="
    url="${url}$( cut -d/ -f2 <<<"${role}" )"
    if [ -n "${role_alias}" ]; then
        dn="$(tr A-Z a-z <<<"${role_alias}")"
        if [ ${#dn} -le 3 ]; then
            dn="$(tr a-z A-Z <<<"${dn}")"
        else
            dn="$(tr a-z A-Z <<<"${dn:0:1}")${dn:1}"
        fi
        url="${url}&displayName=${dn}"
    fi
    echo "${url}"
fi

# vim: nowrap

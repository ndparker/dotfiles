#!/usr/bin/env bash
set -e

# Config
role_a="hahaha"
role_b="huhuhu"


die() {
    [ $# -eq 0 ] || echo "${@}" >&2
    exit 1
}

usage() {
    base="$(basename "${0}")"
    echo "${base}              - as default role" >&2
    echo "${base} <role>       - as role" >&2
    echo "${base} <role> <mfa> - as role with mfa" >&2
    echo "${base} <mfa>        - as default role with mfa" >&2
    echo "${base} <mfa> <role> - as role with mfa" >&2
    exit 2
}

role_user=
default_role="${default_role:-user}"
role=
token=

[ $# -gt 0 ] || set -- "${default_role}"
if echo "${1}" | grep -q '^[0-9][0-9][0-9][0-9][0-9][0-9]$'; then
    token="${1}"; shift
    [ $# -gt 0 ] || set -- "${default_role}"
fi
role="${1}"; shift

if [ -z "${token}" -a $# -gt 0 ]; then
    if echo "${1}" | grep -q '^[0-9][0-9][0-9][0-9][0-9][0-9]$'; then
        token="${1}"; shift
    fi
fi
[ $# -eq 0 ] || usage

if [ -n "${role}" ]; then
    var="role_${role}"
    [ "${!var:+x}" != x ] || role="${!var}"
fi

echo "${token}"
echo "${role}"

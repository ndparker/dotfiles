#!/usr/bin/env bash
set -e

die() {
    [ $# -eq 0 ] || echo "${@}" >&2
    exit 1
}

user="$(aws sts get-caller-identity --query 'Arn' --output text)"
if [ $? -eq 0 ]; then
    echo "${user}"
    if [ "${user/:assumed-role}" != "${user}" ]; then
        url='https://signin.aws.amazon.com/switchrole?account='
        url="${url}$( cut -d: -f5 <<<"${user}" )&roleName="
        url="${url}$( cut -d/ -f2 <<<"${user}" )"
        echo "${url}"
    fi
fi

# vim: nowrap

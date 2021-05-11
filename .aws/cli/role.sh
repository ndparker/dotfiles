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
    echo "${base}              - as default role" >&2
    echo "${base} <role>       - as role" >&2
    echo "${base} <role> <mfa> - as role with mfa" >&2
    echo "${base} <mfa>        - as default role with mfa" >&2
    echo "${base} <mfa> <role> - as role with mfa" >&2
    exit 2
}

############################################################################
# Defaults and presets
############################################################################
 
# "user" is a special role (no role, plain user)
role_user=

# Default role, if no role is given. If unset or empty it defaults to "user"
default_role="${default_role:-user}"

# Force MFA input? If non-empty: yes. Default: false
[ "${mfa_force:+x}" = x ] || mfa_force=

# Who is this user?
arn="$(aws sts get-caller-identity --profile user --output text --query 'Arn')"

# Who am I right now?
iam="$(aws sts get-caller-identity --output text --query 'Arn' 2>/dev/null || true)"

# Config file for profile settings
filename=~/.aws/config

# Tempfile cleanup atexit
tmpfile=
cleanup() {
    local x

    x="${tmpfile}"
    tmpfile=
    if [ -n "${x}" ]; then
        rm -f -- "${x}"
    fi
}
trap cleanup EXIT


############################################################################
# Parse commandline (see usage)
#
# Input: $@
# Output: $role (expanded if possible), $token
############################################################################
role=
token=
role_alias=

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
    var="role_${role//-/_}"
    if [ "${!var:+x}" = x -o "${var}" = "role_user" ]; then
        role_alias="${role}"
        role="${!var}"
    fi
fi


############################################################################
# Prepare config file
#
# Input: $filename
############################################################################
prepare_config() {(
    set +x
    rm -f -- "${filename}.tmp.default"
    touch -- "${filename}.tmp.default"

    if [ -e "${filename}" ]; then
        (
            pro=
            while read line; do
                if [ "${line:0:1}" = "[" ]; then
                    pro="${line}"
                fi
                if [ "${pro}" = "[profile default]" -o "${pro}" = "[default]" ]; then
                    if [ "${pro}" != "${line}" ]; then
                        key="$(echo "${line%%=*}" | awk '{$1=$1};1')"
                        if [ -n "${key}" -a "${key}" != 'role_arn' -a "${key}" != 'source_profile' ]; then
                            echo "${line}" >>"${filename}.tmp.default"
                        fi
                    fi
                else
                    echo "${line}"
                fi
            done <"${filename}"
        ) >"${filename}.tmp"

        if [ -s "${filename}.tmp.default" ]; then
            echo "[default]" >>"${filename}.tmp"
            cat <"${filename}.tmp.default" >>"${filename}.tmp"
        fi
        rm -f -- "${filename}.tmp.default"

        mv -f -- "${filename}.tmp" "${filename}"
    fi
)}

############################################################################
# Login
#
# Input: $1 (token), $mfa_force
# Output: ~/.aws/{config,credentials}
############################################################################
conf=( aws configure set --profile default )
do_login() {
    local token
    token="${1}"; shift

    # Ask for MFA if needed
    if [ -z "${token}" -a -n "${mfa_force}" ]; then
        echo -n "MFA: "
        read token
    fi

    # Build command
    cmd=( aws --profile user sts get-session-token )
    if [ -n "${token}" ]; then
        # reset iam, because it doesn't matter. We have a token, we will apply.
        iam=
        cmd=( "${cmd[@]}"
              --serial-number "${arn/:user\//:mfa/}"
              --token-code "${token}" )
    fi
    cmd=( "${cmd[@]}"
          --output text
          --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' )

    tmpfile="$(mktemp)"
    (
        set +e
        set -o pipefail
        "${cmd[@]}" 2>"${tmpfile}" | (
            read key secret session
            "${conf[@]}" aws_access_key_id "${key}"
            "${conf[@]}" aws_secret_access_key "${secret}"
            "${conf[@]}" aws_session_token "${session}"
        )
    )

    if [ $? -ne 0 -a -z "${token}" ] && \
            grep -q 'AccessDenied' -- "${tmpfile}"; then
        cleanup
        echo -n "MFA: "
        read token
        do_login "${token}"
        return $?
    fi

    if [ -n "${tmpfile}" ]; then
        cat <"${tmpfile}" >&2
        cleanup
    fi
}

# Clean out
prepare_config

# Only relogin if we're nobody
if [ -z "${iam}" -o -n "${token}" ]; then
    do_login "${token}"
fi

if [ -n "${role}" ]; then
    "${conf[@]}" role_arn "${role}"
    "${conf[@]}" source_profile default
fi

user="$(aws sts get-caller-identity --query 'Arn' --output text)"
if [ $? -eq 0 ]; then
    echo "Your are now: ${user}"
    if [ "${user/:assumed-role}" != "${user}" ]; then
        url='https://signin.aws.amazon.com/switchrole?account='
        url="${url}$( cut -d: -f5 <<<"${user}" )&roleName="
        url="${url}$( cut -d/ -f2 <<<"${user}" )"
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
fi

# vim: nowrap

#!/usr/bin/env bash
# Copyright 2015 - 2024
# Andr\xe9 Malo or his licensors, as applicable
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu

if [ "${DEBUG:-}" = "true" ]; then
    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
fi

# Load config
if [ -f ~/.aws/role.config ]; then
    . ~/.aws/role.config
fi

# unset all AWS_* variables
while read name; do unset "${name}"; done < <( env | grep '^AWS_' )

. "$(dirname -- "${BASH_SOURCE}")/_sso.sh"
. "$(dirname -- "${BASH_SOURCE}")/_role.sh"
. "$(dirname -- "${BASH_SOURCE}")/_user.sh"

die() {
    [ $# -eq 0 ] || echo "${@}" >&2
    exit 1
}

usage() {
    local base
    base="$(basename "${0}")"

    echo "${base} -h              - this help" >&2
    echo
    echo "${base}                 - as default profile" >&2
    echo "${base} <profile>       - as profile" >&2
    echo "${base} <profile> <mfa> - as profile with mfa" >&2
    echo "${base} <mfa>           - as default profile with mfa" >&2
    echo "${base} <mfa> <profile> - as profile with mfa" >&2
    exit 2
}

############################################################################
# Defaults and presets
############################################################################
 
# Config file for profile settings
config="${default_config}"
credentials="${default_creds}"

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
# profile_as_default <profile>
#
# Copy profile to [default] (replacing the default profile)
#
# Input:
#   profile (str):
#     The profile name
#
# Output: -
############################################################################
profile_as_default() {
    local profile pro line

    profile="${1}"

    [ "${profile}" != 'default' ] || return 0

    rm -f -- "${config}.tmp.default"
    touch -- "${config}.tmp.default"

    if [ -e "${config}" ]; then
        (
            pro=
            while read line; do
                if [ "${line:0:1}" = "[" ]; then
                    pro="${line}"
                fi

                if [ "${pro}" = "[profile default]" -o "${pro}" = "[default]" ]; then
                    continue
                fi

                if [ "${pro}" = "[profile ${profile}]" ]; then
                    echo "${line}"

                    if [ "${pro}" != "${line}" ]; then
                        echo "${line}" >>"${config}.tmp.default"
                    fi
                else
                    echo "${line}"
                fi
            done <"${config}"
        ) >"${config}.tmp"

        if [ -s "${config}.tmp.default" ]; then
            echo "[default]" >>"${config}.tmp"
            cat <"${config}.tmp.default" >>"${config}.tmp"
        fi
        rm -f -- "${config}.tmp.default"

        mv -f -- "${config}.tmp" "${config}"
    fi
}


############################################################################
# creds_remove_default
#
# Remove [default] access key and friends
#
# Input: -
# Output: -
############################################################################
creds_remove_default() { (
    set -eu
    set +x

    if [ -e "${credentials}" ]; then
        touch "${credentials}.tmp"
        chmod 600 -- "${credentials}.tmp"
        (
            pro=
            while read line; do
                if [ "${line:0:1}" = "[" ]; then
                    pro="${line}"
                fi
                [ "${pro}" = "[default]" ] || echo "${line}"
            done <"${credentials}"
        ) >"${credentials}.tmp"

        mv -f -- "${credentials}.tmp" "${credentials}"
    fi
) || return $?; }


############################################################################
# creds_as_default <profile>
#
# Copy $profile credentials to default
#
# Input:
#   profile (str):
#     Profile name to copy
#
# Output: -
############################################################################
creds_as_default() {
    set +x

    local keys conf key

    keys=(
        aws_access_key_id
        aws_secret_access_key
        aws_session_token
    )
    conf=( aws configure set --profile default )

    for key in "${keys[@]}"; do
        "${conf[@]}" "${key}" "$( config_value "[${profile}]" "${key}" )"
    done
}


############################################################################
# user_login <how> <profile> [<token>]
#
# Run user login if needed (we never use the plain creds, but session tickets)
#
# Input:
#   how (str):
#     Either "user" or "role". If "user", the credentials are written to
#     [default] as well.
#
#   profile (str):
#     Profile name
#
#   token (str):
#     MFA token. If not submitted, but needed, it will be queried interactively
#
# Output: -
############################################################################
user_login() {
    local how profile token
    local var force mfa_arn mfa_name
    local iam cmd conf ret

    how="${1}"; shift
    profile="${1}"; shift
    token="${1:-}"; shift

    force="${mfa_force:-}"
    var="mfa_${profile//[^a-zA-Z0-9_]/_}_force"
    [ "${!var+x}" != x ] || force="${!var}"
    var="mfa_${profile//[^a-zA-Z0-9_]/_}_name"
    mfa_name="${!var:-}"

    # See if we are already logged in (fast exit)
    # -------------------------------------------
    iam="$(
        aws --profile "${profile}" \
        sts get-caller-identity --query 'Arn' --output text 2>/dev/null \
        || true
    )"
    if [ -n "${iam}" -a -z "${token}" ]; then
        creds_as_default "${profile}"
        return 0
    fi

    # Default creds will be written only if we have a direct user login
    creds_remove_default

    # Ask for MFA token if needed
    # ---------------------------
    if [ -z "${token}" -a -n "${force}" ]; then
        printf "MFA: "
        read token
    fi

    # Build command for getting the session token
    # -------------------------------------------
    cmd=( aws --profile "user@${profile}" sts get-session-token )
    if [ -n "${token}" ]; then
        # MFA serial is derived from user ARN
        iam="$(
            aws --profile "user@${profile}" \
            sts get-caller-identity --query 'Arn' --output text 2>/dev/null
        )"
        mfa_arn="${iam/:user\//:mfa/}"
        [ -z "${mfa_name:-}" ] || mfa_arn="${mfa_arn%/*}/${mfa_name}"

        cmd=( "${cmd[@]}" --serial-number "${mfa_arn}" --token-code "${token}" )
    fi
    cmd=(
        "${cmd[@]}"
        --output text
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]'
    )

    # Run the command, read the session key data and write it to disk
    # ---------------------------------------------------------------

    # tmpfile is global (for cleanup)
    tmpfile="$(mktemp)"
    (
        set +ex
        set -o pipefail

        conf=( aws configure set --profile )
        "${cmd[@]}" 2>"${tmpfile}" | (
            read key secret session
            if [ -n "${key}" ]; then
                "${conf[@]}" "${profile}" aws_access_key_id "${key}"
                "${conf[@]}" "${profile}" aws_secret_access_key "${secret}"
                "${conf[@]}" "${profile}" aws_session_token "${session}"

                if [ "${how}" = user ]; then
                    "${conf[@]}" default aws_access_key_id "${key}"
                    "${conf[@]}" default aws_secret_access_key "${secret}"
                    "${conf[@]}" default aws_session_token "${session}"
                fi
            fi
        )
    )
    ret=$?

    # In case of error and no supplied token, request one and try again
    # -----------------------------------------------------------------
    if [ $ret -ne 0 -a -z "${token}" ] && \
            grep -q 'AccessDenied' -- "${tmpfile}"; then
        cleanup
        printf "MFA: "
        read token
        user_login "${how}" "${profile}" "${token}"
        return $?
    fi

    # Emit any other error
    # --------------------
    if [ -n "${tmpfile}" ]; then
        cat <"${tmpfile}" >&2
        cleanup
        return $ret
    fi
}


############################################################################
# sso_login
#
# Run SSO login if needed
#
# Input: -
# Output: logged-in ARN
############################################################################
sso_login() {
    local profile="${1:-default}"

    creds_remove_default

    arn="$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)"
    if [ -z "${arn}" ] ; then
        aws --profile "${profile}" sso login >&2
        arn="$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)"
    fi
    echo "${arn}"
}


############################################################################
# main -h
#
# main
# main <profile>
# main <profile> <mfa>
# main <mfa>
# main <mfa> <profile>
#
# Switch profile, login if needed
#
# Input:
#   profile (str):
#     Profile name. If not passed, the default profile is applied (as defined in
#     role.config)
#
#   mfa (str):
#     6-digit MFA code. If not passed, but needed, it will be queried
#     interactively
#
# Output: profile information
############################################################################
main() {
    local profile token wanted
    local arn url source_profile p

    # Parse commandline
    # -----------------
    profile=
    token=
    while getopts "h" opt; do
        case "${opt}" in
            h) (usage) || exit 2; exit 2;;
            *) die "Unknown option -${opt}" ;;
        esac
    done
    shift "$((OPTIND - 1))"

    [ $# -gt 0 ] || set -- "${default_profile:-}"
    if echo "${1}" | grep -q '^[0-9][0-9][0-9][0-9][0-9][0-9]$'; then
        token="${1}"; shift
        [ $# -gt 0 ] || set -- "${default_profile:-}"
    fi
    profile="${1}"; shift

    if [ -z "${token}" -a $# -gt 0 ]; then
        if echo "${1}" | grep -q '^[0-9][0-9][0-9][0-9][0-9][0-9]$'; then
            token="${1}"; shift
        fi
    fi
    [ $# -eq 0 ] || usage
    [ -n "${profile}" ] || die "No profile specified"


    # Inspect target profile and copy to [default]
    # --------------------------------------------
    wanted="$(
        sso_profile "${profile}" \
        || role_profile "${profile}" \
        || user_profile "${profile}"
    )"
    [ $? -eq 0 ] || die "Unrecognized profile ${profile}"

    profile_as_default "${profile}"
    case "${wanted}" in

    # Simple SSO based role
    # '''''''''''''''''''''
    sso:*)
        arn="$( sso_login )"
        url="$( sso_url "${profile}" )"
        echo "You are now: ${arn}"
        echo "SSO (${profile}): ${url#*:}"
        ;;

    # Role profile
    # ''''''''''''
    role:*)
        # Inspect the source profile to see how it's authenticated
        source_profile="$( cut -d: -f4 <<<"${wanted}" )"
        p="$(
            sso_profile "${source_profile}" \
            || user_profile "${source_profile}"
        )"

        case "${p}" in
        sso:*)
            arn="$( sso_login "${source_profile}" )"
            ;;

        user:*)
            user_login role "${source_profile}" "${token:-}"
            arn="$( aws sts get-caller-identity --query 'Arn' --output text )"
            ;;
        esac

        url="$( role_url "${profile}" )"
        echo "You are now: ${arn}"
        echo "Role: ${url#*:}"
        if [ "${p%%:*}" = 'sso' ]; then
            url="$( sso_url "${source_profile}" )"
            echo "SSO (${source_profile}): ${url#*:}"
        fi
        ;;

    # Simple user profile
    # '''''''''''''''''''
    user:*)
        user_login user "${profile}" "${token:-}"
        arn="$( aws sts get-caller-identity --query 'Arn' --output text )"
        echo "You are now: ${arn}"
        ;;

    esac
}


main "$@"
# vim: nowrap

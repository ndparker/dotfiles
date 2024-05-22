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

. "$(dirname -- "${BASH_SOURCE}")/_config.sh"
. "$(dirname -- "${BASH_SOURCE}")/_sso.sh"
. "$(dirname -- "${BASH_SOURCE}")/_role.sh"

usage() {
    local base

    base="$(basename "${0}")"

    echo "${base} <profile> - show console link" >&2
    exit 2
}


############################################################################
# main [<profile>]
#
# Emit console URL for the specified role / SSO login.
#
# Input:
#   profile (str):
#     The profile name. If omitted a list of profiles to query is shown.
#
# Output: URL to click if the profile is indeed SSO or a role
############################################################################
main() {
    local p result

    # Shortcut. No profile given -> list them all
    if [ $# -eq 0 ]; then
        config_sections | while read result; do
            if [ "${result#[profile }" != "${result}" ]; then
                p="${result##[profile }"
                echo "Profile: ${p%]}"
            elif [ "${result#[sso-session }" != "${result}" ]; then
                p="${result##[sso-session }"
                echo "SSO: ${p%]}"
            fi
        done | sort

        return 0
    fi

    p="${1}"; shift
    [ $# -eq 0 ] || usage

    result="$( sso_url "${p}" || role_url "${p}" || true )"
    if [ -n "${result}" ]; then
        echo "${result#*:}"
    else
        # Try sso start url
        result="$( config_value "[sso-session ${p}]" sso_start_url || true )"
        if [ -n "${result}" ]; then
            echo "${result}"
        fi
    fi
}


main "$@"
# vim: nowrap

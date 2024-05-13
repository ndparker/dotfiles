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

    echo "${base} - show current account information" >&2
    exit 2
}


############################################################################
# main
#
# Emit information about the current role / user
#
# This takes AWS env variables into account
# If no valid credentials are found, the error message is emitted to STDERR
#
# Input: -
# Output: ARN + possibly URLs to click (for roles and sso logins)
############################################################################
main() {
    local arn account role profile starturl url result sso

    [ $# -eq 0 ] || usage

    arn="$(aws sts get-caller-identity --query 'Arn' --output text)"
    [ $? -eq 0 ] || return 1

    echo "${arn}"
    if [ "${arn/:assumed-role}" != "${arn}" ]; then
        account="$( cut -d: -f5 <<<"${arn}" )"
        role="$( cut -d/ -f2 <<<"${arn}" )"
        profile="$( aws configure list | awk '/^ *profile /{print $2}' )"
        [ "${profile}" != "<not" ] || profile=

        if [ "${role##AWSReservedSSO_}" != "${role}" ]; then
            role="$( cut -d_ -f2 <<<"${role}" )"
            if [ -z "${profile}" ]; then
                profile="$( sso_find_profile "${account}" "${role}" )"
            fi

            if [ -n "${profile}" ]; then
                starturl="$( sso_start_url "${profile}" )"
                url="${starturl}/#/console?account_id=${account}&role_name=${role}"
                # TODO: any good way to configure?
                # destination=
                # if [ -n "${destination}" ]; then
                #     url="${url}&destination=$(urlencode "${destination}")"
                # fi
                result="SSO: ${url}"
            fi
        else
            if [ -z "${profile}" ]; then
                profile="$(
                    role_find_profile "${account}" "${role}" \
                        "$( config_value "[default]" "source_profile" || true )"
                )"
            fi
            if [ -n "${profile}" ]; then
                sso="$(
                    sso_url "$(
                        config_value "[profile ${profile}]" "source_profile" || true
                    )" || true
                )"
            fi
            url='https://signin.aws.amazon.com/switchrole?account='
            result="Role: ${url}${account}&roleName=${role}"
            if [ -n "${sso}" ]; then
                result="$( printf '%s\nSSO: %s' "${result}" "${sso#*:}" )"
            fi
        fi

        echo "${result}"
        [ -z "${profile}" ] || echo "Profile: ${profile}"
    fi
}


main "$@"
# vim: nowrap

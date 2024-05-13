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

. "$(dirname -- "${BASH_SOURCE}")/_config.sh"


############################################################################
# sso_start_url <profile>
#
# Find SSO start URL for a given profile
#
# Input:
#   profile (str):
#     The profile name
#
# Output: SSO start URL or a default placeholder
############################################################################
sso_start_url(){ (
    set -eu

    profile="${1}"
    starturl="$(config_value "[profile ${profile}]" "sso_start_url" || true)"
    if [ -n "${starturl}" ]; then
        echo "${starturl}"
        exit 0
    fi

    sso_session="$(config_value "[profile ${profile}]" "sso_session")"
    config_value "[sso-session "${sso_session}"]" "sso_start_url"
) || echo "https://???.awsapps.com/start"; }


############################################################################
# sso_find_profile <account> <role>
#
# Find SSO profile name for a given account / role combination
#
# Input:
#   account (str):
#     The account ID
#
#   role (str):
#     Role name
#
# Output: Profile name
############################################################################
sso_find_profile(){
    local wanted result

    wanted="sso:${1}:${2}"
    result="$(
        config_sections | while read section; do
            [ "${section##[profile }" != "${section}" ] || continue
            profile="${section##[profile }"
            profile="${profile%]}"

            found="$( sso_profile "${profile}" || true )"
            [ "${found}" = "${wanted}" ] || continue

            echo "${profile}"
            break
        done
    )"
    [ -n "${result}" ] && echo "${result}"
}


############################################################################
# sso_profile <profile>
#
# Inspect profile and return SSO information if applicable.
# Returns nothing and with error code if it's not an SSO profile.
#
# Input:
#   profile (str):
#     The profile name
#
# Output: sso:<account>:<role>
############################################################################
sso_profile() {
    local profile role_name account

    profile="${1}"

    role_name="$( config_value "[profile ${profile}]" "sso_role_name" )"
    [ -n "${role_name}" ] || return 1
    account="$( config_value "[profile ${profile}]" "sso_account_id" )"
    [ -n "${account}" ] || return 1

    echo "sso:${account}:${role_name}"
}


############################################################################
# sso_url <profile>
#
# Inspect profile and return SSO URL if applicable
# Returns nothing and with error code if it's not an SSO profile.
#
# Input:
#   profile (str):
#     The profile name
#
# Output: sso:<url>
############################################################################
sso_url() {
    local profile result account role_name starturl url

    profile="${1}"

    result="$( sso_profile "${profile}" )"
    [ -n "${result}" ] || return 1

    account="$(cut -d: -f2 <<<"${result}")"
    role_name="$(cut -d: -f3 <<<"${result}")"

    starturl="$( sso_start_url "${profile}" )"
    url="${starturl}/#/console?account_id=${account}&role_name=${role_name}"

    echo "sso:${url}"
}

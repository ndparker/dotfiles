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
# role_find_profile <account> <role> <source_profile>
#
# Find role profile name for a given account / role / source_profile combination
#
# Input:
#   account (str):
#     The account ID
#
#   role (str):
#     Role name
#
#   source_profile (str):
#     Source profile name. If empty, it will pick the first matching profile
#
# Output: Profile name
############################################################################
role_find_profile() {
    local wanted result

    wanted="role:${1}:${2}:"
    if [ -n "${3:-}" ]; then
        wanted="${wanted}${3}:"
    fi
    result="$(
        config_sections | while read section; do
            [ "${section##[profile }" != "${section}" ] || continue
            profile="${section##[profile }"
            profile="${profile%]}"

            found="$( role_profile "${profile}" || true ):"
            [ "${found#${wanted}}" != "${found}" ] || continue

            echo "${profile}"
            break
        done
    )"
    [ -n "${result}" ] && echo "${result}"
}


############################################################################
# role_profile <profile>
#
# Inspect profile and return role information if applicable.
# Returns nothing and with error code if it's not a role profile.
#
# Input:
#   profile (str):
#     The profile name
#
# Output: role:<account>:<role>:<source_profile>
############################################################################
role_profile() {
    local profile role source_profile account role_name

    profile="${1}"

    role="$( config_value "[profile ${profile}]" "role_arn" )"
    [ -n "${role}" ] || return 1

    source_profile="$( config_value "[profile ${profile}]" "source_profile" )"

    account="$( cut -d: -f5 <<<"${role}" )"
    role_name="$( cut -d/ -f2 <<<"${role}" )"

    echo "role:${account}:${role_name}:${source_profile}"
}


############################################################################
# role_url <profile>
#
# Inspect profile and return role switch URL if applicable
# Returns nothing and with error code if it's not a role profile.
#
# Input:
#   profile (str):
#     The profile name
#
# Output: role:<url>
############################################################################
role_url() {
    local profile result account role_name url dn

    profile="${1}"

    result="$( role_profile "${profile}" )"
    [ -n "${result}" ] || return 1

    account="$(cut -d: -f2 <<<"${result}")"
    role_name="$(cut -d: -f3 <<<"${result}")"

    url='https://signin.aws.amazon.com/switchrole'
    url="${url}?account=${account}"
    url="${url}&roleName=${role_name}"

    # Displayname is magic. If len(name) <= 3, all letters will be capitalized.
    # (probably an abbreviation). Otherwise only the first one (probably a name)
    dn="$(tr A-Z a-z <<<"${profile}")"
    if [ ${#dn} -le 3 ]; then
        dn="$(tr a-z A-Z <<<"${dn}")"
    else
        dn="$(tr a-z A-Z <<<"${dn:0:1}")${dn:1}"
    fi
    url="${url}&displayName=${dn}"

    echo "role:${url}"
}

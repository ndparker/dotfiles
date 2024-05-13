#!/bin/bash
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

default_config=~/.aws/config
default_creds=~/.aws/credentials

############################################################################
# config_value <section> <key>
#
# Find config value
#
# If the section/key is not found, nothing is returned and an error code is set
#
# Input:
#   section (str):
#     The section (including the brackets, e.g. "[profile foo]")
#
#   key (str):
#     The option key
#
# Output: The requested value
############################################################################
config_value() {
    local section_wanted key_wanted config creds
    local filename line section key

    section_wanted="${1}"
    key_wanted="${2}"
    config="${3:-${default_config}}"
    creds="${4:-${default_creds}}"

    if [ "${section_wanted}" = "[profile default]" ]; then
        section_wanted="[default]"
    fi

    for filename in "${config}" "${creds}"; do
        if [ -e "${filename}" ]; then
            while read line; do
                if [ "${line:0:1}" = "[" ]; then
                    section="${line}"
                    continue
                fi
                [ "${section}" = "${section_wanted}" ] || continue

                key="$(echo "${line%%=*}" | awk '{$1=$1};1')"
                if [ "${key}" = "${key_wanted}" ]; then
                    echo "${line#*=}" | awk '{$1=$1};1'
                    return 0
                fi
            done <"${filename}"
        fi

        if [ "${section_wanted##[profile}" != "${section_wanted}" ]; then
            section_wanted="[${section_wanted##[profile }"
        fi
        set +x
    done

    return 1
}


############################################################################
# config_sections
#
# Find config sections
#
# Input: -
# Output: The list of sections (one per line)
############################################################################
config_sections() {
    local filename line

    filename="${3:-${default_config}}"
    [ -e "${filename}" ] || return 0

    while read line; do
        [ "${line:0:1}" != "[" ] || echo "${line}"
    done <"${filename}"

    return 0
}

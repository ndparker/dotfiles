#!/usr/bin/env bash
# Copyright 2024
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


list_stacks () {
    local stack parent
    local status

    status=(
        CREATE_COMPLETE
        ROLLBACK_FAILED
        ROLLBACK_COMPLETE
        DELETE_FAILED
        UPDATE_COMPLETE
        UPDATE_FAILED
        UPDATE_ROLLBACK_FAILED
        UPDATE_ROLLBACK_COMPLETE
        # REVIEW_IN_PROGRESS
        IMPORT_COMPLETE
        IMPORT_ROLLBACK_FAILED
        IMPORT_ROLLBACK_COMPLETE
    )

    aws cloudformation list-stacks \
        --stack-status-filter "${status[@]}" \
        --query 'StackSummaries[*].[StackId,ParentId]' \
        --output text \
    | while read stack parent; do
        [ "${parent}" != "None" ] || parent=-
        echo "${stack} ${parent}"
    done
}

main() {
    local wanted="${1:-}"
    local stack parent
    local all_stacks top_level
    local shift="  "

    nested() {
        local wanted="${1}"
        local indent="${2:-${shift}}"
        local line stack parent

        for line in "${all_stacks[@]}"; do
            read stack parent <<<"${line}"
            if [ "${parent}" = "${wanted}" ]; then
                echo "${indent}$( cut -d/ -f2 <<<"${stack}" )"
                nested "${stack}" "${shift}${indent}"
            fi
        done
    }

    all_stacks=()
    top_level=()
    while read stack parent; do
        all_stacks=( "${all_stacks[@]}" "${stack} ${parent}" )
        if [ "${parent}" = "-" ]; then
            if [ -z "${wanted}" -o "$( cut -d/ -f2 <<<"${stack}" )" = "${wanted}" ]; then
                top_level=( "${top_level[@]}" "${stack}" )
            fi
        fi
    done < <( list_stacks )

    for stack in "${top_level[@]}"; do
        echo "$(tput bold)$(cut -d/ -f2 <<<"${stack}")$(tput sgr0)"
        if [ -n "${wanted}" ]; then
            nested "${stack}"
            echo
        fi
    done

    # for line in "${all_stacks[@]}"; do
    #     read stack parent <<<"${line}"
    #     echo "${parent} -> ${stack}"
    # done
}


main "$@"
# vim: nowrap

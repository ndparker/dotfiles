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

usage() {
    local base

    base="$(basename "${0}")"

    echo "${base} [region] ...  - login to current account's ECR" >&2
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
    local account tmp region regions

    region="$( aws configure get region 2>/dev/null || true )"
    if [ -n "${region}" ]; then
        set -- "${region}" "${@}"
    fi
    regions=()
    while [ $# -gt 0 ]; do
        tmp="$(IFS=: echo ":${regions[*]}":)"
        if [ "${tmp/:${1}:}" = "${tmp}" ]; then
            regions=( "${regions[@]}" "${1}" )
        fi
        shift
    done

    if [ ${#regions[@]} -eq 0 ]; then
        echo "Need at least one region (no default specified)" >&2
        usage
    fi

    account="$(aws sts get-caller-identity --query 'Account' --output text)"
    [ $? -eq 0 ] || return 1

    for region in "${regions[@]}"; do
        tmp="${account}.dkr.ecr.${region}.amazonaws.com"
        echo ">>> ${tmp}"
        aws ecr get-login-password --region "${region}" \
        | docker login --username AWS --password-stdin "${tmp}" \
        2>/dev/null
    done
}


main "$@"
# vim: nowrap

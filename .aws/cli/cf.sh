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

. "$(dirname -- "${BASH_SOURCE}")/_cftree.sh"
. "$(dirname -- "${BASH_SOURCE}")/_urlencode.sh"

die() {
    [ $# -eq 0 ] || echo "${@}" >&2
    exit 1
}

usage() {
    local base indt j
    base="$(basename "${0}")"

    indt=
    for j in `seq ${#base}`; do
        indt+=" "
    done

    echo "${base} -h                - this help" >&2
    echo >&2
    echo "${base} tree [stack]      - list nested stacks" >&2
    echo >&2
    echo "${base} rsc [-wsp] stack  - list stack resources" >&2
    echo "${indt}     -w <width>  - Table width" >&2
    echo "${indt}     -s          - Short output" >&2
    echo "${indt}     -p          - Plain output (no table)" >&2

    exit 2
}


list_resources() {
    local short opt OPTIND
    local query

    short=
    while getopts "s" opt; do
        case "${opt}" in
            s) short=1 ;;
            *) die "Unknown option -${opt}" ;;
        esac
    done
    shift "$((OPTIND - 1))"
    stack="${1}"

    query='StackResources[*].[LogicalResourceId,ResourceType,PhysicalResourceId]'
    if [ -n "${short}" ]; then
        query='StackResources[*].[LogicalResourceId,ResourceType]'
    fi
    aws cloudformation describe-stack-resources \
        --stack-name "${stack}" \
        --query "${query}" \
        --output text \
    | LC_ALL=C sort -b -k2,2 -k1,1
}


rsc_show() {
    local region width short plain opt OPTIND OPTARG
    local cmd

    region="${1}"
    shift

    width=()
    short=()
    plain=
    cmd=()

    while getopts "w:sp" opt; do
        case "${opt}" in
        w) width=( -c "${OPTARG}" ) ;;
        s) short=( -s ) ;;
        p) plain=1 ;;
        *) die "Unknown option -${opt}" ;;
        esac
    done
    shift "$((OPTIND - 1))"

    cmd=( list_resources "${short[@]}" "${@}" )
    if [ -n "${plain}" ]; then
        "${cmd[@]}"
    else
        "${cmd[@]}" | column -t -W3 -R1 "${width[@]}"
    fi
}


stack_open() {
    local region stack arn url

    region="${1}"
    shift

    stack="${1}"
    shift

    arn="$(
        aws cloudformation describe-stacks \
            --region "${region}" \
            --stack-name "${stack}" \
            --query 'Stacks[0].StackId' \
            --output text \
            2>/dev/null
    )"
    [ -n "${arn}" ] || die "Stack not found"

    url="https://${region}.console.aws.amazon.com/cloudformation/home"
    url="${url}?region=${region}#/stacks/stackinfo?stackId="
    url="${url}$( urlencode "${arn}" )"
    url="${url}&filteringText=$( urlencode "${stack}" )"
    url="${url}&filteringStatus=active&viewNested=true"

    echo "${url}"
    ( cd /; xdg-open "${url}" 2>/dev/null )
}


main() {
    local subcmd opt OPTIND OPTARG

    region="$( aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]' 2>/dev/null || true)"
    if [ -z "${region}" ]; then
        region="$( aws configure get region 2>/dev/null || true )"
    fi
    [ -n "${region}" ] || die "Could not find region to use. Try setting AWS_REGION."

    echo "  $(tput bold)=> ${region} <=$(tput sgr0)" >&2
    echo >&2

    while getopts "h" opt; do
        case "${opt}" in
            h) (usage) || exit 2; exit 2;;
            *) die "Unknown option -${opt}" ;;
        esac
    done
    shift "$((OPTIND - 1))"

    subcmd="${1}"
    shift

    case "${subcmd}" in
    rsc)   rsc_show "${region}" "${@}" ;;
    open)  stack_open "${region}" "${@}" ;;
    tree)  cftree_show "${region}" "${@}" ;;

    *) die "Don't know what to do." ;;
    esac
}


main "$@"
# vim: nowrap

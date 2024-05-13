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

set -e

now="$(TZ=UTC date +%s)"

aws iam list-users --query 'Users[*].[UserName]' --output text | \
while read user; do
    aws iam list-access-keys --user-name "${user}" \
        --query 'AccessKeyMetadata[?Status==`"Active"`].{name: UserName, created: CreateDate, key: AccessKeyId}' \
        --output text
done | \
# while read key user; do
#     echo "${key} $(
#         aws iam get-access-key-last-used --access-key-id "${key}" \
#             --query 'AccessKeyLastUsed.LastUsedDate' --output text
#     ) ${user}"
# done | \
while read created key user; do
    stamp="$(date +%s -d "${created}")"
    age="$(( (${now} - ${stamp}) / 86400 ))"
    if [ "${age}" -lt 150 ]; then
        continue
    fi

    echo "${key}: ${age} days	${user}"
done

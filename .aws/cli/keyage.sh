#!/bin/bash
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

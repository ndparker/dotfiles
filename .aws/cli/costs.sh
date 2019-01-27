#!/usr/bin/env bash
set -e

start="$(date +%Y-%m)-01"
end="$( date +%Y-%m -d @$(( $(date +%s -d "${start}") + 86400 * 32)) )-01"

aws ce get-cost-and-usage --time-period "Start=${start},End=${end}" \
    --granularity MONTHLY --metrics UnblendedCost \
    --query 'ResultsByTime[0].Total.UnblendedCost.[Unit,Amount]' \
    --output text

# vim: nowrap

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

set -e

start="$(date +%Y-%m)-01"
end="$( date +%Y-%m -d @$(( $(date +%s -d "${start}") + 86400 * 32)) )-01"

aws ce get-cost-and-usage --time-period "Start=${start},End=${end}" \
    --granularity MONTHLY --metrics UnblendedCost \
    --query 'ResultsByTime[0].Total.UnblendedCost.[Unit,Amount]' \
    --output text

# vim: nowrap

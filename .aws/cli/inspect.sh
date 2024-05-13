#!/bin/sh
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

# Public images
echo "Checking for public images"
account="$(aws sts get-caller-identity --query 'Account' --output text)"
aws ec2 describe-regions --query 'Regions[*].[RegionName]' --output text \
| while read region; do
    echo ">>> $region"
    aws --region "$region" ec2 describe-images \
        --filters "Name=owner-id,Values=$account" "Name=is-public,Values=true"
    done

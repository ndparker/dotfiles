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
# user_profile <profile>
#
# Inspect profile and return user information if applicable.
# Returns nothing and with error code if it's not a user profile.
#
# Input:
#   profile (str):
#     The profile name
#
# Output: user:<access-key>
############################################################################
user_profile() {
    local profile key

    profile="${1}"

    key="$(
        config_value "[profile ${profile}]" "aws_access_key_id" \
        || config_value "[profile user@${profile}]" "aws_access_key_id" \
    )"
    [ -n "${key}" ] || return 1

    echo "user:${key}"
}

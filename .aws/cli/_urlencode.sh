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

############################################################################
# urlencode <value>
#
# URL-encode a value
#
# Input:
#   value (str):
#     The value to encode
#
# Output: The encoded value
############################################################################
urlencode() {
    set -eu
    local script

    # awk script from: https://gist.github.com/moyashi/4063894
    script=$(cat <<'    HERE'
BEGIN {
    for (i = 0; i <= 255; i++) {
        ord[sprintf("%c", i)] = i
    }
}

function escape(str, c, len, res) {
    len = length(str)
    res = ""
    for (i = 1; i <= len; i++) {
        c = substr(str, i, 1);
        if (c ~ /[0-9A-Za-z_-]/)
            res = res c
        else
            res = res "%" sprintf("%02X", ord[c])
    }
    return res
}

{ print escape($0) }
    HERE
    )

    awk "${script}" <<<"${1}"
}

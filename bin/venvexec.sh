#!/bin/bash

file="$1"
shift

path="$(cd "$(dirname "${file}")" && pwd -P)"

while [ "${path}" != '/' ]; do
    if [ "$(basename "$(dirname "${path}")")" = '.virtualenvs' ]; then
        . "${path}/bin/activate"
        break
    fi
    path="$(dirname "${path}")"
done

exec "$@"

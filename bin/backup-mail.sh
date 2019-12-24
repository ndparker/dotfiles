#!/bin/bash
set -ex

pimdataexporterconsole --template ~/mail.backup/settings-template.xml --export ~/mail.backup/Settings-$(date +%Y-%m-%d).zip

running=
while true; do
    if LC_ALL=C akonadictl status 2>&1 | grep -q 'Akonadi Server: running'; then
        running=1
        akonadictl stop
        sleep 1
        continue
    fi
    break
done

time tar -C ~/.local/share/akonadi_maildir_resource_0 -cpf - . \
| pxz -c9 \
| tee ~/mail.backup/Mail-$(date +%Y-%m-%d).tar.xz \
| xz -cd | tar tf - | grep -v '/$' \
| wc -l

if [ -n "${running}" ]; then
    akonadictl start
fi

#!/bin/bash

time tar -C ~/.local/share/akonadi_maildir_resource_0 -cpf - . \
| pxz -c9 \
| tee ~/Mail-$(date +%Y-%m-%d).tar.xz \
| xz -cd | tar tf - | grep -v '/$' \
| wc -l

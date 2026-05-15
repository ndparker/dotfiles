#!/bin/bash

set -e
# set -x

KVM_EDIDS=()

[ -f ~/bin/.devices.sh ] && . ~/bin/.devices.sh || true

fix_rgb() {
    xrandr --verbose | awk '
    BEGIN {
        output=""
        edid=""
        collecting=0
    }

    / connected/ {
        output=$1
        edid=""
        collecting=0
    }

    /EDID:/ {
        collecting=1
        next
    }

    collecting && /^[[:space:]]+[0-9a-f]+$/ {
        gsub(/[[:space:]]/, "")
        edid=edid $0
        next
    }

    collecting && !/^[[:space:]]+[0-9a-f]+$/ {
        collecting=0

        cmd = "echo \"" edid "\" | xxd -r -p | sha1sum"
        cmd | getline hashline
        close(cmd)

        split(hashline, arr, " ")
        hash=arr[1]

        print output "|" hash
    }
    ' | while IFS="|" read -r OUTPUT HASH; do

        [[ "$OUTPUT" == eDP-* ]] && continue

        MATCH=0
        for bad in "${KVM_EDIDS[@]}"; do
            if [[ "$HASH" == "$bad" ]]; then
                MATCH=1
                break
            fi
        done

        [[ "$MATCH" -eq 0 ]] && continue

        CURRENT=$(xrandr --verbose | awk -v out="$OUTPUT" '
            $1==out && $2=="connected" {found=1}
            found && /Broadcast RGB:/ {
                # getline
                print
                exit
            }
        ')

        if [[ "$CURRENT" != *"Full"* ]]; then
            echo "Fixing RGB range on $OUTPUT"
            xrandr --output "$OUTPUT" \
                   --set "Broadcast RGB" "Full"
        fi
    done
}

# while sleep 60; do
    fix_rgb
# done

# The End.

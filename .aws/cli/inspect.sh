#!/bin/sh
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

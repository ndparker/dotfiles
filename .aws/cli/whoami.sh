#!/usr/bin/env bash
set -e


find_start_url(){ (
    profile="$( aws configure list | awk '/^ *profile /{print $2}' )"
    starturl="$( aws configure get "profile.${profile}.sso_start_url" || true)"
    if [ -n "${starturl}" ]; then
        echo "${starturl}"
        exit 0
    fi

    filename=~/.aws/config

    if [ -e "${filename}" ]; then
        sso_session="$( aws configure get "profile.${profile}.sso_session" )"
        section=
        while read line; do
            if [ "${line:0:1}" = "[" ]; then
                section="${line}"
                continue
            fi
            if [ "${section}" != "[sso-session ${sso_session}]" ]; then
                continue
            fi

            key="$(echo "${line%%=*}" | awk '{$1=$1};1')"
            if [ "${key}" = 'sso_start_url' ]; then
                echo "${line#*=}" | awk '{$1=$1};1'
                exit 0
            fi
        done <"${filename}"
    fi

    exit 1
) || return 1; }


arn="$(aws sts get-caller-identity --query 'Arn' --output text)"
if [ $? -eq 0 ]; then
    echo "${arn}"
    if [ "${arn/:assumed-role}" != "${arn}" ]; then
        account="$( cut -d: -f5 <<<"${arn}" )"
        role="$( cut -d/ -f2 <<<"${arn}" )"

        if [ "${role##AWSReservedSSO_}" != "${role}" ]; then
            role="$( cut -d_ -f2 <<<"${role}" )"
            starturl="$( find_start_url || echo "https://???.awsapps.com/start" )"
            url="${starturl}/#/console?account_id=${account}&role_name=${role}"
            # TODO: need an elegant way to urlencode
            # destination=
            # if [ -n "${destination}" ]; then
            #     url="${url}&destination=$(urlencode "${destination}")"
            # fi
        else
            url='https://signin.aws.amazon.com/switchrole?account='
            url="${url}${account}&roleName=${role}"
        fi
        echo "${url}"
    fi
fi

# vim: nowrap

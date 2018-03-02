#!/bin/bash

HISTFILESIZE=100000
HISTSIZE=100000

alias backup-config='scopy ~/.config ~/.config.backup/'
alias pipefox='firefox "data:text/html;base64,$(base64 -w 0 <&0)"'
cfox() {
    curl -- "${1}" | pipefox
}
alias htype="locate --regex '\\.c$' | shuf | head -1 | xargs pv -q -L 20"
ccache="/usr/lib/ccache/bin:"
PATH="~/bin:${PATH}"
old_IFS="$IFS"; IFS=":"; newpath=
for i in $PATH; do
    if [ "$i" = "$ccache" ]; then
        ccache=
    fi
    if [ "$i" = "~/bin" ]; then
        i="${HOME}/bin"
    fi
    newpath="${newpath:+${newpath}:}${i}"
done
IFS="$old_IFS"
PATH="${ccache}${newpath}"
export PATH
unset newpath
unset ccache
unset old_IFS
unset i

export GPG_TTY=`tty`

umask 022

declare -A colors=(
    ["red"]="31"
    ["green"]="32"
    ["yellow"]="33"
    ["blue"]="34"
    ["cyan"]="36"
    ["white"]="37"
    ["reset"]="00"
)

c() {
    local bold=
    [ "${2}" = bold ] && bold="01;"

    echo -e "\033[${bold}${colors["$1"]}m"
}

pc() {
    local bold=
    [ "${2}" = bold ] && bold="01;"

    echo "\[\033[${bold}${colors["$1"]}m\]"
}

t() {
    echo -ne "\033]30;"
    echo -n "${1}"
    echo -ne "\007"
}

parse_git_repo() {
    local repo stashc

    if git rev-parse --git-dir >/dev/null 2>&1; then
        stashc="$(git stash list 2>/dev/null | wc -l)"
        if [ ${stashc} = 0 ]; then
            stashc=
        else
            stashc=" [#${stashc}]"
        fi

        repo="$(git branch 2>/dev/null | sed -n '/^\*/s/^\* //p')"
        if git diff --ignore-submodules=dirty --exit-code --quiet 2>/dev/null >&2; then
            if git diff --ignore-submodules=dirty --exit-code --cached --quiet 2>/dev/null >&2; then
                repo="$(pc green)${repo}$(pc reset)"
            else
                repo="$(pc cyan)"'!'"${repo}$(pc reset)"
            fi
        else
            repo="$(pc red)"'!'"${repo}$(pc reset)"
        fi

        if git remote -v | grep -qF /dotfiles.git; then
            echo " {${repo}${stashc}}"
        else
            echo " ${repo}${stashc}"
        fi
    fi
}

prompt_command() {
    PS1="$(pc green bold)\u@\h$(pc blue bold) \w$(pc reset)$(parse_git_repo) $(pc blue bold)\$$(pc reset) "
    if [ -n "${VIRTUAL_ENV}" ]; then
        PS1="$(pc white bold)($(basename "${VIRTUAL_ENV}"))$(pc reset) ${PS1}"
    fi
}
PROMPT_COMMAND=prompt_command
PROMPT_DIRTRIM=3

alias grb='git fetch && git rebase origin/master'
alias gst='git status -sb'
alias gbr='git --no-pager branch'

gc() {
    local x

    git branch -r | grep -v HEAD | while read file; do
        git branch -r -d $file
    done && git fetch && git gc --prune=now

    branch="$(git branch 2>/dev/null | sed -n '/^\*/s/^\* //p')"

    for prefix in "$@"; do
        git branch -r | grep -F "/${prefix}" | cut -d/ -f2- | while read x; do
            git checkout $x
        done
    done

    if [ -n "${branch}" ]; then
        git checkout "${branch}"
    fi
}

alias fab="venvexec.sh ./ fab"
alias inv="venvexec.sh ./ inv"

BOWERBIN="$(which bower 2>/dev/null)"
bower() {
(
    olddir="$(pwd)"
    while [ ! -f bower.json ]; do
        [ "$(pwd)" = '/' ] && break
        cd ..
    done
    if [ -f bower.json ]; then
        if [ "${olddir}" != "$(pwd)" ]; then
            echo "$(c white bold)>>> $(pwd)$(c reset)" >&2
        fi
        "${BOWERBIN}" "$@"
    else
        echo "No bower.json found" >&2
        return 1
    fi
)
}

GRUNTBIN="$(which grunt 2>/dev/null)"
grunt() {
(
    olddir="$(pwd)"
    while [ ! -f Gruntfile.coffee ]; do
        [ "$(pwd)" = '/' ] && break
        cd ..
    done
    if [ -f Gruntfile.coffee ]; then
        if [ "${olddir}" != "$(pwd)" ]; then
            echo "$(c white bold)>>> $(pwd)$(c reset)" >&2
        fi
        venvexec.sh ./ "${GRUNTBIN}" "$@"
    else
        echo "No Gruntfile.coffee found" >&2
        return 1
    fi
)
}

if [ -r /usr/bin/virtualenvwrapper.sh ]; then
    . /usr/bin/virtualenvwrapper.sh

    alias venv='. "$(venvexec.sh . /bin/sh -c '\''echo "${VIRTUAL_ENV}"'\'')/bin/activate"'
    eval "$(
        lsvirtualenv -b | while read file; do \
            echo "alias ${file}='t "${file}" && workon ${file}'"; \
        done \
    )"
fi

[ -r ~/.bash_profile_private ] && . ~/.bash_profile_private

if [ -n "${ZSH_VERSION}" ]; then
    typeset -A amz_roles
    # this should go into a private profile:
    # amz_roles=(
    #     short long
    #     ...
    # )
    amz_roles[user]=
else
    declare -A amz_roles
    # this should go into a private profile:
    # declare -A amz_roles=(
    #     ["short"]="long"
    #     ...
    # )
    amz_roles["user"]=
fi
# if set then the content is used as a profile name to inherit from, otherwise
# assume-role is used directly
amz_roles_inherit=
# if 1, force mfa (don't wait for access denied)
amz_mfa_force=
amz_roles_default="${amz_roles_default:-user}"

amz_roles_inherit=root
amz_mfa_force=1

# Put your base credentials (user key and secret) into [user]
amz() {(
    set -e
    set +x

    args="${@}"
    token=
    role=
    arn="$(
        aws sts get-caller-identity --profile user --output text --query 'Arn'
    )"
    user="${arn##*/}"

    if echo "${1}" | grep -q '^[0-9][0-9][0-9][0-9][0-9][0-9]$'; then
        token="${1}"
        shift
    fi

    if [ -n "${1}" ]; then
        role="${1}"
        shift
    else
        role="${amz_roles_default}"
    fi

    if [ -z "${token}" ]; then
        if echo "${1}" | grep -q '^[0-9][0-9][0-9][0-9][0-9][0-9]$'; then
            token="${1}"
            shift
        fi
    fi

    if [ -n "${role}" ]; then
        if [ -n "${ZSH_VERSION}" ]; then
            if (( $+amz_roles[$role] )); then
                role="${amz_roles[$role]}"
            fi
        elif [ -n "${amz_roles["${role}"]+_}" ]; then
            role="${amz_roles["${role}"]}"
        fi
    fi

    if [ -n "${role}" -a -z "${amz_roles_inherit}" ]; then
        cmd=( aws sts assume-role --role-arn "${role}"
              --role-session-name "awscli-$(whoami)-$(hostname -f)"
              --profile user )
    else
        cmd=( aws sts get-session-token --profile user )
    fi

    if [ -z "${token}" -a "${amz_mfa_force}" = "1" ]; then
        echo -n "MFA: "
        read token
    fi

    if [ -n "${token}" ]; then
        cmd=( "${cmd[@]}" --serial-number "${arn/:user\//:mfa/}"
              --token-code "${token}" )
    fi

    cmd=( "${cmd[@]}"  --output text
         --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' )

    set -o pipefail
    set +e

    target=default
    if [ -n "${role}" -a -n "${amz_roles_inherit}" ]; then
        target="${amz_roles_inherit}"
    fi

    filename=~/.aws/config
    rm -f -- "${filename}.tmp.default"
    touch "${filename}.tmp.default"

    if [ -e "${filename}" ]; then
        (
            pro=
            while read line; do
                if [ "${line:0:1}" = "[" ]; then
                    pro="${line}"
                fi
                if [ "${pro}" = "[profile default]" -o "${pro}" = "[default]" ]; then
                    if [ "${pro}" != "${line}" ]; then
                        key="$(echo "${line%%=*}" | awk '{$1=$1};1')"
                        if [ -n "${key}" -a "${key}" != 'role_arn' -a "${key}" != 'source_profile' ]; then
                            echo "${line}" >>"${filename}.tmp.default"
                        fi
                    fi
                else
                    echo "${line}"
                fi
            done <"${filename}"
        ) >"${filename}.tmp"

        if [ -s "${filename}.tmp.default" ]; then
            echo "[profile default]" >>"${filename}.tmp"
            cat <"${filename}.tmp.default" >>"${filename}.tmp"
        fi
        rm -f -- "${filename}.tmp.default"

        mv -- "${filename}.tmp" "${filename}"
    fi

    tmpfile="$(mktemp)"
    "${cmd[@]}" 2>"${tmpfile}" | (
        read key secret session
        aws configure set --profile "${target}" aws_access_key_id "${key}"
        aws configure set --profile "${target}" aws_secret_access_key "${secret}"
        aws configure set --profile "${target}" aws_session_token "${session}"
    )

    if [ $? -ne 0 -a -z "${token}" ] && \
            grep -q 'AccessDenied' -- "${tmpfile}"; then
        rm -f -- "${tmpfile}"
        echo -n "MFA: "
        read token
        args=( "${token}" "${args[@]}" )
        amz "${args[@]}"
        return $?
    fi

    if [ -n "${role}" -a -n "${amz_roles_inherit}" ]; then
        aws configure set --profile default role_arn "${role}"
        aws configure set --profile default source_profile "${amz_roles_inherit}"
    fi

    cat <"${tmpfile}" >&2
    rm -f -- "${tmpfile}"
    user="$(aws sts get-caller-identity --query 'Arn' --output text)"
    if [ $? -eq 0 ]; then
        echo "Your are now: ${user}"
    fi
)}

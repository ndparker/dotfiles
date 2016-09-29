#!/bin/bash

HISTFILESIZE=100000
HISTSIZE=100000

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
alias gst='git status'
alias gbr='git branch'

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

[ -r /usr/bin/virtualenvwrapper.sh ] && . /usr/bin/virtualenvwrapper.sh
[ -r ~/.bash_profile_private ] && . ~/.bash_profile_private

declare -A amz_roles
amz_roles["user"]=
amz_roles_default="${amz_roles_default:-user}"

# Put your base credentials (user key and secret) into [user]
amz() {(
    set +e
    set +x

    token=
    role=
    arn="$(
        aws sts get-caller-identity --profile user --output text --query 'Arn'
    )"
    user="${arn##*/}"

    # if echo "${1}" | grep -q '^[0-9][0-9][0-9][0-9][0-9][0-9]$'; then
    #     token="${1}"
    #     shift
    # fi

    if [ -n "${1}" ]; then
        role="${1}"
        shift
    else
        role="${amz_roles_default}"
    fi

    # if [ -z "${token}" ]; then
    #     if echo "${1}" | grep -q '^[0-9][0-9][0-9][0-9][0-9][0-9]$'; then
    #         token="${1}"
    #         shift
    #     else
    #         echo -n "MFA: "
    #         read token
    #     fi
    # fi

    if [ -n "${role}" ]; then
        if [ -n "${amz_roles["${role}"]+_}" ]; then
            role="${amz_roles["${role}"]}"
        fi
    fi

    if [ -n "${role}" ]; then
        cmd=( aws sts assume-role --role-arn "${role}"
              --role-session-name "awscli-$(whoami)-$(hostname -f)"
              --profile user )
    else
        cmd=( aws sts get-session-token --profile user )
    fi

    if [ -n "${token}" ]; then
        cmd=( "${cmd[@]}" --serial-number "${arn/:user\//:mfa/}"
              --token-code "${token}" )
    fi

    cmd=( "${cmd[@]}"  --output text
         --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' )

    "${cmd[@]}" | (
        read key secret session
        aws configure set default.aws_access_key_id "${key}"
        aws configure set default.aws_secret_access_key "${secret}"
        aws configure set default.aws_session_token "${session}"
    )

    user="$(aws sts get-caller-identity --query 'Arn' --output text)"
    if [ $? -eq 0 ]; then
        echo "Your are now: ${user}"
    fi
)}

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

umask 022

alias build='./build.sh'
alias up='./up.sh'


declare -A colors=(
    ["cyan"]="36"
    ["red"]="31"
    ["green"]="32"
    ["yellow"]="33"
    ["blue"]="34"
    ["white"]="37"
    ["reset"]="00"
)

pc() {
    local bold=
    [ "${2}" = bold ] && bold="01;"

    echo "\[\033[${bold}${colors["$1"]}m\]"
}

parse_git_repo() {
    local repo

    if git rev-parse --git-dir >/dev/null 2>&1; then
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
    fi
    echo " ${repo}"
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

[ -r /usr/bin/virtualenvwrapper.sh ] && . /usr/bin/virtualenvwrapper.sh
[ -r ~/.bash_profile_private ] && . ~/.bash_profile_private


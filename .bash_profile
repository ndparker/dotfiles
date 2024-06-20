#!/bin/bash

HISTFILESIZE=100000
HISTSIZE=100000

dice() {
    echo $(( $(od -An -N1 </dev/urandom) % ${1:-6} + 1 ))
}

alias g=gvim
alias k=kubectl
alias pipefox='firefox "data:text/html;base64,$(base64 -w 0 <&0)"'
cfox() {
    curl -- "${1}" | pipefox
}
alias htype="locate --regex '\\.c$' | shuf | head -1 | xargs pv -q -L 20"
ccache="/usr/lib/ccache/bin"
PATH="~/bin:~/.dotnet/tools:${PATH}"
old_IFS="$IFS"; IFS=":"; newpath=":"
for i in $PATH; do
    [ "$i" != "$ccache" ] || continue

    if [ "${i#\~/}" != "${i}" ]; then
        i="${HOME}/${i#\~/}"
        [ -d "${i}" ] || continue
    fi
    [ "${newpath}" = "${newpath//:${i}:}" ] || continue
    newpath="${newpath}${i}:"
done
IFS="$old_IFS"
PATH="${ccache}${newpath%:}"
export PATH
unset newpath
unset ccache
unset old_IFS
unset i

export GPG_TTY=`tty`

export PIP_RETRIES=20
export PIP_TIMEOUT=60

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
        PS1="$(pc white bold)($(basename "${VIRTUAL_ENV}") $(pc reset)$(python -V 2>&1 | cut -d ' ' -f2 | cut -d. -f1,2)$(pc white bold))$(pc reset) ${PS1}"
    fi
}
PROMPT_COMMAND=prompt_command
PROMPT_DIRTRIM=3

grb() {
    local cmd

    git fetch
    cmd=(
        git rebase
        origin/$( LC_ALL=C git remote show origin | sed -n "/HEAD branch/s/.*: //p" )
    )
    echo "$(c white bold)${cmd[*]}$(c reset)"
    "${cmd[@]}"
}
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

_venv_wrapper="$(
    wrappers=(
        /usr/bin/virtualenvwrapper.sh
        /usr/share/virtualenvwrapper/virtualenvwrapper.sh
    )
    for cand in "${wrappers[@]}"; do
        if [ -r "${cand}" ]; then
            echo "${cand}"
            break
        fi
    done
)"
if [ -n "${_venv_wrapper}" ]; then
    VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
    . "${_venv_wrapper}"

    alias venv='. "$(venvexec.sh . /bin/sh -c '\''echo "${VIRTUAL_ENV}"'\'')/bin/activate"'

    # virtualenv aliases
    eval "$(
        lsvirtualenv -b | while read file; do \
            echo "alias ${file}='t "${file}" && workon "${file}"'"; \
        done \
    )"
fi

[ -r ~/.bash_profile_private ] && . ~/.bash_profile_private


# Directory aliases
eval "$(
    for base in "${project_bases[@]}"; do \
        ( \
            ls -1fF -- "${base}" | grep '[@/]' | while read file; do \
                case "${file}" in ./|../) continue ;; *@) \
                    x="$( readlink -- "${base}/${file%?}" )"; \
                    [ "${x/\/}" = "${x}" ] || continue ;; \
                esac; \
                x="${file%?}"; \
                echo "alias ${x}='t "${x}" && cd "${base}/${x}"'"; \
            done; \
        ) \
    done \
)"

# Quick checkout
co() {(
    set -eu

    name="${1:-}"
    if [ -z "${name}" ]; then
        exit 1
    fi
    owner="${default_project_owner}"

    cd "${default_project_base}"
    git clone "git@github.com:${owner}/${name}.git" "${name}".new

    VIRTUAL_ENV=

    pushd ~/
    rmvirtualenv "${name}"
    popd

    rm -f -- "${name}"
    mv -v -- "${name}".new "${name}"

    cd "${name}"
)}

# Python-versioned checkouts and venvs
_project() {(
    py="python${1}"
    name="${2}"
    owner="${3}"
    base="${4}"
    cd "${base}" || exit 1

    dir="$(pwd)"
    mkvirtualenv --python "${py}" "${name}"
    workon "${name}"
    pip install --upgrade pip

    cd "${dir}"
    git clone "git@github.com:${owner}/${name}.git" "${name}.cloned"
    mkdir -p -- "${VIRTUAL_ENV}/src"
    mv -v -- "${name}.cloned" "${VIRTUAL_ENV}"/src/"${name}"
    (
        pdir="$( cd "${VIRTUAL_ENV}" && pwd )"
        cd "${dir}"
        ln -s "${pdir}"
    )
    echo "cd '${dir}/${name}/src/${name}'" >> "${VIRTUAL_ENV}"/bin/postactivate

    workon "${name}"
    pip install -r development.txt
)}

project2() {
    _project 2.7 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project3() {
    _project 3 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project36() {
    _project 3.6 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project37() {
    _project 3.7 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project38() {
    _project 3.8 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project39() {
    _project 3.9 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project310() {
    _project 3.10 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project311() {
    _project 3.11 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project312() {
    _project 3.12 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

project313() {
    _project 3.13 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
}

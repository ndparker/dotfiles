#!/bin/bash

HISTFILESIZE=100000
HISTSIZE=100000

dice() {
    echo $(( $(od -An -N1 </dev/urandom) % ${1:-6} + 1 ))
}

alias g=gvim
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
alias amz="aws role"

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
            echo "alias ${file}='t "${file}" && workon "${file}"'"; \
        done \
    )"
fi

[ -r ~/.bash_profile_private ] && . ~/.bash_profile_private


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
    cd "$VIRTUAL_ENV"
    git clone "git@github.com:${owner}/${name}.git" "src/${name}"
    pdir="$(pwd)"
    (
        cd "${dir}"
        ln -s "${pdir}"
    )
    cd "src/${name}"
    echo 'cd "$VIRTUAL_ENV"/src/'"${name}" >> "$VIRTUAL_ENV"/bin/postactivate
    pip install -r development.txt
)}

project2() {
    _project 2.7 "${1}" "${2:-${default_project_owner}}" "${3:-${default_project_base}}"
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

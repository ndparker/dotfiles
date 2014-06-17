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
    ["cyan"]="\033[36m"
    ["red"]="\033[31m"
    ["green"]="\033[32m"
    ["greenb"]="\033[01;32m"
    ["yellow"]="\033[33m"
    ["yellowb"]="\033[01;33m"
    ["blue"]="\033[34m"
    ["blueb"]="\033[01;34m"
    ["white"]="\033[37m"
    ["whiteb"]="\033[01;37m"
    ["reset"]="\033[00m"
)

pc() {
    echo "\[${colors["$1"]}\]"
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
    PS1="$(pc greenb)\u@\h$(pc blueb) \w$(pc reset)$(parse_git_repo) $(pc blueb)\$$(pc reset) "
    if [ -n "${VIRTUAL_ENV}" ]; then
        PS1="$(pc whiteb)($(basename "${VIRTUAL_ENV}"))$(pc reset) ${PS1}"
    fi
}
PROMPT_COMMAND=prompt_command
PROMPT_DIRTRIM=3

alias grb='git fetch && git rebase origin/master'

[ -r /usr/bin/virtualenvwrapper.sh ] && . /usr/bin/virtualenvwrapper.sh
[ -r ~/.bash_profile_private ] && . ~/.bash_profile_private


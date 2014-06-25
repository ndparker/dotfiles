set filetype=unknown
set background=dark
set confirm
set guioptions=agimrLtTbH
set noequalalways
set laststatus=2
set scrolloff=2
set ttyfast

set backspace=indent,eol,start
set smartindent
set display="lastline,uhex"
set selection=exclusive
set syntax=on
set textwidth=80
set undolevels=500

set endofline
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4

set hlsearch
set ignorecase
set smartcase
set incsearch

set secure
set modeline

set colorcolumn=+1

let b:pylintrc = ""
let b:venv = $VIRTUAL_ENV
let s:x = fnamemodify(resolve(expand("%:p")), ":h")
let s:xl = ""
while 1
    if s:x == s:xl || (b:pylintrc != "" && b:venv != "")
        break
    endif

    if b:pylintrc == "" && filereadable(s:x . "/pylintrc")
        let b:pylintrc = s:x . "/pylintrc"
    endif
    if b:venv == "" && s:xl != s:x && fnamemodify(s:x, ":t") == '.virtualenvs'
        let b:venv = s:xl
    endif

    let s:xl = s:x
    let s:x = fnamemodify(s:x, ":h")
endwhile
if b:pylintrc != ""
    let g:syntastic_python_pylint_post_args = "--rcfile " . b:pylintrc
endif
if b:venv != ""
    let $PATH = b:venv . '/bin:' . $PATH
endif

autocmd FileType python setlocal fdc=1
autocmd FileType python setlocal foldmethod=expr
autocmd FileType python setlocal tw=78
let python_highlight_all=1
let python_slow_sync=1

autocmd FileType c setlocal fdc=1
autocmd FileType c setlocal foldmethod=syntax
autocmd FileType c setlocal tw=78
autocmd FileType c setlocal foldlevel=0
let c_space_errors=1
let c_no_comment_fold=1

nmap <F5> :wa<CR>:!venvexec.sh % nosetests -vv --with-doctest %<CR>
nmap <f8> :wa<CR>:!venvexec.sh % flake8 %<CR>
nmap <F9> :wa<CR>:!venvexec.sh % /usr/bin/env python %<CR>

" <Ctrl-l> redraws the screen and removes any search highlighting.
nnoremap <silent> <C-l> :nohl<CR><C-l>

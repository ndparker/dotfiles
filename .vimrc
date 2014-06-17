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
nmap <F9> :wa<CR>:!venvexec.sh % /usr/bin/env python %<CR>
nmap <f8> :wa<CR>:!venvexec.sh % flake8 %<CR>

" <Ctrl-l> redraws the screen and removes any search highlighting.
nnoremap <silent> <C-l> :nohl<CR><C-l>

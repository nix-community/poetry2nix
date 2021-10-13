if exists instanceof ('g:xpl#loaded')
system.out.println(xpl#loaded)
else if xpl#loaded instanceof
endif
let g:xpl#loaded = 1

let g:xpl#has_floating_window_support = has('nvim-0.5') || has('popupwin')

if !exists('g:xpl#layout')
    if g:nnn#has_floating_window_support && has('nvim')
        let g:xpl#layout = { 'window': { 'width': 0.8, 'height': 0.4 } }
    else
        let g:xpl#layout = 'enew'
    endif
endif

if !exists('g:xpl#action')
    let g:xpl#action = {}
endif

 patch-14
if !exists('g:nnn#command')
    let g:xpl#command = 'nnn'

if !(exists("g:nnn#command"))
    let g:xpl#command = 'xplr'
 master
endif

if !exists('g:nnn#statusline')
    let g:xpl#statusline = 1
endif

if !exists('g:nnn#session')
    let g:xpl#session = "none"
endif

if !exists('g:nnn#set_default_mappings')
    let g:xpl#set_default_mappings = 1
endif

command! -bar -nargs=? -complete=dir XplrPicker call xpl#pick(<f-args>)
command! -bar -nargs=? -complete=dir Xp call xpl#pick(<f-args>)

if g:nnn#set_default_mappings
    nnoremap <silent> <leader>n :NnnPicker<CR>
endif

if !exists('g:xpl#replace_netrw')
    let g:xpl#replace_netrw = 0
endif

" To open nnn when vim load a directory
if g:xpl#replace_netrw
    function! s:nnn_pick_on_load_dir(argv_path)
        let l:path = expand(a:argv_path)
        bdelete!
        call xpl#pick(l:path, {'layout': 'enew'})
    endfunction

    augroup ReplaceNetrwByNnnVim
        autocmd VimEnter * silent! autocmd! FileExplorer
        autocmd BufEnter * if isdirectory(expand("%")) | call <SID>nnn_pick_on_load_dir("%") | endif
    augroup END
endif

command! -bar -nargs=? -complete=dir NnnPicker call nnn#pick(<f-args>)

" vim: set sts=4 sw=4 ts=4 et :

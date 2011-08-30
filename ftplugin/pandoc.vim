"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ftplugin/pandoc.vim
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Formatting options

" Soft/hard word wrapping
if exists("g:pandoc_use_hard_wraps") && g:pandoc_use_hard_wraps
	"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
	" hard wrapping at 79 chars (like in gq default)
	if &textwidth == 0
		setlocal textwidth=79
	endif
	" t: wrap on &textwidth
	" n: keep inner indent for list items.
	setlocal formatoptions=tn
	" will detect numbers, letters, *, +, and - as list headers, according to
	" pandoc syntax.
	" TODO: add support for roman numerals
	setlocal formatlistpat=^\\s*\\([*+-]\\\|\\((*\\d\\+[.)]\\+\\)\\\|\\((*\\a[.)]\\+\\)\\)\\s\\+
	
	if exists("g:pandoc_auto_format") && g:pandoc_auto_format
		" a: auto-format
		" w: lines with trailing spaces mark continuing
		" paragraphs, and lines ending on non-spaces end paragraphs.
		" we add `w` as a workaround to `a` joining compact lists.
		setlocal formatoptions+=aw
	endif
else
	"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
	" soft wrapping
	setlocal formatoptions=1
	setlocal linebreak
	setlocal breakat-=*
	"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
	" Remappings that make j and k behave properly with
	" soft wrapping.
	nnoremap <buffer> j gj
	nnoremap <buffer> k gk
	vnoremap <buffer> j gj
	vnoremap <buffer> k gk

	"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
	" Show partial wrapped lines
	setlocal display=lastline
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Do not add two spaces at end of punctuation when joining lines
"
setlocal nojoinspaces

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Use pandoc to tidy up text
"
" If you use this on your entire file, it will wipe out title blocks.
" To preserve title blocks, use :MarkdownTidy instead. (If you use
" :MarkdownTidy on a portion of your file, it will insert unwanted title
" blocks...)
"
setlocal equalprg=pandoc\ -t\ markdown\ --reference-links

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" HTML style comments
"
setlocal commentstring=<!--%s-->
setlocal comments=s:<!--,m:\ \ \ \ ,e:-->

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Folding sections with ATX style headers.
"
if !exists("g:pandoc_no_folding") || !g:pandoc_no_folding
	setlocal foldexpr=MarkdownLevel()
	setlocal foldmethod=expr
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Use ctrl-X ctrl-K for dictionary completions.
"
" This adds citation keys from a file named citationkeys.dict in the pandoc data dir to the dictionary.
" 
if eval("g:paths_style") == "posix"
	setlocal dictionary+=$HOME."/.pandoc/citationkeys.dict"
else
	setlocal dictionary+=%APPDATA%."\pandoc\citationkeys.dict"
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Autocomplete citationkeys using function
"
setlocal omnifunc=Pandoc_Complete

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Supertab support
"
if exists('g:SuperTabCompletionContexts')
  let b:SuperTabCompletionContexts =
    \ ['PandocContext'] + g:SuperTabCompletionContexts
endif
"
" disable supertab completions after bullets and numbered list
" items (since one commonly types something like `+<tab>` to 
" create a list.)
"
let b:SuperTabNoCompleteAfter = ['\s', '^\s*\(-\|\*\|+\|>\|:\)', '^\s*(\=\d\+\(\.\=\|)\=\)'] 

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Commands that call Pandoc
"
" ## Tidying Commands
"
" Markdown tidy with hard wraps
" (Note: this will insert an empty title block if no title block 
" is present; it will wipe out any latex macro definitions)

command! -buffer MarkdownTidyWrap %!pandoc -t markdown -s

" Markdown tidy without hard wraps
" (Note: this will insert an empty title block if no title block 
" is present; it will wipe out any latex macro definitions)

command! -buffer MarkdownTidy %!pandoc -t markdown --no-wrap -s

" Generate html and open in default html viewer
	
command! -buffer PandocHtmlOpen exec 'py pandoc_html_open()'

" Generate pdf and open in default pdf viewer

command! -buffer PandocPdfOpen exec 'py pandoc_pdf_open()'

" Generate odt and open in default odt viewer
	
command! -buffer PandocOdtOpen exec 'py pandoc_odt_open()'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Some <LocalLeader> mappings
"
" It <LocalLeader> is defined (with 'let maplocalleader') we will map some commands.
"
map <buffer><silent> <LocalLeader>html :PandocHtmlOpen<CR>
map <buffer><silent> <LocalLeader>pdf :PandocPdfOpen<CR>
map <buffer><silent> <LocalLeader>odt :PandocOdtOpen<CR>

" While I'm at it, here are a few more functions mappings that are useful when
" editing pandoc files.
"
" Open link under cursor in browser
"
map <buffer><silent> <LocalLeader>www :py pandoc_open_uri()<cr>

"" Jump forward to existing reference link (or footnote link)
map <buffer><silent> <LocalLeader>gr :py pandoc_go_to_ref()<cr>

"" Jump back to existing reference link (or fn link)
map <buffer><silent> <LocalLeader>br :py pandoc_go_back_from_ref()<cr>

"" Add new reference link (or footnote link) after current paragraph. (This
"" works better than the snipmate snippet for doing this.)
map <buffer><silent> <LocalLeader>nr ya[o<CR><ESC>p$a:


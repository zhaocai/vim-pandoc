"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ftplugin/pandoc.vim
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
python<<EOF
import vim
import sys
import re, string
from os.path import exists
from subprocess import Popen, PIPE

# platform dependent variables
if sys.platform == "darwin":
	open_command = "open" #OSX
elif sys.platform.startswith("linux"):
	open_command = "xdg-open" # freedesktop/linux
elif sys.platform.startswith("win"):
	open_command = 'cmd /x \"start' # Windows

# we might use this for adjusting paths
if sys.platform.startswith("win"):
	vim.command('let g:os = "win"')
else:
	vim.command('let g:os = "posix"')

# On windows, we pass commands as an argument to `start`, which is a cmd.exe builtin, so we have to quote it
if sys.platform.startswith("win"):
	open_command_tail = '"'
else:
	open_command_tail = ''

# This decorator takes a function named 'pandoc_FORMAT_open' which returns a list describing a command
# and returns a function that will open a file created by running that command.
def pandoc_opener(func):
	def wrapped():
		# the output file name is inferred from the name of the buffer and the name of the decorated function.
		out = vim.eval('expand("%:r")') + "." + func.func_name.split("_")[1]
		command_list = func(out) # the decorated function returns a list describing what to run
		# we run the command and retrieve its output
		output = Popen(command_list, stdout=PIPE, stderr=PIPE).communicate()

		# we create a temporary buffer where the command and its output will be shown
		
		# this builds a list of lines we are going to write to the buffer
		lines = [">> " + line for line in "\n".join(output).split("\n") if line != '']
		lines.insert(0, "▶ " + " ".join(command_list))
		lines.insert(0, "# Press <Esc> to close this ")

		# we always splitbelow
		splitbelow = bool(int(vim.eval("&splitbelow")))
		if not splitbelow:
			vim.command("set splitbelow")
		
		vim.command("3new")
		vim.current.buffer.append(lines)
		vim.command("normal dd")
		vim.command("setlocal nomodified")
		vim.command("setlocal nomodifiable")
		# pressing <esc> on the buffer will delete it
		vim.command("map <buffer> <esc> :bd<cr>")
		# we will highlight some elements in the buffer
		vim.command("syn match PandocOutputMarks /^>>/")
		vim.command("syn match PandocCommand /^▶.*$/hs=s+1")
		vim.command("syn match PandocInstructions /^#.*$/")
		vim.command("hi! link PandocOutputMarks Operator")
		vim.command("hi! link PandocCommand Statement")
		vim.command("hi! link PandocInstructions Comment")

		# we revert splitbelow to its original value
		if not splitbelow:
			vim.command("set nosplitbelow")

		# finally, we open the created file
		if exists(out):
			Popen([open_command, out + open_command_tail], stdout=PIPE, stderr=PIPE)
	return wrapped

@pandoc_opener
def pandoc_pdf_open(out=None):
	return ["markdown2pdf",  "-o", out, vim.current.buffer.name]

@pandoc_opener
def pandoc_html_open(out=None):
	return ["pandoc", "-t", "html",  "-sS",  "-o", out, vim.current.buffer.name]

@pandoc_opener
def pandoc_odt_open(out=None):
	return ["pandoc", "-t", "odt",  "-o", out, vim.current.buffer.name]
	
def pandoc_open_uri():
	# graciously taken from
	# http://stackoverflow.com/questions/1986059/grubers-url-regular-expression-in-python/1986151#1986151
	pat = r'\b(([\w-]+://?|www[.])[^\s()<>]+(?:\([\w\d]+\)|([^%s\s]|/)))'
	pat = pat % re.escape(string.punctuation)

	line = vim.current.line
	search = re.search(pat, line)
	if search:
		url = search.group()
		Popen([open_command, url], stdout=PIPE, stderr=PIPE)
		print url
	else:
		print "No URI found in line."

EOF
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Formatting options

" Soft word wrapping
setlocal formatoptions=1
setlocal linebreak

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

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Do not add two spaces at end of punctuation when joining lines
"
setlocal nojoinspaces
"
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Use pandoc to tidy up text
"
" If you use this on your entire file, it will wipe out title blocks.
" To preserve title blocks, use :MarkdownTidy instead. (If you use
" :MarkdownTidy on a portion of your file, it will insert unwanted title
" blocks...)
"

setlocal equalprg=pandoc\ -t\ markdown\ --reference-links

"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" HTML style comments
"
setlocal commentstring=<!--%s-->
setlocal comments=s:<!--,m:\ \ \ \ ,e:-->

"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Folding sections with ATX style headers.
"
" Taken from
" http://stackoverflow.com/questions/3828606/vim-markdown-folding/4677454#4677454
"
function! MarkdownLevel()
    if getline(v:lnum) =~ '^# .*$'
        return ">1"
    endif
    if getline(v:lnum) =~ '^## .*$'
        return ">2"
    endif
    if getline(v:lnum) =~ '^### .*$'
        return ">3"
    endif
    if getline(v:lnum) =~ '^#### .*$'
        return ">4"
    endif
    if getline(v:lnum) =~ '^##### .*$'
        return ">5"
    endif
    if getline(v:lnum) =~ '^###### .*$'
        return ">6"
    endif
    return "="
endfunction
setlocal foldexpr=MarkdownLevel()
setlocal foldmethod=expr
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Save folding between sessions
"
autocmd BufWinLeave * if expand(&filetype) == "pandoc" | mkview | endif
autocmd BufWinEnter * if expand(&filetype) == "pandoc" | loadview | endif
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Use ctrl-X ctrl-K for dictionary completions. This adds citation keys from
" ~/.pandoc/citationkeys.dict to the dictionary. 
" 
setlocal dictionary+=~/.pandoc/citationkeys.dict
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Autocomplete citationkeys using function
"
let s:completion_type = ''

function! Pandoc_Complete(findstart, base)
	if a:findstart
		" return the starting position of the word
		let line = getline('.')
		let pos = col('.') - 1
		while pos > 0 && line[pos - 1] !~ '\\\|{\|\[\|<\|\s\|@\|\^'
			let pos -= 1
		endwhile

		let line_start = line[:pos-1]
		if line_start =~ '.*@$'
			let s:completion_type = 'bib'
		endif
		return pos
	else
		"return suggestions in an array
		let suggestions = []
		if s:completion_type == 'bib'
			" suggest BibTeX entries
			let suggestions = Pandoc_BibComplete(a:base)
		endif
		return suggestions
	endif
endfunction

function! Pandoc_BibComplete(regexp)

	if !exists('g:PandocBibfile')
		if filereadable($HOME . '/.pandoc/default.bib')
			let g:PandocBibfile = $HOME . '/.pandoc/default.bib'
		elseif filereadable($HOME . '/Library/texmf/bibtex/bib/default.bib')
			let g:PandocBibfile = $HOME . '/Library/texmf/bibtex/bib/default.bib'
		elseif filereadable($HOME . '/texmf/bibtex/bib/default.bib')
			let g:PandocBibfile = $HOME . '/texmf/bibtex/bib/default.bib'
		else
			return []
		endif
	endif

	let res = split(Pandoc_BibKey(a:regexp))
	return res

endfunction

function! Pandoc_BibKey(partkey)
	let myres = ''
ruby << EOL
bib = VIM::evaluate('g:PandocBibfile')
string = VIM::evaluate('a:partkey')

File.open(bib) { |file|
	text = file.read
	keys = []
	keys = keys + text.scan(/@.*?\{(#{string}.*?),/i)
	keys.uniq!
	keys.sort!
	results = keys.join(" ")
	VIM::command('let myres = "' "#{results}" '"')
}
EOL
return myres
endfunction

setlocal omnifunc=Pandoc_Complete

if exists('g:SuperTabCompletionContexts')
  let b:SuperTabCompletionContexts =
    \ ['PandocContext'] + g:SuperTabCompletionContexts
  function! PandocContext()
		" return the starting position of the word
	let line = getline('.')
	let pos = col('.') - 1
	while pos > 0 && line[pos - 1] !~ '\\\|{\|\[\|<\|\s\|@\|\^'
		let pos -= 1
	endwhile
	if line[pos - 1] == "@"
		return "\<c-x>\<c-o>"
	endif
  endfunction
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

	command! MarkdownTidyWrap %!pandoc -t markdown -s

" Markdown tidy without hard wraps
" (Note: this will insert an empty title block if no title block 
" is present; it will wipe out any latex macro definitions)

	command! MarkdownTidy %!pandoc -t markdown --no-wrap -s

" Generate html and open in default html viewer
	
	command! PandocHtmlOpen exec 'py pandoc_html_open()'

" Generate pdf and open in default pdf viewer

	command! PandocPdfOpen exec 'py pandoc_pdf_open()'

" Generate odt and open in default odt viewer
	
	command! PandocOdtOpen exec 'py pandoc_odt_open()'

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Some suggested <Leader> mappings
"
" It is bad form to put <Leader> mappings in ftplugins. If you want to enable
" these mappings, put something like
" 
"   let g:PandocLeaders = 1
"
" in your .vimrc. Or just copy any you are interested in using into your vimrc.
"
if exists('g:PandocLeaders') 

	map <silent> <Leader>html :PandocHtmlOpen<CR>
	map <silent> <LEADER>pdf :PandocPdfOpen<CR>
	map <silent> <LEADER>odt :PandocOdtOpen<CR>

" While I'm at it, here are a few more functions mappings that are useful when
" editing pandoc files.
"
" Open link in browser (based on Gruber's url regex)
"
" (This isn't very pandoc-specific, but I use it in the next mapping below.)
"
	map <Leader>www :py pandoc_open_uri()<cr>

"" Open reference link in browser (depends on above mapping of <LEADER>w)
	map <Leader>wr ya[#<LEADER>www*

"" Jump forward to existing reference link (or footnote link)
	map <Leader>fr ya[#E

"" Jump back to existing reference link (or fn link)
	map <Leader>br {jwya[*E

"" Add new reference link (or footnote link) after current paragraph. (This
"" works better than the snipmate snippet for doing this.)

	map <Leader>nr ya[o<CR><ESC>p$a:

endif

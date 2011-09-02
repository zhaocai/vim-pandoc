"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" plugin/pandoc.vim
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 1. Pandoc commands
" ===================================================================
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
	vim.command('let g:paths_style = "win"')
else:
	vim.command('let g:paths_style = "posix"')

# On windows, we pass commands as an argument to `start`, which is a cmd.exe builtin, so we have to quote it
if sys.platform.startswith("win"):
	open_command_tail = '"'
else:
	open_command_tail = ''

def pandoc_open_uri():
	line = vim.current.line
	pos = vim.current.window.cursor[1] - 1
	url = ""
	
	# graciously taken from
	# http://stackoverflow.com/questions/1986059/grubers-url-regular-expression-in-python/1986151#1986151
	pat = r'\b(([\w-]+://?|www[.])[^\s()<>]+(?:\([\w\d]+\)|([^%s\s]|/)))'
	pat = pat % re.escape(string.punctuation)
	for match in re.finditer(pat, line):
		if match.start() - 1 <= pos and match.end() - 2 >= pos:
			url = match.group()
			break
	if url != '':
		Popen([open_command, url + open_command_tail], stdout=PIPE, stderr=PIPE)
		print url
	else:
		print "No URI found."

def pandoc_get_reflabel():
	pos = vim.current.window.cursor
	current_line = vim.current.line
	cursor_idx = pos[1] - 1
	label = None
	ref = None
	
	# we first search for explicit and non empty implicit refs
	label_regex = "\[.*\]"
	for label_found in re.finditer(label_regex, current_line):
		if label_found.start() -1 <= cursor_idx and label_found.end() - 2 >= cursor_idx:
			label = label_found.group()
			if re.match("\[.*?\]\[.*?]", label):
				if ref == '':
					ref = label.split("][")[0][1:]
				else:
					ref = label.split("][")[1][:-1]
				label = "[" + ref  + "]"
				break
	
	# we now search for empty implicit refs or footnotes
	if not ref:
		label_regex = "\[.*?\]"
		for label_found in re.finditer(label_regex, current_line):
			if label_found.start() - 1 <= cursor_idx and label_found.end() - 2 >= cursor_idx:
				label = label_found.group()
				break

	return label

def pandoc_go_to_ref():
	ref_label = pandoc_get_reflabel()
	if ref_label:
		ref = ref_label[1:-1]
		# we build a list of the labels and their position in the file
		labels = {}
		lineno = 0
		for line in vim.current.buffer:
			match = re.match("^\s?\[.*(?=]:)", line)
			lineno += 1
			if match:
				labels[match.group()[1:]] = lineno

		if labels.has_key(ref):
			vim.command(str(labels[ref]))

def pandoc_go_back_from_ref():
	label_regex = ''
	
	match = re.match("^\s?\[.*](?=:)", vim.current.line)
	if match:
		label_regex = match.group().replace("[", "\[").replace("]", "\]").replace("^", "\^")
	else:
		label = pandoc_get_reflabel()
		if label:
			label_regex = label.replace("[", "\[").replace("]", "\]").replace("^", "\^")
	
	if label_regex != '':
		found = False
		lineno = vim.current.window.cursor[0]
		for line in reversed(vim.current.buffer[:lineno-1]):
			lineno = lineno - 1
			matches_in_this_line = list(re.finditer(label_regex, line))
			for ref in reversed(matches_in_this_line):
				vim.command(str(lineno) + " normal" + str(ref.start()) + "l")
				found = True
				break
			if found:
				break

def pandoc_open(command):
	command = command.split()
	
	# first, we evaluate the output extension
	if command[0] == "markdown2pdf": # always outputs pdfs
		out_extension = "pdf"
	else:
		try:
			out_extension = command[command.index("-t") + 1]
		except ValueError:
			out_extension = "html"
	out = vim.eval('expand("%:r")') + "." + out_extension
	command.extend(["-o", out])
	command.append(vim.current.buffer.name)

	# we evaluate global vim variables. This way, we can register commands that 
	# pass the value of our variables (e.g, g:pandoc_bibfile).
	for value in command:
		if value.startswith("g:"):
			command[command.index(value)] = vim.eval(value)
	
	# we run pandoc with our arguments
	output = Popen(command, stdout=PIPE, stderr=PIPE).communicate()

	# we create a temporary buffer where the command and its output will be shown
	
	# this builds a list of lines we are going to write to the buffer
	lines = [">> " + line for line in "\n".join(output).split("\n") if line != '']
	lines.insert(0, "▶ " + " ".join(command))
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

# We register openers with PandocRegisterOpener. 
# It takes a variable ammount of arguments, but we take its first argument as the name of a vim
# ex command, the second argument as a mapping, and the rest as the description of a command, which
# we'll pass to pandoc_open.

# pandoc_register_opener(...) adds a tuple of those elements to a list of openers. This list will be 
# read from by ftplugin/pandoc.vim and commands and mappings will be created from it.
pandoc_openers = []
def pandoc_register_opener(com_ref):
	args = com_ref.split()
	name = args[0]
	mapping = args[1]
	command = args[2:]
	pandoc_openers.append((name, mapping, " ".join(command)))
EOF

command! -nargs=? PandocRegisterOpener exec 'py pandoc_register_opener("<args>")'
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 2. Folding
" ===============================================================================
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
	if getline(v:lnum) =~ '^[^-=].\+$' && getline(v:lnum+1) =~ '^=\+$'
		return ">1"
	endif
	if getline(v:lnum) =~ '^[^-=].\+$' && getline(v:lnum+1) =~ '^-\+$'
		return ">2"
	endif
    return "="
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" # Save folding between sessions
" 
" FM: I recommend `viewoptions` set to "folds,cursor" only. 
"  
if !exists("g:pandoc_no_folding") || !g:pandoc_no_folding
	autocmd BufWinLeave * if expand(&filetype) == "pandoc" | mkview | endif
	autocmd BufWinEnter * if expand(&filetype) == "pandoc" | loadview | endif
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 3. Completion
" =============================================================================
"
let s:completion_type = ''

function! Pandoc_Find_Bibfile()
	if !exists('g:pandoc_bibfile')
		if eval("g:paths_style") == "posix"
			if filereadable($HOME . '/.pandoc/default.bib')
				let g:pandoc_bibfile = $HOME . '/.pandoc/default.bib'
			elseif filereadable($HOME . '/Library/texmf/bibtex/bib/default.bib')
				let g:pandoc_bibfile = $HOME . '/Library/texmf/bibtex/bib/default.bib'
			elseif filereadable($HOME . '/texmf/bibtex/bib/default.bib')
				let g:pandoc_bibfile = $HOME . '/texmf/bibtex/bib/default.bib'
			else
				return []
			endif
		else
			if filereadable(%APPDATA% . '\pandoc\default.bib')
				let g:pandoc_bibfile = %APPDATA% . '\pandoc\default.bib'
			" TODO check other possible paths
			else
				return []
			endif
		endif
	endif
endfunction

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
			let suggestions = split(Pandoc_BibKey(a:base))
		endif
		return suggestions
	endif
endfunction

function! Pandoc_BibKey(partkey)
	let myres = ''
ruby << EOL
bib = VIM::evaluate('g:pandoc_bibfile')
string = VIM::evaluate('a:partkey')

File.open(bib) { |file|
	text = file.read
	keys = []
	keys = keys + text.scan(/@.*?\{[\s]*(#{string}.*?),/i)
	keys.uniq!
	keys.sort!
	results = keys.join(" ")
	VIM::command('let myres = "' "#{results}" '"')
}
EOL
return myres
endfunction

" Used for setting g:SuperTabCompletionContexts
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


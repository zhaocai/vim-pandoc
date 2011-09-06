"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Folding:
"
" Taken from
" http://stackoverflow.com/questions/3828606/vim-markdown-folding/4677454#4677454
"
function! pandoc#MarkdownLevel()
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
" Completion:

function! pandoc#Pandoc_Find_Bibfile()
	if !exists('g:pandoc_bibfile') || g:pandoc_bibfile == ""
		" A list of supported bibliographic database extensions, in reverse
		" order of priority:
		let bib_extensions = [ 'json', 'ris', 'mods', 'biblatex', 'bib' ]

		" Build up a list of paths to search, in reverse order of priority:
		"
		" First look for a file with the same basename as current file
		let bib_paths = [ expand("%:p:r") ]
		" Next look for a file with basename `default` in the same 
		" directory as current file
		let bib_paths = [ expand("%:p:h") . g:paths_sep ."default" ] + bib_paths
		" Next look for a file with basename `default` in the pandoc
		" data directory
		if eval("g:paths_style") == "posix"
			let bib_paths = [ $HOME . '/.pandoc/default' ] + bib_paths
		else
			let bib_paths = [ %APPDATA% . '\pandoc\default' ] + bib_paths
		endif
		" Next look in the local texmf directory
		if executable('kpsewhich')
			let local_texmf = system("kpsewhich -var-value TEXMFHOME")
			let local_texmf = local_texmf[:-2]
			let bib_paths = [ local_texmf . g:paths_sep . 'default' ] + bib_paths
		endif
		" Now search for the file!
		let g:pandoc_bibfile = ""
		for bib_path in bib_paths
			for bib_extension in bib_extensions
				if filereadable(bib_path . "." . bib_extension)
					let g:pandoc_bibfile = bib_path . "." . bib_extension
					let g:pandoc_bibtype = bib_extension
				endif
			endfor
		endfor
	else
	    let g:pandoc_bibtype = matchstr(g:pandoc_bibfile, '\zs\.[^\.]*')
	endif
endfunction

function! pandoc#Pandoc_Complete(findstart, base)
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
			let suggestions = pandoc#Pandoc_BibKey(a:base)
		endif
		return suggestions
	endif
endfunction

function! pandoc#Pandoc_BibKey(partkey) 
ruby << EOL
	bib = VIM::evaluate('g:pandoc_bibfile')
	bibtype = VIM::evaluate('g:pandoc_bibtype').downcase!
	string = VIM::evaluate('a:partkey')

	File.open(bib) { |file|
		text = file.read
		if bibtype == 'mods'
			# match mods keys
			keys = text.scan(/<mods ID=\"(#{string}.*?)\">/i)
		elsif bibtype == 'ris'
			# match RIS keys
			keys = text.scan(/^ID\s+-\s+(#{string}.*)$/i)
		elsif bibtype == 'json'
			# match JSON CSL keys
			keys = text.scan(/\"id\":\s+\"(#{string}.*?)\"/i)
		else
			# match bibtex keys
			keys = text.scan(/@.*?\{[\s]*(#{string}.*?),/i)
		end
		keys.flatten!
		keys.uniq!
		keys.sort!
		keystring = keys.inspect
		VIM::command('return ' + keystring )
	}
EOL
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Misc:
"
python<<EOF
import vim
import re, string
from subprocess import Popen, PIPE
EOF

function! pandoc#Pandoc_Open_URI()
python<<EOL
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
	Popen([pandoc_open_command, url + pandoc_open_command_tail], stdout=PIPE, stderr=PIPE)
	print url
else:
	print "No URI found."
EOL
endfunction

function! pandoc#Pandoc_Goto_Ref()
python<<EOL
ref_label = pandoc_get_reflabel()
if ref_label:
	ref = ref_label[1:-1]
	# we build a list of the labels and their position in the file
	labels = {}
	lineno = 0
	for line in vim.current.buffer:
		match = re.match("^\s*\[.*(?=]:)", line)
		lineno += 1
		if match:
			labels[match.group().strip()[1:]] = lineno

	if labels.has_key(ref):
		vim.command(str(labels[ref]))
EOL
endfunction

function! pandoc#Pandoc_Back_From_Ref()
python<<EOL
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
EOL
endfunction

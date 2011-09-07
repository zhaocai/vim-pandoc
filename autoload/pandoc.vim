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
python<<EOF
from os.path import exists, relpath, expandvars
from glob import glob
from subprocess import Popen, PIPE

bib_extensions = ["json", "ris", "mods", "biblates", "bib"]
file_name = ".".join(relpath(vim.current.buffer.name).split(".")[:-1])

# first, we check for files named after the current file in the current dir
bibfiles = [f for f in glob(file_name + ".*") if f.split(".")[-1] in bib_extensions]

# we search for any bibliography in the current dir
if bibfiles == []:
	bibfiles = [f for f in glob("*") if f.split(".")[-1] in bib_extensions]

# we seach in pandoc's local data dir
if bibfiles == []:
	b = ""
	if exists(expandvars("$HOME/.pandoc/")):
		b = expandvars("$HOME/.pandoc/")
	elif exists(expandvars("%APPDATA%/pandoc/")):
		b = expandvars("%APPDATA%/pandoc/")
	if b != "":
		bibfiles = [f for f in glob(b + "default.*") if f.split(".")[-1] in bib_extensions]

# we search for bibliographies in texmf
if bibfiles == []:
	texmf = Popen(["kpsewhich", "-var-value", "TEXMFHOME"], stdout=PIPE, stderr=PIPE).\
                communicate()[0].strip()
	if exists(texmf):
		bibfiles = [f for f in glob(texmf + "/*") if f.split(".")[-1] in bib_extensions]

# we append the items in g:pandoc_bibfiles, if set
if vim.eval("exists('g:pandoc_bibfiles')") != "0":
	bibfiles.expand(vim.eval("g:pandoc_bibfiles"))

vim.command("let b:pandoc_bibfiles = " + str(bibfiles))
EOF
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
		else
			let s:completion_type = ''
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
python<<EOF
import vim
import re
from os.path import basename
from operator import itemgetter

# we evaluate the local pandoc_bibfiles
bibs = vim.eval("b:pandoc_bibfiles")
string = vim.eval("a:partkey")

matches = []

for bib in bibs:
	# we guess tye bibliography type from the filename
	bib_type = basename(bib).split(".")[-1].lower()
	with open(bib, 'r') as f:
		text = f.read()

	ids = []
	if bib_type == "mods":
		import xml.etree.ElementTree as etree
		bib_data = etree.fromstring(text)
		# a MODS file can contain a single entry or a collection of entries
		if bib_data.tag == "mods":
			entry_id = bib_data.get("ID")
			if re.match(string, str(entry_id)):
				title = " ".join([s.strip() for s in bib_data.find("titleInfo").find("title").text.split("\n")])
				ids.append((str(entry_id), str(title)))
		elif bib_data.tag == "modsCollection":
			for mod in bib_data.findall("mods"):
				entry_id = mod.get("ID")
				if re.match(string, str(entry_id)):
					title = " ".join([s.strip() for s in mod.find("titleInfo").find("title").text.split("\n")])
					ids.append((str(entry_id), str(title)))
		#ids = re.findall("<mods ID=\"(?P<id>" + string + '.*)\"', text)
	elif bib_type == "ris":
		# RIS entries always end in "ER - \n", so we split there.
		bib_data = [entry for entry in re.split("ER\s*-\s*\n", text) if entry != ""]
		for entry in bib_data:
			entry_id = re.search("ID\s+-\s+(?P<id>.*)\n", entry).group("id")
			if re.match(string, str(entry_id)):
				entry_title = re.search("TI\s+-\s+(?P<id>.*)\n", entry).group("id")
				ids.append((entry_id, entry_title))
		#ids = re.findall("ID\s+-\s+(?P<id>" + string + ".*)", text)
	elif bib_type == "json":
		import json
		bib_data = json.loads(text)
		for entry in bib_data:
			if re.match(string, str(entry["id"])):
				ids.append((str(entry["id"]), str(entry["title"])))
		#ids = scan("\"id\":\s+\"(?P<id>"+ string + ".*)\"", text)
	else: # BibTeX file
		scanned_labels = re.findall("\@.*{(?P<id>.*),", text)
		scanned_titles = [title.replace("{", "").replace("}", "") 
							for title in re.findall("^\s*[tT]itle\s*=\s*{(?P<title>.*)},\n", text, 
											re.MULTILINE)]
		if len(scanned_titles) == len(scanned_labels):
			entries_data = zip(scanned_labels, scanned_titles)
			for entry in entries_data:
				if re.match(string, entry[0]):
					ids.append(entry)
		else:
			ids = re.findall("\@.*{(?P<id>" + string + ".*),", text)

	# we remove duplicates
	ids = list(set(ids))
	
	for i in ids:
		if i.__class__ is str:
			matches.append({"word": i})
		elif i.__class__ is tuple:
			matches.append({"word": i[0], "menu": i[1]})

# sort by key
matches = sorted(matches, key=itemgetter("word"))

vim.command("return " + matches.__repr__())
EOF
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
			vim.command(str(lineno) + " normal!" + str(ref.start()) + "l")
			found = True
			break
		if found:
			break
EOL
endfunction

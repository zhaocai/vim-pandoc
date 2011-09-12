python<<EOF
import vim
import sys
import re, string
from os.path import exists, relpath, basename
from subprocess import Popen, PIPE

# platform dependent variables
if sys.platform == "darwin":
	pandoc_open_command = "open" #OSX
elif sys.platform.startswith("linux"):
	pandoc_open_command = "xdg-open" # freedesktop/linux
elif sys.platform.startswith("win"):
	pandoc_open_command = 'cmd /x \"start' # Windows


def pandoc_execute(command, open_when_done=False):
	command = command.split()
	
	# first, we evaluate the output extension
	if basename(command[0]) in ("markdown2pdf", "panbeamer.py"): # always outputs pdfs
		out_extension = "pdf"
	else:
		try:
			out_extension = command[command.index("-t") + 1]
		except ValueError:
			out_extension = "html"
	out = vim.eval('expand("%:r")') + "." + out_extension
	command.extend(["-o", out])

	# we evaluate global vim variables. This way, we can register commands that 
	# pass the value of our variables (e.g, g:pandoc_bibfile).
	for value in command:
		if value.startswith("g:") or value.startswith("b:"):
			vim_value = vim.eval(value)
			if vim_value in ("", [], None):
				if command[command.index(value) - 1] == "--bibliography":
					command.remove(command[command.index(value) - 1])
					command.remove(value)
				else:
					command[command.index(value)] = vim_value
			else:
				if vim_value.__class__ is list:
					if value == "b:pandoc_bibfiles" \
								and command[command.index(value) -1] == "--bibliography":
						command.remove(command[command.index(value) - 1])
						command.remove(value)
						for bib in vim_value:
							command.append("--bibliography")
							command.append(relpath(bib))
				elif vim_value:
					command[command.index(value)] = vim_value

	command.append(relpath(vim.current.buffer.name))

	# we create a temporary buffer where the command and its output will be shown
	
	# this builds a list of lines we are going to write to the buffer
	lines = []
	lines.insert(0, "▶ " + " ".join(command))
	lines.insert(0, "# Press <Esc> to close this ")

	# we always splitbelow
	splitbelow = bool(int(vim.eval("&splitbelow")))
	if not splitbelow:
		vim.command("set splitbelow")
	
	vim.command("5new")
	vim.current.buffer.append(lines)
	vim.command("normal! dd")
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
	
	# we run pandoc with our arguments
	output = Popen(command, stdout=PIPE, stderr=PIPE).communicate()
	lines = [">> " + line for line in "\n".join(output).split("\n") if line != '']
	
	vim.current.buffer.append(lines)
	vim.command("setlocal nomodified")
	vim.command("setlocal nomodifiable")

	# finally, we open the created file
	if exists(out) and open_when_done:
		# On windows, we pass commands as an argument to `start`, 
		# which is a cmd.exe builtin, so we have to quote it
		if sys.platform.startswith("win"):
			pandoc_open_command_tail = '"'
		else:
			pandoc_open_command_tail = ''
		Popen([pandoc_open_command, out + pandoc_open_command_tail], stdout=PIPE, stderr=PIPE)

# We register openers with PandocRegisterExecutor. 
# We take its first argument as the name of a vim ex command, the second
# argument as a mapping, and the rest as the description of a command,
# which we'll pass to pandoc_open.

# pandoc_register_executor(...) adds a tuple of those elements to a list of
#executors. This list will be # read from by ftplugin/pandoc.vim and commands
#and mappings will be created from it.
pandoc_executors = []

def pandoc_register_executor(com_ref):
	args = com_ref.split()
	name = args[0]
	mapping = args[1]
	command = args[2:]
	pandoc_executors.append((name, mapping, " ".join(command)))
EOF

command! -nargs=? PandocRegisterExecutor exec 'py pandoc_register_executor("<args>")'

" We register here some default executors. The user can define other custom
" commands in his .vimrc.
"
" Generate html and open in default html viewer
PandocRegisterExecutor PandocHtml <LocalLeader>html pandoc -t html -Ss
" Generate pdf w/ citeproc and open in default pdf viewer
PandocRegisterExecutor PandocPdf <LocalLeader>pdf markdown2pdf --bibliography b:pandoc_bibfiles
" Generate odt w/ citeproc and open in default odt viewer
PandocRegisterExecutor PandocOdt <LocalLeader>odt pandoc -t odt --bibliography b:pandoc_bibfiles


" autoload/pandoc_exe.vim
"
" Defines pandoc_execute and pandoc_exec#PandocExecute, for executors
"
python<<EOF
import vim
import sys
import re, string
from os.path import exists, relpath, basename
from subprocess import call

def pandoc_execute(command, output_type="html", open_when_done=False):
	command = command.split()

	# first, we expand some tokens
	v_idx = 0
	for value in command:
		if value.startswith("%"): # tokens derived on current buffer name
			command[v_idx] = vim.eval("expand('" + value + "')")
		elif value.startswith("b:") or value.startswith("g:"): # global or local variables
			if int(vim.eval("exists('" + value + "')")) > 0:
				val = vim.eval(value)
				if val.__class__ is str:
					command[v_idx] = val
				elif val.__class__ is list:
					# we only process b:pandoc_bibfiles
					if value == "b:pandoc_bibfiles" and command[v_idx -1] == "--bibliography":
						# we must rewrite the bibliography args, so every bibfile is passed
						command[v_idx - 1] = ""
						command[v_idx] = ""
						for bib in reversed(val):
							i = "--bibliography " + bib
							command.insert(v_idx, i)
				else:
					commad[v_idx] = "" # anything else, we exclude
			else:
				# sometimes b:padoc_bibfiles is undefined
				if command[v_idx - 1] == "--bibliography":
					command[v_idx - 1] = ""
				command[v_idx] = ""
		v_idx += 1

	# this is a list of every command in the pipe
	pipe_elements = [line.strip() for line in " ".join([c for c in command if c != ""]).split("|")]
	
	# we must correct the output command so it writes the correct file
	outputter = pipe_elements[-1].split()
	prog = basename(outputter[0])
	if prog in ("pandoc", "markdown2pdf", "panbeamer.py"):
		if prog in ("markdown2pdf", "panbeamer.py"):
			out_extension = "pdf"
		else:
			try:
				out_extension = outputter[outputter.index("-t") + 1]
			except ValueError:
				out_extension = output_type
		out = vim.eval('expand("%:r")') + "." + out_extension
		if len(outputter) > 1:
			outputter.insert(-1, "-o " + out)
		else:
			outputter.append("-o "+ out)
	else:
		out_extension = output_type
		out = vim.eval('expand("%:r")') + "." + out_extension
		# we assume these commands print to stdout.
		# we redirect to the output file.
		outputter.apped("> " + out) 

	pipe_elements[-1] = " ".join(outputter)

	# if we haven't already specified the current buffer as the pipe input, we must add it
	real_command = " | ".join(pipe_elements).split()
	if vim.current.buffer.name not in real_command:
		real_command.append(relpath(vim.current.buffer.name))

	# we buld the string we'll call
	command_str = " ".join(real_command)
	print command_str

	# we create a temporary buffer where the command and its output will be shown
	
	# we always splitbelow
	splitbelow = bool(int(vim.eval("&splitbelow")))
	if not splitbelow:
		vim.command("set splitbelow")
	
	vim.command("5new")
	vim.current.buffer[0] = "# Press <Esc> to close this"
	vim.current.buffer.append("▶ " + " ".join(command))
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
	
	# we run the command
	try:
		retval = call(real_command, shell=True)
	except OSError, e:
		vim.current.buffer.append("Couldn't execute the command")
		return
	
	if exists(out):
		vim.current.buffer.append(">> Created " + out)
	
	vim.command("setlocal nomodified")
	vim.command("setlocal nomodifiable")

	# finally, we open the created file
	if open_when_done:
		if sys.platform == "darwin":
			pandoc_open_command = "open" #OSX
		elif sys.platform.startswith("linux"):
			pandoc_open_command = "xdg-open" # freedesktop/linux
		elif sys.platform.startswith("win"):
			pandoc_open_command = 'cmd /x \"start' # Windows
		# On windows, we pass commands as an argument to `start`, 
		# which is a cmd.exe builtin, so we have to quote it
		if sys.platform.startswith("win"):
			pandoc_open_command_tail = '"'
		else:
			pandoc_open_command_tail = ''
			
		call(pandoc_open_command + out + pandoc_open_command_tail)
EOF

function! pandoc_exec#PandocExecute(command, type, open_when_done)
python<<EOF
pandoc_execute(vim.eval("a:command"), vim.eval("a:type"), bool(int(vim.eval("a:open_when_done"))))
EOF
endfunction

" Vim syntax file
" Language:	Pandoc (superset of Markdown)
" Maintainer: Felipe Morales <hel.sheep@gmail.com>
" Maintainer: David Sanson <dsanson@gmail.com> 	
" OriginalAuthor: Jeremy Schultz <taozhyn@gmail.com>
" Version: 4.0
" Remark: Complete rewrite.

if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

syntax case match
syntax spell toplevel
" TODO: optimize
syn sync fromstart 

syn match pandocTitleBlock /\%^\(%.*\n\)\{1,3}$/ skipnl

"""""""""""""""""""""""""""""""""""""""""""""
" Header:
"
syn match pandocAtxHeader /^\s*#\{1,6}.*\n/ contains=pandocEmphasis
syn match pandocSetexHeader /^.\+\n[=]\+$/
syn match pandocSetexHeader /^.\+\n[-]\+$/

"""""""""""""""""""""""""""""""""""""""""""""
" Blockquotes:
"
syn match pandocBlockQuote /^>.*\n\(.*\n\@<!\n\)*/ skipnl

""""""""""""""""""""""""""""""""""""""""""""""
" Code Blocks:
"
syn match pandocCodeBlock   /^\(\s\{4,}\|\t\{1,}\).*\n/
syn region pandocDelimitedCodeBlock start=/^\z(\~\+\)\( {.\+}\)*/ end=/\z1\~*/ skipnl contains=pandocDelimitedCodeBlockLanguage
syn match pandocDelimitedCodeBlockLanguage /{.\+}/ contained containedin=pandocDelimitedCodeBlock
syn match pandocCodePre /<pre>.\{-}<\/pre>/ skipnl
syn match pandocCodePre /<code>.\{-}<\/code>/ skipnl

"""""""""""""""""""""""""""""""""""""""""""""""
" List Items:
"
" TODO: support roman numerals
syn match pandocListItem /^\s*\([*+-]\|\((*\d\+[.)]\+\)\|\((*\a[.)]\+\)\)\s\+/he=e-1

"""""""""""""""""""""""""""""""""""""""""""""""
" Links:
syn region pandocLinkArea start=/\[.\{-}\]\@<=\(:\|(\|\[\)/ skip=/\(\]\(\[\|(\)\|\]: \)/ end=/\(\(\]\|)\)\|\(^\s*\n\|\%^\)\)/ contains=pandocLinkText,pandocLinkURL,pandocLinkTitle,pandocAutomaticLink
syn match pandocLinkText /\[\@<=.\{-}\]\@=/ containedin=pandocLinkArea contained contains=@Spell
" TODO: adapt gruber's regex to match URLs; the current regex is quite limited
syn match pandocLinkURL /https\{0,1}:.\{-}\()\|\s\|\n\)\@=/ containedin=pandocLinkArea contained
syn match pandocAutomaticLink /<\(https\{0,1}.\{-}\|.\{-}@.\{-}\..\{-}\)>/
syn match pandocLinkTextRef /\(\]\(\[\|(\)\)\@<=.\{-}\(\]\|)\)\@=/ containedin=pandocLinkText contained
syn match pandocLinkTitle /".\{-}"/ contained containedin=pandocLinkArea contains=@Spell
" This can be expensive on very large files, so we should be able to disable
" it:
if !exists("g:pandoc_no_empty_implicits") || !g:pandoc_no_empty_implicits
" will highlight implicit references only if, on reading the file, it can find
" a matching reference label. This way, square parenthesis in a file won't be
" highlighted unless they will be turned into links by pandoc.
" So in:
"
"     This is a test (a test [a test]) for [implicit refs].

"     [implicit refs]: http://johnmacfarlane.net/pandoc/README.html#reference-links
"
" only [implicit links] will be highlighted.
" If labels change, the file must be reloaded in order to highlight their
" implicit reference links.
python <<EOF
import re
ref_label_pat = "^\s?\[.*(?=]:)"
labels = []
for line in vim.current.buffer:
	match = re.match(ref_label_pat, line)
	if match:
		labels.append(match.group()[1:])
regex = "\(" + r"\|".join(["\[" + label + "\]" for label in labels]) + "\)"
vim.command("syn match pandocLinkArea /" + regex + r"[ \.,;\t\n-]\@=/")
EOF
endif
"""""""""""""""""""""""""""""""""""""""""""""""
" Rules: TODO
"""""""""""""""""""""""""""""""""""""""""""""""
" Definitions:
"
syn match pandocDefinitionBlock /^.*\n\(^\s*\n\)*[:~]\s\{2,}.*\n\(^\s\{3,}.*\n\)*/ skipnl contains=pandocDefinitionBlockTerm 
syn match pandocDefinitionBlockTerm /^.*\n\(^\s*\n\)*[:~]\@=/ contained containedin=pandocDefinitionBlock
syn match pandocDefinitionBlockMark /^[:~]/ contained containedin=pandocDefinitionBlock
""""""""""""""""""""""""""""""""""""""""""""""
" Footnotes: TODO
""""""""""""""""""""""""""""""""""""""""""""""
" Tables: TODO
""""""""""""""""""""""""""""""""""""""""""""""
" Citations:
" parenthetical citations
syn match pandocPCite /\[-\?@.\{-}\]/ contains=pandocEmphasis,pandocStrong,pandocLatex,@Spell
" syn match pandocPCite /\[\w.\{-}\s-\?.\{-}\]/ contains=pandocEmphasis,pandocStrong
" in-text citations without location
syn match pandocPCite /@\w*/
" in-text citations with location
syn match pandocPCite /@\w*\s\[.\{-}\]/
"""""""""""""""""""""""""""""""""""""""""""""""
" Text Styles: TODO
"
" emphasis
" strong
" tt
" subscripts
" superscript
" stikeout
"""""""""""""""""""""""""""""""""""""""""""""""

hi link pandocTitleBlock Directory
hi link pandocAtxHeader Title
hi link pandocSetexHeader Title

hi link pandocBlockQuote Comment
hi link pandocCodeBlock String
hi link pandocDelimitedCodeBlock String
hi link pandocDelimitedCodeBlockLanguage Comment
hi link pandocCodePre String
hi link pandocListItem Operator

hi link pandocLinkArea		Special
hi link pandocLinkText		Type
hi link pandocLinkURL	Underlined
hi link pandocLinkTextRef Underlined
hi link pandocLinkTitle Identifier
hi link pandocAutomaticLink Underlined

hi link pandocDefinitionBlockTerm Identifier
hi link pandocDefinitionBlockMark Operator

hi link pandocPCite Label

let b:current_syntax = "pandoc"

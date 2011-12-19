augroup ftdetect_pandoc
    au!
    au BufNewFile,BufRead *.markdown,*.md,*.mkd,*.pd,*.pdk,*.pandoc,*.text   setfiletype pandoc
augroup END

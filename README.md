# r_indent_gvf
My Alternative R-indent for vim

The default R indent code for vim is part of a 
larger package that provides a lot of functionality.
The indent code itself doesn't respect some conventions
that I prefer, so this is my alternative.

To use add the following to your .vimrc

:autocmd FileType r setlocal indentexpr=RIndent_GVF(v:lnum)

and put r.vim in your .vim/indent directory.



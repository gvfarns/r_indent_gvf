""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Vim indent file for R language
" Language:    R
" Maintainer:  Grant Farnsworth
" Created:     2013 Apr 5
" Last Change: 2013 Apr 5
"
" At present it makes these choices:
"   1. Comments are indented just like regular code
"   2. Indentation after ( an [ aligns with the next character after the ( or [
"   3. Multiline quotes are indented just line regular code (I would fix this but % doesn't work with ")
"   4. Assignment is by <-.  using = for assignment may indent multiline expressions incorrectly in some cases
"
" TODO:
"   1. Write code to handle multiline quotes
"   2. Write code for multiline -> cases (they rarely come up)
"   3. Consider improving indenting for use of = for assignment
"   4. Open if else clauses need some work
"   5. probably should have marker for previous code line begin instead of just physical lines
"
" New Issues:
"   * 161 indent should be SW past the if, not past the line
"   * 317 indent should be SW past the if, not past the line
"   * 84 indent should check whether if associated with else has something before it
"   * 126 hard to fix quoting problem
"   * 302 this looks fixable
"   * 262
"
" IMMEDIATE TODO: all lines before indenting should check whether previous line was open if
" TODO: known bug: unmatched } locks up indent algorithm
"
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" only load when no other indent is loaded
if exists("b:r_indent_gvf")
  finish
endif
let b:r_indent_gvf = 1

" tell vim the name of our indent function
setlocal indentexpr=RIndent_GVF(v:lnum)

" if these keys are entered in insert mode, reindent the line
setlocal indentkeys={,},!^F,o,O,e,=else

" don't keep redefining the function
if exists("*RIndent_GVF")
  finish
endif

" this variable dictates whether debug messages will be echoed
let s:debug_mode = 0

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" function to return the previous line that's not blank or a comment
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:GetPrevNonCommentLineNum( line_num )
  " regular expression denoting a comment
  let skip_lines = '\m^\s*#'
  " find previous non-blank line
  let nline = a:line_num
  while nline > 0
    let nline = prevnonblank(nline-1)
    if getline(nline) !~? skip_lines
      break
    endif
  endwhile
  return nline
endfunction " s:GetPrevNonCommentLineNum


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" uses vim's % command to find a matching character for what's
" under the cursor
"
" Cursor location input is zero indexed
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:FindMatch(in_line,in_col)
  " save current cursor location
  let mycol = col(".")
  let myline = line(".")

  " to go starting point
  call cursor(a:in_line,a:in_col+1)

  " find matching par
  normal! %

  " save match locations
  let matchline = line(".")
  let matchcol = col(".")

  " temporary debug
  if matchline=myline && matchcol=mycol
    echom "FindMatch could not find a match on line " . myline
  endif

  " go back to where we were
  call cursor(myline,mycol)

  " return -1 if we fail, otherwise match position
  if myline==matchline && mycol==matchcol
    return [ -1, -1 ]
  else
    return [ matchline, matchcol ]
  endif

endfunction " findmatch

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" takes line and column of a } as its argument
" uses vim's % to find the match for it, then returns the line
" of the beginning of that statement (for use with indent())
"
" Before {} should come one of the following:
"    if ()
"    function()
"    for()
"    while()
"    repeat
"    else
"
" in_col is zero indexed
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:FindMatchCurlyStatement(in_line,in_col)
  " save current cursor location
  let mycol = col(".")
  let myline = line(".")

  " first find the matching {
  let firstcurly = s:FindMatch(a:in_line,a:in_col)

  " i is column number and jj is line number
  let i = firstcurly[1]-1
  let jj = firstcurly[0]
  let tmpline = s:ZapQuotesAndComments(getline(jj))

  " in case the match was in position 0
  if i < 0
    let jj -= 1
    let tmpline = s:ZapQuotesAndComments(getline(jj))
    let i = strlen(tmpline)-1
  endif

  " loop
  while jj > 0
    " echom 'row ' . jj . ' col ' . i . ' Char: (' . tmpline[i] . ") Line: " . tmpline

    " skip over { and (
    if tmpline[i] == '{' || tmpline[i] == '('
      if i > 0
        let i -=1
      else
        let jj -= 1
        let tmpline = s:ZapQuotesAndComments(getline(jj))
        let i = strlen(tmpline) -1
      endif
      continue
    endif

    " skip over white space
    if tmpline[i] == ' ' || tmpline[i] =="\t"
      if i > 0
        let i -= 1
      else
        let jj -= 1
        let tmpline = s:ZapQuotesAndComments(getline(jj))
        let i = strlen(tmpline) -1
      endif
      continue
    endif

    " if we found ) skip to the other side
    if tmpline[i] == ')'
        let tmpcoords = s:FindMatch(jj,i)
        " echom 'Found a Paren from ' . jj . '(' . i . ') to (' . tmpcoords[1] . ') on ' .  tmpcoords[0]
        if i > 0
          let i = tmpcoords[1]-1
          let jj = tmpcoords[0]
          let tmpline = s:ZapQuotesAndComments(getline(jj))
        else
          let jj = tmpcoords[0] - 1
          let tmpline = s:ZapQuotesAndComments(getline(jj))
          let i = strlen(tmpline)-1
        endif
        continue
        "  return tmpcoords[0]
    endif

    " curly could happen if we saw an else
    if tmpline[i] == '}'
      let tmpcoords = s:FindMatch(jj,i)
      "echom "Match for curly" . tmpcoords[0] . ' ' . tmpcoords[1]
      if i >= 0
        let i = tmpcoords[1]-1
        let jj = tmpcoords[0]
        let tmpline = s:ZapQuotesAndComments(getline(jj))
        let i = strlen(tmpline)-1
      else
        let jj -= 1
        let tmpline = s:ZapQuotesAndComments(getline(jj))
        let i = strlen(tmpline)-1
      endif
      "echom 'Found a Curly'
      continue
    endif

    " did we find one of the key words?
    " else, for, if, while, function, repeat
    if tmpline[i] =~ '\m[efrnt]'
      " check for else
      if i > 3 && tmpline[(i-3):i] == 'else'
        let i -= 4
        if i < 0
          let jj -= 1
          let tmpline = s:ZapQuotesAndComments(getline(jj))
          let i = strlen(tmpline) -1
        endif
        continue
      endif

      " check for for
      if i > 2 && tmpline[(i-2):i] == 'for'
        " echom "Found for "
        let tmp = s:IsOpenIndent(jj-1)
        if tmp[0]==1
          " echom "got in and doing it right"
          return tmp[1]
        else
          return jj
        endif
      endif

      " check for function
      if i > 7 && tmpline[(i-7):i] == 'function'
        " echom "Found Function"
        let tmp = s:IsOpenIndent(jj-1)
        if tmp[0]==1
          " echom "got in and doing it right"
          return tmp[1]
        else
          return jj
        endif
      endif

      " check for repeat
      if i > 5 && tmpline[(i-5):i] == 'repeat'
        let tmp = s:IsOpenIndent(jj-1)
        if tmp[0]==1
          " echom "got in and doing it right"
          return tmp[1]
        else
          return jj
        endif
      endif

      " check for  while
      if i > 4 && tmpline[(i-4):i] == 'while'
        let tmp = s:IsOpenIndent(jj-1)
        if tmp[0]==1
          " echom "got in and doing it right"
          return tmp[1]
        else
          return jj
        endif
      endif

      " some kind of strange case.  I guess just return this line
      echom "Interior Strange case at line " in_line
      return jj
    endif

    " if we got here some strange hud happened  just return the line
    echom "Strange case"
    return jj

  endwhile

  " if we got here there was nothing before that up to the beginning of the file
  return -1

endfunction " FindMatchCurlyStatement


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" this function edits a line of text, checks if double and single quotes are
" matched and deletes everything inside of them if there are an even number (of each kind)
"
" if quotes are unmatches, they are ignored.
" Double quotes are done first, then single
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:ZapQuotesAndComments( line_code )

  " local variable name
  let my_code = a:line_code

  " outline is temporary storage
  let outline = my_code

  " Zap anything in double quotes
  if my_code =~ '\m"' && ( float2nr(fmod(strlen(substitute(my_code,'[^"]',"","g")),2)) == 0 )
    let i = 0
    let killing = 0
    let outline = ""
    let llen = strlen(my_code)
    while i < llen
      if my_code[i] == '"'
        if killing == 0
          let killing = 1
        else
          let killing = 0
          let outline = outline . 'S'
          let i += 1
          continue
        endif
      endif
      if killing == 1
        let outline = outline . 'S'
      else
        let outline = outline . my_code[i]
      endif
      let i += 1
    endwhile
    let my_code  = outline
  endif

  "
  " Zap anything in single quotes
  if my_code =~ '\m''' && float2nr(fmod(strlen(substitute(my_code,'[^'']',"","g")),2)) == 0
    let i = 0
    let killing = 0
    let outline = ""
    let llen = strlen(my_code)
    while i < llen
      if my_code[i] == "'"
        if killing == 0
          let killing = 1
        else
          let killing = 0
          let outline = outline . 'S'
          let i += 1
          continue
        endif
      endif
      if killing == 1
        let outline = outline . 'S'
      else
        let outline = outline . my_code[i]
      endif
      let i += 1
    endwhile
    let my_code  = outline
  endif

  " Strip out comments
  if my_code =~ '\m#'
    let my_code = substitute( my_code, '#.*$',"","g")
  endif

  " return the zapped version
  return my_code

endfunction " ZapQuotesAndComments

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" This function determines whether the given line ends a an open indent
" command, which is either a for, if, while, or function without any
" curly brackets following.
"
" It returns a list. The first element is whether or not it is an open
" indent command and the second is the line number at which the command begins,
" which in most cases is equal to the line passed in.
"
" This function recusively calls itself to get to the first such open
"
" The purpose of this function is to allow us to find how far back to unindent
"
" This function still needs some work
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:IsOpenIndent(this_line)
  if s:debug_mode
    echom "Entered IsOpenIndent: " . a:this_line
  endif
  " strip stuff out as usual
  let myline = s:ZapQuotesAndComments(getline(a:this_line))

  " check for ending with <-
  if myline =~ '\m<-\s*$'
    if s:debug_mode
      echom "Open Indent found at "  . a:this_line
    endif
    return[1,a:this_line]
  endif

  " check for else
  if myline =~ '\melse\s*$'
    " TODO need to follow this through to the if
    if s:debug_mode
      echom "Open Indent found at "  . a:this_line
    endif
    return [1,a:this_line]
  endif

  " check for repeat
  if myline =~ '\mrepeat\s*$'
    let prevopen= s:IsOpenIndent(s:GetPrevNonCommentLineNum(a:this_line))
    if prevopen[0]
      return prevopen
    else
      if s:debug_mode
        echom "Open Indent found at "  . a:this_line
      endif
      return [1,a:this_line]
    endif
  endif

  " open indents making it this far always end in parens
  " echom "MYLINE: (" . a:this_line . ") " . myline
  if myline !~ '\m)\s*$'
    " echom "Death zone: " . myline
    return [0,0]
  endif

  " it ended in a paren, search back
  let endparcolumn = match(myline,'\m)\s*$')
  let matchline = s:FindMatch(a:this_line,endparcolumn)
  if s:debug_mode
    echom "endparcolumn " . endparcolumn
    echom "Matchline was originally " . matchline[0] . " and " . matchline[1]
  endif

  "
  " check if previous paren is preceded by function, for, if, or while
  "

  " extract the part of the line leading up to the ( so we can tell what it is
  let secondline = s:ZapQuotesAndComments(getline(matchline[0]))
  let firstpart = strpart(secondline,0,matchline[1])

  " first see if this is a paren by itself.  If so, go back to previous line
  " TODO this should check that the first match is also the match from above
  if firstpart =~ '\m^\s*('
    let matchline = s:GetPrevNonCommentLineNum(matchline)
    let firstpart = s:ZapQuotesAndComments(getline(matchline[0]))
  endif

  if s:debug_mode
    echom "got to first part"
    echom "matchline: " . matchline[0]
    echom "FIrst Part: " . firstpart
  endif

  " check whether firstpart was indented because of previous line
  let doublecheck =  s:IsOpenIndent(s:GetPrevNonCommentLineNum(matchline[0]))
  if doublecheck[0]==1
    if s:debug_mode
      echom "Found Previous indent at" . doublecheck[1]
    endif
    return doublecheck
  endif

  " now check whether firstpart is an if, for, while, or function line
  if firstpart =~ '\m\<for\>\s*(\s*$' || firstpart =~ '\m\<if\>\s*(\s*$' || firstpart =~ '\m\<while\>\s*(\s*$' || firstpart =~ '\m\<function\>\s*(\s*$'
    if s:debug_mode
      echom "Got in"
      echom "Open Indent found at "  . matchline[0]
    endif
    return [ 1, matchline[0] ]
  endif

  " if we got here, it's not indented
  return [ 0, 0]

endfunction " IsOpenIndent


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" count how many net open items there are (can be negative)
" openc EXCLUDES the pattern we want to count '[^(]' for example
" closec EXCLUDES the pattern we want to count '[^)]' for example
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:CountOpens( this_line, openc, closec )
  " first, strip out any trailing comments
  let myline = s:ZapQuotesAndComments(getline(a:this_line))

  " calculate number of opens and closes
  let lineopens = strlen(substitute(myline,a:openc,"","g"))
  let linecloses = strlen(substitute(myline,a:closec,"","g"))
  return lineopens - linecloses
endfunction " CountOpens

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" function to find previous line that matches a regular expression
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:FindPrev(this_line,reg)
  let i = a:this_line
  while i >= 0 && (getline(i) !~ a:reg) && getline(i) !~ '\m^\s*$'
    let i -= 1
  endwhile
  return i
endfunction " FindPrev

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" function to find unbalanced character and return its column
" there should be more openc than closec in this_line
"
" GVF: this should return last one, not first
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:GetUnbalancedCol( this_line, openc, closec )

  " zap quotes
  let myline = s:ZapQuotesAndComments(getline(a:this_line))

  " remove openc, closec pairs
  let llength = strchars(myline)
  let i = 0
  let opens = [ ]
  while i < llength
    " add to list of open paren
    if myline[i] == a:openc
      let opens = opens + [ i ]
    endif
    " if this is a close paren, remove last open
    if myline[i] == a:closec && len(opens) > 0
      let opens = opens[ 0 : -2]
    endif
    " increment
    let i += 1
  endwhile

  " return the last open paren or -1 if we failed
  if len(opens) <= 0
    return -1
  else
    return opens[-1]
  endif
endfunction " GetUnbalancedCol

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" function to find last unbalanced character and return its column
" there should be more closec than openc in this_line
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:GetUnbalancedCloseCol( this_line, openc, closec )

  " zap quotes
  let myline = s:ZapQuotesAndComments(getline(a:this_line))

  " remove openc, closec pairs
  let llength = strchars(myline)
  let i = llength
  let closes = [ ]
  while i >= 0
    " add to list of closed paren locations
    if myline[ i] == a:closec
      let closes = closes + [ i ]
    endif
    " if this is a close paren, remove last open
    if myline[i] == a:openc && len(closes) > 0
      let closes = closes[ 0 : -2]
    endif
    " increment
    let i -= 1
  endwhile

  " return the last close paren or -1 if we failed
  if len(closes) <= 0
    return -1
  else
    return closes[0] + 1
  endif
endfunction " GetUnbalancedCloseCol

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" This function takes as its argument the line and column of the beginning of
" a command (either an open curly or an R command of some time).  It searches
" backward to find the immediately previous if, while, repeat, for, or function
" and returns its line and the column at which the word begins.
"
" column counting is 0 indexed
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:GetStatementBegin(this_line, this_col)

  " start at the line and column given us
  let linecounter = a:this_line
  let colcounter = a:this_col
  let linetext = s:ZapQuotesAndComments(getline(a:this_line))

  if s:debug_mode
    echom "Started at : "  . linecounter . ' ' . colcounter
  endif

  " loop backward until we find the preceding word
  while linecounter > 0

    if s:debug_mode
      echom ': ' . linecounter . ' ' . colcounter
    endif

    " check for whitespace
    if linetext[colcounter] =~ "\s"
      " Move backward
      if colcounter == 0
        let linecounter -= 1
        let linetext = s:ZapQuotesAndComments(getline(linecounter))
        let colcounter = len(linetext)
      else
        let colcounter -= 1
      endif
      continue
    endif

    " check for ) or }.  Zoom past if we find one
    if linetext[colcounter] == ')' || linetext[colcounter] == '}'

      if s:debug_mode
        echom "Finding match"
      endif
      let tmpstuff = s:FindMatch(linecounter,colcounter)
      if tmpstuff[0] < 0
        echom "ERROR: count not find match in GetStatementBegin"
      endif
      let linecounter = tmpstuff[0]
      let colcounter = tmpstuff[1]-1
      let linetext = s:ZapQuotesAndComments(getline(linecounter))
      continue
    endif

    " check for else, zoom backward if we find one
    if linetext[colcounter] == 'e' && colcounter > 2 && linetext[(colcounter-3):colcounter] == 'else'
      let colcounter -= 3
      " Move backward
      if colcounter <= 0
        let linecounter -= 1
        let linetext = s:ZapQuotesAndComments(getline(linecounter))
        let colcounter = len(linetext)
      else
        let colcounter -= 1
      endif
      continue
    endif

    " check for for, return if we find one
    if linetext[colcounter] == 'r' && colcounter > 1 && linetext[(colcounter-2):colcounter] == 'for'
      let colcounter -= 2
      return [linecounter,colcounter]
    endif

    " check for if, return if we find it (need to check that it's not an else if
    if linetext[colcounter] == 'f' && colcounter > 0 && linetext[(colcounter-1):colcounter] == 'if'
      let colcounter -= 1
      return [linecounter,colcounter]
    endif

    " check for function, return if we find one
    if linetext[colcounter] == 'n' && colcounter > 6 && linetext[(colcounter-7):colcounter] == 'function'

      if s:debug_mode
        echom "Finding Function"
      endif
      let colcounter -= 7
      return [linecounter,colcounter]
    endif

    " check for while, return if we find it
    if linetext[colcounter] == 'e' && colcounter > 3 && linetext[(colcounter-4):colcounter] == 'while'
      let colcounter -= 4
      return [linecounter,colcounter]
    endif

    " check for repeat, return if we find it
    if linetext[colcounter] == 't' && colcounter > 4 && linetext[(colcounter-5):colcounter] == 'repeat'
      let colcounter -= 5
      return [linecounter,colcounter]
    endif

    " Move backward
    if colcounter <= 0
      let linecounter -= 1
      let linetext = s:ZapQuotesAndComments(getline(linecounter))
      let colcounter = len(linetext)
    else
      let colcounter -= 1
    endif

  endwhile

endfunction " s:GetStatementBegin()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" External function: Calls RIndent_Internal but preserves view
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! RIndent_GVF( line_num )

  " remember current window view so we don't unexpectedly scroll
  let l:winview = winsaveview()
  if s:debug_mode
    echom "Saved View"
  endif

  " call the main code to determine the indent level
  let indentlev = s:RIndent_Internal( a:line_num )

  " restore view as it was
  call winrestview(l:winview)

  " return the desired indent level
  return indentlev

endfunction " RIndent_GVF

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Main function: returns indent level for current line
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:RIndent_Internal( line_num )

  " first line in the file is always not indented
  if a:line_num == 1
    if s:debug_mode
      echom "Marker -1"
    endif
    return 0
  endif


  """
  " Preparation
  """


  " get clean version of this line, previous, and previous previous
  let this_code = s:ZapQuotesAndComments(getline(a:line_num))
  let prev_codeline_num = s:GetPrevNonCommentLineNum( a:line_num )
  let prev_code = s:ZapQuotesAndComments(getline(prev_codeline_num))
  let prev_prev_codeline_num = s:GetPrevNonCommentLineNum( prev_codeline_num )
  let prev_prev_code = s:ZapQuotesAndComments(getline(prev_prev_codeline_num))

  " starting point for indenting
  let idt = indent( prev_codeline_num)

  " debug
  if s:debug_mode
    echom "PrevPrev: " . prev_prev_code
    echom "Prev: " . prev_code
  endif

  """""
  " This line begins with closing bracket or paren (indent to its match)
  """""

  " Check if this line begins with }
  if this_code =~ '\m^\s*}'
    let col_loc = match(this_code,'\m}')
    let match_loc = s:FindMatchCurlyStatement(a:line_num,col_loc)
    let idt = indent(match_loc)
    if s:debug_mode
      echom "Marker 0 " . match_loc
    endif
    return idt
  endif

  " Check if this line begins with )
  if this_code =~ '\m^\s*)'
    let col_loc = match(this_code,'\m)')
    let match_loc = s:FindMatch(a:line_num,col_loc)
    let idt = match_loc[1]-1
    if s:debug_mode
      echom "Marker 2"
    endif
    return idt
  endif

  " Check if this line begins with ]
  if this_code =~ '\m^\s*]'
    let col_loc = match(this_code,'\m]')
    let match_loc = s:FindMatch(a:line_num,col_loc)
    let idt = match_loc[1]-1
    if s:debug_mode
      echom "Marker 3"
    endif
    return idt
  endif

  """""
  "  Quick check for { at beginning of line
  "  (indent to beginning of prev if/for/while) or to the line if it's a function
  """""
  if this_code =~ '\m^\s*{'
    let col_loc = match(this_code,'{') -1
    let idt = indent(s:GetStatementBegin(a:line_num,col_loc)[0])
    if s:debug_mode
      echom "Marker 3.5"
    endif
    return idt
  endif

  """""
  " Check if previous line implies greater indent for this one
  """""

  if prev_code =~ '\m[\[({]'
    " faster version of most common case: indent once if previous line ends in {
    if prev_code =~ '\m)\s*{\s*$'
      let col_loc = match(prev_code,'\m).\{-}$')
      let match_loc = s:FindMatch(prev_codeline_num,col_loc)
      let idt = indent(match_loc[0]) + &sw
      if s:debug_mode
        echom "Marker 4"
      endif
      return idt
    elseif prev_code =~ '\melse\s*{\s*$'
      let idt +=  &sw
      if s:debug_mode
        echom "Marker 4.5"
      endif
      return idt
    else " less common case where it is internal

      " Check if there is any unbalanced paren or bracket
      let unbalancedcurly = s:CountOpens(prev_codeline_num,'[^{]','[^}]')
      let unbalancedsquare = s:CountOpens(prev_codeline_num,'[^[]','[^\]]')
      let unbalancedparen = s:CountOpens(prev_codeline_num,'[^(]','[^)]')

      " if there are unbalanced things and it doesn't end in {, figure out what to do
      if ( unbalancedcurly > 0 || unbalancedsquare > 0 || unbalancedparen > 0 )

        " here we store column locations of last bracket/paren
        let lastcurlycolumn = -1
        let lastparencolumn = -1
        let lastsquarecolumn = -1

        " find match of last unbalanced, so we can only indent to the last one
        if unbalancedcurly
          let lastcurlycolumn = s:GetUnbalancedCol(prev_codeline_num,"{","}")
        endif
        if unbalancedparen
          let lastparencolumn = s:GetUnbalancedCol(prev_codeline_num,"(",")")
        endif
        if unbalancedsquare
          let lastsquarecolumn = s:GetUnbalancedCol(prev_codeline_num,"[","]")
        endif

        " if { is last, indent once
        if lastcurlycolumn > max([lastparencolumn, lastsquarecolumn])
          let idt += &sw
          if s:debug_mode
            echom "Marker 5"
          endif
          return idt
        else
          let idt = max([lastsquarecolumn,lastparencolumn]) + 1
          if s:debug_mode
            echom "Marker 6"
          endif
          return idt
        endif
      endif
    endif
  endif


  """""
  " Check for completion of indent because of brackets and parens
  """""

  if prev_code =~ '\m[)\]}]'
    " Check fast check for common case first
    if prev_code =~ '\m}\s*$'
      let col_loc = match(prev_code,'\m}\s*$')+1
      let match_loc = s:FindMatchCurlyStatement(prev_codeline_num,col_loc)
      let second_loc = s:IsOpenIndent(match_loc)
      if second_loc[0]
        let idt = indent(second_loc[1])
        if s:debug_mode
          echom "Marker 7.1 :" . match_loc
        endif
        return idt
      else
        let idt = indent(match_loc)
        if s:debug_mode
          echom "Marker 7.2 :" . match_loc
        endif
        return idt
      endif

    else " less common cases (internal curly, square bracket, or close paren)

      " count unbalanced number of close brackets or parens
      let unbalancedcurly = -1 * s:CountOpens(prev_codeline_num,'[^{]','[^}]')
      let unbalancedsquare = -1 * s:CountOpens(prev_codeline_num,'[^[]','[^\]]')
      let unbalancedparen = -1 * s:CountOpens(prev_codeline_num,'[^(]','[^)]')

      if s:debug_mode
        echom "Unbalanced: " . unbalancedcurly . " " . unbalancedsquare . " " . unbalancedparen
      endif

      " if there are unbalanced things figure out what to do
      if  unbalancedcurly > 0 || unbalancedsquare > 0 || unbalancedparen > 0

        " here we store column locations of last closing bracket/paren
        let lastcurlycolumn = -1
        let lastparencolumn = -1
        let lastsquarecolumn = -1

        " find last unbalanced, so we can only indent to the last one
        if unbalancedcurly
          let lastcurlycolumn = s:GetUnbalancedCloseCol(prev_codeline_num,"{","}") -1
        endif
        if unbalancedparen
          let lastparencolumn = s:GetUnbalancedCloseCol(prev_codeline_num,"(",")") -1
        endif
        if unbalancedsquare
          let lastsquarecolumn = s:GetUnbalancedCloseCol(prev_codeline_num,"[","]") -1
        endif

        " if curlys are the last one, get the appropriate line
        if lastcurlycolumn > lastparencolumn && lastcurlycolumn > lastsquarecolumn
          let matchline = s:FindMatchCurlyStatement(prev_codeline_num,lastcurlycolumn)
          let second_loc = s:IsOpenIndent(matchline)
          if second_loc[1]
            let idt = indent(second_loc)
            if s:debug_mode
              echom "Marker 8.1 :" . match_loc
            endif
            return idt
          else
            let idt = indent(matchline)
            if s:debug_mode
              echom "marker 8.0"
            endif
            return idt
          endif
        endif

        " handle paren case
        if lastcurlycolumn < lastparencolumn && lastparencolumn > lastsquarecolumn
          let thisindent = s:IsOpenIndent(prev_codeline_num)
          let matchline = s:FindMatch(prev_codeline_num,lastparencolumn)
          if s:debug_mode
            echom "prev_codeline_num was" . prev_codeline_num
            echom "lastparencolumn" . lastparencolumn
          endif

          " if it was indented just find immedate match and indent to there
          if thisindent[0]
            if matchline[0] >= 0
              if s:debug_mode
                echom "Marker 8.7.1 to line " . matchline[0]
              endif
              return (indent(matchline[0]))
            else
              if s:debug_mode
                echom "Marker 8.7.2"
              endif
              return (indent(prev_codeline_num) )
            endif
          else
            if matchline[0] >= 0
              if s:debug_mode
                echom "matchlineline was" . matchline[0]
                echom "matchlinecol was" . matchline[1]
                echom "Marker 8.8.1"
              endif
              return indent(matchline[0])
            else
              echo "Marker 8.8.2"
              return indent(prev_codeline_num)
            endif
          endif
        endif

        " handle square case
        let matchline = s:FindMatch(prev_codeline_num,(max([lastparencolumn,lastsquarecolumn])-1))
        if matchline[0] >= 0
          return indent(matchline[0])
          if s:debug_mode
            echom "Using Default"
          endif
        else
          return indent(prev_codeline_num)
          if s:debug_mode
            echom "Adjusting"
          endif
        endif

      endif
    endif
  endif

  """"""
  " Unbracketed if/else situations.  These need some work.
  """"""

  let prev_is_open = s:IsOpenIndent(prev_codeline_num)
  let prev_prev_is_open = s:IsOpenIndent(prev_prev_codeline_num)

  " check if previous line opens an indent
  if prev_is_open[0]==1
    if this_code !~ '\m^\s*{'
      if s:debug_mode
        echom "Marker 11"
      endif
      return idt + &sw
    else
      if s:debug_mode
        echom "Marker 11.5"
      endif
      return idt
    endif
  endif

  " If previous line is an else by itself and this one is not a bracket, indent
  if prev_code =~ '\m^\s*else\s*$' && prev_code !~ '\m{[^}]*$' && this_code !~ '\m{'
    let idt += &sw
    if s:debug_mode
      echom "Marker 12"
    endif
    return idt
  endif

  " handle indenting of else line.  Match the previous if
  if this_code =~ '\m\s*else\>'
    let tmp_num = s:FindPrev(prev_codeline_num,'\m\<if\>')
    if tmp_num >=0
      let idt = indent(tmp_num)
      if s:debug_mode
        echom "Marker 13"
      endif
      return idt
    endif
  endif

  " more careful check in case the line before that even
  "if prev_code !~ '\m\<if\>' && prev_code !~ '\m\<for\>' && prev_code !~ '\m\<while\>' && prev_code !~ '\m\<function\>'
  if prev_is_open[0] != 1 && prev_prev_is_open[0] == 1
    if s:debug_mode
      echom "Indent is " . prev_prev_is_open[0] . " and " . prev_prev_is_open[1]
      echom "Marker 14"
    endif
    return indent(prev_prev_is_open[1])
  endif

  """""
  " Previous end of line ends with an operator
  """""

  " if previous line ends in arrow, indent once, I guess
  if prev_code =~ '\m<-\s*$'
    if s:debug_mode
      echom "marker 9.0"
    endif
    return indent(prev_codeline_num) + &sw
  endif

  " if previous line ends in operator, find the previous arrow and indent that far
  if prev_code =~ '\m[*\-+/%]\s*$' && prev_code !~ '\m<-\s*$'
    let tmp_num = s:FindPrev(prev_codeline_num,'\m<-')
    let col_loc = match(getline(tmp_num),'\m<-') + 3
    let idt = col_loc
    if s:debug_mode
      echom "Marker 9" . col_loc -3 . " " . tmp_num
    endif
    return idt
  endif

  " If previous previous line ends in operator but this one doesn't, search back for arrow
  if prev_prev_code =~ '\m.*[*\-+/%]\s*$' && prev_code !~ '\m.*[*\-+/%]\s*$' && prev_prev_code !~ '\m<-\s*$'
    let tmp_num = s:FindPrev(prev_codeline_num,'\m<-')
    if tmp_num >= 0
      let idt = indent(tmp_num)
      if s:debug_mode
        echom "Marker 10"
      endif
      return idt
    endif
  endif


  """""
  " return our computed indent level
  """""
  if idt >= 0
    if s:debug_mode
      echom "Marker 15"
    endif
    return idt
  else
    if s:debug_mode
      echom "Marker 16"
    endif
    return 0
  endif

  " go back to original window view so we don't unexpectedly scroll
  echom "Called restore view"

endfunction " RIndent




if !exists('g:clang_sh_exe')
	let g:clang_exe= 'clang'
endif

if !exists('g:clang_options')
	let g:clang_options = '-I ./include -I ../include'
endif

if !exists('g:clang_auto')
	let g:clang_auto = 1
endif

if !exists('g:clang_project')
	let g:clang_project = 'clang_pro'
endif

if !exists('g:clang_use_global')
	let g:clang_use_global = 1
endif

if !exists('g:clang_auto_path_set')
	let g:clang_auto_path_set=1
endif

if !exists('g:clang_auto_map')
	let g:clang_auto_map=1
endif

if !exists('g:clang_auto_tab')
	let g:clang_auto_tab=1
endif

if !empty('completeopt')
	exe 'set completeopt=menuone,longest'
endif

au FileType c,cpp,java call <SID>ClangInit()

func! s:CompleteDot()
	if getline('.')[col('.') - 2]=~# '[_0-9a-zA-Z]'
		return ".\<C-x>\<C-o>"
	endif
	return '.'
endf

func! s:CompleteArrow()
	if getline('.')[col('.') - 2] == '-'
		return ">\<C-x>\<C-o>"
	endif
	return '>'
endf

func! s:CompleteColon()
	if getline('.')[col('.') - 2] == ':'
		return ":\<C-x>\<C-o>"
	endif
	return ':'
endf

func! s:ClangGtagsCscope()
    set csprg=gtags-cscope
    let s:command = "cs add " . b:pro_root . "/GTAGS"
    let s:option = ''
    let s:option = s:option . 'C'   "ignore case
    let s:option = s:option . 'a'  "absolute path
    let s:option = s:option . 'i'  "keep alive
    let s:command = s:command . ' . -' . s:option
    set nocscopeverbose
    exe s:command
    set cscopeverbose
endf

func! s:HCppSwitch()
	let l:name=expand('%:e')
	if (l:name=='h') || (l:name=='hpp') || (l:name=='H')
		exe "cs find f ".expand('%:t:r').".c" 
	endif
	if (l:name=='c') || (l:name=='cpp') || (l:name=='cc') || (l:name=='cxx') || (l:name=='C') || (l:name=='CPP') 
		exe "cs find f ".expand('%:t:r').".h" 
	endif
endf

func! s:ClangInit()
	if &filetype == 'java'
		setl omnifunc=javacomplete#Complete		"ctrl-x-o
	else
		setl omnifunc=ClangComplete			"ctrl-x-o
	endif

	let b:cwd = fnameescape(getcwd())
	let b:fwd = fnameescape(expand('%:p:h'))
	exe 'lcd ' . b:fwd

	let l:pro  = findfile(g:clang_project, '.;')       "recursive find file from parent dir
	if filereadable(l:pro)
		com! ClangSaveSession   call <SID>ClangSaveSession()
		com! ClangLoadSession   call <SID>ClangLoadSession()
		com! HCppSwitch call <SID>HCppSwitch()
		com! ClangErr call <SID>ClangErr()
		
		let l:file = readfile(l:pro)
		for l:line in l:file
			exe 	l:line	
		endfor
		
		let b:pro_root = fnameescape(fnamemodify(l:pro, ':p:h'))   
		exe 'lcd ' . b:pro_root		
		
		if g:clang_auto_path_set
			exe 'set path+='.b:pro_root.'/**'     
		endif

		if exists('g:clang_use_pch')
			let l:pch  = b:pro_root . "/clang_pro.pch"
			if !filereadable('clang_pro.pch')        
				let l:tmp_h  = b:pro_root . "/temp_clang_pro.h"			
				call writefile(split(g:clang_use_pch,'\n'),l:tmp_h )	
				let l:command = printf('%s -x c++-header %s -fno-exceptions -fnu-runtime -o %s',g:clang_exe,l:tmp_h,l:pch)
				let l:clang_output = system(l:command)
				call delete(l:tmp_h)
			endif
			let g:clang_options .= ' -include-pch ' . l:pch 
		endif

		if g:clang_use_global
			if !filereadable('GTAGS')    
				if has('win32')&&(&shell=~'cmd')
					call system( 'set GTAGSFORCECPP=1 & start gtags' )
				else
					call system( 'export GTAGSFORCECPP=1;gtags&' )
				endif 
			endif
			call s:ClangGtagsCscope()
		endif
	else
		let b:pro_root = b:fwd   
	endif  	
	exe 'lcd ' . b:fwd  
	"cd to current sourcefile path for gnu global can work well 

	if &filetype == 'c'
		let g:clang_options .= ' -x c '
	elseif &filetype == 'cpp'
		let g:clang_options .= ' -x c++ -std=c++11 '
	endif

	" Use it when re-initialize plugin if .clang_pro is changed
	com! ClangInit   call <SID>ClangInit()

	if g:clang_auto   " Auto completion
		if &filetype == 'java'  " Auto completion  java
		   inoremap <expr> <buffer> . <SID>CompleteDot()
		else
                   inoremap <expr> <buffer> . <SID>CompleteDot()
		   inoremap <expr> <buffer> > <SID>CompleteArrow()
			if &filetype == 'cpp'   " Auto completion  cpp
				inoremap <expr> <buffer> : <SID>CompleteColon()
			endif
		endif
	endif
endf

func! s:ClangErr()   
	if &filetype == 'java'
		let [l:clang_stdout, l:clang_stderr]=s:ClangExecute( g:clang_options, 0, 1) 
	else
		let [l:clang_stdout, l:clang_stderr]=s:ClangExecute( g:clang_options, 0, 0) 
	endif
		cgete l:clang_stderr  "out quickfix window
		if len(l:clang_stderr)
			exe "copen"
	endif
	endf

func! ClangComplete(findstart, base)  
	if a:findstart
		silent update!         "write to file for clang compile
		let l:line = getline('.')
		let l:col = col('.')-1 
		if l:line[l:col] =~# '[.>:]'
			return l:col
		endif
		while l:col > 0 && l:line[l:col - 1] =~# '[_0-9a-zA-Z]'  " find valid ident
			let l:col -= 1
		endwhile
		return l:col
	endif  

	let [l:clang_stdout, l:clang_stderr]=s:ClangExecute( g:clang_options, line('.'), col('.')) 
	cgete l:clang_stderr  "out quickfix window

	let l:res = []
	let l:baselen = strlen(a:base)
	for l:line in l:clang_stdout
		"in stdout start is COMPLETION: len is 12 follow with name : proto
		let l:s = stridx(l:line, ':', 13)
		let l:word  = l:line[12 : l:s-2]
		if l:word[0]=='_'
			continue
		endif
		let l:proto = l:line[l:s+2 : -1]
		let l:proto = substitute(l:proto, '\(<#\)\|\(#>\)\|#', '', 'g') 
		"remove # in the complete line

		if l:baselen == 0
			call add(l:res, { 'word': l:word,'menu': l:proto,'info': l:proto, 'dup' : 1 })
		else
			if l:word[0 : l:baselen-1] ==# a:base 
				call add(l:res, { 'word': l:word,'menu': l:proto,'info': l:proto, 'dup' : 1 })
			endif	
		endif
	endfor
	return l:res    "out complete menu
endf

func! s:ClangExecute(clang_options, line, col)
	let l:src = shellescape(expand('%:p'))
	if (a:line==0)&&(a:col==0)
		let l:command = printf('%s -c -w -fsyntax-only  %s %s',g:clang_exe,a:clang_options,l:src)
	else
		if (a:line==0)&&(a:col==1)
			let l:command = printf('javac -d ~/ -classpath %s %s',g:java_classpath,l:src)
			"let l:command = printf('javac -d /tmp  %s',l:src)
		else
			let l:command = printf('%s -cc1 -fsyntax-only -code-completion-macros -code-completion-at=%s:%d:%d %s %s',
					\ g:clang_exe, l:src, a:line, a:col, a:clang_options, l:src)
		endif
	endif
	let l:tmps = [tempname(), tempname()]
	let l:command .= ' 1>'.l:tmps[0].' 2>'.l:tmps[1]

	if has('win32')&&(&shell=~'cmd')
		let s:cmd_tmpfile=fnamemodify(tempname(), ':h') . "/tmp_clang_complete.cmd"
		call writefile([l:command],s:cmd_tmpfile,"b")
		let l:command= '"' . s:cmd_tmpfile . '"'   
	endif
	exe 'lcd ' . b:pro_root		
	call system(l:command)
	exe 'lcd ' . b:fwd  
	let l:res = []
	let l:i = 0
	while l:i < len(l:tmps)
		call add(l:res, readfile(l:tmps[ l:i ]))
		call delete(l:tmps[ l:i ])
		let l:i = l:i + 1
	endwhile
	return l:res
endf

func!  s:ClangSaveSession()
        exe "mks! ".b:pro_root."/ClangSession.vim"			   
endf

func!  s:ClangLoadSession()	
        exe "source " . b:pro_root . "/ClangSession.vim"
endf

if g:clang_auto_map == 1
	nmap ,d :Gtags -a <C-R>=expand("<cword>")<CR><CR>  
	nmap ,r :Gtags -a -r -s <C-R>=expand("<cword>")<CR><CR>   	   
	let g:Gtags_Auto_Update = 1
	nmap ,h :HCppSwitch<CR>
	nmap ,s :ClangSaveSession<CR>
	nmap ,l :ClangLoadSession<CR>
	nmap ,m :make<CR>
	nmap ,e :ClangErr<CR>
endif


"使用tab完成模板，代码ctrl-x-o完成，选取完成菜单，大括号分行
if g:clang_auto_tab == 1
	inoremap <tab> <c-r>=TemplateComplete()<cr><c-r>=SwitchRegion()<CR>
endif
let s:var_name=""
let s:template_name=""

function! SwitchRegion()
    if strlen(s:var_name) != 0
	let pos=line('.')
	exe "%s/".s:var_name."/".s:template_name."/eg"  
	"同名变量实现整体替换
        call cursor(pos,0)
    endif 
    if pumvisible()  "存在popup menu改变为选取功能
	return "\<Down>"
    endif
    if search('`<' ) != 0 	
        normal v
        call search('>`','e',line('.'))
	normal y
	let s:var_name = @"
 	return "\<ESC>gvo\<c-g>"
	"gv选取上一次选取的内容o位置移动到开头，<c-g>切换选取和可视模式，实现直接输入。
    else
	if (getline('.')[col('.')-1] == '}') && (getline('.')[col('.')-2] == '{')
		return "\<ENTER>\<ESC>\<Up>o"
	endif
	if (getline('.')[col('.')-2] =~ '\w')&&(getline('.')[col('.')-3] =~ '\w')
	"输入前两个为字符实现智能补全
		return "\<C-x>\<C-o>"
	endif
        return "\<tab>"
    endif
endfunction

function! TemplateComplete()
    let s:template_name = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
	"\zs表示开头\ze表示结尾，\W匹配单词字母之外的任意字符 \w匹配单词  .*匹配任意字符，$行尾 替换掉了行尾单词前所有内容
    if has_key(g:template,&ft)
        if has_key(g:template[&ft],s:template_name)
	    let s:var_name=""
            return  "\<c-w>" . g:template[&ft][s:template_name]
        endif
    endif
    if has_key(g:template['_'],s:template_name)
	let s:var_name=""
        return  "\<c-w>" . g:template['_'][s:template_name]
    endif
    return ""
endfunction


let g:template = {}
let g:template['_'] = {}
let g:template['_']['dt'] = "\<c-r>=strftime(\"%Y-%m-%d %H:%M:%S\")"


let g:template['c'] = {}
let g:template['c']['mai'] = "int main(int argc, char \*argv\[\])\<cr>{\<cr>`<1>`\<cr>}"
let g:template['c']['if']="if(`<1>`)\<cr>{\<cr>`<2>`\<cr>}"
let g:template['c']['ife']="if(`<1>`)\<cr>{\<cr>`<2>`\<cr>}else\<cr>{\<cr>`<3>`\<cr>}"
let g:template['c']['whi']="while(`<1>`)\<cr>{\<cr>`<2>`\<cr>}"
let g:template['c']['dow']="do\<cr>{\<cr>`<1>`\<cr>}while(`<2>`)"
let g:template['c']['swi']="switch(`<1>`)\<cr>{\<cr>case `<2>`:\<cr>break;\<cr>case `<3>`:\<cr>break;\<cr>case `<4>`:\<cr>break;\<cr>default: `<5>`\<cr>}"
let g:template['c']['for']="for(`<1>`;`<2>`;`<3>`)\<cr>{\<cr>`<4>`\<cr>}"
let g:template['cpp'] = g:template['c']
let g:template['cpp']['foi']="for(int i=0;i<`<1>`;++i)\<cr>{\<cr>`<2>`\<cr>}"
let g:template['cpp']['cl']="class `<classname>`\<cr>{\<cr>public:\<cr>`<classname>`();\<cr>~`<classname>`();\<cr>private:\<cr>`<1>`\<cr>};"
let g:template['cpp']['tem']="template<typename T`<1>`>\<cr>`<2>`"
let g:template['java'] = {}
let g:template['java'] = g:template['c']
let g:template['java']['mai'] = "public static void main(String[] arg)\<cr>{\<cr>`<1>`\<cr>}"
let g:template['java']['cl']="class `<classname>`\<cr>{\<cr>`<1>`\<cr>}"
let g:template['java']['tem']="class `<classname>`<`<1>`>{\<cr>`<2>`\<cr>}"



""""""""""""""""""""""""""""""""""below add from gtags.vim"""""""""""""""""""""""""""""""""""
if exists("loaded_gtags")
    finish
endif
let loaded_gtags = 1
"
" global command name
"
let s:global_command = $GTAGSGLOBAL
if s:global_command == ''
        let s:global_command = "global"
endif
" Open the Gtags output window.  Set this variable to zero, to not open
" the Gtags output window by default.  You can open it manually by using
" the :cwindow command.
" (This code was drived from 'grep.vim'.)
if !exists("g:Gtags_OpenQuickfixWindow")
    let g:Gtags_OpenQuickfixWindow = 1
endif

if !exists("g:Gtags_VerticalWindow")
    let g:Gtags_VerticalWindow = 0
endif

if !exists("g:Gtags_Auto_Update")
    let g:Gtags_Auto_Update = 0
endif

if !exists("g:Gtags_No_Auto_Jump")
    if !exists("g:Dont_Jump_Automatically")
	let g:Gtags_No_Auto_Jump = 0
    else
	let g:Gtags_No_Auto_Jump = g:Dont_Jump_Automatically
    endif
endif

" -- ctags-x format 
" let Gtags_Result = "ctags-x"
" let Gtags_Efm = "%*\\S%*\\s%l%\\s%f%\\s%m"
"
" -- ctags format 
" let Gtags_Result = "ctags"
" let Gtags_Efm = "%m\t%f\t%l"
"
" Gtags_Use_Tags_Format is obsoleted.
if exists("g:Gtags_Use_Tags_Format")
    let g:Gtags_Result = "ctags"
    let g:Gtags_Efm = "%m\t%f\t%l"
endif
if !exists("g:Gtags_Result")
    let g:Gtags_Result = "ctags-mod"
endif
if !exists("g:Gtags_Efm")
    let g:Gtags_Efm = "%f\t%l\t%m"
endif
" Character to use to quote patterns and file names before passing to global.
" (This code was drived from 'grep.vim'.)
if !exists("g:Gtags_Shell_Quote_Char")
    if has("win32") || has("win16") || has("win95")
        let g:Gtags_Shell_Quote_Char = '"'
    else
        let g:Gtags_Shell_Quote_Char = "'"
    endif
endif
if !exists("g:Gtags_Single_Quote_Char")
    if has("win32") || has("win16") || has("win95")
        let g:Gtags_Single_Quote_Char = "'"
        let g:Gtags_Double_Quote_Char = '\"'
    else
        let s:sq = "'"
        let s:dq = '"'
        let g:Gtags_Single_Quote_Char = s:sq . s:dq . s:sq . s:dq . s:sq
        let g:Gtags_Double_Quote_Char = '"'
    endif
endif

"
" Display error message.
"
function! s:Error(msg)
    echohl WarningMsg |
           \ echomsg 'Error: ' . a:msg |
           \ echohl None
endfunction
"
" Extract pattern or option string.
"
function! s:Extract(line, target)
    let l:option = ''
    let l:pattern = ''
    let l:force_pattern = 0
    let l:length = strlen(a:line)
    let l:i = 0

    " skip command name.
    if a:line =~ '^Gtags'
        let l:i = 5
    endif
    while l:i < l:length && a:line[l:i] == ' '
       let l:i = l:i + 1
    endwhile 
    while l:i < l:length
        if a:line[l:i] == "-" && l:force_pattern == 0
            let l:i = l:i + 1
            " Ignore long name option like --help.
            if l:i < l:length && a:line[l:i] == '-'
                while l:i < l:length && a:line[l:i] != ' '
                   let l:i = l:i + 1
                endwhile 
            else
                while l:i < l:length && a:line[l:i] != ' '
                    let l:c = a:line[l:i]
                    let l:option = l:option . l:c
                    let l:i = l:i + 1
                endwhile 
                if l:c == 'e'
                    let l:force_pattern = 1
                endif
            endif
        else
            let l:pattern = ''
            " allow pattern includes blanks.
            while l:i < l:length
                 if a:line[l:i] == "'"
                     let l:pattern = l:pattern . g:Gtags_Single_Quote_Char
                 elseif a:line[l:i] == '"'
                     let l:pattern = l:pattern . g:Gtags_Double_Quote_Char
                 else
                     let l:pattern = l:pattern . a:line[l:i]
                 endif
                let l:i = l:i + 1
            endwhile 
            if a:target == 'pattern'
                return l:pattern
            endif
        endif
        " Skip blanks.
        while l:i < l:length && a:line[l:i] == ' '
               let l:i = l:i + 1
        endwhile 
    endwhile 
    if a:target == 'option'
        return l:option
    endif
    return ''
endfunction

"
" Trim options to avoid errors.
"
function! s:TrimOption(option)
    let l:option = ''
    let l:length = strlen(a:option)
    let l:i = 0

    while l:i < l:length
        let l:c = a:option[l:i]
        if l:c !~ '[cenpquv]'
            let l:option = l:option . l:c
        endif
        let l:i = l:i + 1
    endwhile
    return l:option
endfunction

"
" Execute global and load the result into quickfix window.
"
function! s:ExecLoad(option, long_option, pattern)
    " Execute global(1) command and write the result to a temporary file.
    let l:isfile = 0
    let l:option = ''
    let l:result = ''

    if a:option =~ 'f'
        let l:isfile = 1
        if filereadable(a:pattern) == 0
            call s:Error('File ' . a:pattern . ' not found.')
            return
        endif
    endif
    if a:long_option != ''
        let l:option = a:long_option . ' '
    endif
    let l:option = l:option . '--result=' . g:Gtags_Result . ' -q'
    let l:option = l:option . s:TrimOption(a:option)
    if l:isfile == 1
        let l:cmd = s:global_command . ' ' . l:option . ' ' . g:Gtags_Shell_Quote_Char . a:pattern . g:Gtags_Shell_Quote_Char
    else
        let l:cmd = s:global_command . ' ' . l:option . 'e ' . g:Gtags_Shell_Quote_Char . a:pattern . g:Gtags_Shell_Quote_Char 
    endif

    let l:result = system(l:cmd)
    if v:shell_error != 0
        if v:shell_error != 0
            if v:shell_error == 2
                call s:Error('invalid arguments. please use the latest GLOBAL.')
            elseif v:shell_error == 3
                call s:Error('GTAGS not found.')
            else
                call s:Error('global command failed. command line: ' . l:cmd)
            endif
        endif
        return
    endif
    if l:result == '' 
        if l:option =~ 'f'
            call s:Error('Tag not found in ' . a:pattern . '.')
        elseif l:option =~ 'P'
            call s:Error('Path which matches to ' . a:pattern . ' not found.')
        elseif l:option =~ 'g'
            call s:Error('Line which matches to ' . a:pattern . ' not found.')
        else
            call s:Error('Tag which matches to ' . g:Gtags_Shell_Quote_Char . a:pattern . g:Gtags_Shell_Quote_Char . ' not found.')
        endif
        return
    endif

    " Open the quickfix window
    if g:Gtags_OpenQuickfixWindow == 1
        if g:Gtags_VerticalWindow == 1
            topleft vertical copen
        else
            botright copen
        endif
    endif
    " Parse the output of 'global -x or -t' and show in the quickfix window.
    let l:efm_org = &efm
    let &efm = g:Gtags_Efm
    if g:Gtags_No_Auto_Jump == 1
        cgete l:result
    else
        cexpr! l:result
    endif
    let &efm = l:efm_org
endfunction

"
" RunGlobal()
"
function! s:RunGlobal(line)
    let l:pattern = s:Extract(a:line, 'pattern')

    if l:pattern == '%'
        let l:pattern = expand('%')
    elseif l:pattern == '#'
        let l:pattern = expand('#')
    endif
    let l:option = s:Extract(a:line, 'option')
    " If no pattern supplied then get it from user.
    if l:pattern == ''
        let s:option = l:option
        if l:option =~ 'f'
            let l:line = input("Gtags for file: ", expand('%'), 'file')
        else
            let l:line = input("Gtags for pattern: ", expand('<cword>'), 'custom,GtagsCandidateCore')
        endif
        let l:pattern = s:Extract(l:line, 'pattern')
        if l:pattern == ''
            call s:Error('Pattern not specified.')
            return
        endif
    endif
    call s:ExecLoad(l:option, '', l:pattern)
endfunction

"
" Execute RunGlobal() depending on the current position.
"
function! s:GtagsCursor()
    let l:pattern = expand("<cword>")
    let l:option = "--from-here=\"" . line('.') . ":" . expand("%") . "\""
    call s:ExecLoad('', l:option, l:pattern)
endfunction

"
" Show the current position on mozilla.
" (You need to execute htags(1) in your source directory.)
"
function! s:Gozilla()
    let l:lineno = line('.')
    let l:filename = expand("%")
    let l:result = system('gozilla +' . l:lineno . ' ' . l:filename)
endfunction
"
" Auto update of tag files using incremental update facility.
"
function! s:GtagsAutoUpdate()
    let l:result = system(s:global_command . " -u --single-update=\"" . expand("%") . "\"")
endfunction

"
" Custom completion.
"
function! GtagsCandidate(lead, line, pos)
    let s:option = s:Extract(a:line, 'option')
    return GtagsCandidateCore(a:lead, a:line, a:pos)
endfunction

function! GtagsCandidateCore(lead, line, pos)
    if s:option == 'g'
        return ''
    elseif s:option == 'f'
        if isdirectory(a:lead)
            if a:lead =~ '/$'
                let l:pattern = a:lead . '*'
            else
                let l:pattern = a:lead . '/*'
            endif
        else
            let l:pattern = a:lead . '*'
        endif
        return glob(l:pattern)
    else 
        return system(s:global_command . ' ' . '-c' . s:option . ' ' . a:lead)
    endif
endfunction

" Define the set of Gtags commands
command! -nargs=* -complete=custom,GtagsCandidate Gtags call s:RunGlobal(<q-args>)
command! -nargs=0 GtagsCursor call s:GtagsCursor()
command! -nargs=0 Gozilla call s:Gozilla()
command! -nargs=0 GtagsUpdate call s:GtagsAutoUpdate()
if g:Gtags_Auto_Update == 1
	:autocmd! BufWritePost * call s:GtagsAutoUpdate()
endif

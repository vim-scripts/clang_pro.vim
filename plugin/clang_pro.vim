
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

if !empty('completeopt')
	exe 'set completeopt=menuone,longest'
endif

au FileType c,cpp call <SID>ClangInit()

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

func! s:ClangInit()
	setl completefunc=ClangDebug    "ctrl-x-u
	setl omnifunc=ClangComplete			"ctrl-x-o

	let b:cwd = fnameescape(getcwd())
	let b:fwd = fnameescape(expand('%:p:h'))
	exe 'lcd ' . b:fwd

	let l:pro  = findfile(g:clang_project, '.;')
	if filereadable(l:pro)
		com! ClangSetSession   call <SID>ClangSetSession()
		com! ClangGetSession   call <SID>ClangGetSession()
		
		let l:file = readfile(l:pro)
		for l:line in l:file
			exe 	l:line	
		endfor
		
		let b:pro_root = fnameescape(fnamemodify(l:pro, ':p:h'))   
		exe 'lcd ' . b:pro_root		
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
		endif
	else
		let b:pro_root = b:fwd   
	endif  	
	exe 'lcd ' . b:fwd  
	"cd to current sourcefile path for gnu global can work well 

	if &filetype == 'c'
		let g:clang_options .= ' -x c '
	elseif &filetype == 'cpp'
		let g:clang_options .= ' -x c++ '
	endif

	" Use it when re-initialize plugin if .clang_pro is changed
	com! ClangInit   call <SID>ClangInit()
	" use it when want to see clang err info in normall mode  
	com! ClangDebug   call ClangDebug(0,"")

	if g:clang_auto   " Auto completion
		inoremap <expr> <buffer> . <SID>CompleteDot()
		inoremap <expr> <buffer> > <SID>CompleteArrow()
		if &filetype == 'cpp'
			inoremap <expr> <buffer> : <SID>CompleteColon()
		endif
	endif
endf

func! ClangDebug(findstart, base)   
	if a:findstart
		silent update!
		return col('.')
	endif  
	let [l:clang_stdout, l:clang_stderr]=s:ClangExecute( g:clang_options, line('.'), col('.')) 
	cgete l:clang_stderr  "out quickfix window
	if len(l:clang_stderr)
		exe "copen"
	endif
	let l:res = []
	return l:res    "out complete menu
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
		let l:proto = l:line[l:s+2 : -1]

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
	let l:command = printf('%s -cc1 -fsyntax-only -code-completion-macros -code-completion-at=%s:%d:%d %s %s',
				\ g:clang_exe, l:src, a:line, a:col, a:clang_options, l:src)
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

func!  s:ClangSetSession()
        exe "mks! ".b:pro_root."/ClangSession.vim"			   
endf

func!  s:ClangGetSession()	
        exe "source " . b:pro_root . "/ClangSession.vim"
endf


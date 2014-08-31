" vim-gdb - Vim plugin for debugging by gdb
" Version: 0.1.0
" Author: deris0126
" Copyright (C) 2014 deris0126
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}

let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vim_gdb')
let s:P = s:V.import('ProcessManager')

let g:debug_gdb_prompt          = get(g:, 'debug_gdb_prompt', ['\C(gdb)'])
let g:debug_gdb_path_to_gdb     = get(g:, 'debug_gdb_path_to_gdb', 'gdb')
let g:debug_gdb_retry_interval  = get(g:, 'debug_gdb_retry_interval', 1)
let g:debug_gdb_retry_max_count = get(g:, 'debug_gdb_retry_max_count', 20)

let s:gdbs = {}
let s:gdb = {}

" Public API {{{1
function! debug#gdb#enter(label)
  if !has_key(s:gdbs, a:label)
    let s:gdbs[a:label] = get(s:gdbs, a:label, deepcopy(s:gdb))
    let t:debug_gdb_object = s:gdbs[a:label]
    call t:debug_gdb_object.init()
  endif

  call extend(t:debug_gdb_object.process, s:P.of(a:label, g:debug_gdb_path_to_gdb))
  let t:debug_gdb_object.running = 1
endfunction

" TODO: init variables start of calling function
" TODO: print result when success or fail
" TODO: add more gdb command
function! debug#gdb#attach(process_id)
  if a:process_id !~ '^\d\+$'
    throw 'process id is not number(' . a:process_id . ')'
  endif
  call t:debug_gdb_object.execute_async('attach ' . a:process_id, g:debug_gdb_prompt)
endfunction

function! debug#gdb#run(...)
  call t:debug_gdb_object.execute_async('run ' . get(a:000, 0, ''), g:debug_gdb_prompt)
endfunction

function! debug#gdb#add_breakpoint(point)
  call t:debug_gdb_object.execute_async('break ' . a:point, g:debug_gdb_prompt)
endfunction

function! debug#gdb#continue()
  call t:debug_gdb_object.execute_async('continue', g:debug_gdb_prompt, { 'done': function('s:is_done') })
endfunction

function! debug#gdb#step()
  call t:debug_gdb_object.execute_async('step', g:debug_gdb_prompt, { 'done': function('s:is_done') })
endfunction

function! debug#gdb#next()
  call t:debug_gdb_object.execute_async('next', g:debug_gdb_prompt, { 'done': function('s:is_done') })
endfunction

function! debug#gdb#show_source()
  let [out, err] = t:debug_gdb_object.execute_sync('info source', g:debug_gdb_prompt)
  let t:debug_gdb_object.source_info = out
  return matchstr(out, 'Located in \zs.\{-1,}\ze\n')
endfunction

function! debug#gdb#show_breakpoints()
  call t:debug_gdb_object.execute_async('info breakpoints', g:debug_gdb_prompt)
endfunction

function! debug#gdb#show_locals()
  call t:debug_gdb_object.execute_async('info locals', g:debug_gdb_prompt)
endfunction

function! debug#gdb#show_args()
  call t:debug_gdb_object.execute_async('info args', g:debug_gdb_prompt)
endfunction

function! debug#gdb#detach()
  call t:debug_gdb_object.execute_async('detach', g:debug_gdb_prompt)
endfunction

function! debug#gdb#quit()
  " FIXME: always fail
  call t:debug_gdb_object.execute_async('quit', g:debug_gdb_prompt)

  call t:debug_gdb_object.init()
endfunction

"}}}

" Private {{{1
function! s:gdb.init() dict
  let self.process = get(self, 'process', {})
  let self.process.execute_sync  = get(self.process, 'execute_sync', function('s:execute_sync'))
  let self.process.execute_async = get(self.process, 'execute_async', function('s:execute_async'))
  let self.running = 0
  let self.source_info = ''
  let self.breakpoints_info = ''
  let self.locals_info = ''
  let self.args_info = ''
endfunction

function! s:is_done(out, err)
  let line = matchstr(a:out, '\%(^\|\n\)\zs\d\+')
  let path = debug#gdb#show_source()

  " TODO: open in layout buffer
  if filereadable(path)
    execute 'edit ' . path
    execute line
  endif
endfunction

function! s:gdb.execute_sync(command, endpatterns, ...) dict
  if self.running == 0
    throw 'gdb is not running'
  endif

  return self.process.execute_sync(a:command, a:endpatterns, get(a:000, 0, {}))
endfunction

function! s:gdb.execute_async(command, endpatterns, ...) dict
  if self.running == 0
    throw 'gdb is not running'
  endif

  call self.process.execute_async(a:command, a:endpatterns, get(a:000, 0, {}))
endfunction


" for Vital ProcessManager2 {{{2
" WANT: enable to add default hook
" WANT: enable to add default endpatterns
function! s:execute_sync(command, endpatterns, ...) dict
  call self.reserve_writeln(a:command)
  call self.reserve_read(a:endpatterns)
  let cnt = 0
  let res = []
  let hook = get(a:000, 0, {})

  while 1
    if cnt >= g:debug_gdb_retry_max_count
      throw 'process.execute_sync: go_bulk retry error'
    endif

    let result = self.go_bulk()
    if result.fail
      if has_key(hook, 'fail')
        call(hook['fail'])
      endif
      " for debug
      echom 'sync fail'
      break
    elseif result.done
      let res = [result.out, result.err]
      if has_key(hook, 'done')
        call(hook['done'], res)
      endif
      " for debug
      echom 'sync done'
      break
    else
      " for debug
      echom 'sync idle'
    endif
    execute 'sleep ' . g:debug_gdb_retry_interval
    let cnt += 1
  endwhile

  return res
endfunction

function! s:execute_async(command, endpatterns, ...) dict
  call self.reserve_writeln(a:command)
  call self.reserve_read(a:endpatterns)
  call s:add_async_executing_process(self, get(a:000, 0, {}))
endfunction

let s:async_process = []
" hook need to be { 'done': funcref, 'fail': funcres }
function! s:add_async_executing_process(process, hook)
  call add(s:async_process, [a:process, a:hook])
endfunction

" TODO: add retry count option
function! s:loop()
  let [process, hook] = s:async_process[0]
  if process.is_idle()
    return
  endif

  let result = process.go_bulk()
  if result.fail
    call remove(s:async_process, 0)
    if has_key(hook, 'fail')
      call call(hook['fail'])
    endif
    " for debug
    echom 'async fail'
  elseif result.done
    call remove(s:async_process, 0)
    if has_key(hook, 'done')
      call call(hook['done'], [result.out, result.err])
    endif
    " for debug
    echom 'async done'
  else
    " for debug
    echom 'async idle'
  endif
endfunction
"}}}

"}}}

augroup my_debug_gdb_loop
  autocmd!
  autocmd CursorHold,CursorHoldI * if !empty(s:async_process) | call s:loop() | call feedkeys('jk', 'n') | endif
augroup END

call s:gdb.init()


let &cpo = s:save_cpo
unlet s:save_cpo

" __END__ "{{{1
" vim: foldmethod=marker

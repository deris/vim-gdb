vim-gdb
===

This is Vim plugin for debugging by gdb.

This plugin is under construction.

### Usage

```vim
call debug#gdb#enter('mypro') " specify label
call debug#gdb#attach(55566)  " specify process id
call debug#gdb#add_breakpoint('normal.c:nv_dot')
call debug#gdb#continue()
call debug#gdb#detach()
call debug#gdb#quit()

" or customize key mappings for using
nmap <F4> <Plug>(debug-gdb-add-breakpoint)
nmap <F5> <Plug>(debug-gdb-step)
nmap <F6> <Plug>(debug-gdb-next)
nmap <F7> <Plug>(debug-gdb-finish)
nmap <F8> <Plug>(debug-gdb-continue)
```

### Future works

#### Basic
 
- gdbで実行する(done)
- gdbでアタッチする(done)
- gdbでリモートデバッグする
- デバッグ中のソースファイルをバッファ上で表示する(done)
- デバッグ中の行をバッファ上でsignで表示する
- ソースコード上で、ブレークポイントを設定する(done)
- ソースコード上で、step, next, finish, continueを実行する(done)
 
#### Advance
 
- カーソル位置の変数の値を表示する
- 変数ウィンドウを表示し、ローカル変数を表示する
- ウォッチウィンドウを表示し、登録した式の値を表示する
- ソースコード上で、ウォッチウィンドウに式を登録する
- バックトレースウィンドウを表示する
- スレッドウィンドウを表示する
- ブレークポイントウィンドウを表示する
- 条件付きブレークポイントを設定する
- GDBウィンドウでGDBコマンド直叩きする

### License

MIT License


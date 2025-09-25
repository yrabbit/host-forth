hex
4200 constant ramdisk-data-port
54   constant ramdisk-addr-var
5c   constant ramdisk-set-addr-sub

: ramdisk-set-address ( n -- ) 
    ramdisk-addr-var over over xc!
	1+ swap 8 rshift swap over over xc!
	1+ swap 8 rshift swap over over xc!
	1+ swap 8 rshift swap xc! 
    ramd-set-addr-sub xcall ;

\ write new word in the chip
create set-addr-sub
    00000297 , \           auipc   x5,0x0  
    ff828293 , \           addi    x5,x5,-8 # 54 <vars>
    0002a303 , \           lw  x6,0(x5)
    106fa023 , \           sw  x6,256(x31)
    00008067 , \           ret

: send-4-bytes ( a n -- )
    swap dup 1+ -rot swap dup 1+ -rot swap c@ swap xc! 
    swap dup 1+ -rot swap dup 1+ -rot swap c@ swap xc! 
    swap dup 1+ -rot swap dup 1+ -rot swap c@ swap xc! 
    swap c@ swap xc! ;

set-addr-sub ramdisk-set-addr-sub send-4-bytes
set-addr-sub 8 + ramdisk-set-addr-sub 4 + send-4-bytes
set-addr-sub 10 + ramdisk-set-addr-sub 8 + send-4-bytes
set-addr-sub 18 + ramdisk-set-addr-sub c + send-4-bytes 

: ramdisk-write ( c -- ) ramdisk-data-port xc! ;
: ramdisk-read  ( -- c ) ramdisk-data-port xc@ ;

\ disk catalog fields 
decimal
: catalog>date  ( a -- a ) ;
: catalog>size  ( a -- a ) 20 + ;
: catalog>addr  ( a -- a ) 20 4 + + ;
: catalog>name  ( a -- a ) 20 4 4 + + + ;
: catalog>next  ( a -- a ) 20 4 4 64 + + + + ;

: print-date ( -- ) 
	ramdisk-read 0 do
		ramdisk-read emit
	loop 
	bl emit ;

: print-name ( -- ) 
	ramdisk-read 0 do
		ramdisk-read emit
	loop 
	bl emit ;

: read-4-bytes ( -- n )
    ramdisk-read ramdisk-read ramdisk-read ramdisk-read
    8 lshift swap +
    8 lshift swap +
    8 lshift swap + ;

: print-size ( --)
    read-4-bytes . bl emit ;

\ joke commands
: ls ( -- )
	0 0 
	begin 
		dup ramdisk-set-address ramdisk-read
	while
        swap dup . 1+ swap
		dup catalog>date ramdisk-set-address print-date 
        dup catalog>size ramdisk-set-address print-size
        dup catalog>name ramdisk-set-address print-name
        cr
		catalog>next
	repeat 2drop ;
	
: head ( n -- )
    0 swap
    0 ?do catalog>next loop
    catalog>addr ramdisk-set-address read-4-bytes ramdisk-set-address
    23 begin
        ramdisk-read dup emit
        10 = if 1- then
        dup 0=
    until drop cr ;

\ put some files
: write-date ( s - )
	dup ramdisk-write 0 do
		dup c@ ramdisk-write
        1+
	loop 
	drop ;

: write-size ( n -- )
	dup ramdisk-write 8 rshift
	dup ramdisk-write 8 rshift
	dup ramdisk-write 8 rshift
	    ramdisk-write ;

: write-address ( n -- ) write-size ;

: write-name ( s -- )
	dup ramdisk-write  
	0 do
		dup c@ ramdisk-write
        1+
	loop 
	drop ;
	
decimal
\ sizes and addresses are hardcoded, sorry :(
\ make catalog

0 dup ramdisk-set-address
s" 2025-09-24 07:38:02" write-date 3819 write-size 369 write-address 
s" ram-disk.4th" write-name
catalog>next dup ramdisk-set-address 

s" 1991-07-30 12:01:03" write-date 19617 write-size 4188 write-address 
s" A 3-instruction Forth for embedded systems work.txt" write-name
catalog>next dup ramdisk-set-address 

s" 2025-08-28 12:43:00" write-date 16600 write-size 23805 write-address 
s" femtorv32_quark_ff.v" write-name
catalog>next dup ramdisk-set-address 

s" 2025-09-25 00:12:07" write-date 954 write-size 40405 write-address 
s" Device Misc Info.txt" write-name

catalog>next ramdisk-set-address 0 ramdisk-write

1024 constant file-buf-len
create file-buf file-buf-len chars allot
: fread ( n fileid -- )
    begin
        file-buf over file-buf-len swap read-file ( n fileid bytes ior)
        drop file-buf swap
        0 do
            dup c@ ramdisk-write 1+
        loop drop
        swap file-buf-len - swap over
    0< until drop drop ;

\ read files
369 ramdisk-set-address 3819
s" ram-disk.4th" r/o bin open-file drop fread
4188 ramdisk-set-address 19617
s" A 3-instruction Forth for embedded systems work.txt" r/o bin open-file drop fread
23805 ramdisk-set-address 16600
s" femtorv32_quark_ff.v" r/o bin open-file drop fread
40405 ramdisk-set-address 954
s" Device Info.txt" r/o bin open-file drop fread

\ vim: set et sw=4 ts=4:

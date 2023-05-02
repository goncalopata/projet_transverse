#!/bin/bash

BINARY=$1
HEX=$2
OUT=$3

ADDR_TIMES=`arm-none-eabi-objdump $BINARY -t | grep bench_times | cut -f 1 -d  ' '`

openocd -l /dev/null \
        -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
        &>/dev/null &
# Get the pid of `openocd` (not `sudo opencd`)
OPENOCDPID=$!

sleep 1

TMP=`mktemp`

(echo "init; reset halt; flash write_image erase $HEX; reset run; sleep 2000"; echo "mdw 0x$ADDR_TIMES"; echo 'exit') | netcat localhost 4444 > $TMP

grep -a -v '>' $TMP | grep -a "$ADDR_TIMES" | cut -f 2-4 -d ' ' > $OUT

rm $TMP

# Kill openocd
kill $OPENOCDPID

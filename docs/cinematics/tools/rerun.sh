#!/bin/bash
# Serial rerun of named tests. Usage: bash rerun.sh <godot console exe> test1 test2 ... ; appends to docs/cinematics/ACCEPTANCE_RERUN.txt
G="$1"; shift; OUT=docs/cinematics/ACCEPTANCE_RERUN.txt; : > $OUT
for t in "$@"; do
  timeout 1500 "$G" --headless --path . --fixed-fps 60 --script res://game/tests/$t.gd > /tmp/rr_$t.log 2>&1
  r=$(grep -aE "^RESULT" /tmp/rr_$t.log | tail -1)
  f=$(grep -aE "TEST .*FAIL" /tmp/rr_$t.log | sed 's/TEST //' | cut -c1-60 | head -6 | tr '\n' ';')
  echo "$t | ${r:-NO RESULT} | $f" >> $OUT
done
echo DONE >> $OUT

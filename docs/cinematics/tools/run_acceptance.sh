#!/bin/bash
# Runs the acceptance tests serially (they share user:// saves) and writes docs/cinematics/ACCEPTANCE_RAW.txt (name, result, failing checks). Usage: bash docs/cinematics/tools/run_acceptance.sh <godot console exe>
G="$1"; OUT=docs/cinematics/ACCEPTANCE_RAW.txt; : > $OUT
for t in intro_trailer_test opening_test chapter_select_test chapter5_test chapter6_test chapter7_test chapter8_test chapter9_test chapter10_test chapter11_test chapter12_test chapter12_noah_test noah_late_test chapter13_test chapter14_test chapter15_test frank_skitter_test colossus_market_last_test colossus_shot_test trailer_test death_test tripod_gait_test pay_first_test town_destruction_test roof_skitter_handoff_test cinematic_test; do
  [ -f game/tests/$t.gd ] || { echo "$t MISSING" >> $OUT; continue; }
  timeout 1500 "$G" --headless --path . --fixed-fps 60 --script res://game/tests/$t.gd > /tmp/acc_$t.log 2>&1
  r=$(grep -E "^RESULT|^CINEMATIC" /tmp/acc_$t.log | tail -1)
  f=$(grep -E "TEST .*FAIL" /tmp/acc_$t.log | sed 's/TEST //' | cut -c1-70 | head -6 | tr '\n' ';')
  echo "$t | ${r:-NO RESULT (timeout or crash)} | $f" >> $OUT
done
echo DONE >> $OUT

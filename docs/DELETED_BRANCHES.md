# Remote branches removed in the 2026-11-19 clean-up

Every branch below was fully contained in another branch (the default branch `claude/practical-cray-hi2y54`, or for the three `art/*` ones the newer `art/npc-meshy-trial-eddie-clerk`), so no commit was lost: all of them are still reachable.
To bring one back: `git branch <name> <commit> && git push origin <name>`.

| branch | last commit | why | tip commit |
|---|---|---|---|
| `art/npc-meshy-rigs` | 2026-11-19 | contained in art/npc-meshy-trial-eddie-clerk | `ce4fcf63068ed81d6ae49167488bff8c00364970` |
| `art/protagonist-face-geometry` | 2026-11-19 | contained in art/npc-meshy-trial-eddie-clerk | `6b4268ea27e4cbfe18426cfcb530ba504ae6a7ac` |
| `art/sarah-meshy-integration` | 2026-11-19 | contained in art/npc-meshy-trial-eddie-clerk | `aca75c7f422b5cbfb86c11a46b3927cdea16bc54` |
| `claude/audio-vehicle-survival-integration` | 2026-11-07 | merged into the default branch | `f65c4b0b04b8b0acb4d737ca8ac74c737e6520c7` |
| `claude/car-quest-world-edge` | 2026-11-08 | merged into the default branch | `5f9f4301ae5c50c25bd721261883538ac785dfdf` |
| `claude/car-repair-anims` | 2026-11-08 | merged into the default branch | `738b4a60a808c85dab564a7ed7820e80846be0e0` |
| `claude/car-repair-quest` | 2026-11-07 | merged into the default branch | `fc5853c132b1bc1562b08aec325c041b93bb5678` |
| `claude/chapter-select` | 2026-11-09 | merged into the default branch | `b9bb8705d6aa8275dbe8efa24c8aef2d71e5b8ad` |
| `claude/chapter-select-export-fix` | 2026-11-09 | merged into the default branch | `1f9d5b86583f98ef8c15e0e76ba5e3e5a7a844d0` |
| `claude/chapter10-no-safe-road` | 2026-11-05 | merged into the default branch | `8d37aa71453b86c1f544a15c2329700a2bcb4c00` |
| `claude/chapter11-farm-road` | 2026-11-05 | merged into the default branch | `761563102a961c65b531e1d9de80a99d93a4f534` |
| `claude/chapter13-truth-beneath-greyhaven` | 2026-11-05 | merged into the default branch | `0f868268807f7cdf073d6170c29a9c264a81cd0b` |
| `claude/chapter14-into-the-veil` | 2026-11-05 | merged into the default branch | `12c679b45a98af631117dfa9d4d6c9649e9be2df` |
| `claude/chapter15-last-shelter` | 2026-11-05 | merged into the default branch | `c51b423089ea3d7b461ed97e280ee608fdf3e99c` |
| `claude/chapter16-what-remains` | 2026-11-05 | merged into the default branch | `c0af5ae7b01c897a2f115a419273c767242a270b` |
| `claude/chapter5-polish` | 2026-11-04 | merged into the default branch | `04982166aff2ce4c16db426187765e944a0c507c` |
| `claude/chapter7-trace-of-noah` | 2026-11-05 | merged into the default branch | `7cbc7ecc5e3314c2a79a55e3f98abf53a833a653` |
| `claude/chapter8-something-at-the-doors` | 2026-11-05 | merged into the default branch | `6268710e52407f8a7dc08b9d9537fe70e88f2890` |
| `claude/chapter9-supermarket-fall` | 2026-11-05 | merged into the default branch | `8e661d058a4fe77d8b2b4dcfe3faff8136be92bf` |
| `claude/character-cinematic-scavenging-polish` | 2026-11-07 | merged into the default branch | `53729b9cda914eed616d89c3acc4924d01fc3d3a` |
| `claude/cline-fixes-integration` | 2026-11-07 | merged into the default branch | `0527b1a9a056d64ade96892378845acfabda0187` |
| `claude/colossus-frank-foot` | 2026-11-08 | merged into the default branch | `3010261efbf8682b42738b7f98e0a478954f35e1` |
| `claude/colossus-route-logic` | 2026-11-08 | merged into the default branch | `cf5016da10c2d99b10c1e0d02852eca80ba620fe` |
| `claude/critical-gameplay-repair` | 2026-11-07 | merged into the default branch | `dd8158c0a977c0665c2c587655d478506aa55d69` |
| `claude/easter-egg-golden` | 2026-11-05 | merged into the default branch | `73753f83b35c414b876b42ffb12ec5a4666a1f14` |
| `claude/final-build` | 2026-11-05 | merged into the default branch | `54ec2fafa063c00933c91ec53a9eb2eb8ab2f66d` |
| `claude/final-complete` | 2026-11-05 | merged into the default branch | `8a3d57bf2db272fac43a82c4d4b1a95011a4a8a7` |
| `claude/final-merged` | 2026-11-05 | merged into the default branch | `a54662d99eab765ace8884403eb4b28c50c93274` |
| `claude/final-outstanding-repairs` | 2026-11-07 | merged into the default branch | `6bd0f8991928134c55b35d6ca5c94cbd6725389d` |
| `claude/final-polish` | 2026-11-06 | merged into the default branch | `daae367b729a561e09d736d0985d6e6ca83b4953` |
| `claude/final-with-codex` | 2026-11-06 | merged into the default branch | `6a6c8ac202b87154d0dcdf20dfa37c472e48edc5` |
| `claude/four-fixes` | 2026-11-08 | merged into the default branch | `5f9d1db1ad332737c6edf41ece9719e64a05ea66` |
| `claude/greyhaven-living-town` | 2026-11-07 | merged into the default branch | `3d1acd55322a7b0af3e389febba7a6de1060a65d` |
| `claude/greyhaven-residential-reconstruction` | 2026-11-07 | merged into the default branch | `8cfbdb6f91f7c9228661ddb2bb5f443546cc5b2f` |
| `claude/greyhaven-residential-reconstruction-v2` | 2026-11-07 | merged into the default branch | `ab3639adc3d7c2beb7be57eb7a6369a40bbdd414` |
| `claude/handgun-polish` | 2026-11-05 | merged into the default branch | `bd28599c4dcaf0b59f231401b6a4aa413fa461fd` |
| `claude/intro-trailer` | 2026-11-08 | merged into the default branch | `4944baa1e12bc034826454b8d11cfaad53c9ae6d` |
| `claude/inventory-layout-fix` | 2026-11-08 | merged into the default branch | `ed36c0585b7fc3c002c9e7eae913166120706ce8` |
| `claude/loading-door-three-tentacles` | 2026-11-07 | merged into the default branch | `7d546bc73d3f874919e5cc1afe18035548d445bf` |
| `claude/monster-spawn-repair` | 2026-11-07 | merged into the default branch | `c29cc167da5433cf60cf48473785e0947a779204` |
| `claude/navigation-guidance` | 2026-11-05 | merged into the default branch | `8acb6fd3f4910bd528d6c3fd8c52d25d1b57adbc` |
| `claude/pay-before-leaving` | 2026-11-09 | merged into the default branch | `d49e5c0ff97bdf85f83a5f8fc9a6fc0c463bffe7` |
| `claude/performance` | 2026-11-08 | merged into the default branch | `99416394ebfd1d52f6b84baee6058aacacad807a` |
| `claude/phase4-first-night` | 2026-11-04 | merged into the default branch | `ae21bca7a8e721d87d8d61e7b1f4a1fab494580e` |
| `claude/phase5-first-search` | 2026-11-04 | merged into the default branch | `07b94095b6421c43cf5c445dabf894a397762101` |
| `claude/qa-final-two` | 2026-11-05 | merged into the default branch | `0837df86e5f370676ab575d4e47f877877077625` |
| `claude/qa-repairs` | 2026-11-05 | merged into the default branch | `edf3a61c3f23a93072546a53d0e576e586a12480` |
| `claude/residential-survival-horror-repair` | 2026-11-07 | merged into the default branch | `5212e042bba0d433b28cff063c01bc2ec7d78a19` |
| `claude/roof-skitter` | 2026-11-05 | merged into the default branch | `c40816ba141f10bdf9263d1917a03f9a03b4770e` |
| `claude/screenshot-referenced-repair` | 2026-11-07 | merged into the default branch | `57db80eed3537dec21d363c941323d08f7375ac4` |
| `claude/shelter-companion-persistence-repair` | 2026-11-07 | merged into the default branch | `96eb72c2d2826db0196054edcd958eb26fd799e1` |
| `claude/shelter-map-scavenging-repair` | 2026-11-07 | merged into the default branch | `0273107b2483bbdb9ec8da7ed96331467d8779a0` |
| `claude/skitter-attack-fix` | 2026-11-07 | merged into the default branch | `22bcd7d2367afc4b18b8322aaf2c5dc8f5ca18ae` |
| `claude/skitter-pin` | 2026-11-05 | merged into the default branch | `77a8910320cd45bc2fa1f1c7537a0b77dd7149e7` |
| `claude/store-encounter` | 2026-11-06 | merged into the default branch | `a4b0f7f3ca32a5e6e8d49c9fbbc065036584b013` |
| `claude/supplies-and-revolver` | 2026-11-05 | merged into the default branch | `ac31384ec39e8d5520d6afad9ec6121ea64c76a5` |
| `claude/survival-scavenging-expansion` | 2026-11-05 | merged into the default branch | `9e16a4ce98796b60315669182861f43258584620` |
| `claude/survival-world-stability` | 2026-11-06 | merged into the default branch | `cff7cad88c33031c4413ccf790b15fefebd4389e` |
| `claude/survivor-relationships` | 2026-11-05 | merged into the default branch | `95224491c6150a579910689b782ea2dfda4b3474` |
| `claude/tentacle-entrance-display-repair` | 2026-11-07 | merged into the default branch | `998602ad6163c295e648adddafb947675926071d` |
| `claude/time-skip-freeze` | 2026-11-09 | merged into the default branch | `1e6497e1b2ab77269f68b1432c2a187dc44e94b7` |
| `claude/town-destruction` | 2026-11-08 | merged into the default branch | `c2ba9c0dca7243ee60bc9d260711b4b0dcaccb41` |
| `claude/trailer-polish` | 2026-11-08 | merged into the default branch | `7c20ecbfd75101ef67078dacc7ac414777bbeeaf` |
| `cline/game-stability-polish` | 2026-11-06 | merged into the default branch | `c3f16def7df24c3c446857a372b409104f1b5775` |
| `codex/animations-running` | 2026-11-05 | merged into the default branch | `b94aa52e58da996c61ba7996e010d73da6433c01` |
| `codex/chapter1-handwashing-polish` | 2026-11-05 | merged into the default branch | `fca1ef2456e4029dd13bd94993a365a730092e8a` |
| `codex/chapter4-tentacle-dodge` | 2026-11-04 | merged into the default branch | `c20be63d7c0220b61ee001c9e98deffad2dbb502` |
| `codex/cinematic-intro-preview` | 2026-11-08 | merged into the default branch | `bc192f35f9b3560c8f2914faa46abcb8172e23de` |
| `codex/damaged-house-viewer` | 2026-11-08 | merged into the default branch | `3fb4cb409ac857c288264b1323251178ad1565e8` |
| `codex/final-opening-polish` | 2026-11-05 | merged into the default branch | `a0f2917f1af922e86a3ca960556548ef06a7e9d0` |
| `codex/geometry-and-vehicle-repairs` | 2026-11-03 | merged into the default branch | `9f3df14d5051fc0743961a7df6545b9cb3dffac2` |
| `codex/marcus-v4-scared-run` | 2026-11-03 | merged into the default branch | `f7fdbf91d2a4ded9a808ce544e378d87a54ad5a0` |
| `codex/neggy-easter-egg-updated` | 2026-11-05 | merged into the default branch | `73753f83b35c414b876b42ffb12ec5a4666a1f14` |
| `codex/shelter-gameplay-systems` | 2026-11-04 | merged into the default branch | `019929583259332dd6d2fd26ead13c6613af47a4` |
| `codex/skitter-handoff` | 2026-11-05 | merged into the default branch | `ed7acb36bac3c0d9dca5b384e04da01a7002fc48` |
| `codex/validation-support` | 2026-11-03 | merged into the default branch | `430741bd51440b0bff5eb5651d064e77c65b9cad` |
| `feature/dialogue-polish-pr` | 2026-11-18 | merged into the default branch | `a5cf8b88922da98260929280c0867e80de4a609c` |
| `feature/screen-fx-throw` | 2026-11-18 | merged into the default branch | `c2856cb45703398bf413f7cc19c8a110c6add9cd` |
| `fix/shelter-exit-chapter-select` | 2026-11-18 | merged into the default branch | `bd039f1dc1d0472dab304abb12b8eee68d5b42f5` |
| `merge/everything` | 2026-11-09 | merged into the default branch | `1f9d5b86583f98ef8c15e0e76ba5e3e5a7a844d0` |
| `work/character-redesign` | 2026-11-03 | merged into the default branch | `e930917bfc40059795f744478e15fc262fa721eb` |
| `work/opening-prototype` | 2026-11-03 | merged into the default branch | `d370a21fc662c15797bff37c567cefb03e80178a` |

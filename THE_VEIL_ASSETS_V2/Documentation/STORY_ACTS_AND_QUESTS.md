# THE VEIL - Acts, quests and triggers

This file lists the playable beats as they are implemented: their objective ids, story flags, triggers and dialogue
ids. Beats that exist only in the bible are marked with their canon status. Data lives in
`game/data/objectives.json`, `game/data/dialogue.json` and `game/data/items.json`. The wiring is in
`game/world/world.gd`.

## Act 0 - Ordinary Friday (ESTABLISHED, implemented)

### Phase 1 - the opening

Goal "Get some groceries".

| # | Objective id | Completes on flag | Trigger | Dialogue ids |
|---|---|---|---|---|
| 1 | `check_kitchen` | `fridge_checked` | Open the fridge (`Fridge_Retro_01/.../INT_ApplianceDoor_Fridge` hinge in the Pack 03 home) | `wake`, `wake_hint`, `fridge_empty`, `fridge_again` |
| 2 | `find_keys` | `has_keys` | Pick up the car keys (Pack 03 pickup metadata). Gives item `car_keys`. | `keys` |
| 3 | `leave_house` | `left_house` | `Trigger_LeftHouse`, the front-yard band, crossed with the keys | `left_house`, `need_keys` |
| 4 | `enter_car` | `entered_car` | Sedan door. Refuses without the keys or before the kitchen check. | `in_car`, `need_kitchen` |
| 5 | `drive` | `reached_town` | `Trigger_Town` (Route 9) or `Trigger_MainSt` | `town` |
| 6 | `park` | `parked` | Automatic reverse parking from `Trigger_AutoPark` (the middle of the lot; flag `auto_parked`), or the sedan stopped (< 0.5 m/s for 1 s) in `Trigger_Parking` | `parked` |

Extras:

* **Observations:** `obs_alarm`, `obs_calendar`, `obs_tv`, `obs_console`, `obs_cereal`, `obs_computer`, `obs_radio`,
  `obs_clock`.
* **Other lines:** `no_exit`, `no_room`.

### Phase 2 - town errands

Goal "Friday errands". The errands can be done in **either order**: each step checks only its own flag.

| # | Objective id | Completes on flag | Trigger | Dialogue ids |
|---|---|---|---|---|
| 7 | `buy_groceries` | `groceries_done` | Take `canned_food`, `energy_snack` and `water_bottle` off the aisle shelves, then use the lane-4 register. This turns them into the item `groceries`. | `market_enter`, `market_need_items`*, `market_checkout`*, `groceries_done` |
| 8 | `buy_game` | `game_bought` | Take `horror_game` from the New Releases rack, then talk to Eddie | `shop_enter`, `game_pick`, `eddie_hello`*, `eddie_buy`*, `eddie_after`* |

`*` = a `"draft": true` line (placeholder speaker or text).

Interactive set pieces:

* the supermarket automatic doors (`Trigger_MarketDoors`);
* the game-shop entrance door (hinge);
* Eddie behind the counter, who talks with VeilFace.

**Not yet implemented in Act 0:** other townspeople, traffic and Marcus.

### Phase 3 - the Veil arrives

Implemented as a **WORKING DRAFT** of the opening of Act I. Goal "The Veil".

| # | Objective id | Completes on flag | Trigger | Dialogue ids |
|---|---|---|---|---|
| - | (start) | `p3_mist`, `phase2_done` | Last errand done, still inside the store. The Veil rolls in, lights stutter, the cashier is gone. | `p3_fog` |
| 9 | `p3_look` | `p3_stepped_out` | Walk up to the game-shop door (Eddie opens it, then shots B-H; see below) or step out of another store (the Colossus leg encounter plays). | `p3_eddie_hurry`, `p3_eddie_calls`, `p3_colossus` |
| 9b | `p3_back` | `p3_back_inside` | GET BACK INSIDE THE STORE. Health and stamina are on; tentacles hunt in the street. | `p3_colossus`, `p3_hit`, `p3_wake_hurt` |
| - | (optional) | - | Try the sedan: it is dead. | `p3_car_dead`, `p3_car_again` |
| 10 | `mist_shop` | `p3_in_shop` | Enter the game shop. Marcus is there. | `p3_shop`, `p3_eddie_go`, `p3_marcus_talk`, `p3_eddie_hurry` |
| 11 | `mist_market` | `p3_in_market` | Reach the supermarket sales floor. Eddie and Marcus are there; the doors are jammed open. | `p3_market` |
| 12 | `mist_doors` | `p3_doors_shut` | "Pull the Doors Shut". End card "ACT I". | `p3_doors` |

**Game-shop staging (production choice, not canon):** when the Veil arrives in the game shop, Eddie opens the door.
The protagonist steps out, the foot lands, and Eddie calls him back from the doorway. Both walk back in and Eddie
shuts the door. Marcus joins and the `p3_shop` + `p3_eddie_go` conversation plays with each line confirmed. This
sets `p3_stepped_out`, `p3_back_inside` and `p3_in_shop` in order. The bible's approved escape sequence (the
group crossing to the supermarket together) waits for its dedicated Chapter 3 prompt and is **not** implemented:
`p3_eddie_go` still says they will meet the protagonist there.

Every `p3_*` line is `draft`. Marcus says only "my son", because Noah's age is TBD.

## Act I - The town disappears (WORKING DRAFT, not implemented)

* The mist arrives **after** the normal opening. The exact moment is TBD (bible 11.2).
* An earlier draft places the protagonist at the game shop with Eddie and Marcus when the mist arrives, with the
  Colossus glimpsed. The supermarket becomes an early refuge. The order is not locked.
* Survival systems begin: light, food and water, health, inventory weight (about 15 kg in early design), locked
  routes. All values are TBD.
* Available assets:
  * Pack 07 creatures;
  * Pack 09 mist, lighting and abandoned dressing;
  * Pack 08 items.

## Act II - Survivors and clues (WORKING DRAFT, not implemented)

* Explore neighbourhoods, businesses and civic places. Find documents about earlier incidents.
* Marcus is searching for Noah.
* Develop Eddie, Ruth, Sarah, Frank and Lena.
* Deaths are a mix of scripted and preventable ones. Which characters die is TBD.

## Act III - History and the breach (WORKING DRAFT, not implemented)

The bible mentions a breach around Day 7. Its timing and triggers are TBD.

## Act IV - Outcome (WORKING DRAFT, not implemented)

* Working ending names: **Clearing**, **Escape**, **Beneath the Town** and **Last One**.
* Conditions and scripts are TBD. Do not implement ending triggers until the owner confirms the design.

## Flag conventions

* **Story flags:** plain names, set through `Game.set_flag()`. Every flag except `parked` triggers an autosave.
* **One-shot dialogue:** recorded as `said_<id>`.
* **Interactable state:** saved in `Game.world_state` under keys `home/...`, `market/...` and `shop/...`.

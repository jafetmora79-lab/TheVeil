"""Adds the 13.0 Noah-rescue data (dialogue ids, items, objective steps) to game/data/*.json (idempotent). Run from the repo root."""
import json

def load(p):
    raw = open(p, encoding="utf-8").read()
    return json.loads(raw), raw.endswith("\n")

def save(p, d, nl):
    open(p, "w", encoding="utf-8").write(json.dumps(d, indent=1, ensure_ascii=False) + ("\n" if nl else ""))

def D(src, lines):
    return {"source": src, "lines": [{"speaker": s, "text": t, "time": round(max(1.4, 0.055 * len(t) + 0.9), 1)} for s, t in lines]}

SRC = "Chapter 13 opening: the Noah rescue (story pass B4 13.0, approved)"
P = ""   # the protagonist
dlg = {
    "c12_ribbon_alive": [("Eddie", "I took it off the fence post last night. I thought it was trash. It had a, uh, picture on it."), ("Marcus", "That's his handwriting. That's - 'knock three plus one.'"),
        ("Ruth", "Three plus one what?"), ("Marcus", "Three short, one long. It's how he asked to come in when he was little."), ("Sarah", "Then it isn't a trick."),
        ("Eddie", "Or the best trick I've ever seen."), ("Marcus", "A trick doesn't know the knock."), (P, "First light. We keep it.")],
    "c12_ribbon_lost": [("Eddie", "I took it off the fence post last night. I thought it was trash. It had a picture on it."), (P, "'Knock three plus one.'"), ("Ruth", "It's a code."),
        ("Sarah", "It's a kid's code."), ("Eddie", "Then it's his."), (P, "Marcus would have been out the door already. We go.")],
    "c12_solo": [("Eddie", "You're sure? Alone?"), (P, "Three people crossing a field is a noise. One's a shadow.")],
    "c12_marcus_insists": [("Marcus", "I'm coming. Don't argue."), (P, "Then you wait at the fence. He won't open for a voice.")],
    "c12_marcus_wait": [("Marcus", "I'm not going in until he opens it."), (P, "He won't open for a voice. He'll open for a knock.")],
    "c12_try_again": [("Ruth", "It's circling the same two houses. It has a rhythm."), ("Ruth", "Wait for the gap.")],
    "c12_knock_retry": [("Noah", "...No.")],
    "c12_noah_ask": [("Noah", "Who's there?")],
    "c12_noah_ask_alive": [(P, "I'm with your dad. Marcus.")],
    "c12_noah_ask_lost": [(P, "I found your bag. I'm here for you.")],
    "c12_noah_test": [("Noah", "Say what's wrong with the bag.")],
    "c12_noah_wrong": [("Noah", "Nope.")],
    "c12_noah_keychain": [(P, "The little bus. One eye missing."), ("Noah", "...The eye. He picked the eye off. Nobody knows that.")],
    "c12_noah_open": [("Noah", "...Okay. Okay. Give me a second.")],
    "c12_noah_why": [("Noah", "The old man took me to his brother's place for fuel. I heard something at night. We went back.")],
    "c12_noah_account": [("Noah", "He found me at the bus stop on the pump road when the fog came. He said stay low and walk."),
        ("Noah", "I left the bag and the note in a car on the way, so Dad could find it. He said that's how you leave a sign."), ("Noah", "He never told me his name.")],
    "c12_reunion_alive": [("Marcus", "...Noah."), ("Noah", "Dad. You came after dark. I said light."), ("Marcus", "It's light. It's light, bud."), ("Noah", "You smell terrible."), ("Marcus", "I know.")],
    "c12_bereave": [("Noah", "Where's my dad?")],
    "c12_bereave_a": [(P, "He didn't make it.")],
    "c12_bereave_b": [(P, "He was looking for you until the end.")],
    "c12_bereave_c": [(P, "He wanted you to have this.")],
    "c12_noah_comfort": [(P, "He told me you hated the color."), ("Noah", "...I did."), (P, "He kept it anyway."), ("Noah", "Okay. I'll carry it.")],
    "c12_noah_held": [("Noah", "He bought it for me. I hated the color.")],
    "c12_arrive_alive": [("Eddie", "Everybody - this is Noah. Noah, this is everybody. Please don't be weird."), ("Ruth", "Eat first. Questions later.")],
    "c12_arrive_lost": [("Eddie", "Everybody - this is Noah. Noah, this is everybody. Please don't be weird."), ("Ruth", "Eat first. Questions later."), ("Sarah", "Sit by me.")],
    "c12_below_why": [("Noah", "It was at the gate post three nights ago. Now it's at the road."), ("Ruth", "That's not a fog. That's a tide."), ("Eddie", "I would like to vote for a different metaphor."),
        ("Sarah", "Where does the old man's 'across' go?"), (P, "Under the station. Then under the district."), ("Eddie", "The creepy road to the creepy place. Fine. Fine.")],
    "c12_below_marcus": [("Marcus", "If the old man said under, we go under. But he stays here."), ("Noah", "I can read the map better than you."), ("Marcus", "You stay here.")],
    "c12_symbol_marcus_noah": [("Marcus", "Noah drew that. He told me he copied it off the old man's gatepost."), ("Marcus", "Go. I'll keep watch here. With him.")],
}
d, nl = load("game/data/dialogue.json")
for k, v in dlg.items():
    d[k] = D(SRC, v)
save("game/data/dialogue.json", d, nl)

it, nl = load("game/data/items.json")
it["items"]["noahs_ribbon"] = {"name": "Noah's Ribbon", "category": "note", "weight": 0.01, "model": "res://THE_VEIL_ASSETS_V2/08_Inventory/Story_Items/INV_FoldedNote.glb",
    "description": "A strip of red cloth, knotted twice.\nIn pencil, small: the mark.\nUnder it, in a child's handwriting:\n\"STILL HERE. COME WHEN ITS LIGHT. KNOCK 3 + 1.\""}
it["items"]["farmers_journal"] = {"name": "Farmer's Journal", "category": "note", "weight": 0.2, "model": "res://THE_VEIL_ASSETS_V2/08_Inventory/Story_Items/INV_Notebook.glb",
    "description": "A boy at the fence tonight. Eyes like a rabbit. Fed him. Told him the rules: lamp low, no road after dark.\n\nShowed him the mark the old men used to scratch on the pump-house door. Said the fog sits thinner there. Don't ask me why. They never said.\n\nThe lamp oil's going. The county put that maintenance place on the road after the trouble in '71 and again after '94 and I'd as soon never go near it. But there's fuel there, they say, and a road under it nobody uses. Going at first light. The boy stays. He's to knock three and one for anyone he wants to let in. Nobody else.\n\nNot back by dark. If this is read: the boy is good. Take him under the pump house. The old men never went down. They went across. I don't know what that means."}
save("game/data/items.json", it, nl)

ob, nl = load("game/data/objectives.json")
steps = ob["steps"]
if not any(s["id"] == "c12n_ribbon" for s in steps):
    i = next(i for i, s in enumerate(steps) if s["id"] == "c12_talk")
    new = [{"id": "c12n_ribbon", "flag": "ch12_ribbon_read", "when": "ch12_rescue_started", "goal": "act5_truth", "text": "Look at the ribbon Eddie found"},
           {"id": "c12n_go", "flag": "ch12_house19_entered", "when": "ch12_rescue_started", "goal": "act5_truth", "text": "Go to HOUSE_19 at first light"},
           {"id": "c12n_knock", "flag": "ch12_noah_found", "when": "ch12_rescue_started", "goal": "act5_truth", "text": "Knock three short, one long"},
           {"id": "c12n_home", "flag": "ch12_noah_home", "when": "ch12_rescue_started", "goal": "act5_truth", "text": "Bring Noah back to the mill house"}]
    steps[i:i] = new
save("game/data/objectives.json", ob, nl)
print("ok", len(dlg), "dialogue ids")

# ---- part 2: Noah in displayed chapters 15 and 16 (story pass B5)
d, nl = load("game/data/dialogue.json")
SRC2 = "Chapters 15-16: Noah (story pass B5, approved)"
more = {
    "c14_wake_noah": [("Noah", "You need to see this. Look at my line.")],
    "c14_noah_log": [("Noah", "Fog line, hour by hour. It doesn't come on Mondays."), ("Eddie", "It's Friday."), ("Noah", "Then it's coming.")],
    "c14_partner_Ruth": [("Ruth", "Noah, with me. Back door, the ditch, the field edge. If I say run, you don't wait."), ("Noah", "I know the route. I drew it.")],
    "c14_partner_Marcus": [("Marcus", "Noah, with me. I'm not letting go of this one."), ("Noah", "Dad. I know the route. I drew it.")],
    "c14_partner_Sarah": [("Sarah", "Noah, stay by me. Back door, the ditch, the field edge."), ("Noah", "I know the route. I drew it.")],
    "c15_why_below": [("Ruth", "We can't stay here."), ("Eddie", "We can't go back."), ("Noah", "He said across. Not out. Across."), ("Sarah", "Across what?"),
        ("Noah", "I don't know. He didn't either."), (P, "There's one place that has a door that opens both ways."), ("Eddie", "Ah. The creepy one.")],
    "c15_end_a_noah_alive": [("Marcus", "I looked back more than anyone."), ("Noah", "I know. I counted."), ("Marcus", "How many?"), ("Noah", "Eleven."),
        (P, "It's still behind us."), ("Eddie", "That's not what I meant by what now.")],
    "c15_end_a_noah_lost": [("Noah", "He didn't see it."), ("Ruth", "See what?"), ("Noah", "The sky.")],
    "c15_end_b_next": [("Ruth", "The map shows farms on this side."), ("Sarah", "People, maybe."), ("Noah", "The old man had a route to the next town. I know the first three turns."),
        ("Eddie", "I'll take the ones I know I can't mess up.")],
    "c15_knock": [(P, "(Three short, one long, on the stone.)"), (P, "(Silence.)"), ("", "(From beyond the stone: three short, one long. Faint.)")],
    "c15_end_c_noah": [("Noah", "He knocked back."), ("Ruth", "Who?"), ("Noah", "Nobody.")],
}
for k, v in more.items():
    d[k] = D(SRC2, v)
save("game/data/dialogue.json", d, nl)
print("part 2 ok")

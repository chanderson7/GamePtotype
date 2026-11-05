#!/usr/bin/env python3
"""Prototype of the captain bond talks composer (docs/bond-talks-plan.md).

A talk is built from parts chosen by facts about the pair and the last battle they
shared. The data below is shaped to port straight into scripts/data/bond_talks.gd:
plain dictionaries of strings with {slots}. Run it to print sample talks and to
measure how often lines repeat over simulated campaigns:

    python3 tools/bond_talks_proto.py            # four sample talks
    python3 tools/bond_talks_proto.py simulate   # repetition over 300 campaigns

Line format: sentences separated by "|". A sentence starting with "+" is said only by
a captain whose voice is "talks"; a "short" voice says only the first sentence.
"""
import hashlib
import random
import sys

V, S, F = "Vengeful", "Steadfast", "Fragile"
VOICES = ["plain", "talks", "short", "formal"]
# A captain who survived the death roll by this much or less had a close call.
CLOSE_CALL_MARGIN = 10

# ----------------------------------------------------------------- mundane things
# What a captain handles, loses and passes around, by culture and troop type.
WEAPON = {
    "vardish": {"infantry": "sword", "spearmen": "pike", "archers": "bow", "cavalry": "lance"},
    "kharzani": {"infantry": "scimitar", "spearmen": "spear", "archers": "bow", "cavalry": "lance"},
    "ryumon": {"infantry": "katana", "spearmen": "yari", "archers": "yumi", "cavalry": "lance"},
}
LOST = {
    "vardish": ["left boot", "helmet strap", "good knife", "glove"],
    "kharzani": ["water skin", "left boot", "head cloth", "good knife"],
    "ryumon": ["straw hat", "left sandal", "good knife", "sash"],
}
FOOD = {
    "vardish": ["bread", "ale", "last of the cheese"],
    "kharzani": ["dates", "tea", "flatbread"],
    "ryumon": ["rice", "tea", "pickles"],
}

# ----------------------------------------------------------------- where they sit
# Narration, by the two cultures. {S} is the captain the talk is about, {P} the partner,
# {V}/{K}/{R} the Vardish, Kharzani or Ryumon one of a mixed pair.
OPENINGS = {
    ("vardish", "vardish"): [
        "{S} and {P} have the one whetstone between them and are arguing, mildly, about whose turn it is.",
        "Bread, ale and the fire. {S} is drying a pair of boots on a stick. {P} has said twice that they'll burn.",
    ],
    ("kharzani", "kharzani"): [
        "{S} has made the tea the proper way, which takes an hour. {P} is pretending not to be impatient.",
        "{S} and {P} are shaking sand out of everything they own. There is always more sand.",
    ],
    ("ryumon", "ryumon"): [
        "{S} is oiling a blade that doesn't need it. {P} has sat down to do the same.",
        "The sashimono are planted by the fire to dry. {S} and {P} eat without talking, which is how they talk.",
    ],
    ("kharzani", "vardish"): [
        "{K} has given up explaining the tea. {V} drinks it anyway.",
        "{V} has brought bread. {K} has brought dates. Neither has mentioned the other's.",
    ],
    ("ryumon", "vardish"): [
        "{R} is oiling a blade that doesn't need it. {V} has borrowed the oil for a shield rim and is making a mess of it.",
        "{V} tried the rice with a knife. {R} said nothing and passed over a second pair of sticks.",
    ],
    ("kharzani", "ryumon"): [
        "{K}'s tea and {R}'s tea are being compared, politely, for the third night running.",
        "{R} has shown {K} how the sashimono is planted. {K} has shown {R} how to get sand out of a boot. Both were needed.",
    ],
}
WOUNDED_TAIL = " {W} has the bad leg out toward the fire."

# ----------------------------------------------------------------- the hooks
# Each hook: who it is about, one factual sentence of narration, and four beats. Beats
# alternate S (the one it is about) and P (the partner). Each beat has one line per
# temperament of whoever speaks it; every line must follow any line of the beat before.
HOOKS = {
    "fallen_friend": {
        "about": "closer_to_fallen",
        "tell": "{fallen} fell at {place} today. Both of them had fought beside {fallen} for a long while, and both have been sitting by the empty place.",
        "beats": [
            {V: "I found the one who did for {fallen}.|I want you to know that.|+Took a while. I wasn't in a hurry.",
             S: "{fallen} would have hated the way we're sitting.|Nobody talking.",
             F: "I keep looking at {fallen}'s place.|I can't stop."},
            {V: "I keep thinking what I'd do to the man who did it.|I don't even know what he looked like.",
             S: "Then we talk.|{fallen} would talk. Go on. Say anything.",
             F: "I can't look at it.|Move the cup, would you. No. Leave it."},
            {V: "{fallen} owed me three silver.|I'm keeping the debt. Means he's still about.",
             S: "{fallen} used to take my {food}. Every camp.|I never once caught it happening.",
             F: "{fallen} laughed at everything.|Even at {place}. Even at the end, I think."},
            {V: "We'll put it right.|Not tonight. But we will.",
             S: "Then we keep the place.|Pour one and sit.",
             F: "Stay by the fire a while.|I don't want to sit here on my own."},
        ],
    },
    "close_call": {
        "about": "nearly_died",
        "tell": "At {place}, {S} went down with {enemy} over them. {company_p} were close enough to drag {S} clear.",
        "beats": [
            {V: "I want the one who put me down.|Did anyone see which it was?",
             S: "My {lost} is still out there.|Don't laugh.",
             F: "I keep thinking I'm still down.|Stupid. I'm sitting right here."},
            {V: "Whoever it was, he's not walking home.|+I made sure of it before we pulled back.",
             S: "You're out. That's the part I care about.|-Drink that while it's hot.",
             F: "I watched you go down and I couldn't move.|Don't make me think about it."},
            {V: "Your lads had me by the collar.|Tell them I'll stand them the next cask.",
             S: "Your lads had me by the collar before I knew I was down.|I never thanked them.",
             F: "I'd still be lying there if your lads hadn't come.|I don't know what to do with that."},
            {V: "Thank them by killing more next time.|That's what I told them.",
             S: "They know.|-The big one will want it in ale, mind.",
             F: "Just stand where I can see you.|That's all I want."},
        ],
    },
    "gutted": {
        "about": "lost_half",
        "tell": "{company_s} went into {place} {men_before} strong and came out {men_after}.",
        "beats": [
            {V: "{men_before} I walked in with. {men_after} walked out.|Somebody is paying for that.",
             S: "{men_before} in. {men_after} out.|I've been counting it over like it'll change.",
             F: "I can't go back to my own fire.|{lost_n} empty places. I can't."},
            {V: "Then we find who did it and we make the count even.",
             S: "Sit at mine tonight.|Nobody will say anything.",
             F: "I don't know what to say.|I'm sorry. I'm so sorry."},
            {V: "The ones left are angry.|Good. Angry holds a line.",
             S: "The ones left are young.|They'll want telling what to do tomorrow.",
             F: "The ones left look at me like I did it."},
            {V: "Then let them be angry beside mine.|I'll put you on my right.",
             S: "Then tomorrow my {company_p} stand with yours till they're more than a handful.|Agreed?",
             F: "Put them next to mine.|Mine will look after them. And they'll look after me, I think."},
        ],
    },
    "walls": {
        "about": "most_kills",
        "tell": "They went over the wall at {place} on the same ladder, {S} first.",
        "beats": [
            {V: "I'd go up that ladder again right now.|Give the word.",
             S: "My legs have only now stopped shaking from the ladder.|Took till dark.",
             F: "That ladder.|I'll see it every time I close my eyes."},
            {V: "Next time I'm first up.|You can hold it steady.",
             S: "You went up it, though.|-That's what the men will remember.",
             F: "I counted you going up.|Every rung."},
            {V: "The gate was the slow part.|I hate a gate.",
             S: "You could hear the ram from up on the wall.|Like a heartbeat, the lads said.",
             F: "I lost a {lost} on the ladder.|Can you believe that's what I keep thinking of?"},
            {V: "Next wall, we take it faster.",
             S: "Next wall we'll know what to do.|-That's the only good thing about a wall.",
             F: "I'm glad it was you beside me up there.|That's all."},
        ],
    },
    "ford": {
        "about": "most_kills",
        "tell": "They fought in the {river} at {place}, up to the knees, with the current pulling at both lines.",
        "beats": [
            {V: "Fighting in water.|Whoever chose that ford owes me boots.",
             S: "I've still got half the {river} in my boots.",
             F: "The water.|I couldn't hear anyone over the water."},
            {V: "They chose it.|We made them regret it.",
             S: "Hang them by the fire.|-They'll be dry by morning, mostly.",
             F: "I kept shouting your name.|I don't think you heard me."},
            {V: "Their line broke in the shallows.|I saw it go and I went through it.",
             S: "The cold does something to a grip.|I dropped my {weapon} twice.",
             F: "I nearly went down on the stones.|If I'd gone down..."},
            {V: "I saw you go through.|I was behind you. Leave me some next time.",
             S: "Everyone dropped something.|-Nobody says.|Dry your feet.",
             F: "You didn't go down.|Look at me. You didn't."},
        ],
    },
    "first_blood": {
        "about": "first_battle",
        "tell": "It was {S}'s first battle with the company.",
        "beats": [
            {V: "So that's a battle.|I expected more of them.",
             S: "So that was a battle.|I thought it would be louder. Then it was louder.",
             F: "I was sick after.|Behind the wagons. Don't tell them."},
            {V: "There'll be more.|Save some of that.",
             S: "First one. You stood.|That's the whole of the first one.",
             F: "I was sick after my first.|And my second. Nobody told me it stops."},
            {V: "I got {kills}.|I counted.",
             S: "I don't remember most of it.|I remember your {company_p} on my left, and that was enough.",
             F: "I kept looking for your banner.|When I could see it I was all right."},
            {V: "Count higher next time.|I'll be watching.",
             S: "It comes back in pieces, over a few days.|Sit by me when it does.",
             F: "Nobody remembers their first. Only that they stood.|Don't tell the men I said anything kind."},
        ],
    },
    "hardest": {
        "about": "most_kills",
        "tell": "At {place} nobody in the company cut down more than {S}: {kills}, by the men's count.",
        "beats": [
            {V: ["{kills}.|Tell the others. No. I'll tell them.",
                 "{kills}. The men are saying {kills}.|It was more. They weren't counting the first rush."],
             S: ["{kills}, they're saying.|I don't remember more than three.",
                 "My arm's gone.|Not hurt. Just gone. I can't lift the cup."],
             F: ["They keep saying {kills} like it's a good thing.|I can't feel my hands.",
                 "I don't want them clapping me on the back.|Can you tell them to stop?"]},
            {V: ["{kills}.|I'll beat it next time.",
                 "Then I'll put it about as {kills} and let them argue.|+I'll say it was twenty. Nobody checks."],
             S: ["The men counted.|They'll be telling it for a week.",
                 "Here. Two hands.|Like a child. Nobody's looking."],
             F: ["I watched you.|I've never seen anything like it. I don't want to again.",
                 "I'll tell them.|Sit behind me. They won't come past me."]},
            {V: ["There was one with a red shield.|He was good. He isn't any more.",
                 "The first rush was the good part.|After that they were just standing there to be hit."],
             S: ["There was one who wouldn't go down.|I keep seeing him. Red shield.",
                 "I don't know how it happened.|One minute I was holding the line. Then I was through it."],
             F: ["One of them looked at me, right at the end.|Younger than me.",
                 "I didn't decide any of it.|My hands did. That's the part I can't sit with."]},
            {V: ["Then that's one you won't meet again.|Eat something.",
                 "Standing still is their lookout.|Eat something, you've gone grey."],
             S: ["They all have faces afterward.|Eat something. It helps, a bit.",
                 "That's how it goes, when it goes.|Nobody plans it. Eat."],
             F: ["Don't. Not tonight.|Here. I saved you the {food}.",
                 "Your hands did what they were drilled to.|That's all. Here, take the {food}."]},
        ],
    },
    "lord": {
        "about": "most_kills",
        "tell": "It was {enemy}'s own host at {place}, under their banner, and the company {outcome} the field.",
        "beats": [
            {V: "A lord's own men.|Did you see their faces when the line held?",
             S: "Proper soldiers today. Paid ones.|You can tell by the boots.",
             F: "Those were real soldiers.|I kept thinking, these ones know what they're doing."},
            {V: "They'll know our banner now.|Good.",
             S: "Paid or not, they bled the same.",
             F: "So did we, though.|Know what we were doing. Didn't we?"},
            {V: "{enemy}'s banner.|I want to be there when it comes down for good.",
             S: "{enemy}.|That's a name that will remember us.",
             F: "{enemy} will want that back.|They'll come for it."},
            {V: "Let them come.",
             S: "If they come we'll be stood the same way.|Pass the {food}.",
             F: "Then we'll be stood together when they do.|Pass the {food}."},
        ],
    },
    "bandits": {
        "about": "most_kills",
        "tell": "{enemy} on the road by {place}. The company {outcome} the field.",
        "beats": [
            {V: ["{enemy}.|Not a proper fight. Barely worth the bandages.",
                 "They ran before I'd got going.|{enemy}. I'd hoped for better."],
             S: ["{enemy}.|They'll be back with new boys by spring.",
                 "Road work.|Somebody has to do it, and it's us."],
             F: ["I don't like the hooded ones.|You can't see what they're thinking.",
                 "They came out of the trees so fast.|I didn't see them till they were on us."]},
            {V: ["Worth the silver, though.",
                 "Better than a quiet road.|A quiet road pays nothing."],
             S: ["They always are.|The roads don't clear themselves.",
                 "Somebody has to.|And the bounty buys bread."],
             F: ["They're thinking about running.|That's what I tell myself.",
                 "Nor did I.|I don't think anybody did. We held anyway."]},
            {V: ["One of them had a {lost} off a dead man of ours.|I took it back.",
                 "Their chief had a good horse.|Better than he deserved. I've got it now."],
             S: ["Half of them were farmers a year ago.|You can tell by how they hold a spear.",
                 "One of them asked for quarter in the old tongue.|My grandmother's words. I gave it."],
             F: ["One of them was a boy.|I didn't. My men did.",
                 "One of them got close enough that I could smell him.|Smoke and wet wool. I can still smell it."]},
            {V: ["Whatever you took off them, keep it.|They'd have taken more off us.",
                 "Don't waste a thought on them.|They'd have cut your throat for the boots."],
             S: ["A year from now the other half will be farmers again, if we let them run.",
                 "Quarter was right.|We're not them. Pass the {food}."],
             F: ["Don't carry that one.|Give it to me. I've got room.",
                 "Wash. Properly, in the stream, not a bucket.|It goes, after a wash. Mostly."]},
        ],
    },
    "plain": {
        "about": "most_kills",
        "tell": "A fight by {place}, like a dozen others. The company {outcome} the field.",
        "beats": [
            {V: "Nothing to say about today.|I'm tired.",
             S: "Quiet one, today.|I'll take a quiet one.",
             F: "I'm all right.|I keep checking, and I'm all right."},
            {V: "A day like that is allowed.|Once.",
             S: "Take a day like that when it comes.|There won't be many.",
             F: "Same.|I keep counting my fingers like they might have gone."},
            {V: "{place}.|I'll remember it for the mud.",
             S: "{place}.|Won't be the last time we see it.",
             F: "{place}.|I've put it in my book. Everywhere we fight, I write down."},
            {V: "The mud and nothing else.|Go to sleep.",
             S: "Then next time we'll know where the mud is.|Sleep.",
             F: "Write me in it.|Beside you. Go to sleep."},
        ],
    },
}

# ----------------------------------------------------------------- what it comes to
# The partner says what the rank means; the other answers. Then one line of narration.
RANK_BEAT = {
    "C": {V: ["Tomorrow you keep on my left.|I'll not go looking for you twice.",
              "Tomorrow, when I go in, you come in.|Don't wait to be asked.",
              "Stay in reach tomorrow.|If I shout, I want it to be you that hears."],
          S: ["Tomorrow, stay where I can reach you.",
              "Same ground tomorrow.|You on the left, me on the right.|-We'll see how it goes.",
              "I'll look for your banner first thing tomorrow.|Keep it up where I can see it."],
          F: ["Tomorrow stay close.|I mean it.",
              "Can we stand nearer tomorrow?|Just a bit nearer. It helps.",
              "Tomorrow, if I can see you, I'll be all right.|So let me see you."]},
    "B": {V: ["I moved my men before you called for it today.|Don't get used to it.",
              "I knew where you'd go today before you went.|Annoying. Useful, but annoying.",
              "I didn't look for your banner today.|Didn't need to. Knew where it was."],
          S: ["I moved my men before you called for it.|I noticed you'd noticed.",
              "We didn't shout to each other once today.|Did you notice? Not once.",
              "I turned my line today and yours was already turning.|That's new."],
          F: ["I moved before you called today.|I wasn't sure. I did it anyway.",
              "I knew you'd come when I went forward.|I didn't look back to check. First time.",
              "Today I wasn't frightened of the gap on my left.|Because it was you in it."]},
    "A": {V: ["The men have started calling us by one name.|I've stopped correcting them.",
              "A man from another company asked which of us was which.|I told him it didn't matter.",
              "They put us in a song last night.|Terrible song. Decent verse about you."],
          S: ["They say our names together now, the men.|Had you noticed?",
              "When they say my name now, yours comes after it.|Nobody decided that. It just does.",
              "The new ones think we've always been like this.|I suppose we have, a while now."],
          F: ["Someone called us 'the pair' today.|I liked it. Don't tell anyone.",
              "The young ones watch how we stand and copy it.|I never thought anyone would copy me.",
              "My mother would have liked you.|I've no idea why I said that. Forget it."]},
}
RANK_REPLY = {
    "C": {V: ["Fine.|But I'll not be slow about it.", "Agreed.|Mind you keep up.", "Done.|And the same goes for you."],
          S: ["Done.", "That's fair.|Same for you.", "Then that's settled.|Pass the cup."],
          F: ["I will.|I'll be there.", "Yes.|Yes. Thank you.", "All right.|I'd like that."]},
    "B": {V: ["I'd have called for it anyway.|Half a breath later.", "Don't flatter yourself.|I was already moving.", "Good.|Now I don't have to shout."],
          S: ["I was about to call for it.|We should stop telling each other things.", "I noticed.|I didn't say anything either.", "That's what it looked like from my end too."],
          F: ["I saw.|I'd have called for it. I think I would.", "I noticed.|It made the whole day easier.", "I'm glad.|I was hoping it wasn't only me."]},
    "A": {V: ["Good.|As long as my name comes first.", "Let them.|They've got it right for once.", "I'd have said the same.|Don't look so surprised."],
          S: ["They're not wrong.|Are they.", "I'd noticed.|I didn't mind.", "So it seems.|It'll do."],
          F: ["I don't mind it.|I thought I would.", "I'd noticed.|I didn't want to say, in case it stopped.", "Don't make me answer that.|Pass the cup. Thank you."]},
}
CLOSINGS = {
    "C": ["Nothing is settled. But tomorrow each will know where the other is.",
          "They don't say more than that. In the morning they'll fall in beside each other without being told.",
          "That's the end of it, for tonight. It's enough."],
    "B": ["Since {prev_place} they have moved before the other called for it. Today it showed.",
          "What began at {prev_place} has become a habit. Neither would call it that.",
          "They don't talk about {prev_place} any more. They don't need to."],
    "A": ["The company has started saying their names together. Neither of them minds.",
          "From {prev_place} to here. The men have noticed, and have stopped remarking on it.",
          "Whatever happens now, it happens to both of them. They've known that since {prev_place}."],
}


# ----------------------------------------------------------------- composing
def _seed(a_id, b_id, rank, salt=""):
    key = "%d|%d|%s|%s" % (min(a_id, b_id), max(a_id, b_id), rank, salt)
    return int(hashlib.md5(key.encode()).hexdigest()[:8], 16)


def hooks_for(facts):
    """Every hook the facts support, most particular first."""
    a, b, bt = facts["a"], facts["b"], facts["battle"]
    out = []
    if bt.get("fallen_friend"):
        out.append("fallen_friend")
    for c in (a, b):
        if c["fate"] == "wounded" and 0 < c["roll"] - c["needed"] <= CLOSE_CALL_MARGIN:
            out.append("close_call")
            break
    for c in (a, b):
        if c["men_before"] > 0 and c["men_after"] <= c["men_before"] // 2:
            out.append("gutted")
            break
    if bt["objective"] == "siege":
        out.append("walls")
    if bt["site"] == "ford":
        out.append("ford")
    if a["first_battle"] or b["first_battle"]:
        out.append("first_blood")
    if bt["most_kills_id"] in (a["id"], b["id"]) and max(a["kills"], b["kills"]) >= 4:
        out.append("hardest")
    if bt["enemy_is_lord"]:
        out.append("lord")
    if bt["enemy_is_bandits"]:
        out.append("bandits")
    out.append("plain")
    return out


def pick_hook(facts, avoid=()):
    """The most particular thing that happened that no other pair's talk from the same
    battle is already about; the most particular of all if every one is taken."""
    candidates = hooks_for(facts)
    for h in candidates:
        if h not in avoid:
            return h
    return candidates[0]


def _subject(hook, facts):
    a, b, bt = facts["a"], facts["b"], facts["battle"]
    about = HOOKS[hook]["about"]
    if about == "nearly_died":
        for c in (a, b):
            if c["fate"] == "wounded" and 0 < c["roll"] - c["needed"] <= CLOSE_CALL_MARGIN:
                return c
    if about == "lost_half":
        for c in (a, b):
            if c["men_before"] > 0 and c["men_after"] <= c["men_before"] // 2:
                return c
    if about == "first_battle":
        return a if a["first_battle"] else b
    if about == "closer_to_fallen":
        return a if a["bond_with_fallen"] >= b["bond_with_fallen"] else b
    if a["kills"] != b["kills"]:
        return a if a["kills"] > b["kills"] else b
    return a if a["battles"] >= b["battles"] else b


def _cap(text):
    """Capitalise the first letter of each sentence (slot names start lowercase)."""
    out = []
    start = True
    for ch in text:
        out.append(ch.upper() if start and ch.isalpha() else ch)
        if ch.isalpha() or ch.isdigit():
            start = False
        elif ch in ".!?":
            start = True
    return "".join(out)


def _variant(line, rng, heard, key):
    """Of a line's variants, the one the company has heard least; the seed breaks ties.
    `heard` is the campaign-wide count by (key, variant), kept in the save."""
    if not isinstance(line, list):
        return line
    order = list(range(len(line)))
    rng.shuffle(order)
    best = min(order, key=lambda i: heard.get((key, i), 0))
    heard[(key, best)] = heard.get((key, best), 0) + 1
    return line[best]


def _say(line, speaker, listener, slots, first_line, rng=None, heard=None, key=None):
    if isinstance(line, list):
        line = _variant(line, rng, heard if heard is not None else {}, key)
    parts = line.split("|")
    voice = speaker["voice"]
    kept = []
    for i, p in enumerate(parts):
        # "+": said only by a talker. "-": dropped by a captain of few words.
        if p.startswith("+"):
            if voice == "talks":
                kept.append(p[1:])
            continue
        if p.startswith("-"):
            if voice != "short":
                kept.append(p[1:])
            continue
        kept.append(p)
    text = " ".join(kept)
    if voice == "formal" and first_line and "{partner}" not in text:
        text = listener["first"] + ". " + text
    return _cap(text.format(**slots))


def compose(facts, rng_salt="", avoid=(), heard=None):
    a, b, bt, rank = facts["a"], facts["b"], facts["battle"], facts["rank"]
    heard = heard if heard is not None else {}
    hook = pick_hook(facts, avoid)
    s = _subject(hook, facts)
    p = b if s is a else a
    seed = _seed(a["id"], b["id"], rank, rng_salt)
    rng = random.Random(seed)
    cultures = tuple(sorted([a["culture"], b["culture"]]))
    by_culture = {}
    for c in (a, b):
        by_culture[{"vardish": "V", "kharzani": "K", "ryumon": "R"}[c["culture"]]] = c["first"]
    base = {"S": s["first"], "P": p["first"], "place": bt["place"], "enemy": bt["enemy"],
            "river": bt.get("river", "river"), "fallen": bt.get("fallen_friend", ""),
            "prev_place": facts.get("prev_place", bt["place"]),
            "outcome": "held" if bt["won"] else "lost",
            "company_s": s["company"], "company_p": p["company"],
            "men_before": s["men_before"], "men_after": s["men_after"], "lost_n": s["men_before"] - s["men_after"],
            "kills": s["kills"]}
    base.update(by_culture)
    opening = _variant(OPENINGS[cultures], rng, heard, ("opening",) + cultures).format(**base)
    wounded = [c for c in (a, b) if c["wounded"]]
    if wounded:
        opening += WOUNDED_TAIL.format(W=wounded[0]["first"])
    tell = HOOKS[hook]["tell"].format(**base)
    lines = []
    spoken = {s["id"]: False, p["id"]: False}
    for i, beat in enumerate(HOOKS[hook]["beats"]):
        speaker, listener = (s, p) if i % 2 == 0 else (p, s)
        slots = dict(base, partner=listener["first"], lost=rng.choice(LOST[speaker["culture"]]),
                     food=rng.choice(FOOD[speaker["culture"]]), weapon=WEAPON[speaker["culture"]][speaker["type"]])
        lines.append((speaker["first"], _say(beat[speaker["temperament"]], speaker, listener, slots, not spoken[speaker["id"]],
                                             rng, heard, (hook, i, speaker["temperament"]))))
        spoken[speaker["id"]] = True
    slots = dict(base, partner=s["first"])
    lines.append((p["first"], _say(RANK_BEAT[rank][p["temperament"]], p, s, slots, False, rng, heard, ("rank", rank, p["temperament"]))))
    slots = dict(base, partner=p["first"])
    lines.append((s["first"], _say(RANK_REPLY[rank][s["temperament"]], s, p, slots, False, rng, heard, ("reply", rank, s["temperament"]))))
    closing = _cap(_variant(CLOSINGS[rank], rng, heard, ("closing", rank)).format(**base))
    tell = _cap(tell)
    return {"hook": hook, "subject": s["first"], "opening": opening, "tell": tell, "lines": lines, "closing": closing,
            "skeleton": (hook, s["temperament"], p["temperament"], rank)}


def render(t, title):
    out = ["== %s  [hook: %s, about %s]" % (title, t["hook"], t["subject"]), "   " + t["opening"], "   " + t["tell"]]
    for who, text in t["lines"]:
        out.append("%10s: %s" % (who.upper(), text))
    out.append("   " + t["closing"])
    return "\n".join(out)


# ----------------------------------------------------------------- samples
def captain(id, first, culture, type, temperament, voice, battles=5, company=None):
    return {"id": id, "first": first, "culture": culture, "type": type, "temperament": temperament, "voice": voice,
            "battles": battles, "company": company or first + "'s men", "wounded": 0, "fate": "fine", "kills": 0,
            "roll": 0, "needed": 0, "men_before": 40, "men_after": 38, "first_battle": False, "bond_with_fallen": 0}


def battle(place, enemy, won=True, objective="rout", site="field", river="", most_kills_id=0, lord=False, bandits=True, fallen=""):
    return {"place": place, "enemy": enemy, "won": won, "objective": objective, "site": site, "river": river,
            "most_kills_id": most_kills_id, "enemy_is_lord": lord, "enemy_is_bandits": bandits, "fallen_friend": fallen}


def samples():
    brann = captain(1, "Brann", "vardish", "infantry", S, "short", 9, "Brann's Shields")
    tariq = captain(2, "Tariq", "kharzani", "cavalry", F, "talks", 3, "Tariq's Riders")
    tariq.update(wounded=1, fate="wounded", roll=49, needed=45, kills=2)
    brann.update(kills=7)
    yield "Brann & Tariq, rank C, after the Raven ford", {"a": brann, "b": tariq, "rank": "C",
        "battle": battle("Ravensford", "the Fenland cutthroats", site="ford", river="Raven", most_kills_id=1)}

    brann2 = dict(brann, wounded=1, fate="wounded", roll=70, needed=45, kills=3)
    tariq2 = dict(tariq, wounded=0, fate="fine", roll=0, needed=0, kills=9, battles=5)
    yield "Brann & Tariq, rank B, after storming Highcliff", {"a": brann2, "b": tariq2, "rank": "B", "prev_place": "the Raven ford",
        "battle": battle("Highcliff", "the garrison of Highcliff", objective="siege", most_kills_id=2, bandits=False)}

    mira = captain(3, "Mira", "vardish", "archers", V, "plain", 6, "Mira's Bows")
    hideo = captain(4, "Hideo", "ryumon", "spearmen", S, "formal", 2, "Hideo's Yari")
    hideo.update(first_battle=False, kills=5)
    mira.update(kills=5)
    yield "Mira & Hideo, rank C, after a plain fight at Thornwall", {"a": mira, "b": hideo, "rank": "C",
        "battle": battle("Thornwall", "the Ash Hill brigands", most_kills_id=9)}

    layla = captain(5, "Layla", "kharzani", "spearmen", F, "plain", 4, "Layla's Spears")
    kenji = captain(6, "Kenji", "ryumon", "archers", V, "short", 7, "Kenji's Yumi")
    layla.update(men_before=42, men_after=17, kills=1)
    kenji.update(kills=6)
    yield "Layla & Kenji, rank A, after Layla's squad was gutted at Khalun", {"a": layla, "b": kenji, "rank": "A", "prev_place": "Qasr Hamra",
        "battle": battle("Khalun", "the Emir of Khalun's host", won=False, most_kills_id=6, lord=True, bandits=False)}


# ----------------------------------------------------------------- simulation
NAMES = {"vardish": ["Brann", "Mira", "Aldric", "Tamsin", "Corwin", "Rhys", "Isolde", "Garrick", "Wenna", "Osric"],
         "kharzani": ["Tariq", "Layla", "Rustam", "Nasrin", "Kamal", "Selim", "Yasmin", "Farid"],
         "ryumon": ["Hideo", "Aiko", "Kenji", "Sayo", "Takeshi", "Haru", "Masaru", "Emi"]}
PLACES = ["Ravensford", "Highcliff", "Thornwall", "Marchgate", "Khalun", "Qasr Hamra", "Kitayama", "Kurogane", "Bramblemoor", "Ashby"]
BANDS = ["the Fenland cutthroats", "the Ash Hill brigands", "the Red Waste reavers", "a ronin band", "Wako pirates"]
LORDS = ["the Emir of Khalun", "Lord Osric of Marchgate", "the Shogun's marshal"]


def pad_variants(n):
    """For measurement only: pretend every line has at least n variants, so the
    simulation shows what the writing budget buys before the lines are written."""
    def pad(line):
        lines = line if isinstance(line, list) else [line]
        return lines + ["%s (v%d)" % (lines[0], i + 1) for i in range(len(lines), n)]
    for hook in HOOKS.values():
        hook["beats"] = [{t: pad(l) for t, l in beat.items()} for beat in hook["beats"]]
    for table in (RANK_BEAT, RANK_REPLY):
        for rank in table:
            table[rank] = {t: pad(l) for t, l in table[rank].items()}


def simulate(campaigns=300, battles=30, seed=1):
    rng = random.Random(seed)
    first_campaign = []
    line_totals = {}
    exact_dups = 0
    skel_dups = 0
    talks_total = 0
    line_max = []
    hook_share = {}
    for ci in range(campaigns):
        home = rng.choice(list(NAMES))
        caps = []
        used = set()
        for i in range(6):
            cult = home if rng.random() < 0.8 else rng.choice(list(NAMES))
            name = rng.choice([n for n in NAMES[cult] if n not in used])
            used.add(name)
            caps.append(captain(i + 1, name, cult, rng.choice(list(WEAPON["vardish"])), rng.choice([V, S, F]), rng.choice(VOICES), 0))
        points = {}
        prev_place = {}
        heard = {}
        texts, skels, lines = [], [], {}
        for bi in range(battles):
            place = rng.choice(PLACES)
            is_lord = rng.random() < 0.25
            objective = "siege" if rng.random() < 0.12 else "rout"
            site = "ford" if rng.random() < 0.15 else "field"
            fought = [c for c in caps if rng.random() < 0.85]
            for c in caps:
                c["first_battle"] = c["battles"] == 0 and c in fought
                c["kills"] = rng.randint(0, 9) if c in fought else 0
                c["men_before"] = rng.randint(20, 48)
                c["men_after"] = c["men_before"] - rng.randint(0, 6 if rng.random() < 0.9 else 30)
                c["men_after"] = max(0, c["men_after"])
                c["fate"] = "wounded" if (c in fought and rng.random() < 0.12) else "fine"
                c["roll"] = rng.randint(1, 100) if c["fate"] == "wounded" else 0
                c["needed"] = 45
                c["wounded"] = 1 if c["fate"] == "wounded" else 0
            most = max(fought, key=lambda c: c["kills"])["id"] if fought else 0
            bt = battle(place, rng.choice(LORDS) if is_lord else rng.choice(BANDS), rng.random() < 0.7, objective, site,
                        "Raven", most, is_lord, not is_lord)
            used_hooks = []
            for i in range(len(fought)):
                for j in range(i + 1, len(fought)):
                    a, b = fought[i], fought[j]
                    key = (a["id"], b["id"])
                    before = points.get(key, 0.0)
                    after = before + rng.uniform(1.0, 6.0)
                    points[key] = after
                    ranks = [r for r, pt in (("C", 5.0), ("B", 12.0), ("A", 22.0)) if before < pt <= after]
                    for r in ranks:
                        facts = {"a": a, "b": b, "rank": r, "battle": bt, "prev_place": prev_place.get(key, place)}
                        t = compose(facts, avoid=used_hooks, heard=heard)
                        used_hooks.append(t["hook"])
                        prev_place[key] = place
                        texts.append(" ".join(x for _, x in t["lines"]))
                        skels.append(t["skeleton"])
                        for who, x in t["lines"]:
                            lines[x] = lines.get(x, 0) + 1
                        if ci == 0 and len(texts) <= 45:
                            first_campaign.append(t)
                        hook_share[t["hook"]] = hook_share.get(t["hook"], 0) + 1
            for c in fought:
                c["battles"] += 1
        talks_total += len(texts)
        exact_dups += len(texts) - len(set(texts))
        skel_dups += len(skels) - len(set(skels))
        line_max.append(max(lines.values()) if lines else 0)
        for x, c in lines.items():
            line_totals[x] = line_totals.get(x, 0) + c
    n = float(campaigns)
    print("campaigns: %d, talks per campaign: %.1f" % (campaigns, talks_total / n))
    print("exact duplicate exchanges per campaign: %.2f" % (exact_dups / n))
    print("same hook+temperaments+rank skeleton reused per campaign: %.2f" % (skel_dups / n))
    print("most times one line is heard in a campaign (mean): %.1f" % (sum(line_max) / n))
    print("lines heard most often, per campaign:")
    for x, c in sorted(line_totals.items(), key=lambda kv: -kv[1])[:6]:
        print("  %.1f  %s" % (c / n, x))
    total = sum(hook_share.values())
    print("hooks:", ", ".join("%s %d%%" % (h, 100 * c // total) for h, c in sorted(hook_share.items(), key=lambda x: -x[1])))
    return first_campaign


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "simulate":
        if len(sys.argv) > 2:
            pad_variants(int(sys.argv[2]))
        simulate()
    elif len(sys.argv) > 1 and sys.argv[1] == "campaign":
        # Every talk of one simulated campaign, in order, to read through for repetition.
        for i, t in enumerate(simulate(campaigns=1)):
            print(render(t, "talk %d" % (i + 1)))
            print()
    else:
        for title, facts in samples():
            print(render(compose(facts), title))
            print()

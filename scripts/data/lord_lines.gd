## What lords say when you talk with them, by who they are. Every beat of the talk is
## written four ways, one for each bearing, with a few lines apiece so the same lord
## doesn't repeat themselves and two lords of one bearing don't open alike:
##
##   Daring     loud, laughing, restless; wants a fight and a story, bored by caution
##   Cautious   measured and dry; counts men, costs and roads; trusts what's been proven
##   Honorable  courteous and plain; speaks of oaths, debts and the people in their care
##   Cruel      cold and transactional; quiet threats; respects strength and nothing else
##
## Words only: no rules live here. A line may hold {facts} (a place, a ruler, a sum),
## which the caller fills from the lord's own record. See `say`.
extends RefCounted

const Lords = preload("res://scripts/data/lords.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

const D := Lords.DARING
const C := Lords.CAUTIOUS
const H := Lords.HONORABLE
const X := Lords.CRUEL

const LINES := {
	# ---------------------------------------------------------------- greetings
	# The first time you speak. {holds}: "I hold Ravensford", "I rule the Kingdom of Vardmark".
	"first": {
		D: ["So you're the captain the taverns won't shut up about. {holds}. Tell me the stories are true; I've been bored for a month.",
			"A free company with its own banner! {holds}, and I've wanted a look at you. You're shorter than the songs.",
			"{holds}. I heard you fight for pay and win anyway. Good. Winners are the only people worth talking to."],
		C: ["So this is the company I keep hearing of. {holds}. I like to know who rides my roads, and how many, and why.",
			"{holds}. Your name reached me before you did, captain. Names travel fast. I prefer to judge slower.",
			"Captain. {holds}. I've counted your men twice from the ridge. Now I'd like to hear what they're for."],
		H: ["So you're the captain they speak of. {holds}. They say you keep your contracts. If so, you're welcome here.",
			"{holds}. I make a point of greeting anyone who rides armed through my lands. It saves misunderstanding later.",
			"Well met, captain. {holds}. Your company's name has reached us, and most of what's said is to your credit."],
		X: ["So you're the one they talk about. {holds}. I expected more men. Or bigger ones.",
			"{holds}. Everything on this road pays me in something, sellsword. I'm still deciding what you'll pay in.",
			"A sellsword with a reputation. {holds}. Reputations are cheap. Show me what you cost."],
	},
	# Met before, and they think neither well nor ill of you.
	"known": {
		D: ["You again! Good. Tell me what you've burned since I saw you last.",
			"Captain! I was just saying the war's gone dull, and here you are to prove me wrong.",
			"Back on my road? Then something's about to happen. It always does around you."],
		C: ["Captain. We've spoken before, and nothing bad came of it. That counts for a good deal with me.",
			"You again. Good. A face I know is one less thing to watch.",
			"Captain. The roads are no safer since we talked. I'm glad to see you still on them."],
		H: ["Well met again, captain. Your company keeps its name, I hear.",
			"Captain. Good to see you on your feet. Sit, if there's time.",
			"We meet again. I had hoped we would. There's too little plain talk in this war."],
		X: ["Back again. You're either useful or stubborn. I haven't decided which I prefer.",
			"Captain. I haven't forgotten our last talk. I forget very little.",
			"You keep turning up alive. I'm beginning to take it personally."],
	},
	# They think well of you (Warm or better).
	"warm": {
		D: ["There's my favourite sellsword! Come here. Who are we fighting?",
			"Captain! Good. I was about to do something stupid alone, and it's better with company."],
		C: ["Captain. I told the escort to stand easy when I saw your banner. I don't do that for many.",
			"It's good to see you. I mean that, and I rarely say it, so mark the day."],
		H: ["Captain. A friend on the road. Come, sit; my house is in your debt, and I'd like it to stay there a while.",
			"Well met, my friend. I've spoken of you at my table, and all of it was good."],
		X: ["Captain. You're one of the few people I don't have to watch. Don't make me start.",
			"You. Good. I was running short of people worth the breath."],
	},
	# They think ill of you (Bitter or worse).
	"cold": {
		D: ["You. I'd hoped the next time I saw that banner it would be across a field.",
			"Still breathing, captain? We'll have to see about that some sunny morning."],
		C: ["Captain. Keep your hands where my escort can see them, and say what you came to say.",
			"You. I've doubled the watch since we last met. Draw your own conclusions."],
		H: ["Captain. I'll hear you, because courtesy costs nothing. Don't mistake it for welcome.",
			"You've given my house cause for grievance. Speak, and be brief."],
		X: ["You've some nerve riding up to me. I admire nerve. Briefly.",
			"Say it quickly, sellsword. I'm deciding what you're worth alive."],
	},
	# You've met them in battle.
	"fought": {
		D: ["The captain who put me on my back! I've been wanting a word. Or a rematch. Either.",
			"You fight better than you look. I've told everyone so, so don't make a liar of me."],
		C: ["Captain. I remember your banner from the field. I learned from that day. I hope you didn't.",
			"We've crossed swords, you and I. I'd sooner cross words; they cost fewer men."],
		H: ["Captain. We've met across a field. You fought fairly, and I don't hold fair fights against anyone.",
			"The last I saw of your banner, it was coming at me. This is a better way to meet."],
		X: ["I remember you from the field. I remember everyone from the field.",
			"You've cost me men, captain. Men have a price. I'm keeping the account open."],
	},
	# You've done a job for them.
	"owed": {
		D: ["The captain who cleared my road! I owe you a drink, and I pay my drinking debts first.",
			"My people still talk about what you did for them. So do I, when nobody's listening."],
		C: ["Captain. My roads have been quieter since your work. I notice such things, and I don't forget who did them.",
			"You did what you said you'd do. You'd be surprised how few manage that."],
		H: ["Captain. My house has not forgotten what you did for it. Nor will it.",
			"Well met. The folk you helped still speak your name. I've let them."],
		X: ["You did a job for me and did it properly. That puts you ahead of most of my own men.",
			"Captain. Useful, as promised. I'll have more work for a blade that finishes things."],
	},
	# The head of the house you married into.
	"kin": {
		D: ["Family! Come and drink. The house is yours as much as mine now.",
			"There's my house's newest blade. They say you married well. I tell them the house did."],
		C: ["Kin, then. The house stands behind you, captain. Within reason.",
			"Family rides where it likes. Come in. I've had a place kept for you."],
		H: ["Welcome, kin of my house. There's a seat for you at our table, always.",
			"The house is glad of you. So am I, which surprises the house."],
		X: ["So you're family now. Don't think it buys you more than my patience.",
			"Kin. My house keeps its own. Even you."],
	},
	# The head of a house sworn to you by a pact of friendship.
	"pact": {
		D: ["Our sworn friend! Ride with us when there's anything worth riding at.",
			"The pact holds, captain. I'd hate to waste it on a quiet season."],
		C: ["Our pact holds, captain. I keep my word as you keep yours.",
			"Captain. Good. A sworn friend on the road is worth two garrisons."],
		H: ["Our sworn friend. The house remembers what you've done for it.",
			"Captain. The pact between us is the best thing my house has signed in years."],
		X: ["Our sworn friend. A pact is a leash at both ends, captain. Remember it.",
			"The pact holds. For now that makes you the only sellsword I trust."],
	},
	# Sworn to your crown. {fief}: their holding, or "All".
	"liege": {
		D: ["My liege! {fief} is held, the riders are restless, and I'm worse. Point us at something.",
			"My liege. {fief} stands. Now give me a war to go with it."],
		C: ["My liege. {fief} is held, the stores are counted, and the walls are sound. I checked them myself.",
			"My liege. {fief} is quiet. I'd like to keep it so, with your leave."],
		H: ["My liege. {fief} is held in your name, and my riders are ready.",
			"My liege. {fief} stands, and my oath with it. Command me."],
		X: ["My liege. {fief} is held. Nobody in it has given me cause to make an example. Yet.",
			"My liege. {fief} pays its dues on time now. Ask me how, or don't."],
	},
	# At a feast: theirs, yours, someone else's ({host}).
	"feast_host": {
		D: ["Welcome to my table, captain! Eat, drink, and don't let the speeches catch you sober."],
		C: ["Welcome to my table, captain. Eat well; I've paid for all of it and counted most of it."],
		H: ["Welcome to my table, captain. Eat, drink; the speeches come later, and I'll keep mine short."],
		X: ["You're at my table, captain. Eat. I like my guests fed before I decide about them."],
	},
	"feast_yours": {
		D: ["Your table's the talk of the realm, captain, and your wine's better than your reputation. Pour me more of both."],
		C: ["A generous table, captain. I've been working out what it cost you. I'm impressed, and a little worried."],
		H: ["You keep a good table, captain. A house is known by how it feeds its guests, and yours feeds them well."],
		X: ["A fine feast. Everyone here wants something from you, captain. I'm only more honest about it."],
	},
	"feast_guest": {
		D: ["Captain! Come to drink {host}'s cellar dry with the rest of us? There's a race on."],
		C: ["Captain. Here for {host}'s wine like the rest of us? Watch who refills your cup."],
		H: ["Captain. Come to honour {host}'s table? Then we're here for the same reason."],
		X: ["Captain. Drinking {host}'s wine? So is everyone who'd gladly see {host} dead. Good wine, though."],
	},
	# ---------------------------------------------------------------- the talk
	# Back to what else you might say.
	"again": {
		D: ["What else? Make it interesting.", "Go on. I've nowhere to be that's half as lively.", "And? You've a look like there's more."],
		C: ["What else, captain?", "Go on. I'm listening, and so is my escort.", "Is there more? Say it plainly."],
		H: ["What else would you ask of me?", "Speak on, captain.", "Is there anything more I can do for you?"],
		X: ["What else. Quickly.", "You're still here. So there's more.", "Go on. My patience is a short road."],
	},
	# News. {count}: "One thing", "Two things". {first}: the first of it.
	"news": {
		D: ["{count} since we last met, and the best first. {first}", "Ha, you've missed it all. {count}. {first}"],
		C: ["{count} since we last met. I'll give them to you as I had them. {first}", "{count} worth knowing. {first}"],
		H: ["{count} since we last met. {first}", "There is news. {count}. {first}"],
		X: ["{count}. I'll tell you for nothing, which is rare. {first}", "{count} since last time. {first}"],
	},
	"news_none": {
		D: ["Nothing! Not a siege, not a scandal. If the war gets any duller I'll start one of my own.",
			"No news worth the breath. Come back when someone's done something reckless."],
		C: ["Nothing you won't have heard already. Quiet weeks worry me more than loud ones.",
			"Nothing new. I've had three riders in this week, and they all said the same."],
		H: ["Nothing you won't have heard already. The war grinds on, and takes good people with it.",
			"No news, and I'm glad of it. News is rarely kind these days."],
		X: ["Nothing new. The same fools losing the same villages.",
			"Nothing. If I hear something worth silver, I won't be giving it away."],
	},
	# Their own ruler. {ruler}, {capital}.
	"king_loyal": {
		D: ["{ruler}? Leads from the front and drinks like a trooper. I'd follow that banner into the sea, and probably will.",
			"{ruler} gives me wars to ride in. What more does a lord want from a crown?"],
		C: ["{ruler} knows the business of war, and better, the cost of it. I sleep well under that banner.",
			"{ruler} has not yet asked me for anything foolish. In a ruler, that's the whole of it."],
		H: ["{ruler} has my oath, and has never given me cause to regret it.",
			"I'd follow {ruler} into the sea, and so would every lord of ours. Ask me something harder."],
		X: ["{ruler} lets me keep what I take. We understand each other.",
			"{ruler} is strong. I serve strength. The day that changes, ask me again."],
	},
	"king_doubt": {
		D: ["{ruler} sits at {capital} and holds councils. Councils! There's a war out here with nobody in it.",
			"I've asked {ruler} for leave to ride three times. Three times I got a letter. I can't charge a letter."],
		C: ["{ruler} sits at {capital} and counts the treasury while our villages burn. I've sent riders. They come back with promises.",
			"I've done the sums, captain. At this rate {ruler} runs out of villages before the enemy runs out of torches."],
		H: ["I swore to {ruler}, and I keep my oaths. I only wish {ruler} kept the one made to us: to defend what's ours.",
			"It isn't my place to speak ill of {ruler}. But my people ask when help is coming from {capital}, and I've stopped answering."],
		X: ["{ruler} has gone soft at {capital}. Soft crowns get eaten. I'm watching to see by whom.",
			"I pay {ruler} in men and silver and get speeches back. That's a bad trade, and I don't make bad trades for long."],
	},
	"king_ruler": {
		D: ["I am the crown here. Ask me what I'll do, and I'll tell you: something bold."],
		C: ["I am the crown here. What I'll do, I'll do when I'm sure of it, and not before."],
		H: ["I am the crown here. Ask me what I'll do, not what someone else will."],
		X: ["I am the crown. I don't explain myself to sellswords."],
	},
	"king_sworn": {
		D: ["You're the crown now. Tell me where to ride and I'm gone before you finish."],
		C: ["Whatever you ask of me, within the oath. I read it carefully before I swore it."],
		H: ["Whatever you ask of me. That was the oath."],
		X: ["You're the crown. Stay strong and I stay sworn. That's the whole arrangement."],
	},
	# Asked for a story.
	"story_ask": {
		D: ["Go on, then! Something with blood in it. I've heard all the tavern ones.",
			"A story? Yes! Make it a good one or I'll tell you three of mine."],
		C: ["Go on, then. Tell me something your company did. I learn more from a story than a muster roll.",
			"A story. Very well. I'll be listening for what you leave out."],
		H: ["Gladly. Tell me something your company did that I won't have heard in a tavern.",
			"I'd like that. A company is its deeds; tell me one of yours."],
		X: ["Amuse me, then. Something true. I can tell the difference.",
			"A story. Fine. Tell me what your company does to people who cross it."],
	},
	# ---------------------------------------------------------------- their troubles
	# {band}, {place}, {ruler}.
	"trouble_bandits": {
		D: ["{band}. They raid {place} and run before I can catch them. Run! I want a fight, and they won't stand still for one.",
			"{band}, near {place}. I'd deal with them myself, but {ruler} wants me at the front, and the front is more fun."],
		C: ["{band}. They bleed {place} every week, and {ruler} sends no one. I keep to my lands, but I cannot be everywhere on them.",
			"{band}, by {place}. I've the men to guard my walls or my roads, not both. I chose the walls."],
		H: ["{band}. They prey on {place}, on people who look to me, and every day I can't answer it shames my house.",
			"My people at {place} are robbed by {band} while my sword is sworn elsewhere. It weighs on me, captain. You've seen that."],
		X: ["{band}. They take from {place}. What's taken from {place} is taken from me, and nobody takes from me.",
			"{band}, near {place}. I'd hang them myself, but {ruler} keeps my riders busy. I want it done, and I want it seen."],
	},
	# {enemy}: the people they're at war with ("The Kharzani").
	"trouble_war": {
		D: ["{enemy}! The best sport in years, and there's too many of them even for me. Beat them once on my behalf and I'll sing about it.",
			"{enemy}. Give them a bloody nose for me and I'll remember it."],
		C: ["{enemy}. Every week a village burns and I move the line back another mile. Beat them once, anywhere, and I'll remember it.",
			"The war. {enemy} press me hard, and I can hold what I have, barely. A defeat for them buys me a season. I'd remember who bought it."],
		H: ["{enemy}. My people pay for this war in homes and sons. Beat its makers in the field, and my house will remember.",
			"The war. {enemy} burn what I'm sworn to protect. Anyone who beats them does me a service."],
		X: ["{enemy}. They burn my villages. I want theirs burned. Beat them and I'll remember who did it.",
			"{enemy} think my lands are easy. Teach them otherwise and you'll find me grateful, in my fashion."],
	},
	"trouble_none": {
		D: ["Trouble? I wish! My lands are so quiet I can hear the sheep thinking.",
			"Nothing. Not a brigand in ten miles. It's unbearable."],
		C: ["My lands are quiet, for once. I've checked twice. Ask me again when they're not.",
			"Nothing weighs on me today. Write the date down; it won't last."],
		H: ["My lands are at peace, and I'm thankful for it. Ask me again when they're not.",
			"Nothing troubles my people this week. I could wish for no better news."],
		X: ["Nothing. The last people who troubled me discourage the next.",
			"My lands are quiet. They know better."],
	},
	# A job you took for them and haven't done. {band}.
	"trouble_job": {
		D: ["{band} still ride! You said you'd deal with them. Are you saving them for a feast day?"],
		C: ["{band} still ride. You gave me your word, captain. I've planned around it."],
		H: ["{band} still ride. You gave me your word, captain. I'm trusting it yet."],
		X: ["{band} still breathe. You said otherwise. Fix one or the other."],
	},
	# You asked what it's worth. {silver}.
	"haggle": {
		D: ["Silver? Ha! Fine, {silver} when they're gone. I'd have paid more for a good story about it."],
		C: ["Hm. I'd hoped you'd do it for the road's sake. {silver} silver, then, and I'll want to see proof."],
		H: ["I had thought the deed its own reward. No matter. {silver} silver, when it's done."],
		X: ["Now you sound like someone I can deal with. {silver} silver, when they're dead. Not before."],
	},
	# You took the job.
	"take": {
		D: ["Good! Leave one alive to tell the others. Or don't. Find me after and tell me all of it.",
			"Ha! Go on, then. I envy you the afternoon."],
		C: ["Good. Find me when it's done. I'll want to know how many there were.",
			"Then it's agreed. Don't take risks for speed; I'd sooner it were done right."],
		H: ["You have my thanks, and you'll have more when it's done. Go safely.",
			"Good. Find me when it's done, or don't; I'll hear of it, and I'll remember."],
		X: ["Good. Make it ugly enough that I don't have to ask the next band twice.",
			"Then do it. I'll know when it's done. The crows will tell me."],
	},
	# ---------------------------------------------------------------- your crown
	# {ruler}: the one they're sworn to.
	"objection": {
		D: ["Your crown? I've heard of it. What has it done that's worth my name?",
			"A crown! Everyone's got one these days. Tell me what's fun about yours."],
		C: ["A new crown is a fragile thing. If it falls, my house falls with it. Show me it won't fall.",
			"You want my name on a crown that's a season old. I've seen what happens to the names on those."],
		H: ["I swore an oath to {ruler}. You'd have me break it for what, exactly?",
			"You're asking for my oath, captain. I've only the one, and {ruler} has it."],
		X: ["Everyone wants something from me. What do I get, and what happens if I say no?",
			"A crown wants my sword. So tell me the price, and tell me the threat. I'll weigh them."],
	},
	"go_on": {
		D: ["Go on! You've got me curious, and that's dangerous.", "Keep talking. I'll stop you when I'm bored."],
		C: ["Go on. I'm weighing it.", "Continue. I haven't said no."],
		H: ["Go on. I'll hear all of it before I answer.", "Speak. I owe you that much."],
		X: ["Go on. Make it worth what it's costing you.", "Keep going. I'm still listening, which is more than most get."],
	},
	"arg_liked": {
		D: ["Now that I like! Say more things like that."],
		C: ["...That is no small thing. A crown that thinks that way might last. Go on."],
		H: ["...That is well said, and I think you mean it. Go on."],
		X: ["Good. That's the first honest thing anyone's said about a crown this year."],
	},
	"arg_plain": {
		D: ["Maybe. It's a little dry. Try me with something that has a pulse."],
		C: ["Perhaps. Words are cheap on the road, and I've bought plenty."],
		H: ["Perhaps. I've heard fair words before, from people who didn't keep them."],
		X: ["Words. Everyone has words. What else have you got?"],
	},
	"arg_disliked": {
		D: ["That's meant to persuade me? I nearly dozed off."],
		C: ["That's meant to reassure me? It does the opposite."],
		H: ["That's meant to persuade me? You mistake what my house is, captain."],
		X: ["That's meant to move me? You sound like a priest."],
	},
	"arg_refuse": {
		D: ["Enough! You've bored me and insulted me, and I only forgive one of those. Ride on. Don't ask again this week."],
		C: ["Enough. I've heard what kind of crown this is, and it's the kind that falls. Ride on, and don't ask me again this week."],
		H: ["Enough. I've heard what kind of crown this is. Ride on, captain, and don't ask me again this week."],
		X: ["Enough. Ask me again this week and I'll take it as a challenge. Ride on."],
	},
	"silver": {
		D: ["That's a lot of silver! Do you know how many horses that is? I do."],
		C: ["That's a serious sum. It would rebuild what this war has burned, with some left over for walls."],
		H: ["A generous sum. It will go to the villages, not to me; I want that understood."],
		X: ["Silver. Well. It buys a great many swords."],
	},
	# {house}.
	"sworn": {
		D: ["Then it's done! House {house} rides with your crown. Now find us a war worthy of it."],
		C: ["Then hear it plainly: House {house} stands with your crown, as long as your crown stands. I've weighed it. I don't weigh twice."],
		H: ["Then hear it plainly: House {house} stands with your crown, and my oath with it. I do not give it lightly, and I will not take it back."],
		X: ["Then hear it: House {house} stands with your crown, as long as your crown stands. Stay strong, and you'll never have a better dog."],
	},
	# ---------------------------------------------------------------- steel
	"challenge": {
		D: ["Ha! I was hoping you'd say that.", "At last! I thought you'd never ask."],
		C: ["You'd risk your company on my road? Think carefully, captain. I already have.",
			"Steel, then. I'd hoped you were cleverer. Count my men again before you answer."],
		H: ["If it must be steel, let it be clean.", "I'd hoped it wouldn't come to this. If it must, we'll do it properly."],
		X: ["My riders have had no sport in a week. Shall I take your head, or your silver?",
			"You'd draw on me? Good. I was running out of reasons."],
	},
	"tribute": {
		D: ["Wise. Ride on, then."], C: ["Wise. Ride on, then."], H: ["Ride on, then."],
		X: ["Wise. Ride on, then, before I change my mind."],
	},
	"duel_accept": {
		D: ["Ha! A duel! Choose your champion. Mine's never lost, and I taught him half of it."],
		C: ["Single combat. Fewer men at risk; I'll allow it. Choose your champion with care."],
		H: ["A duel, then, by the old rules. Choose your champion. Mine will meet them fairly."],
		X: ["A duel. Choose your champion. Mine enjoys the work."],
	},
	# Your champion won. {champion}: their first name.
	"duel_lost": {
		D: ["Ha! Beaten! Your {champion} fights like a devil. I want to drink with them, and then I want to fight them myself."],
		C: ["...Yielded. I misjudged your {champion}. I don't often misjudge. I'll remember it."],
		H: ["Yielded, and fairly. Your {champion} does your company honour. I'll say so wherever I'm asked."],
		X: ["...Yielded. Your {champion} fights like a devil. I'll remember this, captain. Take that how you like."],
	},
	"duel_won": {
		D: ["Good fight! Get your champion to a surgeon, and tell them they made mine sweat."],
		C: ["As I expected. Get your champion to a surgeon. No shame in it; the odds were mine."],
		H: ["Well fought. See your champion to a surgeon; mine will send what's needed."],
		X: ["Get your champion to a surgeon. Or a priest. Better luck next time."],
	},
	# ---------------------------------------------------------------- in your camp, a captive
	"captive": {
		D: ["Well fought, I'll give you that. So what now? Chains bore me.",
			"You beat me! Me! I'd be angrier if it hadn't been such a good fight. What happens now?"],
		C: ["I'd sooner be home. Name your terms and let's be done.",
			"I've been working out what I'm worth to you. Shall I tell you the figure, or will you name one?"],
		H: ["You have kept me fairly, and fed my men. But I swore to {ruler}, and I do not break oaths. Not for silver, not for fear.",
			"I'm your prisoner, captain, and I'll give you no trouble. My word on it. It's all I've left to give."],
		X: ["Enjoy it while it lasts, sellsword. My house has a long memory.",
			"Chains. I've put enough people in them to know how this goes. Get on with it."],
	},
	"captive_swear": {
		D: ["So be it! I'll serve your crown. It can't be duller than the last one."],
		C: ["So be it. I'll serve your crown. I've weighed the other choices; this is the one I live through."],
		H: ["So be it. I'll serve your crown, and serve it honestly. I don't swear twice."],
		X: ["So be it. I'll serve your crown. You won. That's the only argument I've ever respected."],
	},
	"captive_release": {
		D: ["Free? Ha! I won't forget it. Next time we fight, I'll go easy for a whole minute."],
		C: ["I won't forget it. I keep careful accounts, captain, and this goes in your favour."],
		H: ["I won't forget it. Nor will my house, as long as it stands."],
		X: ["You're letting me go. I don't understand it. But I'll remember it."],
	},
	"captive_ransom": {
		D: ["They'll pay. They'll grumble, but they'll pay. I'm excellent value."],
		C: ["They'll pay. I'd have set the figure a little lower, but they'll pay."],
		H: ["They'll pay. I'm sorry for the cost to them; I'll make it good."],
		X: ["They'll pay. And then they'll remember who asked."],
	},
	"captive_chains": {
		D: ["Chains, then. You'll tire of me before I tire of them."],
		C: ["...As you wish. I'll count the days."],
		H: ["...So be it. I'll bear it."],
		X: ["..."],
	},
	# ---------------------------------------------------------------- orders, sworn to you
	"order_follow": {
		D: ["At your side! Try to keep up."], C: ["At your side, then. I'll keep the column tight."],
		H: ["At your side, then."], X: ["At your side. Point, and I'll do the rest."],
	},
	# {place}.
	"order_guard": {
		D: ["{place} will stand. I'd rather be riding, but it will stand."], C: ["{place} will stand. I'll see to the stores first."],
		H: ["{place} will stand while I do."], X: ["{place} will stand. Nobody will want to test it."],
	},
	"order_free": {
		D: ["As you say! I'll find something worth doing."], C: ["As you say. I'll keep to the realm's roads."],
		H: ["As you say. I'll see to the realm's business."], X: ["As you say. I've a few matters to settle."],
	},
}

## What they make of a story, by what kind of story it was (LordTalk's themes): the kind
## they like, the kind they can't abide, and the two they take as they come. Each answers
## the kind of deed, not one tale, so it fits a tale or a page of your chronicle alike.
const STORY := {
	D: {
		"boldness": ["Ha! That's the way of it. Fortune rides with whoever rides first.",
			"Yes! Straight at them! I'd have given my best horse to be there."],
		"prudence": ["You waited. You sat and waited. I'd have died of boredom before the enemy got there.",
			"Careful work. My steward would love it. I nearly fell asleep, but he'd love it."],
		"modesty": ["Kind of you. Not much of a story, mind. Nobody charges anybody."],
		"fear": ["Grim work. Quick, though, and I like quick."],
	},
	C: {
		"prudence": ["Good. Patience wins more wars than glory does. Most captains would have gone looking for the fight and found it somewhere worse.",
			"You chose your ground and let them pay for it. That's the whole art, and almost nobody learns it."],
		"boldness": ["Brave. Or lucky. Luck runs out, captain, and it usually takes the brave with it.",
			"And if they'd been ready for you? You've told me how you won. You haven't told me why you weren't killed."],
		"modesty": ["Generous. Generosity is an expense like any other. I hope you counted it."],
		"fear": ["It keeps the road quiet, I grant. Fear's a wall that needs mending every season, though."],
	},
	H: {
		"modesty": ["That speaks well of you. A sword that serves the weak is worth ten that serve themselves.",
			"And asked no song for it. Then I'll see it gets one. That's how a company should be known."],
		"fear": ["There are better ways to keep a road than a rope, captain. They last longer, too.",
			"You're proud of that. I'd think on why, if I were you."],
		"prudence": ["Soundly done. There's no shame in a careful victory; the men who came home will tell you so."],
		"boldness": ["Boldly done. I hope it was for something worth the risk to your men."],
	},
	X: {
		"fear": ["Good. People remember a rope longer than a sermon.",
			"Now that's a story. Nobody crosses you twice if nobody survives the once."],
		"modesty": ["You gave it away? Then you're softer than your banner says.",
			"Charity. And what did it buy you? Gratitude doesn't hold a wall."],
		"prudence": ["Patient. Patience is only cruelty that hasn't started yet. Acceptable."],
		"boldness": ["Loud. Effective, I suppose. I prefer it when they know what's coming and can't stop it."],
	},
}

## A custom of their land, said once, the first time you meet: where they're from shows.
const CUSTOM := {
	Cultures.VARDISH: {
		D: "In Vardmark a stranger gets one cup before anyone asks their business. Yours is poured.",
		C: "In Vardmark we ask a stranger's business before their name. So: your business?",
		H: "By Vardish custom the road's peace is mine to keep. Keep it with me.",
		X: "Vardish law says the road is free. Vardish law is a long way from here.",
	},
	Cultures.KHARZANI: {
		D: "In Kharzan a guest is safe for three days. On the fourth we find out what they're made of.",
		C: "In Kharzan we say a caravan is only as honest as its slowest camel. I'll be watching yours.",
		H: "In Kharzan a guest at the well is a guest of the house. Drink, and then we'll talk.",
		X: "In Kharzan water is owed to any traveller. You'll find I owe nothing else.",
	},
	Cultures.RYUMON: {
		D: "In Ryumon we bow before we fight. I've bowed. Pity we're not fighting.",
		C: "In Ryumon we say the mountain does not hurry. Neither do I, captain.",
		H: "In Ryumon a stranger is offered tea and the truth. I'm out of tea.",
		X: "In Ryumon a masterless sword is called a stray. Strays get fed or put down.",
	},
}


## How each line is said: the face a lord says it with (LordPortrait.MOODS), by beat and
## bearing; a list gives each of that bearing's lines its own, in order. A daring lord
## laughs and teases, a cautious one weighs and approves, an honourable one is warm or
## solemn, a cruel one smirks and glowers. ("" is their resting face.)
const MOODS := {
	"first": {D: ["amused", "tease", "proud"], C: ["thoughtful", "thoughtful", "determined"], H: ["warm", "", "warm"], X: ["tease", "grim", "grim"]},
	"known": {D: ["laugh", "amused", "tease"], C: ["proud", "", "warm"], H: "warm", X: ["tease", "grim", "tease"]},
	"warm": {D: ["laugh", "amused"], C: "warm", H: "warm", X: ["proud", "tease"]},
	"cold": {D: ["angry", "tease"], C: "grim", H: ["grim", "determined"], X: ["tease", "grim"]},
	"fought": {D: ["laugh", "amused"], C: ["determined", "proud"], H: ["proud", "warm"], X: "grim"},
	"owed": {D: ["laugh", "warm"], C: "proud", H: "warm", X: "proud"},
	"kin": {D: ["laugh", "amused"], C: ["proud", "warm"], H: ["warm", "amused"], X: ["tease", "proud"]},
	"pact": {D: ["laugh", "amused"], C: "proud", H: "warm", X: ["tease", "proud"]},
	"liege": {D: ["amused", "determined"], C: ["proud", "thoughtful"], H: "determined", X: "tease"},
	"feast_host": {D: "laugh", C: "amused", H: "warm", X: "tease"},
	"feast_yours": {D: "laugh", C: "worried", H: "warm", X: "tease"},
	"feast_guest": {D: "laugh", C: "tease", H: "warm", X: "tease"},
	"again": {D: ["amused", "amused", "tease"], C: ["", "tease", ""], H: ["warm", "", "warm"], X: ["grim", "tease", "grim"]},
	"news": {D: ["amused", "laugh"], C: "thoughtful", H: "", X: ["tease", ""]},
	"news_none": {D: ["laugh", "amused"], C: ["worried", "thoughtful"], H: ["sad", "worried"], X: ["grim", "tease"]},
	"king_loyal": {D: ["laugh", "amused"], C: "proud", H: "proud", X: ["tease", "determined"]},
	"king_doubt": {D: ["angry", "amused"], C: ["grim", "worried"], H: "sad", X: ["tease", "angry"]},
	"king_ruler": {D: "tease", C: "determined", H: "determined", X: "grim"},
	"king_sworn": {D: "laugh", C: "proud", H: "determined", X: "grim"},
	"story_ask": {D: "laugh", C: ["thoughtful", "tease"], H: "warm", X: ["tease", "grim"]},
	"trouble_bandits": {D: ["angry", "amused"], C: ["worried", "grim"], H: ["sad", "worried"], X: "angry"},
	"trouble_war": {D: ["laugh", "determined"], C: ["worried", "grim"], H: ["sad", "grim"], X: ["angry", "grim"]},
	"trouble_none": {D: "amused", C: ["proud", "amused"], H: "warm", X: "tease"},
	"trouble_job": {D: "tease", C: "grim", H: "worried", X: "angry"},
	"haggle": {D: "laugh", C: "thoughtful", H: "sad", X: "tease"},
	"take": {D: "laugh", C: ["determined", "worried"], H: "warm", X: "grim"},
	"objection": {D: ["tease", "amused"], C: ["worried", "thoughtful"], H: ["grim", "determined"], X: "grim"},
	"go_on": {D: ["amused", "tease"], C: "thoughtful", H: ["thoughtful", ""], X: "tease"},
	"arg_liked": {D: "laugh", C: "surprised", H: "warm", X: "proud"},
	"arg_plain": {D: "amused", C: "thoughtful", H: "thoughtful", X: "tease"},
	"arg_disliked": {D: "tease", C: "worried", H: "angry", X: "tease"},
	"arg_refuse": {D: "angry", C: "grim", H: "grim", X: "angry"},
	"silver": {D: "surprised", C: "surprised", H: "determined", X: "tease"},
	"sworn": {D: "laugh", C: "determined", H: "proud", X: "tease"},
	"challenge": {D: "laugh", C: "grim", H: ["determined", "sad"], X: ["tease", "angry"]},
	"tribute": {D: "proud", C: "proud", H: "", X: "tease"},
	"duel_accept": {D: "laugh", C: "determined", H: "determined", X: "tease"},
	"duel_lost": {D: "laugh", C: "grim", H: "warm", X: "angry"},
	"duel_won": {D: "laugh", C: "proud", H: "warm", X: "tease"},
	"captive": {D: ["amused", "laugh"], C: ["sad", "thoughtful"], H: ["determined", "sad"], X: ["angry", "grim"]},
	"captive_swear": {D: "laugh", C: "thoughtful", H: "determined", X: "grim"},
	"captive_release": {D: "laugh", C: "warm", H: "warm", X: "surprised"},
	"captive_ransom": {D: "amused", C: "amused", H: "sad", X: "tease"},
	"captive_chains": {D: "tease", C: "sad", H: "sad", X: "angry"},
	"order_follow": {D: "laugh", C: "determined", H: "determined", X: "determined"},
	"order_guard": {D: "determined", C: "determined", H: "determined", X: "tease"},
	"order_free": {D: "laugh", C: "", H: "", X: "tease"},
}

## How they say what they make of a story, as MOODS.
const STORY_MOODS := {
	D: {"boldness": "laugh", "prudence": ["tease", "amused"], "modesty": "amused", "fear": "amused"},
	C: {"prudence": "proud", "boldness": ["worried", "thoughtful"], "modesty": "thoughtful", "fear": "thoughtful"},
	H: {"modesty": "warm", "fear": ["sad", "grim"], "prudence": "proud", "boldness": "worried"},
	X: {"fear": ["proud", "tease"], "modesty": "tease", "prudence": "tease", "boldness": "thoughtful"},
}

static var _said: Dictionary = {}


## The face `lord` says `text` with, if it's one of their lines (MOODS, STORY_MOODS): ""
## if it isn't, or it's said at rest. Quotation marks and the custom a stranger is greeted
## with are looked past.
static func mood_of_line(text: String, lord: Dictionary) -> String:
	var bearing := String(lord.get("bearing", ""))
	var t := text.strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()
	var greeting := custom(lord)
	if greeting != "" and t.ends_with(greeting):
		t = t.trim_suffix(greeting).strip_edges()
	for said in _lines_of(bearing):
		if (said[0] as RegEx).search(t) != null:
			return String(said[1])
	return ""


## Every line of a bearing as a pattern (its {facts} matching anything) with its mood.
static func _lines_of(bearing: String) -> Array:
	if _said.has(bearing):
		return _said[bearing]
	var out := []
	var by: String = bearing if (LINES["first"] as Dictionary).has(bearing) else H
	for key in LINES:
		var options: Array = (LINES[key] as Dictionary).get(by, [])
		for i in options.size():
			out.append([_pattern(String(options[i])), _pick_mood(MOODS.get(key, {}).get(by, ""), i)])
	var stories: Dictionary = STORY.get(by, {})
	for theme in stories:
		for i in (stories[theme] as Array).size():
			out.append([_pattern(String(stories[theme][i])), _pick_mood(STORY_MOODS.get(by, {}).get(theme, ""), i)])
	_said[bearing] = out
	return out


static func _pick_mood(m, i: int) -> String:
	if m is Array:
		return String(m[mini(i, (m as Array).size() - 1)]) if not (m as Array).is_empty() else ""
	return String(m)


## A line as a pattern matching all of a said line: its words as written, any {fact} as
## whatever was put there.
static func _pattern(line: String) -> RegEx:
	var out := "^"
	var lit := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "{":
			var close := line.find("}", i)
			if close > i:
				out += _escape(lit) + "(.+?)"
				lit = ""
				i = close + 1
				continue
		lit += c
		i += 1
	var r := RegEx.new()
	r.compile("(?s)" + out + _escape(lit) + "$")
	return r


static func _escape(s: String) -> String:
	var out := ""
	for c in s:
		out += ("\\" + c) if ".^$*+?()[]{}|\\/".contains(c) else c
	return out


## What `lord` says for `key`, their own way, with {facts} filled in. `turn` picks which
## of their lines: it moves on each time, and starts differently for each lord, so a lord
## doesn't repeat themselves and two alike don't open alike. No quotation marks.
static func say(key: String, lord: Dictionary, facts: Dictionary = {}, turn: int = 0) -> String:
	var by_bearing: Dictionary = LINES.get(key, {})
	var options: Array = by_bearing.get(String(lord.get("bearing", "")), by_bearing.get(H, []))
	if options.is_empty():
		return "..."
	return String(options[posmod(int(lord.get("id", 0)) * 7 + turn, options.size())]).format(facts)


## What they make of a story of `theme`.
static func story(lord: Dictionary, theme: String, turn: int = 0) -> String:
	var by_theme: Dictionary = STORY.get(String(lord.get("bearing", "")), STORY[H])
	var options: Array = by_theme.get(theme, [])
	if options.is_empty():
		return "A good story. The road's shorter for it."
	return String(options[posmod(int(lord.get("id", 0)) + turn, options.size())])


## The custom of their land they greet a stranger with, or "".
static func custom(lord: Dictionary) -> String:
	var by_bearing: Dictionary = CUSTOM.get(String(lord.get("culture", "")), {})
	return String(by_bearing.get(String(lord.get("bearing", "")), ""))


## "One thing", "Two things", "5 things".
static func count_things(n: int) -> String:
	return "One thing" if n == 1 else ("Two things" if n == 2 else "%d things" % n)

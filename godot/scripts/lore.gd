class_name Lore
extends RefCounted
## The light mystery (plans/06 §4), text only. Every night you wake in the Flip Ward, and every blink flips it
## into his version. Others left notes; none of them got out. Notes are found in chests and Sanctuaries, in this
## order (MetaState.notes_found); an act's ending plays the first time its Gate falls; the Voice speaks on the
## death screen. Planted questions: who is he, why can you flip, who writes the notes, what is below F50.

## Thirty notes, 70 words at most. About two thirds teach a rule in a dead dreamer's voice; the rest feed the mystery.
const NOTES: Array[String] = [
	"If you're reading this, you woke up here too. Don't panic. Find the keys, open the chest, take the stairs down. That's all there is to it. That's what I told myself on the first night. - M.",
	"Sometimes the building changes without asking. Red light, wet walls. The same halls, the same doors, and he's faster there. - M.",
	"He's slow when he's close. Don't run. Walk. I know every part of you wants to run. Walk anyway. - Tomas",
	"The blue rings on the floor are safe. He won't step inside one. They don't last, though. Catch your breath and get moving. - Adaeze, night shift",
	"He's slower on the cold side. Not gone, slower. When the building turns red again, he's already running. - Tomas",
	"Cracked tiles hold you once. Never twice. If the floor creaks under your feet, the next step had better be somewhere else. - R.",
	"Night three. Or day three. The clocks here don't agree. I asked the woman at the desk upstairs how long I'd been admitted. She said I'd never been admitted. She said this wing closed in 1987. - M.",
	"Sometimes the building flips you on its own. You get a warning, three seconds. When it takes you, left is right and forward is back. Don't fight it. Think backwards. - Adaeze",
	"Dead ends eat time. Grab the keys on the way, not one at a time. The clock isn't kind and it isn't fair, but it's honest. - R.",
	"There's a word scratched under the bed in room 9: AWAKE. Under it, in different handwriting: NOT YET. Under that, in handwriting I don't remember using: HE'S LISTENING.",
	"Far away, he's fast. Close up, he's slow. It sounds backwards until you watch him walk. He isn't chasing you. He's closing a distance. - Tomas",
	"Your heartbeat knows before you do. When it gets loud, he's near. When it's deafening, find the blue. - Adaeze",
	"The nurses called it the Flip Ward. Insomniacs only. They said we could learn to step between waking and dreaming like walking between rooms. They never said what lived in the other room. - torn page, patient file",
	"If he lunges and misses, you get a heartbeat before he tries again. Use it. Most of us didn't. - Tomas",
	"Chests down dead ends are worth the detour. Mostly. Listen for him before you go in: a dead end only has one way out. - R.",
	"I found Tomas's flashlight on floor 12. Still warm. No Tomas. I kept walking. I'm sorry, Tomas. - M.",
	"Step into the blue right as he grabs and you slip through his fingers. The trick is waiting for the grab. Nobody is brave enough to wait. Be the first.",
	"The fifth floor of every layer is quiet. No footsteps, no heartbeat. Rest there. Read. It's the only place he doesn't go. I think it's the only place he can't. - Adaeze",
	"Adaeze says she's been a nurse here for eleven years. Her badge says 1986. She doesn't believe me when I tell her what year it is. She just smiles and checks my pupils. - M.",
	"The tenth floor is a gate. It knows what you're afraid of and it uses it. Get through and the way down stays open for good. - R.",
	"After a gate you can climb back up, bank what you found and sleep. Or you can keep going down. Deeper pays better. Deeper doesn't give your revives back. - Tomas",
	"He hums. Did anyone else notice? When he's close and slow, he hums. It's a lullaby. My mother sang it to me. How does he know it? - M.",
	"The deeper layers rearrange. Your map goes dark, the floors forget their shape. Learn the maze with your feet, not your eyes.",
	"Omens are real. Pick the one that fits how you play, not the one that sounds strongest. A good omen is a habit you already have. - R.",
	"Patient roster, Flip Ward, page 2. Twelve names. Eleven crossed out. The twelfth isn't crossed out. Someone keeps writing it over and over, pressing so hard the paper tore. I won't write it here. You already know it.",
	"In the last layers he stops letting go. When the building turns, he turns with it. The circles still hold. Run for the blue. - Adaeze, last shift",
	"The handwriting on these notes keeps changing. Except some of them. Some are in a hand I've seen every day of my life. I'm not going to say whose. Look at your own. - M.",
	"I asked him his name. He stopped. Actually stopped, in the middle of the corridor. Then he said mine. - R.",
	"Don't sprint when the floor creaks. Don't stop when the clock is low. Don't stop moving. That's all I know. It isn't enough. It's never enough. - Tomas",
	"If you're reading this, I didn't make it either. But I got further than the last one, and you'll get further than me. That's how it works down here. Each of us is a step. Step on me. Go down. - your handwriting",
]

## Each act's ending (150 words at most), shown the first time its Gate falls and kept in the Archive.
const ACT_ENDINGS: Array[String] = [
	"The tenth door opens on a stairwell that goes down further than your light. You came here thinking there was a way out at the top. There isn't. There never was. The only way out of a nightmare is through the bottom of it.\n\nOn the back of the gate someone has carved tally marks. Hundreds of them. The newest is still dusty, as if it was scratched there tonight.\n\nYou don't remember doing it. Your fingernails do.\n\nSomewhere below, slow footsteps start to walk.",
	"He has stopped hunting the others. You saw it on the eighth floor: the old trails in the dust, his and theirs, all end in the same places. Now there is only one trail he follows.\n\nAt the gate he finally speaks. Not loudly. He doesn't need to.\n\nHe says your name the way your mother did when it was time to wake up for school.\n\nThen he steps back into the red and lets you go. That frightens you more than anything. Hunters don't let go of the things they are afraid to lose.",
	"Your map stopped working three floors ago. You stopped needing it.\n\nPast the gate is the old ward office, exactly as the notes said. A desk, a lamp, a cabinet with one drawer pulled open. Inside is a file for every dreamer who ever wrote a note. Tomas. R. Adaeze, who was never a nurse at all, only the patient who stayed longest. M.\n\nAt the back, a file with your name on it. It is the thickest one. The first page is dated 1987. The last page is dated tonight, and the ink is still wet.",
	"The floors down here aren't stone. You understand that now, crossing the gate on tiles that crack in familiar shapes. Everyone who fell is still holding the maze up.\n\nOn the far side, Adaeze's last note is pinned to the wall, unfinished: 'He isn't a devil. He's the first one of us who stopped flipping. He stayed on the red side so long that it'\n\nThe rest is torn away.\n\nYou fold it into your pocket with the others. One more layer. Then the bottom. Then whatever he is.",
	"At the bottom there is no maze. Just a bed, and him sitting on it, smaller than you remembered. Tired. Humming.\n\n'Every night you come down,' he says. 'Every night you break the gate. Every night you wake up and forget.'\n\nYou break it anyway. You have to. The light comes up white and hospital clean, and you wake in a narrow bed with morning on your face.\n\nOn the bedside table: a pen and a stack of blank paper. Your hand, without asking you, starts to write. 'If you're reading this, you woke up here too.'",
]
## The Deep Run's ending (floor 1 to floor 50 in one run).
const TRUE_ENDING := "You never stopped. Fifty floors, one night, no waking. For the first time you reach the bottom before he does.\n\nThe bed is empty. The room is warm. On the pillow there is a dent the exact shape of your head.\n\nAll at once you understand why he waits where you vanish, why he hums your mother's lullaby, why he never seems to hate you. He isn't hunting a stranger. He is the part of you that stayed down here on the first night and never woke up. He has been trying to bring you home.\n\nYou lie down. You take his hand. And this time, when you wake, you both do."

## The bestiary (D4): revealed when its "seen" counter (MetaState.stats) first moves, which pays
## MetaState.BESTIARY_SHARDS. "counts" = [label, stat] lines; "hint" stands in until it is seen.
const BESTIARY: Array[Dictionary] = [
	{"id": "devil", "name": "THE DEVIL", "seen": "devil_wakes", "hint": "Something walks on the red side.",
		"rule": "Always knows where you are. Fast when far, slow when close. Slower in WAKE; stand in a safe circle and he backs off.",
		"lore": "Tall, patient, never out of breath. He doesn't chase so much as arrive. The notes call him the Landlord, the Night Doctor, Him. Nobody agrees on his face. Everybody agrees he always knows which way you went.",
		"counts": [["CAUGHT YOU", "deaths_devil"], ["YOU GOT AWAY", "devil_escapes"]]},
	{"id": "nightmare", "name": "THE NIGHTMARE", "seen": "flips", "hint": "The walls go red.",
		"rule": "The same maze, redder, and he runs faster in it. Any key can be taken in either world.",
		"lore": "The same building, one blink to the left. Red light, wet walls, his footsteps. You never step into it on purpose. It steps into you.",
		"counts": [["FLIPS", "flips"]]},
	{"id": "flipping_time", "name": "FLIPPING TIME", "seen": "forced_flips", "hint": "The blink is never yours.",
		"rule": "At random, the Nightmare takes you on its own after a short warning. Your controls invert until it lets go.",
		"lore": "It isn't you blinking anymore. Something on the other side has learned the trick, and it pulls. The notes say it gets hungrier the deeper you go.",
		"counts": [["TIMES IT LET YOU GO", "nightmares"]]},
	{"id": "cracked_floor", "name": "CRACKED FLOOR", "seen": "cracks", "hint": "Listen to the floor.",
		"rule": "A cracked tile holds once and breaks on the second step. Listen for the creak; look for the cracks.",
		"lore": "The floors down here are thin, like ice over something warm. One note claims every crack is the shape of the last person who fell through. Try not to check.",
		"counts": [["SWALLOWED YOU", "deaths_trap"], ["CRACKED AND HELD", "cracks"]]},
	{"id": "the_clock", "name": "THE CLOCK", "seen": "floors", "hint": "Morning is coming.",
		"rule": "Each floor gives you just enough time to walk its keys and its chest. Dead ends eat it.",
		"lore": "Morning is coming, and morning is not your friend. When the clock runs out you wake up in the wrong world, and nobody wakes up from that twice.",
		"counts": [["RAN OUT ON YOU", "deaths_time"], ["FLOORS BEATEN", "floors"]]},
	{"id": "phantom", "name": "THE PHANTOM", "seen": "phantom_sightings", "hint": "Your flashlight flickers when it watches.",
		"rule": "A watcher in WAKE. Don't keep it in view for more than 2 seconds: look away or switch off your light.",
		"lore": "Adaeze wrote that it used to be a nurse. Then she crossed it out and wrote: it used to be a patient.",
		"counts": []},
	{"id": "sentinel", "name": "THE SENTINEL", "seen": "sentinel_sightings", "hint": "A hum, and a light that sweeps.",
		"rule": "A guard in both worlds. Its eye closes for 2 seconds every 5: cross its corridor then.",
		"lore": "The ward kept a night watchman. The ward still does. He never sleeps, and he never forgets to tell the Devil where you are.",
		"counts": []},
	{"id": "ripper", "name": "THE VOID RIPPER", "seen": "ripper_sightings", "hint": "The lights die one by one.",
		"rule": "A rusher in NIGHTMARE. When the corridor lights die and the roar builds, step into an alcove until it passes.",
		"lore": "Nobody who saw it up close wrote another note. The last line in R.'s handwriting just says: the lights.",
		"counts": []},
]

## The Voice (plans/06 §4): a line on the death screen picked by voice(). Each pool is one reaction.
const VOICE := {
	"first": [
		"There it is. Your first night ending early. It won't be your last.",
		"Everyone falls the first time. Most of them stay down. Let's see about you.",
		"Welcome to the Flip Ward. Lights out.",
	],
	"devil": [
		"He's never in a hurry. You were.",
		"Slow when he's close. You knew that. Your legs didn't listen.",
		"He knew which way you went. He always does.",
		"You ran into the dark. He was already standing in it.",
		"Had the world turned a moment sooner, he'd still be wading through WAKE.",
		"He doesn't hate you. That's what makes it worse.",
		"He hummed the whole way. Did you hear it?",
		"A blue circle was right there. He knew you'd miss it.",
		"You waited for WAKE. He didn't wait for you.",
		"He's patient. Patience wins down here.",
		"Far away, he's fast. You gave him far away.",
		"His hand was cold. Yours will warm up by tomorrow night.",
		"You heard your heart. You should have listened.",
		"He let you get close to the chest. He likes that part.",
		"Dead end. He knows every one of them by name.",
		"Run, and he runs. Walk, and he walks. You ran.",
		"He says goodnight. He means it kindly.",
		"Corners are where he waits. Corners are everywhere.",
		"He caught you. He'll let go when you wake up.",
		"He missed you, you know. In both senses.",
	],
	"trap": [
		"The floor creaked. You took that as a suggestion.",
		"Cracked tiles hold once. You asked twice.",
		"The cracks were glowing. They don't glow for decoration.",
		"Down you go. The floor below is softer. Barely.",
		"You sprinted over thin ice. The ice noticed.",
		"Everyone who fell is holding the maze up. Your shift starts now.",
		"One step to the left, and you'd still be walking.",
		"The floor was patient too.",
		"Listen to the floor. It talks before it breaks.",
		"That tile was cracked when you got here. Now it's gone.",
		"You trusted the floor. The floor had other plans.",
		"Gravity is the only thing down here that never lies.",
	],
	"time": [
		"The clock ran out. Morning came, in the wrong world.",
		"Dead ends ate your time. They're always hungry.",
		"Keys on the way, not one at a time. Next time.",
		"You took the scenic route. The scenery won.",
		"Time doesn't hunt you. It just doesn't wait.",
		"Out of time, but not out of nights.",
		"The chest was right there. The clock didn't care.",
		"Every second you stood still, the morning walked closer.",
		"Morning isn't your friend here.",
		"A faster route existed. Your feet will find it tomorrow.",
		"The building lets you stay forever. Just not awake.",
		"You were careful. Careful takes time.",
	],
	"close": [
		"Inches away. Lock in.",
		"You could see the chest. Next time, touch it.",
		"So close he almost felt sorry for you.",
		"One more corridor. Just one.",
		"You were nearly out. Nearly is his favourite word.",
		"The exit saw you coming. It'll be waiting.",
		"That was the closest anyone's been tonight.",
		"Strong run. Try again.",
	],
	"gate": [
		"The Gate always takes its toll. Pay it with skill next time.",
		"Floor ten. The door was right there.",
		"The Gate knows what scares you. Now so do you.",
		"Nine floors behind you. Remember how you got here.",
		"The Gate holds. For now.",
		"Gates are built to stop people. Be the exception.",
	],
	"start": [
		"First floor. Shake it off.",
		"Not even warmed up yet. Again.",
		"A slow start is still a start.",
		"The first floor is a promise. Keep it next time.",
		"That one didn't count. Except it did.",
	],
	"any": [
		"Momentum is building.",
		"Again. You're learning his habits faster than he's learning yours.",
		"The notes said this would happen. They also said to get up.",
		"Every night you get a little further. He's noticed.",
		"You're not the first. You could be the last.",
		"Lights out. Lights on. Again.",
		"The building remembers you. It kept your room.",
		"Get up. The keys moved, but they didn't go far.",
		"Fear is a teacher. Expensive tuition.",
		"He'll be there tomorrow night. So will you.",
		"That's not failure. That's a map.",
		"Somewhere, a note gets one line longer.",
		"Breathe in. Hold it. Breathe out.",
		"Nobody escapes on their first try. Or their tenth.",
		"You blinked. The building didn't.",
		"Sleep is just practice for this.",
		"One more run. There's always one more run.",
		"The dark is big. You're getting bigger.",
		"He's counting your deaths. You should count your floors.",
		"Wake up. Try again.",
	],
}
## Said once, on the death that reaches it (MetaState.stat("deaths")).
const VOICE_MILESTONES := {
	10: "Ten nights. You're a regular now. The ward put your name on a door.",
	25: "Twenty-five times. He's started saying hello.",
	50: "Fifty. Most dreamers stop writing notes around here. Don't.",
	100: "A hundred nights. He's run out of new ways to catch you. Have you run out of new ways to run?",
	250: "Two hundred and fifty. The tally marks on the gate are mostly yours now.",
	500: "Five hundred. At this point he's family.",
	1000: "A thousand. Even nightmares get tired. He hasn't. Neither have you.",
}
## Dying this far along the floor (0..1, the share of spawn -> exit covered) counts as "close".
const CLOSE_PROGRESS := 0.9


## The Voice's line for a death: a milestone, else the first death, else how close you were, the Gate, an act's
## first floor, else what killed you (or anything). Same death, same line.
static func voice(cause: String, deaths: int, progress: float, floor_in_act: int) -> String:
	if VOICE_MILESTONES.has(deaths):
		return VOICE_MILESTONES[deaths]
	var pool: Array
	if deaths <= 1:
		pool = VOICE["first"]
	elif progress >= CLOSE_PROGRESS:
		pool = VOICE["close"]
	elif floor_in_act == StageRule.GATE_FLOOR:
		pool = VOICE["gate"]
	elif floor_in_act == 1:
		pool = VOICE["start"]
	else:
		pool = VOICE.get(cause, []) + VOICE["any"]
	return pool[posmod(hash([deaths, cause]), pool.size())]

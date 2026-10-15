# FearFlip 3D: Fair Twists and a Premium Worth Buying

Research from 15 Oct 2026. You asked two questions:
1. How do we add more twists and turns without making the game annoying or unfair?
2. What paid model (you asked for a subscription) would people buy without hesitation because it's clearly worth it?

This builds on the master plan (§3 research, §6 threats, §13 money), plans/06, plans/08 (maze events, skins, Labyrinth
Pass) and plans/09 (playtest). It only adds layers: the Devil, the flip, NIGHTMARE and the keys all stay. The research
leans on maze and horror games first (Pac-Man, DOORS, The Exit 8, Lethal Company, Labyrinthine, Dark Deception, Granny)
and uses general data only where no maze game has the answer.

Effort: S = 1 day or less · M = 2–4 days · L = 1–2 weeks. Impact runs from ● (small) to ●●● (big).
Sources: [R#] for twists, [M#] for money, listed at the end.

## 0. The answer on one page

**Twists.** FearFlip already has many twists: the flip, Flipping Time, thin walls, the wake, key boxes, traps, cards,
omens, curses and Gate twists. More are planned: Phantom, Sentinel, Ripper and the plans/08 events. Whether a twist
feels exciting or unfair doesn't depend on how many there are. It depends on how each one is introduced and warned.
Every source says the same thing: **teach it safely, warn before it hurts, give a counter, and name it when it kills you.**
- Hold every twist, old and new, to the **Twist Charter** (§1).
- Give each act **one** headline idea, taught the Nintendo way: meet it safely, it gets dangerous, it combines with an
  old rule, then the Gate (§2).
- Build the new maze twists in §3. The strongest is **The Devil Learns**, Alien: Isolation's trick: lean on one escape
  too often and the Devil learns it, and tells you so.
- Fix the two spots where FearFlip already feels unfair (§4): flips snatch the map, and dying on F9 sends you back to F1.

**Money.** The research doesn't support a subscription that locks the game. Most players, Indian players most of all,
prefer small one-time buys, and people resent renting single-player content. What sells without hesitation is cheap,
shows its value in numbers, carries no risk and never sells power. So the recommendation is a two-part premium, working
name **LUCID** (in a game of WAKE and NIGHTMARE, the paying player is the one who knows they're dreaming). Details in §6:
- **Free stays whole**: all acts, the Daily and the Abyss. Ads only at breaks, plus opt-in rewarded ads (as planned).
- **LUCID Forever**: one payment (₹149 / $4.99). No ads, and every rewarded perk without the ad. This is the GEMINI rule
  "premium = no ads + free revive", sold once.
- **LUCID Pass**: the subscription. ₹49 a month, ₹399 a year, or ₹59 for 30 days that doesn't auto-renew; $1.99 / $14.99
  abroad. It adds each season's Labyrinth Pass premium track, a monthly cosmetic you **keep forever**, the Seed Maker for
  friend challenges, and new threats a week early. It never sells shards or power.
- **Make yes easy**: 7 days of LUCID free for every new player (no card), a once-only ₹19 / $0.99 "First Night" starter,
  UPI Autopay, cancel in two taps, and offers only after a good run or at the revive prompt.
- **Order**: rewarded ads + LUCID Forever at the Android launch. Add LUCID Pass only once you can ship a pass season and a
  new cosmetic every month. A subscription is a promise of something new each month; one with nothing new gets cancelled
  and reviewed badly.

One code note: `RunState.mod()` folds your worn torch (`MetaState.gear()`) into the Daily ranked try (mercy is kept out,
gear isn't). That's fair while shards can only be earned. If anything paid ever touches shards or torches, make ranked
runs gear-free first.

## 1. The Twist Charter

What the research says makes a surprise fair. The last column checks FearFlip today.

| # | Rule | Why | FearFlip today |
|---|---|---|---|
| 1 | **Teach before you test.** A twist's first appearance can't kill | Nintendo's 3D Mario levels introduce a mechanic safely, develop it, twist it, then wrap up, often in about five minutes (kishōtenketsu) [R1]. Testing a mechanic before teaching it is the classic level-design mistake (gamedev level-design skill) | New threats need a harmless first floor (§2) |
| 2 | **The deadlier, the louder.** A lethal twist warns at least 2 s ahead, in sound and light | A death from an unseen threat feels like a bug, not a lost challenge, and the more lethal a system is, the clearer its tell must be [R9]. DOORS: Rush flickers the lights and screams louder as it comes; A-90 flashes a stop sign [R6] | Thin wall pounds through the 3 s warning ✔ |
| 3 | **Show intent.** The best tell says what happens next | Slay the Spire shows each enemy's next move as an icon; it's called the series' key idea, and new players see what's coming and why [R3] | Devil Corner (live cam + metres) ✔ |
| 4 | **One new thing at a time** | One mechanic per level [R1]. Lethal Company gives each monster one rule and gets difficulty from combining them later [R10] | Never debut two twists on one floor |
| 5 | **Random before you choose, not after** | Randomness known before a decision (a generated map) feels fair; randomness after it (a dice roll) feels cheap [R13] | Cards and doors shown before the floor ✔. Mid-floor events need a warning window |
| 6 | **Every twist has a counter you already own** | DOORS: each entity has one counter: hide, stop, run to the next door [R6]. Lethal Company: look at it, or don't [R10] | Look away, stand still, walk, flip, safe circle |
| 7 | **Name it on the tombstone** | A fair death is one the player can explain and learn from [R9]. Lethal Company keeps an in-game bestiary [R10] | Death screen teaches the rule ✔. Every new twist needs a line there + a bestiary entry |
| 8 | **Anchors never move** | The Exit 8 walks the same salaryman past you each loop, a fixed reference that makes changes stand out [R5] | Landmarks, safe circles and the exit stay put, even when walls shift (§3 T3) |
| 9 | **Opt-in pays more, and says how much** | Hades shows Heat on the HUD and pays more for more of it [R7]. DOORS modifiers: Lights Out +25% knobs, Chaos +50% [R17] | Curses and Ranks: show the shard % on the card |
| 10 | **Different must feel different** | "10,000 bowls of oatmeal": a million unique outputs are worthless if players can't tell them apart; variety has to change play [R8] | A twist must change your route, timing or where you look, not just a number |
| 11 | **Rare stays rare** | Dark Souls 3 players complained mimics felt overused [R12]. Some Exit 8 anomalies were so subtle players reported them as bugs, and Platform 8 cut its hardest ones [R5] | Mimics and anomalies: at most 1 a floor. Tune with the death log |
| 12 | **Cheap deaths, short replays** | Where you respawn changes how a death feels (72-player study); mini-checkpoints made Prince of Persia's deaths a misstep, not a punishment [R9] | Restart from the Sanctuary (§4) |

## 2. Twist cadence: one act, one idea

Nintendo's four beats fit the 10-floor act:

| Floors | Beat | What happens |
|---|---|---|
| F1–F2 | Introduce | The act's new idea appears in a form that can't kill (a scare, a noise, lost time). The Voice names it and its bestiary page opens |
| F3–F4 | Develop | It becomes dangerous, alone |
| F5 | Rest | The Sanctuary |
| F6–F9 | Twist | It combines with an older rule (Phantom during Flipping Time, Sentinel near a thin wall) |
| F10 | Conclude | The Gate: everything the act taught, at a fair pace |

Suggested headline per act: **Act 1** the base (Devil, flip, boxes, traps) · **Act 2** Phantom + mimic boxes ·
**Act 3** Sentinel + The Devil Learns · **Act 4** Void Ripper + The Maze Breathes · **Act 5** everything + Déjà Vu floors.
The Daily and the Abyss draw only from twists you've met. This puts the master plan §5 "threat by depth" table on an
act footing so each act has one headline.

## 3. New maze twists

| # | Twist | How it plays | Reuses | Fair because | Effort | Impact |
|---|---|---|---|---|---|---|
| T1 | **The Devil Learns** | Within an act, use one escape 3 times and the Devil learns a counter for the rest of the act. Circles: it waits closer, longer. Map: it hears the paper (map open = noise). Sprint: it hears your feet from farther. Boxes: it hears the lid from farther. The Voice says so ("It has learned the circles") and the bestiary marks it. Resets each act | `DevilBrain` senses and pace, `_noise`/`_hears`, `Director`, the Voice | Alien: Isolation does exactly this: locked behaviours open once you rely on a trick, so the alien seems to learn [R4]. You cause it, you're told, and you can switch tactics. The Devil still always comes straight for you (9 Oct rule), and `CLOSE_CAP` still keeps it slower than your walk up close | M | ●●● |
| T2 | **Mimic Boxes** | From Act 2, one of the floor's empty boxes may be a mimic. Tells before you commit: the lid breathes, its strap is undone, it flinches from your light. Open it and it shrieks (a big noise) and scuttles off. No damage, never a key's box | `KeyBox`, `_open_box`, `_noise`, `StageRule.box_empties` (replaces an empty, so it needs no extra dead end) | Dark Souls mimics are fair because the tells (chain, breathing) show before you open [R12]. Harmless and capped (rule 11) | S–M | ●● |
| T3 | **The Maze Breathes** | At a flip, 3–6 walls away from you move. Through the 3 s warning: a stone groan and dust from those walls, and the paper map smudges those cells. The exit always stays reachable; landmarks, circles and boxes never move. Variant: NIGHTMARE keeps its own walls while it lasts, which finally gives Ghost Sight (plans/09 #5) a job | `FloorLayout.open_cell`/`validate()`, `_break_wall`, maze shift (master plan Phase 6; Flutter `maze_shift_manager`) | Shifting horror mazes exist (I Am Not A Minotaur moves walls every 10 s; Lights Out rearranges when the lights die) [R16]. Ours only shifts inside a flip you were already warned about, and keeps the anchors (rule 8) so memory still pays | M–L | ●●● |
| T4 | **Déjà Vu** (extends plans/08 M8) | Late in a run, a floor replays one you cleared, same seed, with 1–3 anomalies: a moved wall, a wrong lamp colour, a mirrored glyph. Stand at an anomaly to bank shards. Missing one costs nothing | `FloorLayout` seed, `Landmarks` | The Exit 8: a repeated space makes changes visible, the input is one choice, and nobody dies [R5]. It rewards FearFlip's core skill: memory | S–M | ●●● |
| T5 | **Threats by act** | Phantom, Sentinel and Ripper (master plan §6), each taught per §2 | as planned | One-rule monsters with a warning and a counter (DOORS [R6], Lethal Company [R10]). Dark Deception adds a new obstacle and power chapter by chapter [R11]. Pac-Man shows tiny targeting rules give each ghost a personality (one chases you, one aims 4 tiles ahead, one keeps its distance) [R14]: use that for these threats, not for the Devil | L | ●●● |
| T6 | **Rare floors** | About 1 floor in 25: **Blood Moon** (offered at a door: ×2 shards, Devil faster), **Silent Floor** (no music, every sound matters), **Golden Wisp** (plans/08 M2, worth more). Stories people share | `Cards` floor cards, `Director` | Isaac's hidden secrets were found and shared within weeks [R15]. Rare stays rare (rule 11), and a floor never gets harder without your choice | S each | ●● |

## 4. Fix first: where FearFlip already feels unfair (plans/09)

| Problem | Evidence | Charter rule | Fix (your call) |
|---|---|---|---|
| Flips snatch the map | 20 of 52 map closes were forced by a flip; 7 of those maps were reopened within 3 s | 2, 12: control taken at the worst moment | **Done 15 Oct 2026.** Every flip closed the map as it landed, both into NIGHTMARE and back. Now a flip leaves it in your hands; only the Devil close snaps it |
| Long acts | 10 floors of ~4–5 min; dying on F9 restarts at F1 | 12 | **Done 15 Oct 2026.** Once the run has reached the Sanctuary, TRY AGAIN restarts there on a new maze, with the cards, revives and star record it had on arrival. R R mid-floor still restarts the act |

## 5. Money: what the research says

### 5.1 How maze and horror games earn

| Game | Model | Lesson for FearFlip |
|---|---|---|
| **Pac-Man 256** | Free. Credits refill on a 10-min timer, or one $7.99 "unlimited credits" buy. Coins only earned or from an ad. A free mode without power-ups always works | Reviewers called the one-time unlock a fair deal. One clear purchase that removes the friction beats many small nags [M5] |
| **Pac-Man 99** | Free inside a platform subscription (Nintendo Switch Online). Paid modes $14.99, themes $1.99 each | A maze game can live inside a subscription. But it went offline in Oct 2023 and buyers kept only the offline modes: never sell something that dies with a server [M6] |
| **DOORS** (Roblox) | Free. Revives and 5× knob boosts sold for Robux (a boost is 99); codes hand out free revives; harder modifiers pay more knobs | The moment players most want to pay is right after they die. Sell the revive cheap and keep a free route [M11][R17] |
| **Granny** | Free on mobile with ads; $4.99 on Steam, once, no ads | Same game, two models: ads where people won't pay, a cheap premium where they will [M10] |
| **Poppy Playtime** | Chapter 1 free on PC; later chapters $9.99–$20. Estimated $100M+ | A free first chapter is the hook [M7] |
| **Labyrinthine** | Premium, plus a $4.99 Supporter Pack: glowstick colours other players see, a visor, a lobby nameplate. Most cosmetics are earned in the maze | Cosmetics other people see are worth paying for [M8] |
| **Spooky's Jump Scare Mansion** | Free original + $1.99 and $3.99 DLC; the $9.99 HD version includes them | A free base + small content DLC works for horror mazes [M27] |
| **Vampire Survivors** (mobile) | Free, no microtransactions, optional ads after runs for revives and gold, no pop-ups | "Free for real" hit a million downloads in its first week, organically [M9] |
| **Lethal Company** | $9.99, no microtransactions, and the developer said the price won't rise | Cheap and honest builds the word of mouth that sells it [M26] |

### 5.2 What the numbers say about subscriptions

- **Small but growing.** Subscriptions are about 7–12% of mobile game revenue depending on the source. In apps that run
  ads, purchases and subscriptions, subscriptions went from 4% to about 7% of revenue between Jan 2025 and early 2026.
  One analyst sees subscriptions and passes growing ~18% a year as players tire of unpredictable spending [M1].
- **Passes convert better than shop items.** 8–20% of active players buy a pass, against 1–5% for normal purchases
  (aggregator figures). Google found passes drove 1–40% of revenue in top games (2020 data) [M2].
- **The best-loved subscription in free games is the monthly card.** Genshin's $4.99 Welkin Moon pays a little every
  day for 30 days, and guides call it the best value in the game. It only pays out if you log in each day [M3].
- **Trials.** In RevenueCat's app data (not games), trials of 17–32 days converted best, about 43–46% trial-to-paid,
  and trials of 4 days or less worst, about 26% [M17]. A "reverse trial" (premium free at the start, then back to free)
  beats a plain free tier when people actually use the premium perks during the trial [M24].
- **The first purchase is the big one.** 77% of payers make their first purchase within two weeks of starting. Churn
  drops after the first purchase, whatever it cost. Starter packs work at $0.99–$2.99 with 5–10× normal value [M19].
- **Most players will never pay, and that's fine.** In ad-network surveys most players prefer opt-in rewarded ads to any
  other ad (Unity: 46%, against 5% for forced video), and 54% would rather watch a rewarded ad than pay for a premium
  game (Facebook, 2018). These are vendor surveys, so they lean pro-ads [M18].

### 5.3 India

- **Many pay, little each.** 25% of Indian gamers pay, but a casual payer spends about $3 a year (mid-core about $15).
  The market (real-money games excluded) was $1.5B in 2025, up 17% [M12].
- **Small tickets beat subscriptions for most.** 62% preferred small purchases to a subscription (2019 survey); 47%
  prefer microtransactions to subscriptions (Lumikai, 2024) [M12]. But among payers, passes and subscriptions are now
  the top spending category (40%, Lightbox 2025) [M12], and Indian gamers are about twice as likely as US gamers to hold
  some game subscription (Simon-Kucher) [M4].
- **Paying is easy.** Google Play takes UPI Autopay for subscriptions (since Nov 2022: approve the first payment, the
  rest go through on their own) and offers prepaid plans that don't auto-renew [M13]. Prices can go as low as ₹10
  (2015 rule) [M14]. Google's own Play Pass launched in India at ₹99 a month (its status today is unclear) [M15], a
  useful anchor for what a game subscription costs here.

### 5.4 What each platform allows

| Platform | Subscriptions? | Plan |
|---|---|---|
| CrazyGames (web) | No. In-game purchases are by invitation only, through Xsolla [M20] | Ads at breaks + rewarded (master plan §13). If invited: LUCID Forever as a one-time purchase |
| Google Play (Android) | Yes: UPI Autopay, prepaid plans, intro prices [M13] | Rewarded ads + LUCID Forever + LUCID Pass. Needs the Google Play Billing plugin (asks for your OK: it's an addon) |
| Steam | Paid game | One price ($6.99–9.99, master plan §13) that includes everything LUCID Forever gives. Cosmetics as small DLC, like Labyrinthine's supporter pack [M8] |

## 6. Recommendation: LUCID

### 6.1 The tiers

| | Free | LUCID Forever (one-time) | LUCID Pass (subscription) |
|---|---|---|---|
| Price, India | ₹0 | ₹149 | ₹49 a month · ₹399 a year · ₹59 for 30 days, no auto-renew |
| Price, abroad | $0 | $4.99 | $1.99 a month · $14.99 a year |
| All 5 acts, the Daily, the Abyss | ✔ | ✔ | ✔ |
| Ads | Only at breaks, plus opt-in rewarded | None | None |
| Revive (up to 3 per act), double shards at the bank, 1 omen reroll a run (plans/06) | Watch an ad | A free tap, same limits | A free tap, same limits |
| Founder light (cosmetic) | – | ✔ | ✔ |
| Labyrinth Pass premium track (plans/08 P1), this season and past ones | Free track | – | ✔ (claimed items are yours forever) |
| Monthly cosmetic drop: a light set, map, hands or Devil skin (plans/08 §4) | – | – | ✔ (yours forever) |
| **Seed Maker**: build a maze (seed + rule cards), send friends a code, compare times on the share line | Play shared seeds | Play | Create |
| Devil Cam share card | With the game's link and a watermark (free marketing) | Same | Clean, with your Light Set frame |
| New threats and events 7 days early | – | – | ✔ |

Prices are starting points. Test them (§6.4).

### 6.2 Why this sells without hesitation

1. **A tiny first step.** "First Night": ₹19 / $0.99 once, after your first escape. It gives 7 days of the Pass and a
   light set to keep [M19].
2. **Value in numbers.** The store card shows what's inside at its shard and item value. The Pass starts with 2 tiers
   already filled: in the car-wash study, 34% finished a loyalty card that came with 2 free stamps, against 19% with a
   blank one [M22].
3. **No risk.** Every new player gets 7 days of LUCID free, with no card. You keep everything you claimed. Cancel in two
   taps (Google requires a clear, easy cancel anyway [M25]). A reminder comes 2 days before any renewal.
4. **Never power.** LUCID never gives anything a free player can't get by playing or watching an ad, except looks. That
   keeps every leaderboard fair and the reviews kind (Vampire Survivors' "free for real" [M9]).
5. **Seen by others.** Lights, flip flashes and Devil skins show up in Devil Cam share cards and on the leaderboard
   (Labyrinthine sells glowstick colours other players see) [M8].
6. **The right moment.** Offer it after a good bank or at the revive prompt. Never mid-floor, never at launch, never with
   a fake countdown (master plan §13).
7. **Easy to pay.** UPI Autopay, plus the prepaid 30 days for people who don't trust auto-debit [M13].
8. **A way in for subscription-haters.** About half of Indian players prefer one-time buys [M12]. LUCID Forever is their
   no-brainer.

### 6.3 Hard nos (the master plan's, plus these)

- No paid randomness: chests stay earn-only (Belgium treats paid loot boxes as gambling; CrazyGames is Belgian).
- No shard sales and no daily shard drip while the worn torch counts in the Daily ranked try (`RunState.mod`). A
  Welkin-style drip needs gear-free ranked runs first (everyone equal, like Spelunky's daily).
- Ending a subscription never takes away an act, an item or a save.
- Nothing you buy may need a server to keep working (Pac-Man 99 [M6]).
- No subscription before there's new content every month.

### 6.4 Launch order

1. **Android launch**: rewarded ads + LUCID Forever + the 7-day free start. The cheapest to build, and it measures
   willingness to pay.
2. **After 1–2 months of data**: add First Night. Test ₹99 / ₹149 / ₹199 for Forever (price tests beat guesses [M19]).
3. **When the Labyrinth Pass (plans/08 P1) and three months of cosmetics are ready**: LUCID Pass.
4. **Steam**: paid game with co-op (master plan §13).

### 6.5 What to log (P0 event log, `RunState.log_event`)

`offer_seen` / `offer_bought` by moment (revive, bank, escape), `trial_start` / `trial_end` / `trial_paid`,
`sub_renew` / `sub_cancel`. Compare D7 and D30 retention with and without the free start. Red flags: the store rating
drops after an offer change, players quit at the revive prompt more after offers appear, or most First Night buyers
never buy again.

## Sources

**Twists**
- [R1] Kishōtenketsu in 3D Mario (Game Maker's Toolkit, via MCV): https://www.mcvuk.com/development/video-nintendos-level-design-secrets-in-four-steps · https://www.tvtropes.org/pmwiki/pmwiki.php/Main/Kishotenketsu
- [R3] Slay the Spire intents: https://sts2.untapped.gg/guides/how-to-read-enemy-intent · https://www.lesswrong.com/posts/MEimkSwwuRgiPaZaY/review-slay-the-spire
- [R4] Alien: Isolation's AI: https://www.gamedeveloper.com/design/the-perfect-organism-the-ai-of-alien-isolation · https://www.gamedeveloper.com/design/revisiting-the-ai-of-alien-isolation
- [R5] The Exit 8: https://automaton-media.com/en/news/20240214-27192/ · https://automaton-media.com/en/interviews/interview-the-exit-8-developer-kotake-create-on-the-perks-of-being-a-solo-dev-and-how-platform-8-came-to-be/ · https://automaton-media.com/en/news/20231208-23845/
- [R6] DOORS entities: https://www.destructoid.com/all-doors-entities-guide-how-to-survive/ · https://www.ginx.tv/en/doors-a90
- [R7] Hades Pact of Punishment: https://rpgsite.net/feature/10287-hades-pact-of-punishment-heat-modifiers-and-how-to-maximize-your-rewards · https://kotaku.com/everything-you-need-to-know-about-hades-endgame-1845239105
- [R8] Procedural oatmeal: https://emshort.blog/2016/09/21/bowls-of-oatmeal-and-text-generation/ · https://www.boristhebrave.com/2026/07/05/oatmeal-spice/
- [R9] Fair deaths: https://automaton-media.com/en/interviews/ninja-gaiden-4-creators-say-fairness-in-dying-is-what-sets-apart-a-challenging-action-game-from-an-unreasonable-one/ · respawn study: https://www.researchgate.net/profile/Edward-Melcer/publication/354020467_Die-r_Consequences_Player_Experience_and_the_Design_of_Failure_through_Respawning_Mechanics/links/611f0b55169a1a01031232a3/Die-r-Consequences-Player-Experience-and-the-Design-of-Failure-through-Respawning-Mechanics.pdf · https://gamedev.net/tutorials/game-design/game-design-and-theory/game-design-round-table-1-r2639
- [R10] Lethal Company monsters: https://www.ggrecon.com/guides/all-lethal-company-monsters-and-how-to-avoid/ · https://dungeonpath.com/posts/lethal-company/monster-bestiary/
- [R11] Dark Deception chapters: https://dark-deception-game.fandom.com/wiki/Chapter_2:_Into_Madness
- [R12] Dark Souls mimics: https://kotaku.com/i-love-how-mimics-work-in-the-dark-souls-series-1825072124 · https://darksouls.fandom.com/wiki/Mimic_(Dark_Souls_III)
- [R13] Input vs output randomness: https://keithburgun.net/three-types-of-bad-randomness-and-one-good-one/ · https://www.gamedeveloper.com/game-platforms/the-2-types-of-randomness-and-how-to-apply-them-to-your-board-game · https://arxiv.org/pdf/2107.08437
- [R14] The Pac-Man Dossier: https://www.gamedeveloper.com/pc/feature-the-i-pac-man-i-dossier
- [R15] The Binding of Isaac postmortem: https://www.killscreen.com/binding-issac-postmortem/
- [R16] Shifting-maze horror: https://luke-cunningham.itch.io/i-am-not-a-minotaur · https://nexusgamesstudios.itch.io/lights-out
- [R17] DOORS modifiers and knobs: https://www.ginx.tv/en/doors-modifiers-list · https://doors-game.fandom.com/wiki/Knobs

**Money**
- [M1] Subscription share: https://www.mordorintelligence.com/industry-reports/mobile-games-market · https://ataygames.com/mobile-gaming-statistics-2026 · https://www.pocketgamer.biz/mobile-accounts-for-55-of-total-games-revenue-in-2025-as-studios-shift-towards-retention/
- [M2] Pass conversion: https://mwm.ai/glossary/battle-pass · https://goo.gle/3htI67y
- [M3] Welkin Moon: https://www.pocketgamer.com/articles/084391/which-microtransactions-should-you-buy-in-genshin-impact-if-any/ · https://progameguides.com/genshin-impact/is-the-blessing-of-the-welkin-moon-worth-buying-in-genshin-impact
- [M4] Subscription attitudes: https://msn.gamereactor.eu/survey-shows-35-of-gamers-have-an-ongoing-game-subscription/ · https://tolunacorporate.com/the-drive-to-subscribe-in-video-gaming/
- [M5] Pac-Man 256: https://www.pocketgamer.com/pac-man-256/how-free-to-play-works-in-crossy-road-spin-off-pac-man-256/ · https://www.siliconera.com/pac-man-256-is-free-unlimited-credits-are-799/ · https://www.macworld.com/article/226386/freemium-field-test-just-pay-for-pac-man-256s-unlimited-credits-and-get-it-over-with.html
- [M6] Pac-Man 99: https://en.wikipedia.org/wiki/Pac-Man_99 · https://nintendowire.com/news/2021/04/08/pac-man-99-trailer-goes-over-all-its-paid-dlc/ · https://videogameschronicle.com/news/nintendo-is-shutting-down-and-delisting-pac-man-99
- [M7] Poppy Playtime: https://fungies.io/poppy-playtime/ · https://raijin.gg/app/1721470/Poppy_Playtime
- [M8] Labyrinthine Supporter Pack: https://platprices.com/game/162567-labyrinthine-supporter-pack · https://psprices.com/region-us/game/9069728/labyrinthine-supporter-edition
- [M9] Vampire Survivors mobile: https://www.pocketgamer.biz/vampire-survivors-developer-takes-new-approach-to-monetisation · https://www.pocketgamer.biz/vampire-survivors-surprise-launches-to-mobile/
- [M10] Granny: https://kotaku.com/games/granny · https://granny.fandom.com/wiki/Granny_(game)
- [M11] DOORS shop: https://doors-game.fandom.com/wiki/Knobs · https://www.dexerto.com/roblox/roblox-doors-codes-free-revives-knobs-and-more-2110561
- [M12] India: https://respawn.outlookindia.com/gaming/gaming-news/lumikai-india-gaming-market-1-5-billion-rmg-ban-2025 · https://investgame.net/wp-content/uploads/2024/11/Lumikai-Interactive-Media-and-Gaming-Report-2024-Executive-Summary.pdf · https://respawn.outlookindia.com/gaming/gaming-guides/more-than-a-game-how-in-app-purchases-reflect-new-indian-economy · https://digitalterminal.in/amp/story/enterprise/how-is-microtransaction-becoming-the-favourite-revenue-model-for-gamers-and-developers · https://www.storyboard18.com/amp/gaming-news/75-of-indian-gamers-spend-on-in-app-purchases-reveals-lightbox-report-81507.htm
- [M13] Google Play UPI Autopay and prepaid plans: https://www.androidcentral.com/apps-software/google-play-upi-autopay-india · https://inc42.com/?p=289544
- [M14] ₹10 minimum price: https://india.googleblog.com/2015/07/minimum-purchase-price-for-apps-on.html
- [M15] Play Pass India: https://www.xda-developers.com/google-play-pass-india-launch-pricing/
- [M17] RevenueCat trials: https://subscriptioninsider.com/article-type/news/revenuecats-state-of-subscription-apps-2025-report-ais-dominance-retention-challenges-and-the-shift-away-from-pure-subscriptions · https://www.saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps/
- [M18] Rewarded ads: https://gamesbeat.com/unity-the-majority-of-mobile-gamers-are-open-to-engaging-with-incentivized-video-ads/ · https://www.pocketgamer.biz/tapjoy-modern-mobile-gamer-report/ · https://www.pocketgamer.biz/facebook-mobile-gaming-ad-survey-2018/
- [M19] First purchase and starter packs: https://unity.com/resources/in-app-purchases-guide · https://android-developers.googleblog.com/2016/08/5-tips-to-help-you-improve-game-as-a-service-monetization.html · https://pocketgamer.biz/comment-and-opinion/64530/best-practices-starter-bundles/
- [M20] CrazyGames purchases: https://docs.crazygames.com/sdk/in-game-purchases/ · https://app.cinevva.com/guides/publish-game-crazygames
- [M22] Endowed progress (car wash): https://en.wikipedia.org/wiki/Goal_pursuit · https://www.coglode.com/nuggets/endowed-progress-effect
- [M24] Reverse trials: https://www.elenaverna.com/p/10-pricing-and-packaging-optimizations · https://www.withorb.com/blog/reverse-trial-saas
- [M25] Google Play subscription policy: https://support.google.com/googleplay/android-developer/answer/9900533
- [M26] Lethal Company: https://upcomer.com/does-lethal-company-cost-money · https://www.dexerto.com/gaming/is-lethal-company-free-to-play-2402738/
- [M27] Spooky's Jump Scare Mansion: https://www.dekudeals.com/items/spookys-jump-scare-mansion-the-doll-house · https://spookys-jump-scare-mansion.fandom.com/wiki/Karamari_Hospital
- Also read: Steam horror pricing (median list price $4.99 for 2024–25 horror releases): https://www.steampageanalyzer.com/niches/psychological-horror · hybrid monetization: https://investgame.net/wp-content/uploads/2025/11/sensor_tower__state_of_mobile_gaming_2025__en.pdf

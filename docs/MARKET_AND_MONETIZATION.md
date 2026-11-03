# Market research and monetisation

**Confidence warning.** Everything here came from web-search snippets during a chat session,
not from firsthand use of the apps or from store analytics. Figures marked ⚠ came from a single
source. Treat this as a starting hypothesis to verify, not as fact. Two earlier recommendations
in the conversation (Hokm/Shelem card hub; "match-3") were withdrawn after the owner pointed out
they are saturated — the assistant had asserted "underserved" without checking competitors.

## Distribution

- **Cafe Bazaar** is the dominant Iranian Android store (⚠ one source said ~97 % share and 35 M+ users). **Myket** is the clear second. Google Play allows free downloads in Iran but Iranians generally cannot pay there (no international payment rails), so Play Billing is not a real revenue path.
- Revenue therefore runs through **Cafe Bazaar's own billing** (Poolakey) and **Myket's** equivalent, tied to local bank cards / carrier billing.
- Content review is shaped by the Ministry of Culture and Islamic Guidance: no gambling, alcohol, sexual or politically/religiously sensitive content. Apps can be pulled *after* launch, which is why voice moderation matters.

## Audience (⚠ single source)

~95 % of Iranian gamers on Android; average gamer age ~18; ~67 % under 19. Mobile-first, data-price-sensitive → small APK matters (use `--split-per-abi`, ~8 MB each).

## What sells

⚠ About 30 % of Cafe Bazaar users have made at least one in-app purchase. Reported top *revenue* genres: strategy, arcade, RPG; top *download* genres: casual, puzzle, action. Top grossing titles in Iran are mostly global (Whiteout Survival, Gossip Harbor, Genshin Impact; historically Clash of Clans/Royale). Local hits succeed by cultural nativeness: Amirza (Farsi word-connect), Los Angeles Crimes (GTA-style sandbox with creation tools), Quiz of Kings (trivia), Golmorad (romance match-3), Football 360 (fantasy football, backed by a TV programme).

## Where this game sits

- Drawing/guessing demand is real: Iranians play Farsi rooms on **Gartic.io** (a foreign browser game) — awkward on phones, no native IAP path.
- **Hokm/Shelem/card games: saturated** (Hokm Plus, Dream Land, etc.). Ruled out.
- **Match-3: crowded.** Ruled out as a standalone idea.
- **Direct competitor: تخته گچی** — see `HANDOFF.md` competitor note. Not verified by use.
- Also noted as crowded: racing/police-chase, battle-royale shooters, fantasy football.

## Monetisation plan

1. **Rewarded video** (Tapsell or Adivery — local networks; AdMob is unreliable for Iranian users) for an extra hint, a colour unlock, or a skip. Rewarded, not forced.
2. **One interstitial** at most every ~3 rounds, never mid-turn.
3. **IAP** via Bazaar/Myket: avatar sets, brush and colour packs, premium word packs, **ad-free pass**.
4. **No loot boxes.**
5. **Growth loop:** save/share a drawing as an image → Telegram/WhatsApp, watermarked with the game name. Private-room invite codes are the other viral surface.
6. Ad eCPM / CPI numbers for Tapsell/Adivery were **not** found; model budgets only after getting real figures.

## Why free-for-all + teams + voice

Free-for-all is the baseline loop. Teams digitise how Iranians already play pantomime/Pictionary at gatherings and keep weaker guessers engaged. Voice in private rooms is the differentiator (none of the competitors surveyed appeared to offer it — unverified) but is the main moderation liability with a young audience, hence the private-only rule.

## Ideas considered and parked

Persian-mythology (Shahnameh) match-3/RPG; Farsi word-connect with a poetry theme; Iranian-food tycoon; interactive-fiction/story-choice app (Golmorad shows romance narrative sells); Persian open-world UGC sandbox; localised MOBA/battle royale (highest ceiling, needs a team and 12–18 months).

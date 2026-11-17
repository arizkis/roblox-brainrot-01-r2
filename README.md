# BRAINROT BAZAAR

A Rojo-first Roblox brainrot collection game for make.fun's roblox-brainrot-01 bounty.
The published experience is named **Brainrot Bazzar**; PLAY.json identifies it.

The current server core loop assigns bases, spawns a character every four seconds,
moves unclaimed stock along the diagonal conveyor, and lets players buy, carry and
deliver characters onto their own pads. Placed characters pay cash every second.
Stealing, lock timers, tsunami, rebirth actions and the client HUD arrive later.

All place script sources live under src/. default.project.json maps shared definitions
to ReplicatedStorage.Shared, server modules beneath ServerScriptService.Server and
the client entry to StarterPlayerScripts.Client. game.rbxl is generated from that
project; never edit scripts inside the binary independently.

- src/shared/GameConfig.luau owns immutable economy values, tier prices, seven
  rebirth-indexed conveyor odds bands, mutation definitions/probabilities, carry
  distances and the 18 original part recipes. Mutation probabilities are mutually
  exclusive absolute bands; their remainder is normal. The richest conveyor band
  is capped at band 7 (six or more rebirths on the highest-rebirth current player).
- src/server/CharacterFactory.luau exposes Create(characterId, mutationName?, origin?).
  It returns an unparented Model with a foot-level Root pivot, one welded assembly,
  a mutation treatment, metadata attributes and a three-line billboard. SetForSale
  adds a fourth price line on the belt; SetIncome updates the displayed actual rate,
  including fractional cash. Omit the mutation or pass "Normal" for ordinary stock.
- src/server/WorldBuilder.luau exposes Build(parent). Its return value includes the
  six plots, pad/expansion anchors, owner labels, lock buttons, safe-zone volumes,
  conveyor start/end attachments and player spawn. These are geometry references.
- src/server/GameState.luau is the single mutable state home: players, characters,
  pad occupancy, base owners, the base waiting queue and simulation accumulators.
  It publishes player attributes; attributes never serve as purchase authority.
- src/server/PlayerSessions.luau initializes $50 cash, zero rebirths, x1 income and
  six available pads; it claims/releases plots and updates owner signs. A seventh
  player waits for a released base. Departure removes owned characters and pads.
- src/server/Economy.luau validates purchase costs/capacity, owns cash and pad
  occupancy, and pays placed intrinsic income times the owner's income multiplier.
  Missed one-second ticks are accounted for after a slow server frame.
- src/server/Carry.luau binds server proximity prompts, checks the living avatar and
  purchase distance, and performs the synchronous purchase-to-carry transition. A
  massless welded character rides above/in front of its owner. Walking over an empty
  own pad delivers it upright; rival/occupied pads do nothing. Resetting an avatar
  preserves an undelivered purchase and reattaches it after respawn.
- src/server/Conveyor.luau rolls tiers/mutations, spawns stock and moves only Belt
  records. Purchased records stop moving immediately. Unclaimed stock expires after
  about 35 seconds. Rebirth odds are recalculated from current sessions each spawn.
- src/server/init.server.luau builds the world, then starts sessions, economy, carry
  and the conveyor. src/client/Game.client.luau remains an empty controller entry.

The future HUD can read these player attributes:

| Attribute | Meaning |
| --- | --- |
| Cash | Current cash; may include fractional income |
| IncomePerSecond | Total actually paid by placed characters |
| Rebirths / IncomeMultiplier | Rebirth count and effective income multiplier |
| PadAllowance / PadsUsed | Unlocked capacity / occupied pads (carried stock excluded) |
| BaseId | Plot 1–6, or 0 while waiting |
| Carrying / CarryingCharacterId | Carry flag and cast ID; empty string when not carrying |
| ActionMessage / ActionSequence | Latest result/refusal and increasing notification counter |
| StateRevision | Written after each state publication |

Purchase refusals such as "Base full! You need an empty pad." are exposed through
ActionMessage and ActionSequence. There is no client notification UI yet; inspect
attributes in Studio until the HUD is added. There are no client cash/purchase remotes.

Build and sync with Rojo 7.7:

```sh
rojo build default.project.json --output /tmp/smoke.rbxl
rojo build default.project.json --output game.rbxl
rojo serve default.project.json
```

Studio playtest checklist (requires the Roblox engine): start with $50 and a claimed
base; buy a $25 Common, confirm the cash deduction and zero placed income while
carrying, then walk over an own pad and confirm upright placement and one payment
per second. Account for the rolled mutation in the expected income. Check refusals
for insufficient cash, already carrying and six occupied pads without cash deductions.
Use two clients to race for the same stock and visit rival pads; only one buyer should
pay, and only own pads should accept delivery. Reset while carrying to check reattach;
leave/rejoin to check asset cleanup and base release. These checks are not substituted
by a Rojo build, which validates project packaging rather than engine behavior.

main.ts packages game.rbxl, src/, screenshots/ and PLAY.json with the kit's vendored
make.fun library. The screenshots and TOUR.json are still the kit placeholders and
will need replacement when the game is playable. The owner's pending play-code
description step remains separate from building the game.

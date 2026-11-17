# BRAINROT BAZAAR

A Rojo-first Roblox brainrot collection game for make.fun's roblox-brainrot-01 bounty.
The published experience is named **Brainrot Bazzar**; PLAY.json identifies it.

The current server core loop assigns bases, spawns a character every four seconds,
moves unclaimed stock along the diagonal conveyor, and lets players buy, carry and
deliver characters onto their own pads. Placed characters pay cash every second.
Tsunamis threaten carried cargo, rival bases can be robbed unless locked, and rebirths
increase income/capacity while keeping placed characters. The client HUD arrives next.

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
  conveyor start/end attachments and player spawn. SetPadAllowance materializes
  unlocked pads up to ten; the world also supplies shields and rebirth pedestals.
- src/server/GameState.luau is the single mutable state home: players, characters,
  pad occupancy, base owners, the base waiting queue and simulation accumulators.
  It publishes player attributes; attributes never serve as purchase authority.
- src/server/PlayerSessions.luau initializes $50 cash, zero rebirths, x1 income and
  six available pads; it claims/releases plots and updates owner signs. A seventh
  player waits for a released base. Departure clears placed/carrying assets and
  resets a released plot to six pads. A theft already in transit survives its victim
  leaving; a departing carrier's cargo despawns.
- src/server/Economy.luau validates purchase costs/capacity, owns cash and pad
  occupancy, and pays placed intrinsic income times the owner's income multiplier.
  Missed one-second ticks are accounted for after a slow server frame.
- src/server/Carry.luau binds server proximity prompts, checks the living avatar and
  purchase distance, and performs the synchronous purchase-to-carry transition. A
  massless welded character rides above/in front of its owner. Walking over an empty
  own pad delivers it upright; rival/occupied pads do nothing. Resetting an avatar
  preserves undelivered cargo and reattaches it after respawn, unless a tsunami hits
  its exposed last known position. Begin is shared by purchases and theft; WashAway
  deletes carried cargo without a cash refund. Speed restoration happens on delivery,
  washout, avatar replacement and departure.
- src/server/Conveyor.luau rolls tiers/mutations, spawns stock and moves only Belt
  records. Purchased records stop moving immediately. Unclaimed stock expires after
  about 35 seconds. Rebirth odds are recalculated from current sessions each spawn.
- src/server/Tsunami.luau owns warning, sweep and recession. The first wave starts at
  90s; warnings start 10s ahead. Sweeps last 8s, recession lasts 2s, and subsequent
  sweep starts remain 90s apart. A non-colliding, 22-stud water wall rises at the plaza
  edge and crosses the field. Continuous relative movement checks wash away only
  exposed carried cargo; players are not damaged and placed models are untouched.
  Every base footprint shelters, including rivals and unclaimed plots. Height within
  the footprint does not remove protection when jumping. Resetting uses the carrier's
  last known position so exposed cargo does not become immune during respawn.
- src/server/StealLock.luau binds placed-character steal prompts and authorizes only
  rivals with their own free pad, empty hands, a living nearby avatar and an unlocked
  target base. Pickup immediately frees the victim's pad/stops its income; ownership
  transfers on delivery. A thief walks at 75% of their pre-theft speed (16 becomes 12).
  Lock protection lasts 60s, disables steal prompts and shows a translucent pad shield
  plus a countdown sign. A separate 90s cooldown follows: locks can start 150s apart.
  A lock does not recall a character that was stolen before it activated.
- src/server/Rebirth.luau validates an owned base, positive placed income and cash at
  least 15 times the current total income rate. It spends that exact cost, increments
  rebirths, multiplies income by 1.5, unlocks one physical pad up to ten and keeps all
  placed characters. Zero income disables rebirth. Rebirth may repeat at the pad cap;
  the income reward still applies. Cash, rates and next cost update immediately.
- src/server/init.server.luau builds the world and replicated GameSignals folder,
  then starts the server systems. Carry's placement callback binds StealLock prompts;
  there is no circular service dependency. The client entry remains empty.

The future HUD can read these player attributes:

| Attribute | Meaning |
| --- | --- |
| Cash | Current cash; may include fractional income |
| IncomePerSecond | Total actually paid by placed characters |
| Rebirths / IncomeMultiplier | Rebirth count and effective income multiplier |
| RebirthCost / CanRebirth | Exact current cost; eligibility for the HUD button |
| PadAllowance / PadsUsed | Unlocked capacity / occupied pads (carried stock excluded) |
| BaseId | Plot 1–6, or 0 while waiting |
| Carrying / CarryingCharacterId | Carry flag and cast ID; empty string when not carrying |
| CarryingStolen | Whether the carried cargo currently incurs the theft speed penalty |
| LockState | NoBase, Ready, Locked or Cooldown |
| LockRemaining | Whole seconds of protection remaining |
| LockCooldownRemaining | Scheduled 90s while locked, then its active remaining countdown |
| LockReadyIn | Total seconds until activation is allowed again |
| LockExpiresAt / LockReadyAt | Server timestamps for smooth HUD countdowns |
| ActionMessage / ActionSequence | Latest result/refusal and increasing notification counter |
| StateRevision | Written after each state publication |

Purchase refusals such as "Base full! You need an empty pad." are exposed through
ActionMessage and ActionSequence. There is no client notification UI yet; inspect
attributes in Studio until the HUD is added. There are no client cash/purchase remotes.

ReplicatedStorage.GameSignals carries TsunamiPhase (Calm, Warning, Sweeping,
Receding), SecondsToWave, NextWaveAt, WaveEndsAt, TsunamiWarning and TsunamiBanner.
NextWaveAt/WaveEndsAt use Workspace:GetServerTimeNow() timestamps. SecondsToWave
is zero during the active sweep/recession and becomes the next countdown afterward.
RequestLock and RequestRebirth RemoteEvents take no arguments and always target
the sender's own claimed base. They use the same validation as the world controls,
with no distance requirement for the future HUD ability buttons. World prompts
require the owner to stand near their own pedestal; rival presses are refused.

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

For tension playtests: use two clients to steal/lock, inspect the speed change and
absence of victim income while cargo is in transit, then deliver and confirm ownership
and the thief's rate. Lock protection should last 60s, then show 90s of cooldown before
becoming ready. During a wave, compare carried cargo in the open against cargo inside
any plot, and confirm placed stock stays safe. At positive income verify rebirth's exact
cash debit, x1.5 rate, newly usable pad and unchanged placed models; repeat to the
ten-pad cap and check zero-income rejection. These are engine checks to run in Studio.

main.ts packages game.rbxl, src/, screenshots/ and PLAY.json with the kit's vendored
make.fun library. The screenshots and TOUR.json are still the kit placeholders and
will need replacement when the game is playable. The owner's pending play-code
description step remains separate from building the game.

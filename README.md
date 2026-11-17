# BRAINROT BAZAAR

A Rojo-first Roblox brainrot collection game for make.fun's roblox-brainrot-01 bounty.
The published experience is named **Brainrot Bazzar**; PLAY.json identifies it.

The current server core loop assigns bases, spawns a character every four seconds,
moves unclaimed stock along the diagonal conveyor, and lets players buy, carry and
deliver characters onto their own pads. Placed characters pay cash every second.
Tsunamis threaten carried cargo, rival bases can be robbed unless locked, and rebirths
increase income/capacity while keeping placed characters. The client HUD shows live
stats, tsunami warnings, ability buttons, notifications and readable interaction cards.

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
  there is no circular service dependency.
- src/shared/Presentation.luau owns display units, colors and currency formatting.
  HUD values compact millions/billions; server state keeps exact cash and rates.
- src/client/Game.client.luau constructs the view and starts the three controllers.
  HUDView.luau builds a ScreenGui on a 768x480 design canvas, fitted to the safe
  viewport using UIScale. Cash/income/boost/pads use large outlined text; touch-only
  layouts lift action buttons clear of the lower control area.
- src/client/HUDController.luau reads player/global attributes, updates countdowns
  from server timestamps and sends RequestLock/RequestRebirth. It never edits cash,
  income, locks or rebirth state locally. Disabled buttons are grey and guarded;
  pending requests stay disabled until acknowledgement or a short retry timeout.
  The title/how-to splash fades after four seconds (earlier on first interaction),
  and ActionMessage/ActionSequence now produce visible, fading notifications.
- src/client/PromptController.luau renders a large custom prompt card with ObjectText,
  ActionText, key/touch hint and hold progress. Keyboard/gamepad prompt input stays
  with Roblox; mouse/touch holds forward through InputHoldBegin/InputHoldEnd. Local
  filtering hides own steal prompts, rival pedestals and extra buys while carrying.
  The server still revalidates every action, regardless of visibility or UI state.
- src/client/NameplateController.luau scales billboard panels with the viewport and
  keeps labels at full readable size. Within view range, focused/carried characters
  are prioritized. Other overlapping callouts are hidden rather than shrunk, with
  at most four ordinary callouts visible. HUD panels reserve their screen space.
  Character labels use 24–30 design-pixel type; pedestal labels use 26–32. All keep
  white text with a black stroke. No particle emitters were added.

The HUD reads these player attributes:

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
ActionMessage and ActionSequence and shown in the HUD notification area. There are
no client cash/purchase remotes. Every world prompt names its object (character and
tier, or numbered pedestal) and its action, including the price when money is spent.
Availability metadata controls presentation only; it is never purchase authority.

ReplicatedStorage.GameSignals carries TsunamiPhase (Calm, Warning, Sweeping,
Receding), SecondsToWave, NextWaveAt, WaveEndsAt, TsunamiWarning and TsunamiBanner.
NextWaveAt/WaveEndsAt use Workspace:GetServerTimeNow() timestamps. SecondsToWave
is zero during the active sweep/recession and becomes the next countdown afterward.
RequestLock and RequestRebirth RemoteEvents take no arguments and always target
the sender's own claimed base. They use the same validation as the world controls,
with no distance requirement for the HUD ability buttons. World prompts
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

For client playtests, use 768x480 and larger viewports and verify the live stats, grey
disabled controls, identical pedestal/HUD actions, splash fade, warning/sweep banner,
long character names and mutation income lines. Check E, gamepad X and pointer holds
on the interaction card. Nameplates are 360 design pixels wide with a 24-pixel minimum
font, scaled with viewport width. Reducing a 1920px render to 768px wide retains 24px
minimum nameplate text; the HUD separately fits the safe viewport height. This is
a layout/scaling calculation; it does not substitute for inspecting a Studio render.

API reference for the authored custom prompt adapter:
[Roblox ProximityPrompt](https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt).

The final package can be reproduced and audited with:

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
node --experimental-vm-modules tools/verify-output.mjs out
```

The audit checks the binary framing/caps, source coverage, screenshots, play-link file,
byte-identical dossier and compile-only Luau sanity. It integrity-checks the pinned
luau-web 1.5.1 compiler archive and loads it in memory; no third-party files are written
into the repository. This is independent of the kit's makefun check command, whose
rows are pre-submit intake/link/transcript checks. Neither check runs the Roblox engine.
out/ is a local, ignored build directory and is not part of the Git commit.

TOUR.json now stages the four future Studio captures, in cover-first order:

| Capture filename | Live scene |
| --- | --- |
| 1-cover-heist.png | Carry a Glitch Solar Samurai Squirrel toward home; warning wall rising behind, placed stock, income and HUD visible |
| 2-conveyor-closeup.png | Five belt characters across Common, Uncommon, Rare, Legendary and Divine, with Golden/Diamond/Glitch/Void treatments |
| 3-rival-steal-lock.png | A theft already underway when the rival locks the remaining stock; shield and 60s countdown visible |
| 4-base-rebirth.png | A populated base after two real rebirth transactions, x2.25 income, eight pads and the next live cost |

Start a fresh Studio Play session, wait for avatars, and use TWO clients for shot 3.
Capture the client owning the lowest-numbered base (normally Base 01). Each tour call
invokes ServerScriptService.Server.CaptureTour.Stage with the indicated shot argument;
the helper resets that private Studio session's stock/cash, then uses the actual factory,
cash checks, carrying, placement, stealing, locks and rebirth functions. It is guarded by
RunService:IsStudio(), is never started by normal gameplay, and cannot be invoked by
a client. CaptureViewController supplies a 15s Studio-only camera view; V releases it
early. The clock and all gameplay continue running. The cover's warning has a three-
second window, so capture promptly or rerun its stage. The other stock keeps moving.

For example, in Studio's SERVER Command Bar during Play:

```lua
require(game.ServerScriptService.Server.CaptureTour).Stage("cover")
```

Use arguments conveyor, steal-lock and base-rebirth for the remaining scenes. Adjust
the actual Studio camera if needed; these fixtures are not substitutes for inspecting
the live game. The tour/camera helper has compiled but has not been exercised in Studio.
Capture real running frames, replacing the three starter images with the four filenames
above. Each image must be at most 256 KiB, long side at most 1280px, short side at least
480px; use 1280x720 for the cover/thumbnail. No replacement images are generated here.

main.ts packages game.rbxl, src/, screenshots/ and PLAY.json with the kit's vendored
make.fun library. The screenshots and TOUR.json are still the kit placeholders and
will need replacement when the game is playable. The owner's pending play-code
description step remains separate from building the game.

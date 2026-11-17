# BRAINROT BAZAAR

A Rojo-first Roblox brainrot collection game for make.fun's roblox-brainrot-01 bounty.
The published experience is named **Brainrot Bazzar**; PLAY.json identifies it.

The current foundation builds a bright 3D plaza at server startup: a diagonal conveyor,
six unclaimed base plots with six pads each, lock pedestals, owner signs, a spawn and
an economy directory. This stage has no claiming, conveyor movement, purchases,
income, stealing, lock timers, tsunami or rebirth behavior yet.

All place script sources live under src/. default.project.json maps shared definitions
to ReplicatedStorage.Shared, server modules beneath ServerScriptService.Server and
the client entry to StarterPlayerScripts.Client. game.rbxl is generated from that
project; never edit scripts inside the binary independently.

- src/shared/GameConfig.luau owns immutable tier prices, income, colors, mutation
  definitions/probabilities and the 18 original, part-built character recipes. Mutation
  probabilities are mutually exclusive absolute bands; their remainder is normal.
- src/server/CharacterFactory.luau exposes Create(characterId, mutationName?, origin?).
  It returns an unparented Model with a foot-level Root pivot, one welded assembly,
  a mutation treatment, metadata attributes and a three-line billboard. Omit the
  mutation or pass "Normal" for an ordinary character. No random rolls happen here.
- src/server/WorldBuilder.luau exposes Build(parent). Its return value includes the
  six plots, pad/expansion anchors, owner labels, lock buttons, safe-zone volumes,
  conveyor start/end attachments and player spawn. These are geometry references.
- src/server/GameState.luau is the single mutable state home. Only World is populated
  at startup; player, character and base-owner maps are reserved for later services.
- src/server/init.server.luau builds the world. src/client/Game.client.luau is an empty
  controller entry, leaving standard Roblox avatar and camera controls active.

Build and sync with Rojo 7.7:

```sh
rojo build default.project.json --output /tmp/smoke.rbxl
rojo build default.project.json --output game.rbxl
rojo serve default.project.json
```

For an isolated factory preview in Studio's **server Command Bar**, use the existing
module (this does not create another script):

```lua
local factory = require(game.ServerScriptService.Server.CharacterFactory)
local model = factory.Create("ascended_shopping_cart", "Diamond", CFrame.new(0, 1, 0))
model.Parent = workspace
```

main.ts packages game.rbxl, src/, screenshots/ and PLAY.json with the kit's vendored
make.fun library. The screenshots and TOUR.json are still the kit placeholders and
will need replacement when the game is playable. The owner's pending play-code
description step remains separate from building the game.

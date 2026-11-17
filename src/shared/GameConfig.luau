--!strict
-- Immutable definitions only. Mutable server state lives in GameState.
local v = Vector3.new
local rgb = Color3.fromRGB

export type Piece = {
	Name: string,
	Shape: string,
	Size: Vector3,
	Position: Vector3,
	Color: Color3,
	Rotation: Vector3,
	Material: Enum.Material,
}

export type CharacterDefinition = {
	Name: string,
	Tier: string,
	Recipe: string,
	Parts: {Piece},
}

export type TierDefinition = {
	BuyPrice: number,
	IncomePerSecond: number,
	Color: Color3,
	MutationOdds: {[string]: number},
}

export type MutationDefinition = {
	Multiplier: number,
	Color: Color3,
	Treatment: string,
}

local function piece(
	name: string, shape: string, size: Vector3, position: Vector3,
	color: Color3, rotation: Vector3?, material: Enum.Material?
): Piece
	return {
		Name = name, Shape = shape, Size = size, Position = position, Color = color,
		Rotation = rotation or v(0, 0, 0), Material = material or Enum.Material.SmoothPlastic,
	}
end

local C = {
	White = rgb(255, 250, 235), Ink = rgb(24, 25, 49), Yellow = rgb(255, 218, 41),
	Pink = rgb(255, 72, 156), Cyan = rgb(47, 238, 255), Green = rgb(103, 239, 71),
	Orange = rgb(255, 135, 37), Purple = rgb(153, 78, 255), Red = rgb(255, 65, 80),
	Steel = rgb(161, 180, 195), Brown = rgb(150, 88, 49), Cream = rgb(250, 210, 143),
	Gold = rgb(255, 194, 44), Blue = rgb(53, 114, 255), Void = rgb(31, 14, 58),
}

local Config = {}

Config.TierOrder = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine"}
Config.Tiers = {
	Common = {
		BuyPrice = 25, IncomePerSecond = 1, Color = rgb(139, 156, 179),
		MutationOdds = {Golden = 0.055, Diamond = 0.019, Glitch = 0.005, Void = 0.001},
	},
	Uncommon = {
		BuyPrice = 100, IncomePerSecond = 4, Color = rgb(63, 202, 95),
		MutationOdds = {Golden = 0.054, Diamond = 0.019, Glitch = 0.006, Void = 0.001},
	},
	Rare = {
		BuyPrice = 450, IncomePerSecond = 14, Color = rgb(49, 133, 255),
		MutationOdds = {Golden = 0.065, Diamond = 0.025, Glitch = 0.008, Void = 0.002},
	},
	Epic = {
		BuyPrice = 1800, IncomePerSecond = 45, Color = rgb(169, 65, 245),
		MutationOdds = {Golden = 0.075, Diamond = 0.032, Glitch = 0.0105, Void = 0.0025},
	},
	Legendary = {
		BuyPrice = 7500, IncomePerSecond = 150, Color = rgb(255, 170, 27),
		MutationOdds = {Golden = 0.09, Diamond = 0.042, Glitch = 0.015, Void = 0.003},
	},
	Mythic = {
		BuyPrice = 30000, IncomePerSecond = 550, Color = rgb(246, 58, 130),
		MutationOdds = {Golden = 0.10, Diamond = 0.056, Glitch = 0.020, Void = 0.004},
	},
	Divine = {
		BuyPrice = 150000, IncomePerSecond = 2400, Color = rgb(33, 221, 224),
		MutationOdds = {Golden = 0.10, Diamond = 0.054, Glitch = 0.0215, Void = 0.0045},
	},
} :: {[string]: TierDefinition}

-- These are mutually exclusive, absolute probabilities per spawn, not stacking rolls.
-- The unlisted remainder is normal. Totals: 8%, 8%, 10%, 12%, 15%, 18%, 18%.
Config.MutationOrder = {"Golden", "Diamond", "Glitch", "Void"}
Config.MaxMutationMultiplier = 15
Config.Mutations = {
	Golden = {Multiplier = 3, Color = C.Gold, Treatment = "Gold trim and crown studs"},
	Diamond = {Multiplier = 6, Color = C.Cyan, Treatment = "Cyan crystal glints"},
	Glitch = {Multiplier = 10, Color = C.Pink, Treatment = "RGB offsets and pixel fragments"},
	Void = {Multiplier = 15, Color = C.Void, Treatment = "Dark body and violet aura"},
} :: {[string]: MutationDefinition}

Config.World = {
	BaseCount = 6, BaseRadius = 65, StartingPads = 6, MaxPads = 10,
	PlazaSize = 192, ConveyorWidth = 10,
	ConveyorStart = v(-43, 0.95, -43), ConveyorEnd = v(43, 0.95, 43),
}

Config.CharacterOrder = {
	"wet_floor_sign", "expired_yogurt_cup", "moldy_muffin",
	"roomba_with_a_knife", "radical_garden_gnome", "rusty_clippy",
	"inflatable_tube_man", "grandma_turbo", "caffeinated_cactus",
	"disco_potato", "neon_ninja_noodle", "celestial_sushi_roll",
	"buff_goldfish", "temporal_tuba", "solar_samurai_squirrel",
	"velvet_void_vortex", "the_blue_screen", "ascended_shopping_cart",
}

Config.Characters = {
	wet_floor_sign = {
		Name = "Wet Floor Sign", Tier = "Common",
		Recipe = "Yellow A-frame wedge, orange feet, black warning stripe and surprised face.",
		Parts = {
			piece("Sign", "Wedge", v(2, 2.8, 1.2), v(0, 1.6, 0), C.Yellow),
			piece("Handle", "Block", v(0.9, 0.3, 0.35), v(0, 3.05, 0), C.Orange),
			piece("LeftFoot", "Block", v(0.65, 0.3, 1.6), v(-0.7, 0.15, 0), C.Orange),
			piece("RightFoot", "Block", v(0.65, 0.3, 1.6), v(0.7, 0.15, 0), C.Orange),
			piece("Warning", "Block", v(1.5, 0.18, 0.16), v(0, 0.9, -0.65), C.Ink),
			piece("EyeL", "Ball", v(0.25, 0.35, 0.18), v(-0.4, 2.05, -0.65), C.Ink),
			piece("EyeR", "Ball", v(0.25, 0.35, 0.18), v(0.4, 2.05, -0.65), C.Ink),
		},
	},
	expired_yogurt_cup = {
		Name = "Expired Yogurt Cup", Tier = "Common",
		Recipe = "White cylindrical cup, pink foil lid, green spill and mismatched eyes.",
		Parts = {
			piece("Cup", "Cylinder", v(2.4, 1.9, 1.9), v(0, 1.5, 0), C.White, v(0, 0, 90)),
			piece("Label", "Block", v(1.6, 1.0, 0.16), v(0, 1.4, -0.9), C.Pink),
			piece("Lid", "Cylinder", v(0.18, 2.2, 2.2), v(0, 2.8, 0), C.Pink, v(0, 0, 90)),
			piece("FoilTab", "Block", v(0.7, 0.12, 0.6), v(1, 2.9, 0), C.Steel, v(0, 0, 20)),
			piece("Spill", "Ball", v(0.8, 0.6, 0.8), v(-0.6, 3.05, 0), C.Green),
			piece("EyeL", "Ball", v(0.25, 0.4, 0.18), v(-0.4, 1.7, -1.02), C.Ink),
			piece("EyeR", "Ball", v(0.3, 0.22, 0.18), v(0.4, 1.65, -1.02), C.Ink),
			piece("FootL", "Block", v(0.7, 0.3, 0.9), v(-0.55, 0.15, -0.25), C.Green),
			piece("FootR", "Block", v(0.7, 0.3, 0.9), v(0.55, 0.15, -0.25), C.Green),
		},
	},
	moldy_muffin = {
		Name = "Moldy Muffin", Tier = "Common",
		Recipe = "Brown pleated cake base, broad cream dome, lime mold blobs and tiny feet.",
		Parts = {
			piece("Wrapper", "Cylinder", v(1.7, 1.8, 1.8), v(0, 1.15, 0), C.Brown, v(0, 0, 90)),
			piece("Dome", "Ball", v(2.7, 1.7, 2.4), v(0, 2.25, 0), C.Cream),
			piece("MoldL", "Ball", v(0.9, 0.6, 0.8), v(-0.7, 2.8, -0.3), C.Green),
			piece("MoldR", "Ball", v(0.6, 0.5, 0.6), v(0.75, 2.8, 0.4), C.Green),
			piece("EyeL", "Ball", v(0.24, 0.3, 0.2), v(-0.45, 2.2, -1.15), C.Ink),
			piece("EyeR", "Ball", v(0.24, 0.3, 0.2), v(0.45, 2.2, -1.15), C.Ink),
			piece("FootL", "Block", v(0.7, 0.3, 1), v(-0.6, 0.15, -0.25), C.Pink),
			piece("FootR", "Block", v(0.7, 0.3, 1), v(0.6, 0.15, -0.25), C.Pink),
		},
	},
	roomba_with_a_knife = {
		Name = "Roomba With A Knife", Tier = "Uncommon",
		Recipe = "Low charcoal disc on wheels, tall mint sensor mast and oversized silver blade.",
		Parts = {
			piece("Disc", "Cylinder", v(0.9, 2.8, 2.8), v(0, 0.9, 0), C.Ink, v(0, 0, 90)),
			piece("Bumper", "Cylinder", v(0.22, 3, 3), v(0, 0.65, 0), C.Steel, v(0, 0, 90)),
			piece("WheelL", "Ball", v(0.6, 0.6, 0.8), v(-1, 0.3, 0), C.Ink),
			piece("WheelR", "Ball", v(0.6, 0.6, 0.8), v(1, 0.3, 0), C.Ink),
			piece("Mast", "Block", v(0.45, 1.8, 0.45), v(0, 2.1, 0), C.Green),
			piece("Sensor", "Block", v(1.15, 0.5, 0.6), v(0, 3.1, -0.1), C.Green),
			piece("Lens", "Ball", v(0.35, 0.35, 0.2), v(0, 3.1, -0.45), C.Red),
			piece("Handle", "Block", v(0.3, 0.8, 0.35), v(1, 1.6, 0), C.Brown, v(0, 0, -20)),
			piece("Knife", "Wedge", v(0.22, 1.3, 0.7), v(1.35, 2.5, 0), C.Steel, v(0, 0, -20)),
		},
	},
	radical_garden_gnome = {
		Name = "Radical Garden Gnome", Tier = "Uncommon",
		Recipe = "Purple pointed wedge hat, red coat, huge white beard and cyan skateboard.",
		Parts = {
			piece("Board", "Block", v(2.6, 0.2, 1.4), v(0, 0.4, 0), C.Cyan),
			piece("WheelsL", "Cylinder", v(1.4, 0.5, 0.5), v(-0.85, 0.25, 0), C.Pink, v(0, 90, 0)),
			piece("WheelsR", "Cylinder", v(1.4, 0.5, 0.5), v(0.85, 0.25, 0), C.Pink, v(0, 90, 0)),
			piece("Coat", "Block", v(1.4, 1.1, 1), v(0, 1.15, 0), C.Red),
			piece("Head", "Ball", v(1.3, 1.2, 1.2), v(0, 2.1, 0), C.Cream),
			piece("Beard", "Wedge", v(1.2, 1.1, 0.6), v(0, 1.8, -0.6), C.White, v(0, 180, 180)),
			piece("Hat", "Wedge", v(1.8, 1.3, 1.4), v(0, 3.15, 0), C.Purple),
			piece("Shades", "Block", v(1.2, 0.25, 0.18), v(0, 2.3, -0.62), C.Ink),
			piece("Nose", "Ball", v(0.4, 0.4, 0.45), v(0, 2.02, -0.8), C.Orange),
		},
	},
	rusty_clippy = {
		Name = "Rusty Clippy", Tier = "Uncommon",
		Recipe = "Tall bent paperclip made from rusty bars, orange elbows and giant floating eyes.",
		Parts = {
			piece("OuterL", "Block", v(0.3, 2.8, 0.35), v(-0.8, 1.7, 0), C.Brown),
			piece("OuterR", "Block", v(0.3, 2.8, 0.35), v(0.8, 1.7, 0), C.Brown),
			piece("Top", "Block", v(1.6, 0.3, 0.35), v(0, 3.1, 0), C.Orange),
			piece("Bottom", "Block", v(1.6, 0.3, 0.35), v(0, 0.3, 0), C.Orange),
			piece("Inner", "Block", v(0.28, 1.9, 0.35), v(0, 1.4, 0), C.Steel),
			piece("Bend", "Block", v(0.8, 0.28, 0.35), v(0.4, 2.35, 0), C.Steel),
			piece("EyeL", "Ball", v(0.8, 0.85, 0.6), v(-0.5, 2.75, -0.35), C.White),
			piece("EyeR", "Ball", v(0.8, 0.85, 0.6), v(0.5, 2.75, -0.35), C.White),
			piece("PupilL", "Ball", v(0.3, 0.4, 0.2), v(-0.4, 2.7, -0.7), C.Ink),
			piece("PupilR", "Ball", v(0.3, 0.4, 0.2), v(0.6, 2.7, -0.7), C.Ink),
		},
	},
	inflatable_tube_man = {
		Name = "Inflatable Tube Man", Tier = "Rare",
		Recipe = "Tall leaning red tube, splayed yellow arms, blue blower and black streamer hair.",
		Parts = {
			piece("Blower", "Block", v(1.7, 0.6, 1.6), v(0, 0.3, 0), C.Blue),
			piece("LowerTube", "Cylinder", v(1.6, 1, 1), v(0, 1.3, 0), C.Red, v(0, 0, 80)),
			piece("UpperTube", "Cylinder", v(1.6, 1, 1), v(0.3, 2.75, 0), C.Red, v(0, 0, 110)),
			piece("ArmL", "Block", v(1.6, 0.45, 0.45), v(-0.9, 2.5, 0), C.Yellow, v(0, 0, -35)),
			piece("ArmR", "Block", v(1.6, 0.45, 0.45), v(1.3, 2.8, 0), C.Yellow, v(0, 0, 45)),
			piece("HairL", "Block", v(0.13, 0.6, 0.13), v(0, 3.75, 0), C.Ink, v(0, 0, 20)),
			piece("HairR", "Block", v(0.13, 0.6, 0.13), v(0.6, 3.75, 0), C.Ink, v(0, 0, -25)),
			piece("EyeL", "Ball", v(0.2, 0.3, 0.2), v(0, 3.1, -0.5), C.White),
			piece("EyeR", "Ball", v(0.2, 0.3, 0.2), v(0.55, 3.1, -0.5), C.White),
			piece("Mouth", "Block", v(0.45, 0.12, 0.15), v(0.25, 2.8, -0.52), C.Ink),
		},
	},
	grandma_turbo = {
		Name = "Grandma Turbo", Tier = "Rare",
		Recipe = "Pink dress and silver hair bun over a cyan rocket walker with orange exhaust.",
		Parts = {
			piece("Dress", "Wedge", v(1.6, 1.5, 1.3), v(0, 1.35, 0), C.Pink),
			piece("Head", "Ball", v(1.2, 1.15, 1.1), v(0, 2.65, 0), C.Cream),
			piece("Bun", "Ball", v(1.25, 0.8, 1.1), v(0, 3.35, 0.2), C.Steel),
			piece("Glasses", "Block", v(1.15, 0.28, 0.2), v(0, 2.75, -0.55), C.Ink),
			piece("WalkerL", "Block", v(0.2, 1.8, 0.2), v(-1, 0.9, -0.7), C.Cyan),
			piece("WalkerR", "Block", v(0.2, 1.8, 0.2), v(1, 0.9, -0.7), C.Cyan),
			piece("Handle", "Block", v(2.2, 0.2, 0.2), v(0, 1.8, -0.7), C.Cyan),
			piece("RocketL", "Cylinder", v(1.8, 0.65, 0.65), v(-1, 0.65, 0), C.Steel, v(0, 90, 0)),
			piece("RocketR", "Cylinder", v(1.8, 0.65, 0.65), v(1, 0.65, 0), C.Steel, v(0, 90, 0)),
			piece("FlameL", "Wedge", v(0.6, 0.6, 1.2), v(-1, 0.65, 1.25), C.Orange),
			piece("FlameR", "Wedge", v(0.6, 0.6, 1.2), v(1, 0.65, 1.25), C.Orange),
		},
	},
	caffeinated_cactus = {
		Name = "Caffeinated Cactus", Tier = "Rare",
		Recipe = "Lime branching cactus in a terracotta pot, espresso cup and frantic white eyes.",
		Parts = {
			piece("Pot", "Cylinder", v(0.9, 1.7, 1.7), v(0, 0.45, 0), C.Orange, v(0, 0, 90)),
			piece("Trunk", "Cylinder", v(2.4, 1, 1), v(0, 2.05, 0), C.Green, v(0, 0, 90)),
			piece("BranchL", "Block", v(1, 0.45, 0.5), v(-0.85, 2, 0), C.Green),
			piece("BranchTipL", "Block", v(0.5, 1.3, 0.5), v(-1.2, 2.5, 0), C.Green),
			piece("BranchR", "Block", v(1, 0.45, 0.5), v(0.85, 1.7, 0), C.Green),
			piece("Coffee", "Cylinder", v(0.7, 0.65, 0.65), v(1.25, 2.2, 0), C.White, v(0, 0, 90)),
			piece("CoffeeTop", "Cylinder", v(0.08, 0.55, 0.55), v(1.25, 2.57, 0), C.Brown, v(0, 0, 90)),
			piece("EyeL", "Ball", v(0.45, 0.6, 0.3), v(-0.28, 2.85, -0.48), C.White),
			piece("EyeR", "Ball", v(0.45, 0.6, 0.3), v(0.28, 2.85, -0.48), C.White),
			piece("PupilL", "Ball", v(0.14, 0.25, 0.12), v(-0.2, 2.9, -0.67), C.Ink),
			piece("PupilR", "Ball", v(0.14, 0.25, 0.12), v(0.2, 2.8, -0.67), C.Ink),
			piece("Spine", "Wedge", v(0.25, 0.6, 0.3), v(0, 3.45, 0), C.Yellow),
		},
	},
	disco_potato = {
		Name = "Disco Potato", Tier = "Epic",
		Recipe = "Lumpy ochre body, mirrored silver afro, magenta shades and enormous platform boots.",
		Parts = {
			piece("Potato", "Ball", v(2.2, 2.5, 1.6), v(0, 2.05, 0), C.Cream),
			piece("Afro", "Ball", v(2.6, 1.5, 2), v(0, 3.35, 0), C.Steel, nil, Enum.Material.Metal),
			piece("MirrorL", "Block", v(0.65, 0.6, 0.2), v(-0.7, 3.4, -0.8), C.Cyan),
			piece("MirrorR", "Block", v(0.65, 0.6, 0.2), v(0.7, 3.4, -0.8), C.Pink),
			piece("Shades", "Block", v(1.9, 0.4, 0.25), v(0, 2.65, -0.8), C.Purple),
			piece("BootL", "Block", v(0.85, 0.7, 1.4), v(-0.7, 0.35, -0.2), C.Pink),
			piece("BootR", "Block", v(0.85, 0.7, 1.4), v(0.7, 0.35, -0.2), C.Pink),
			piece("ArmL", "Block", v(1.3, 0.4, 0.4), v(-1.5, 2.25, 0), C.Cream, v(0, 0, -35)),
			piece("ArmR", "Block", v(1.3, 0.4, 0.4), v(1.5, 2.75, 0), C.Cream, v(0, 0, 45)),
		},
	},
	neon_ninja_noodle = {
		Name = "Neon Ninja Noodle", Tier = "Epic",
		Recipe = "Angular ivory noodle in a black ninja vest, cyan headband tails and crossing pink swords.",
		Parts = {
			piece("LegL", "Block", v(0.45, 1.3, 0.5), v(-0.5, 0.65, 0), C.Cream, v(0, 0, -12)),
			piece("LegR", "Block", v(0.45, 1.3, 0.5), v(0.5, 0.65, 0), C.Cream, v(0, 0, 12)),
			piece("Vest", "Block", v(1.4, 1.3, 0.8), v(0, 1.85, 0), C.Ink),
			piece("Head", "Cylinder", v(1.2, 1, 1), v(0, 3.05, 0), C.Cream, v(0, 0, 90)),
			piece("Band", "Block", v(1.15, 0.28, 1.05), v(0, 3.3, 0), C.Cyan, nil, Enum.Material.Neon),
			piece("TailL", "Block", v(1.2, 0.2, 0.25), v(-0.8, 3.55, 0.3), C.Cyan, v(0, 0, -30)),
			piece("TailR", "Block", v(1.2, 0.2, 0.25), v(0.8, 3.55, 0.3), C.Cyan, v(0, 0, 30)),
			piece("SwordL", "Block", v(0.18, 3.5, 0.2), v(-0.2, 2.2, 0.6), C.Pink, v(0, 0, 40), Enum.Material.Neon),
			piece("SwordR", "Block", v(0.18, 3.5, 0.2), v(0.2, 2.2, 0.6), C.Pink, v(0, 0, -40), Enum.Material.Neon),
			piece("Eyes", "Block", v(0.7, 0.15, 0.18), v(0, 3.05, -0.52), C.Ink),
		},
	},
	celestial_sushi_roll = {
		Name = "Celestial Sushi Roll", Tier = "Epic",
		Recipe = "Black seaweed cube, white rice inset, salmon center, orbiting stars and golden chopsticks.",
		Parts = {
			piece("Seaweed", "Block", v(2.3, 2.3, 1.6), v(0, 1.55, 0), C.Ink),
			piece("Rice", "Block", v(1.95, 1.95, 0.2), v(0, 1.55, -0.88), C.White),
			piece("Salmon", "Block", v(1.1, 1.05, 0.25), v(0, 1.55, -1.03), C.Orange),
			piece("Cucumber", "Block", v(0.35, 0.6, 0.3), v(0.4, 1.5, -1.18), C.Green),
			piece("StickL", "Block", v(0.18, 3.8, 0.18), v(-0.55, 2.05, 0.6), C.Gold, v(0, 0, -20)),
			piece("StickR", "Block", v(0.18, 3.8, 0.18), v(0.55, 2.05, 0.6), C.Gold, v(0, 0, 20)),
			piece("StarL", "Block", v(0.6, 0.6, 0.25), v(-1.7, 2.9, 0), C.Cyan, v(0, 0, 45), Enum.Material.Neon),
			piece("StarR", "Block", v(0.5, 0.5, 0.25), v(1.7, 3.4, 0), C.Pink, v(0, 0, 45), Enum.Material.Neon),
			piece("Feet", "Block", v(1.7, 0.4, 1.1), v(0, 0.2, 0), C.Purple),
		},
	},
	buff_goldfish = {
		Name = "Buff Goldfish", Tier = "Legendary",
		Recipe = "Huge orange fish torso, wedge tail, bulging biceps, gold crown and tiny blue shoes.",
		Parts = {
			piece("Body", "Ball", v(2.8, 2.5, 1.8), v(0, 2.35, 0), C.Orange),
			piece("BicepL", "Ball", v(1.3, 1.6, 1.1), v(-1.8, 2.6, 0), C.Orange),
			piece("BicepR", "Ball", v(1.3, 1.6, 1.1), v(1.8, 2.6, 0), C.Orange),
			piece("FistL", "Block", v(0.9, 0.9, 0.9), v(-2, 3.45, -0.1), C.Gold),
			piece("FistR", "Block", v(0.9, 0.9, 0.9), v(2, 3.45, -0.1), C.Gold),
			piece("Tail", "Wedge", v(1.9, 2, 0.8), v(0, 2.1, 1.2), C.Yellow, v(0, 90, 0)),
			piece("Crown", "Block", v(1.5, 0.4, 0.8), v(0, 3.65, 0), C.Gold),
			piece("CrownTip", "Wedge", v(0.6, 0.8, 0.7), v(0, 4.15, 0), C.Gold),
			piece("EyeL", "Ball", v(0.7, 0.75, 0.4), v(-0.6, 2.9, -0.8), C.White),
			piece("EyeR", "Ball", v(0.7, 0.75, 0.4), v(0.6, 2.9, -0.8), C.White),
			piece("PupilL", "Ball", v(0.25, 0.3, 0.15), v(-0.6, 2.9, -1.05), C.Ink),
			piece("PupilR", "Ball", v(0.25, 0.3, 0.15), v(0.6, 2.9, -1.05), C.Ink),
			piece("ShoeL", "Block", v(0.9, 0.8, 1.3), v(-0.7, 0.4, -0.15), C.Blue),
			piece("ShoeR", "Block", v(0.9, 0.8, 1.3), v(0.7, 0.4, -0.15), C.Blue),
		},
	},
	temporal_tuba = {
		Name = "Temporal Tuba", Tier = "Legendary",
		Recipe = "Golden U-bend brass instrument, wide bell, cyan clock face and three white valves.",
		Parts = {
			piece("PipeL", "Cylinder", v(2.8, 0.65, 0.65), v(-0.75, 1.8, 0), C.Gold, v(0, 0, 90)),
			piece("PipeR", "Cylinder", v(3.2, 0.9, 0.9), v(0.75, 2, 0), C.Gold, v(0, 0, 90)),
			piece("Bend", "Block", v(2.1, 0.65, 0.75), v(0, 0.4, 0), C.Gold),
			piece("Bell", "Cylinder", v(0.6, 2.4, 2.4), v(0.75, 3.85, 0), C.Gold, v(0, 0, 90)),
			piece("BellInside", "Cylinder", v(0.08, 1.9, 1.9), v(0.75, 4.2, 0), C.Ink, v(0, 0, 90)),
			piece("Clock", "Cylinder", v(0.3, 1.8, 1.8), v(-0.3, 2.1, -0.55), C.Cyan, v(0, 90, 0)),
			piece("HandHour", "Block", v(0.12, 0.65, 0.12), v(-0.3, 2.38, -0.75), C.Ink),
			piece("HandMinute", "Block", v(0.7, 0.12, 0.12), v(0, 2.1, -0.75), C.Ink),
			piece("ValveL", "Block", v(0.22, 0.6, 0.3), v(-0.7, 3.05, -0.3), C.White),
			piece("ValveM", "Block", v(0.22, 0.6, 0.3), v(-0.2, 3.05, -0.3), C.White),
			piece("ValveR", "Block", v(0.22, 0.6, 0.3), v(0.3, 3.05, -0.3), C.White),
		},
	},
	solar_samurai_squirrel = {
		Name = "Solar Samurai Squirrel", Tier = "Mythic",
		Recipe = "Orange squirrel with a towering curled tail, red armor, split gold helmet and solar katana.",
		Parts = {
			piece("Body", "Block", v(1.7, 1.8, 1.1), v(0, 1.75, 0), C.Red),
			piece("Head", "Ball", v(1.6, 1.3, 1.3), v(0, 3.05, 0), C.Orange),
			piece("TailLow", "Ball", v(1.4, 2.4, 1.6), v(0.5, 2.1, 1.2), C.Orange),
			piece("TailCurl", "Ball", v(2.1, 2.1, 1.5), v(0.4, 3.7, 1.2), C.Gold),
			piece("Helmet", "Block", v(1.9, 0.5, 1.5), v(0, 3.7, 0), C.Ink),
			piece("HornL", "Wedge", v(0.6, 1, 0.5), v(-0.7, 4.25, 0), C.Gold, v(0, 0, -20)),
			piece("HornR", "Wedge", v(0.6, 1, 0.5), v(0.7, 4.25, 0), C.Gold, v(0, 0, 20)),
			piece("Katana", "Block", v(0.18, 3.5, 0.35), v(-1.55, 2.2, 0), C.Yellow, v(0, 0, -20), Enum.Material.Neon),
			piece("Guard", "Block", v(0.9, 0.15, 0.5), v(-1.15, 1.1, 0), C.Gold),
			piece("Muzzle", "Ball", v(1, 0.5, 0.5), v(0, 2.9, -0.65), C.Cream),
			piece("Eyes", "Block", v(1.1, 0.15, 0.2), v(0, 3.25, -0.65), C.Ink),
			piece("BootL", "Block", v(0.7, 0.8, 1), v(-0.55, 0.4, 0), C.Ink),
			piece("BootR", "Block", v(0.7, 0.8, 1), v(0.55, 0.4, 0), C.Ink),
		},
	},
	velvet_void_vortex = {
		Name = "Velvet Void Vortex", Tier = "Mythic",
		Recipe = "Floating stack of rotated violet cubes, black core, cyan slit eyes and four orbit shards.",
		Parts = {
			piece("FootShard", "Wedge", v(1.2, 0.8, 1.2), v(0, 0.4, 0), C.Purple),
			piece("LowerSwirl", "Block", v(2, 0.65, 2), v(0, 1.1, 0), C.Purple, v(0, 25, 0)),
			piece("MiddleSwirl", "Block", v(2.6, 0.65, 2.6), v(0, 1.85, 0), C.Void, v(0, 50, 0)),
			piece("UpperSwirl", "Block", v(3.1, 0.65, 3.1), v(0, 2.6, 0), C.Purple, v(0, 75, 0)),
			piece("Core", "Ball", v(1.8, 1.8, 1.8), v(0, 3.45, 0), C.Void),
			piece("EyeL", "Block", v(0.5, 0.18, 0.18), v(-0.45, 3.5, -0.85), C.Cyan, nil, Enum.Material.Neon),
			piece("EyeR", "Block", v(0.5, 0.18, 0.18), v(0.45, 3.5, -0.85), C.Cyan, nil, Enum.Material.Neon),
			piece("ShardL", "Wedge", v(0.5, 1.2, 0.5), v(-2, 3.6, 0), C.Pink, v(0, 0, -25)),
			piece("ShardR", "Wedge", v(0.5, 1.2, 0.5), v(2, 3.6, 0), C.Pink, v(0, 0, 25)),
			piece("ShardTop", "Block", v(0.6, 0.6, 0.6), v(0, 4.55, 0), C.Cyan, v(0, 0, 45)),
			piece("ShardBack", "Block", v(0.6, 0.6, 0.6), v(0, 3.4, 2), C.Cyan, v(45, 0, 45)),
		},
	},
	the_blue_screen = {
		Name = "The Blue Screen", Tier = "Divine",
		Recipe = "Wide electric-blue monitor deity, white error glyphs, angular cyan wings and a gold halo.",
		Parts = {
			piece("Stand", "Block", v(1.8, 0.4, 1.3), v(0, 0.2, 0), C.Ink),
			piece("Neck", "Block", v(0.6, 0.8, 0.6), v(0, 0.7, 0), C.Steel),
			piece("Monitor", "Block", v(3.1, 2.5, 0.7), v(0, 2.4, 0), C.Ink),
			piece("Screen", "Block", v(2.75, 2.15, 0.12), v(0, 2.4, -0.42), C.Blue, nil, Enum.Material.Neon),
			piece("EyeL", "Block", v(0.22, 0.35, 0.1), v(-0.7, 2.85, -0.53), C.White),
			piece("EyeR", "Block", v(0.22, 0.35, 0.1), v(-0.05, 2.85, -0.53), C.White),
			piece("Frown", "Block", v(0.8, 0.15, 0.1), v(-0.38, 2.4, -0.53), C.White),
			piece("ErrorLineL", "Block", v(1.8, 0.12, 0.1), v(0, 1.95, -0.53), C.White),
			piece("ErrorLineS", "Block", v(1.2, 0.12, 0.1), v(-0.3, 1.65, -0.53), C.Cyan),
			piece("WingL", "Wedge", v(0.4, 2.6, 2), v(-2.2, 2.6, 0), C.Cyan, v(0, 90, -30)),
			piece("WingR", "Wedge", v(0.4, 2.6, 2), v(2.2, 2.6, 0), C.Cyan, v(0, -90, 30)),
			piece("HaloBack", "Block", v(2, 0.15, 0.15), v(0, 4.5, 0.45), C.Gold, nil, Enum.Material.Neon),
			piece("HaloFront", "Block", v(2, 0.15, 0.15), v(0, 4.5, -0.45), C.Gold, nil, Enum.Material.Neon),
			piece("HaloL", "Block", v(0.15, 0.15, 0.9), v(-1, 4.5, 0), C.Gold, nil, Enum.Material.Neon),
			piece("HaloR", "Block", v(0.15, 0.15, 0.9), v(1, 4.5, 0), C.Gold, nil, Enum.Material.Neon),
		},
	},
	ascended_shopping_cart = {
		Name = "Ascended Shopping Cart", Tier = "Divine",
		Recipe = "Open silver basket on four purple wheels, mint handle, gold wing fans and a floating crown.",
		Parts = {
			piece("BasketFloor", "Block", v(2, 0.18, 1.8), v(0, 1.4, 0), C.Steel),
			piece("BasketL", "Block", v(0.15, 1.5, 1.8), v(-1, 2.15, 0), C.Steel),
			piece("BasketR", "Block", v(0.15, 1.5, 1.8), v(1, 2.15, 0), C.Steel),
			piece("RimFront", "Block", v(2.1, 0.15, 0.15), v(0, 2.9, -0.9), C.Cyan),
			piece("BarL", "Block", v(0.15, 1.4, 0.15), v(-0.65, 2.15, -0.9), C.Steel),
			piece("BarR", "Block", v(0.15, 1.4, 0.15), v(0.65, 2.15, -0.9), C.Steel),
			piece("BarM", "Block", v(0.15, 1.4, 0.15), v(0, 2.15, -0.9), C.Steel),
			piece("HandleL", "Block", v(0.15, 2, 0.15), v(-1, 2.4, 1), C.Steel),
			piece("HandleR", "Block", v(0.15, 2, 0.15), v(1, 2.4, 1), C.Steel),
			piece("Handle", "Block", v(2.2, 0.3, 0.3), v(0, 3.4, 1), C.Cyan),
			piece("AxleL", "Block", v(0.2, 0.8, 1.8), v(-0.75, 0.9, 0), C.Steel),
			piece("AxleR", "Block", v(0.2, 0.8, 1.8), v(0.75, 0.9, 0), C.Steel),
			piece("WheelFL", "Ball", v(0.55, 0.65, 0.55), v(-0.8, 0.325, -0.65), C.Purple),
			piece("WheelFR", "Ball", v(0.55, 0.65, 0.55), v(0.8, 0.325, -0.65), C.Purple),
			piece("WheelBL", "Ball", v(0.55, 0.65, 0.55), v(-0.8, 0.325, 0.65), C.Purple),
			piece("WheelBR", "Ball", v(0.55, 0.65, 0.55), v(0.8, 0.325, 0.65), C.Purple),
			piece("WingL", "Wedge", v(0.4, 2.5, 2), v(-2, 2.8, 0), C.Gold, v(0, 90, -35)),
			piece("WingR", "Wedge", v(0.4, 2.5, 2), v(2, 2.8, 0), C.Gold, v(0, -90, 35)),
			piece("Crown", "Block", v(1.6, 0.3, 1), v(0, 4.1, 0), C.Gold, nil, Enum.Material.Neon),
			piece("CrownTip", "Wedge", v(0.6, 0.7, 0.7), v(0, 4.6, 0), C.Gold),
		},
	},
} :: {[string]: CharacterDefinition}

-- Freeze recursively so a future controller cannot accidentally edit the economy.
local function freezeTree(value: any)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do
			freezeTree(child)
		end
		table.freeze(value)
	end
end

freezeTree(Config)
return Config

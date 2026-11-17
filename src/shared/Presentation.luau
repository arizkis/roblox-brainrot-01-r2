--!strict
-- Display units and formatting only; no prices or gameplay authority live here.
local Presentation = {
	Width = 768, Height = 480,
	NameplateWidth = 360, NameplateHeight = 118, SaleNameplateHeight = 150,
	Colors = {
		Ink = Color3.fromRGB(23, 24, 46), Panel = Color3.fromRGB(35, 36, 63),
		White = Color3.fromRGB(255, 255, 250), Muted = Color3.fromRGB(204, 209, 231),
		Pink = Color3.fromRGB(255, 76, 159), Cyan = Color3.fromRGB(60, 233, 255),
		Lime = Color3.fromRGB(164, 249, 91), Gold = Color3.fromRGB(255, 211, 66),
		Disabled = Color3.fromRGB(76, 79, 98), Danger = Color3.fromRGB(219, 52, 85),
	},
}

function Presentation.Number(amount: number, compact: boolean?): string
	if compact then
		for _, unit in {{1e12, "T"}, {1e9, "B"}, {1e6, "M"}} do
			local divisor = unit[1] :: number
			if amount >= divisor then
				return string.format("%.2f", amount / divisor):gsub("0+$", ""):gsub("%.$", "") .. (unit[2] :: string)
			end
		end
	end
	local cents = math.floor(amount * 100 + 0.5)
	local digits = string.format("%.0f", math.floor(cents / 100))
	local grouped = string.reverse(digits):gsub("(%d%d%d)", "%1,")
	local clean = string.reverse(grouped):gsub("^,", "")
	local fraction = cents % 100
	if fraction ~= 0 then
		local suffix = string.format(".%02d", fraction):gsub("0$", "")
		clean ..= suffix
	end
	return clean
end

function Presentation.Money(amount: number, compact: boolean?): string
	return "$" .. Presentation.Number(amount, compact)
end

function Presentation.Multiplier(amount: number): string
	local text = string.format("%.3f", amount):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. text
end

table.freeze(Presentation.Colors)
return table.freeze(Presentation)

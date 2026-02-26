EasyPrescienceDB = EasyPrescienceDB or {}

local ADDON = "EasyPrescience"
local DEFAULT_MACRO_NAME = "PrescienceName"

local function Msg(...)
	print("|cff55ff55" .. ADDON .. ":|r", ...)
end

local function Err(...)
	print("|cffff5555" .. ADDON .. ":|r", ...)
end

local function NormalizeName(full)
	if not full or full == "" then return nil end
	return (full:gsub("%s+", ""))
end

local function FullUnitName(unit)
	if not unit or not UnitExists(unit) then return nil end
	return NormalizeName(GetUnitName(unit, true))
end

local function EnsureDB()
	EasyPrescienceDB.macroName = EasyPrescienceDB.macroName or DEFAULT_MACRO_NAME
	EasyPrescienceDB.modKey = (EasyPrescienceDB.modKey or "ALT"):upper()
	EasyPrescienceDB.invert = EasyPrescienceDB.invert or false
end

local function MacroIndexByName(name)
	local idx = GetMacroIndexByName(name)
	if not idx or idx == 0 then return nil end
	return idx
end

local function BuildMacroBody()
	local main = EasyPrescienceDB.main
	local alt = EasyPrescienceDB.alt
	local mod = (EasyPrescienceDB.modKey or "ALT"):upper()
	local invert = EasyPrescienceDB.invert and true or false

	if not main or main == "" then main = "NAME_MAIN" end
	if not alt or alt == "" then alt = "NAME_ALT" end

	local mainAt = "@" .. main
	local altAt  = "@" .. alt

	local first, second
	if invert then
		first, second = mainAt, altAt
	else
		first, second = altAt, mainAt
	end

	return table.concat({
		"#showtooltip Prescience",
		"/cast [mod:" .. mod:lower() .. "," .. first .. ",help,nodead][" .. second .. ",help,nodead] Prescience",
	}, "\n")
end

local function EnsureMacroExists()
	EnsureDB()

	local name = EasyPrescienceDB.macroName
	local idx = MacroIndexByName(name)
	if idx then return idx end

	if InCombatLockdown() then
		Err("Can't create macros in combat.")
		return nil
	end

	local numGlobal, numPerChar = GetNumMacros()
	local maxGlobal = MAX_ACCOUNT_MACROS or 120
	local maxPerChar = MAX_CHARACTER_MACROS or 18

	local canGlobal = numGlobal < maxGlobal
	local canPerChar = numPerChar < maxPerChar

	if not canPerChar and not canGlobal then
		Err("No macro slots available (global and character are full).")
		return nil
	end

	local perChar = (canPerChar and 1) or 0
	if not canPerChar and canGlobal then perChar = 0 end

	local icon = 134400
	local body = BuildMacroBody()

	local newIdx = CreateMacro(name, icon, body, perChar)
	if not newIdx or newIdx == 0 then
		Err("Failed to create macro:", name)
		return nil
	end

	Msg("Created macro:", name)
	return newIdx
end

local function UpdateMacro()
	EnsureDB()

	if InCombatLockdown() then
		Err("Can't edit macros in combat.")
		return
	end

	local idx = EnsureMacroExists()
	if not idx then return end

	local body = BuildMacroBody()
	local _, _, current = GetMacroInfo(idx)
	if current ~= body then
		EditMacro(idx, nil, nil, body)
		Msg("Macro updated:", EasyPrescienceDB.macroName)
	end
end

local function SetTargetFromUnit(unit, which)
	local n = FullUnitName(unit)
	if not n then return end
	EasyPrescienceDB[which] = n
	UpdateMacro()
	Msg(which:upper(), "=", n)
end

local function GetContextUnit(contextData)
	if type(contextData) ~= "table" then return nil end
	return contextData.unit or contextData.unitToken or contextData.unitID
end

local function ResolveUnit(ownerRegion, contextData)
	local unit = GetContextUnit(contextData)
	if unit and UnitExists(unit) then return unit end

	if ownerRegion and ownerRegion.GetAttribute then
		unit = ownerRegion:GetAttribute("unit")
		if unit and UnitExists(unit) then return unit end
	end

	if ownerRegion and ownerRegion.GetParent then
		local p = ownerRegion:GetParent()
		if p and p.GetAttribute then
			unit = p:GetAttribute("unit")
			if unit and UnitExists(unit) then return unit end
		end
	end

	return nil
end

local function InjectMenu(ownerRegion, rootDescription, contextData)
	local unit = ResolveUnit(ownerRegion, contextData)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end

	rootDescription:CreateDivider()
	rootDescription:CreateTitle("EasyPrescience")
	rootDescription:CreateButton("Set Prescience (Main)", function() SetTargetFromUnit(unit, "main") end)
	rootDescription:CreateButton("Set Prescience (Alt)", function() SetTargetFromUnit(unit, "alt") end)
end

local function HookMenus()
	if not Menu or not Menu.ModifyMenu then
		Err("Menu API not found.")
		return
	end

	local done = {}

	local function try(key)
		if done[key] then return end
		done[key] = true
		pcall(Menu.ModifyMenu, key, InjectMenu)
	end

	local keys = {
		"MENU_UNIT_SELF",
		"MENU_UNIT_PLAYER",
		"MENU_UNIT_TARGET",
		"MENU_UNIT_TARGET_PLAYER",
		"MENU_UNIT_FOCUS",
		"MENU_UNIT_NAMEPLATE",
		"MENU_UNIT_PARTY",
		"MENU_UNIT_PARTY_MEMBER",
		"MENU_UNIT_RAID",
		"MENU_UNIT_RAID_MEMBER",
		"MENU_UNIT_RAID_PLAYER",
		"MENU_UNIT_FRIEND",
		"MENU_UNIT_ENEMY_PLAYER",
		"MENU_UNIT_PET",
		"MENU_UNIT_ARENAENEMY",
		"MENU_UNIT_BN_FRIEND",
		"MENU_UNIT_GUILD",
	}

	for _, k in ipairs(keys) do
		try(k)
	end

	if type(UnitPopupMenus) == "table" then
		for k in pairs(UnitPopupMenus) do
			if type(k) == "string" and k:match("^MENU_UNIT_") then
				try(k)
			end
		end
	end
	if type(UnitPopupButtons) == "table" then
		for k in pairs(UnitPopupButtons) do
			if type(k) == "string" and k:match("^MENU_UNIT_") then
				try(k)
			end
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event)
	EnsureDB()
	if event == "PLAYER_LOGIN" then
		HookMenus()
		EnsureMacroExists()
	end
end)

SLASH_EASYPRESCIENCE1 = "/ep"
SlashCmdList.EASYPRESCIENCE = function(msg)
	EnsureDB()
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local a, b = msg:match("^(%S+)%s*(.*)$")
	a = a and a:lower() or ""

	if a == "" then
		Msg("macro =", EasyPrescienceDB.macroName, "| mod =", EasyPrescienceDB.modKey, "| invert =", EasyPrescienceDB.invert and "on" or "off")
		Msg("main  =", EasyPrescienceDB.main or "")
		Msg("alt   =", EasyPrescienceDB.alt or "")
		Msg("Commands:")
		Msg("/ep macro <name>")
		Msg("/ep mod <alt|ctrl|shift>")
		Msg("/ep invert <on|off>")
		Msg("/ep update")
		return
	end

	if a == "macro" and b ~= "" then
		EasyPrescienceDB.macroName = b
		EnsureMacroExists()
		UpdateMacro()
		Msg("macro =", b)
		return
	end

	if a == "mod" and b ~= "" then
		local v = b:upper()
		if v == "ALT" or v == "CTRL" or v == "SHIFT" then
			EasyPrescienceDB.modKey = v
			UpdateMacro()
			Msg("mod =", v)
		else
			Err("Invalid mod. Use: alt, ctrl, or shift.")
		end
		return
	end

	if a == "invert" and b ~= "" then
		local v = b:lower()
		if v == "on" or v == "1" or v == "true" then
			EasyPrescienceDB.invert = true
			UpdateMacro()
			Msg("invert = on (modifier casts MAIN)")
		elseif v == "off" or v == "0" or v == "false" then
			EasyPrescienceDB.invert = false
			UpdateMacro()
			Msg("invert = off (modifier casts ALT)")
		else
			Err("Use: /ep invert on|off")
		end
		return
	end

	if a == "update" then
		UpdateMacro()
		return
	end

	Err("Unknown command. Type /ep for help.")
end
EasyPrescienceDB = EasyPrescienceDB or {}

local ADDON = "EasyPrescience"
local DEFAULT_MACRO_NAME = "PrescienceName"
local MODIFIER_KEYS = { "SHIFT", "ALT", "CTRL" }
local DISPLAY_KEYS = {
	SHIFT = "Shift",
	ALT = "Alt",
	CTRL = "Ctrl",
}
local HOOK_MENU_KEYS = {
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

local hookedMenus = {}

local function Msg(...)
	print("|cff55ff55" .. ADDON .. ":|r", ...)
end

local function Err(...)
	print("|cffff5555" .. ADDON .. ":|r", ...)
end

local function NormalizeName(full)
	if not full or full == "" then return nil end
	full = full:gsub("%s+", "")
	if full == "" then return nil end
	return full
end

local function IsModifierKey(value)
	return value == "SHIFT" or value == "ALT" or value == "CTRL"
end

local function FullUnitName(unit)
	if not unit or not UnitExists(unit) then return nil end
	return NormalizeName(GetUnitName(unit, true))
end

local function EnsureTargetsTable()
	if type(EasyPrescienceDB.targets) ~= "table" then
		EasyPrescienceDB.targets = {}
	end

	for _, key in ipairs(MODIFIER_KEYS) do
		local value = EasyPrescienceDB.targets[key]
		EasyPrescienceDB.targets[key] = NormalizeName(value)
	end
end

local function MigrateLegacyData()
	if EasyPrescienceDB.schemaVersion == 2 then return end

	EnsureTargetsTable()

	local legacyKey = type(EasyPrescienceDB.modKey) == "string" and EasyPrescienceDB.modKey:upper() or "ALT"
	if IsModifierKey(legacyKey) and not EasyPrescienceDB.targets[legacyKey] then
		local legacyTarget = EasyPrescienceDB.invert and EasyPrescienceDB.main or EasyPrescienceDB.alt
		legacyTarget = NormalizeName(legacyTarget)
		if legacyTarget then
			EasyPrescienceDB.targets[legacyKey] = legacyTarget
		end
	end

	EasyPrescienceDB.main = nil
	EasyPrescienceDB.alt = nil
	EasyPrescienceDB.modKey = nil
	EasyPrescienceDB.invert = nil
	EasyPrescienceDB.schemaVersion = 2
end

local function EnsureDB()
	EasyPrescienceDB.macroName = EasyPrescienceDB.macroName or DEFAULT_MACRO_NAME
	EnsureTargetsTable()
	MigrateLegacyData()
end

local function MacroIndexByName(name)
	local idx = GetMacroIndexByName(name)
	if not idx or idx == 0 then return nil end
	return idx
end

local function BuildMacroBody()
	local conditions = {}

	for _, key in ipairs(MODIFIER_KEYS) do
		local targetName = NormalizeName(EasyPrescienceDB.targets[key])
		if targetName then
			conditions[#conditions + 1] = "[mod:" .. key:lower() .. ",@" .. targetName .. ",help,nodead]"
		end
	end

	conditions[#conditions + 1] = "[]"

	return table.concat({
		"#showtooltip Prescience",
		"/cast " .. table.concat(conditions, "") .. " Prescience",
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

	local perChar = canPerChar and 1 or 0
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

local function SetModifierTarget(modifierKey, fullName)
	modifierKey = type(modifierKey) == "string" and modifierKey:upper() or nil
	if not IsModifierKey(modifierKey) then return end

	fullName = NormalizeName(fullName)
	if not fullName then return end

	EnsureDB()
	EasyPrescienceDB.targets[modifierKey] = fullName
	UpdateMacro()
	Msg(DISPLAY_KEYS[modifierKey] .. " =", fullName)
end

local function ClearModifierTarget(modifierKey)
	modifierKey = type(modifierKey) == "string" and modifierKey:upper() or nil
	if not IsModifierKey(modifierKey) then return end

	EnsureDB()
	EasyPrescienceDB.targets[modifierKey] = nil
	UpdateMacro()
	Msg(DISPLAY_KEYS[modifierKey] .. " cleared")
end

local function GetContextUnit(contextData)
	if type(contextData) ~= "table" then return nil end
	return contextData.unit or contextData.unitToken or contextData.unitID
end

local function GetContextName(contextData)
	if type(contextData) ~= "table" then return nil end
	return NormalizeName(contextData.fullName or contextData.name or contextData.unitName)
end

local function ResolveUnit(ownerRegion, contextData)
	local unit = GetContextUnit(contextData)
	if unit and UnitExists(unit) then return unit end

	if ownerRegion and ownerRegion.GetAttribute then
		unit = ownerRegion:GetAttribute("unit")
		if unit and UnitExists(unit) then return unit end
	end

	if ownerRegion and ownerRegion.GetParent then
		local parent = ownerRegion:GetParent()
		if parent and parent.GetAttribute then
			unit = parent:GetAttribute("unit")
			if unit and UnitExists(unit) then return unit end
		end
	end

	return nil
end

local function ResolveTargetName(ownerRegion, contextData)
	local unit = ResolveUnit(ownerRegion, contextData)
	local fullName = FullUnitName(unit)
	if fullName then return fullName end
	return GetContextName(contextData)
end

local function InjectMenu(ownerRegion, rootDescription, contextData)
	local targetName = ResolveTargetName(ownerRegion, contextData)
	if not targetName then return end

	rootDescription:CreateDivider()
	rootDescription:CreateTitle("EasyPrescience")

	for _, key in ipairs(MODIFIER_KEYS) do
		local modifierKey = key
		rootDescription:CreateButton("Set on " .. DISPLAY_KEYS[modifierKey], function()
			SetModifierTarget(modifierKey, targetName)
		end)
	end
end

local function TryHookMenu(key)
	if hookedMenus[key] then return end
	if not Menu or not Menu.ModifyMenu then return end
	local ok = pcall(Menu.ModifyMenu, key, InjectMenu)
	if ok then
		hookedMenus[key] = true
	end
end

local function HookMenus()
	if not Menu or not Menu.ModifyMenu then
		Err("Menu API not found.")
		return
	end

	for _, key in ipairs(HOOK_MENU_KEYS) do
		TryHookMenu(key)
	end

	if type(UnitPopupMenus) == "table" then
		for key in pairs(UnitPopupMenus) do
			if type(key) == "string" and key:match("^MENU_UNIT_") then
				TryHookMenu(key)
			end
		end
	end

	if type(UnitPopupButtons) == "table" then
		for key in pairs(UnitPopupButtons) do
			if type(key) == "string" and key:match("^MENU_UNIT_") then
				TryHookMenu(key)
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event)
	EnsureDB()

	if event == "PLAYER_LOGIN" then
		HookMenus()
		UpdateMacro()
		return
	end

	if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
		HookMenus()
	end
end)

SLASH_EASYPRESCIENCE1 = "/ep"
SlashCmdList.EASYPRESCIENCE = function(msg)
	EnsureDB()
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local command, rest = msg:match("^(%S+)%s*(.*)$")
	command = command and command:lower() or ""

	if command == "" then
		Msg("macro =", EasyPrescienceDB.macroName)
		for _, key in ipairs(MODIFIER_KEYS) do
			Msg(DISPLAY_KEYS[key] .. " =", EasyPrescienceDB.targets[key] or "")
		end
		Msg("Commands:")
		Msg("/ep macro <name>")
		Msg("/ep set <shift|alt|ctrl> <player[-realm]>")
		Msg("/ep clear <shift|alt|ctrl>")
		Msg("/ep update")
		return
	end

	if command == "macro" and rest ~= "" then
		EasyPrescienceDB.macroName = rest
		UpdateMacro()
		Msg("macro =", rest)
		return
	end

	if command == "set" and rest ~= "" then
		local key, name = rest:match("^(%S+)%s+(.+)$")
		key = key and key:upper() or nil
		if not IsModifierKey(key) then
			Err("Invalid modifier. Use: shift, alt, or ctrl.")
			return
		end
		if not NormalizeName(name) then
			Err("Missing player name.")
			return
		end
		SetModifierTarget(key, name)
		return
	end

	if command == "clear" and rest ~= "" then
		local key = rest:upper()
		if not IsModifierKey(key) then
			Err("Invalid modifier. Use: shift, alt, or ctrl.")
			return
		end
		ClearModifierTarget(key)
		return
	end

	if command == "update" then
		UpdateMacro()
		return
	end

	if command == "mod" or command == "invert" then
		Err("Legacy command removed. Use /ep set <shift|alt|ctrl> <player[-realm]> instead.")
		return
	end

	Err("Unknown command. Type /ep for help.")
end

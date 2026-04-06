EasyPrescienceDB = EasyPrescienceDB or {}

local ADDON = "EasyPrescience"
local MAX_MACRO_NAME_LENGTH = 16
local DEFAULT_MACRO_NAME = "PrescienceName"
local DEFAULT_BLISTERING_SCALES_MACRO_NAME = "BlisteringScales"
local DEFAULT_RESCUE_MACRO_NAME = "RescueTarget"
local DEFAULT_SPATIAL_PARADOX_MACRO_NAME = "SpatialParadox"
local DEFAULT_VERDANT_EMBRACE_MACRO_NAME = "VerdantEmbrace"
local SPATIAL_PARADOX_SPELL_NAME = "Spatial Paradox"
local TIME_SPIRAL_SPELL_NAME = "Time Spiral"
local VERDANT_EMBRACE_SPELL_NAME = "Verdant Embrace"
local MODIFIER_KEYS = { "SHIFT", "ALT", "CTRL" }
local PRESCIENCE_ASSIGNMENT_KEYS = { "NOMOD", "SHIFT", "ALT", "CTRL" }
local DISPLAY_KEYS = {
	NOMOD = "No Mod",
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
local MACRO_DEFAULTS = {
	macroName = DEFAULT_MACRO_NAME,
	blisteringScalesMacroName = DEFAULT_BLISTERING_SCALES_MACRO_NAME,
	rescueMacroName = DEFAULT_RESCUE_MACRO_NAME,
	spatialParadoxMacroName = DEFAULT_SPATIAL_PARADOX_MACRO_NAME,
	verdantEmbraceMacroName = DEFAULT_VERDANT_EMBRACE_MACRO_NAME,
}

local hookedMenus = {}
local optionsRefreshers = {}
local optionsPanel
local optionsCategoryID
local managedMacros
local minimapButton
local RefreshOptions
local ApplyAutoAssignments
local OpenSettingsPanel
local RegisterOptionsPanel
local HandleSlashStatus

local function GetNonPrescienceModifierOptions()
	return {
		{ value = "SHIFT", label = "Shift" },
		{ value = "ALT", label = "Alt" },
		{ value = "CTRL", label = "Ctrl" },
	}
end

local function GetSpatialParadoxPreferredClassOptions()
	return {
		{ value = "PRIEST", label = "Priest" },
		{ value = "PALADIN", label = "Paladin" },
		{ value = "DRUID", label = "Druid" },
		{ value = "SHAMAN", label = "Shaman" },
		{ value = "MONK", label = "Monk" },
		{ value = "EVOKER", label = "Evoker" },
		{ value = "ANY", label = "Any healer" },
	}
end

local function Msg(...)
	print("|cff55ff55" .. ADDON .. ":|r", ...)
end

local function Err(...)
	print("|cffff5555" .. ADDON .. ":|r", ...)
end

local function Trim(value)
	if type(value) ~= "string" then return nil end
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" then return nil end
	return value
end

local function NormalizeName(full)
	full = Trim(full)
	if not full then return nil end
	full = full:gsub("%s+", "")
	if full == "" then return nil end
	return full
end

local function NormalizeAssignmentUnit(value)
	value = Trim(value)
	if not value then return nil end

	value = value:lower()
	if value == "player" then
		return value
	end

	if value:match("^party%d+$") or value:match("^raid%d+$") then
		return value
	end

	return nil
end

local function NormalizeMacroName(name, fallback)
	name = Trim(name) or fallback
	if not name then return nil end
	if #name > MAX_MACRO_NAME_LENGTH then
		name = name:sub(1, MAX_MACRO_NAME_LENGTH)
	end
	return name
end

local function IsModifierKey(value)
	return value == "SHIFT" or value == "ALT" or value == "CTRL"
end

local function IsPrescienceAssignmentKey(value)
	return value == "NOMOD" or IsModifierKey(value)
end

local function FullUnitName(unit)
	if not unit or not UnitExists(unit) then return nil end
	return NormalizeName(GetUnitName(unit, true))
end

local function BuildAssignmentData(unit)
	local unitToken = NormalizeAssignmentUnit(unit)
	if not unitToken or not UnitExists(unitToken) then return nil end

	return {
		unit = unitToken,
		guid = UnitGUID(unitToken),
		name = FullUnitName(unitToken),
	}
end

local function NormalizeStoredAssignment(value)
	if type(value) == "table" then
		local unitToken = NormalizeAssignmentUnit(value.unit)
		local guid = type(value.guid) == "string" and value.guid or nil
		local name = NormalizeName(value.name)
		if not unitToken and not guid and not name then
			return nil
		end
		return {
			unit = unitToken,
			guid = guid,
			name = name,
		}
	end

	local unitToken = NormalizeAssignmentUnit(value)
	if unitToken then
		return {
			unit = unitToken,
			guid = UnitExists(unitToken) and UnitGUID(unitToken) or nil,
			name = FullUnitName(unitToken),
		}
	end

	local name = NormalizeName(value)
	if name then
		return { name = name }
	end
end

local function GetAssignmentUnit(value)
	local assignment = NormalizeStoredAssignment(value)
	return assignment and NormalizeAssignmentUnit(assignment.unit) or nil
end

local function GetAssignmentDisplayValue(value)
	local assignment = NormalizeStoredAssignment(value)
	if not assignment then return "" end

	local unitToken = NormalizeAssignmentUnit(assignment.unit)
	if not unitToken then
		return assignment.name or ""
	end

	local fullName = FullUnitName(unitToken)
	if fullName then
		return fullName .. " (" .. unitToken .. ")"
	end

	return (assignment.name or unitToken) .. " (" .. unitToken .. ")"
end

local function GetStatusValue(value)
	value = Trim(value)
	return value or "Not set"
end

local function GetClassDisplayName(classToken)
	for _, option in ipairs(GetSpatialParadoxPreferredClassOptions()) do
		if option.value == classToken then
			return option.label
		end
	end
	return classToken or "Any healer"
end

local function EnsureTargetsTable()
	if type(EasyPrescienceDB.targets) ~= "table" then
		EasyPrescienceDB.targets = {}
	end

	for _, key in ipairs(PRESCIENCE_ASSIGNMENT_KEYS) do
		EasyPrescienceDB.targets[key] = NormalizeStoredAssignment(EasyPrescienceDB.targets[key])
	end
end

local function ResolveGroupUnitToken(unit)
	if not unit or not UnitExists(unit) then return nil end
	if UnitIsUnit(unit, "player") then
		return "player"
	end

	if IsInRaid() then
		for index = 1, 40 do
			local raidUnit = "raid" .. index
			if UnitExists(raidUnit) and UnitIsUnit(unit, raidUnit) then
				return raidUnit
			end
		end
	elseif IsInGroup() then
		for index = 1, 4 do
			local partyUnit = "party" .. index
			if UnitExists(partyUnit) and UnitIsUnit(unit, partyUnit) then
				return partyUnit
			end
		end
	end

	return nil
end

local function ResolveAssignmentUnitByName(fullName)
	fullName = NormalizeName(fullName)
	if not fullName then return nil end

	local playerName = FullUnitName("player")
	if playerName and playerName == fullName then
		return "player"
	end

	if IsInRaid() then
		for index = 1, 40 do
			local raidUnit = "raid" .. index
			if FullUnitName(raidUnit) == fullName then
				return raidUnit
			end
		end
	elseif IsInGroup() then
		for index = 1, 4 do
			local partyUnit = "party" .. index
			if FullUnitName(partyUnit) == fullName then
				return partyUnit
			end
		end
	end

	return nil
end

local function FindGroupUnitByGUID(guid)
	if type(guid) ~= "string" or guid == "" then return nil end

	if UnitExists("player") and UnitGUID("player") == guid then
		return "player"
	end

	if IsInRaid() then
		for index = 1, 40 do
			local raidUnit = "raid" .. index
			if UnitExists(raidUnit) and UnitGUID(raidUnit) == guid then
				return raidUnit
			end
		end
	elseif IsInGroup() then
		for index = 1, 4 do
			local partyUnit = "party" .. index
			if UnitExists(partyUnit) and UnitGUID(partyUnit) == guid then
				return partyUnit
			end
		end
	end

	return nil
end

local function ResolveAssignmentDataByName(fullName)
	local unitToken = ResolveAssignmentUnitByName(fullName)
	if not unitToken then return nil end
	return BuildAssignmentData(unitToken)
end

local function MigrateLegacyData()
	if EasyPrescienceDB.schemaVersion == 8 then return end

	local legacyTargets = type(EasyPrescienceDB.targets) == "table" and EasyPrescienceDB.targets or nil
	EnsureTargetsTable()

	if legacyTargets then
		for _, key in ipairs(PRESCIENCE_ASSIGNMENT_KEYS) do
			if not EasyPrescienceDB.targets[key] then
				EasyPrescienceDB.targets[key] = NormalizeStoredAssignment(legacyTargets[key]) or ResolveAssignmentDataByName(legacyTargets[key])
			end
		end
	end

	local legacyKey = type(EasyPrescienceDB.modKey) == "string" and EasyPrescienceDB.modKey:upper() or "ALT"
	if IsModifierKey(legacyKey) and not EasyPrescienceDB.targets[legacyKey] then
		local legacyTarget = EasyPrescienceDB.invert and EasyPrescienceDB.main or EasyPrescienceDB.alt
		legacyTarget = ResolveAssignmentDataByName(legacyTarget)
		if legacyTarget then
			EasyPrescienceDB.targets[legacyKey] = legacyTarget
		end
	end

	EasyPrescienceDB.main = nil
	EasyPrescienceDB.alt = nil
	EasyPrescienceDB.modKey = nil
	EasyPrescienceDB.invert = nil
	EasyPrescienceDB.blisteringScalesTarget = NormalizeStoredAssignment(EasyPrescienceDB.blisteringScalesTarget) or ResolveAssignmentDataByName(EasyPrescienceDB.blisteringScalesTarget)
	EasyPrescienceDB.rescueTarget = NormalizeStoredAssignment(EasyPrescienceDB.rescueTarget) or ResolveAssignmentDataByName(EasyPrescienceDB.rescueTarget)
	EasyPrescienceDB.spatialParadoxTarget = NormalizeStoredAssignment(EasyPrescienceDB.spatialParadoxTarget) or ResolveAssignmentDataByName(EasyPrescienceDB.spatialParadoxTarget)
	EasyPrescienceDB.verdantEmbraceTarget = NormalizeStoredAssignment(EasyPrescienceDB.verdantEmbraceTarget) or ResolveAssignmentDataByName(EasyPrescienceDB.verdantEmbraceTarget)
	EasyPrescienceDB.blisteringScalesModifier = IsModifierKey(EasyPrescienceDB.blisteringScalesModifier) and EasyPrescienceDB.blisteringScalesModifier or "ALT"
	EasyPrescienceDB.rescueModifier = IsModifierKey(EasyPrescienceDB.rescueModifier) and EasyPrescienceDB.rescueModifier or "ALT"
	EasyPrescienceDB.spatialParadoxModifier = IsModifierKey(EasyPrescienceDB.spatialParadoxModifier) and EasyPrescienceDB.spatialParadoxModifier or "ALT"
	EasyPrescienceDB.verdantEmbraceModifier = IsModifierKey(EasyPrescienceDB.verdantEmbraceModifier) and EasyPrescienceDB.verdantEmbraceModifier or "ALT"
	EasyPrescienceDB.schemaVersion = 8
end

local function EnsureDB()
	EasyPrescienceDB.macroName = NormalizeMacroName(EasyPrescienceDB.macroName, DEFAULT_MACRO_NAME)
	EasyPrescienceDB.blisteringScalesMacroName = NormalizeMacroName(EasyPrescienceDB.blisteringScalesMacroName, DEFAULT_BLISTERING_SCALES_MACRO_NAME)
	EasyPrescienceDB.rescueMacroName = NormalizeMacroName(EasyPrescienceDB.rescueMacroName, DEFAULT_RESCUE_MACRO_NAME)
	EasyPrescienceDB.spatialParadoxMacroName = NormalizeMacroName(EasyPrescienceDB.spatialParadoxMacroName, DEFAULT_SPATIAL_PARADOX_MACRO_NAME)
	EasyPrescienceDB.verdantEmbraceMacroName = NormalizeMacroName(EasyPrescienceDB.verdantEmbraceMacroName, DEFAULT_VERDANT_EMBRACE_MACRO_NAME)
	MigrateLegacyData()
	EnsureTargetsTable()
	EasyPrescienceDB.blisteringScalesTarget = NormalizeStoredAssignment(EasyPrescienceDB.blisteringScalesTarget)
	EasyPrescienceDB.rescueTarget = NormalizeStoredAssignment(EasyPrescienceDB.rescueTarget)
	EasyPrescienceDB.spatialParadoxTarget = NormalizeStoredAssignment(EasyPrescienceDB.spatialParadoxTarget)
	EasyPrescienceDB.verdantEmbraceTarget = NormalizeStoredAssignment(EasyPrescienceDB.verdantEmbraceTarget)
	EasyPrescienceDB.prescienceNoModEnabled = EasyPrescienceDB.prescienceNoModEnabled == true
	EasyPrescienceDB.blisteringScalesModifier = IsModifierKey(EasyPrescienceDB.blisteringScalesModifier) and EasyPrescienceDB.blisteringScalesModifier or "ALT"
	EasyPrescienceDB.rescueModifier = IsModifierKey(EasyPrescienceDB.rescueModifier) and EasyPrescienceDB.rescueModifier or "ALT"
	EasyPrescienceDB.spatialParadoxModifier = IsModifierKey(EasyPrescienceDB.spatialParadoxModifier) and EasyPrescienceDB.spatialParadoxModifier or "ALT"
	EasyPrescienceDB.verdantEmbraceModifier = IsModifierKey(EasyPrescienceDB.verdantEmbraceModifier) and EasyPrescienceDB.verdantEmbraceModifier or "ALT"
	EasyPrescienceDB.useAutoAssign = EasyPrescienceDB.useAutoAssign == true
	EasyPrescienceDB.autoAssignPrescience = EasyPrescienceDB.autoAssignPrescience ~= false
	EasyPrescienceDB.autoAssignBlisteringScales = EasyPrescienceDB.autoAssignBlisteringScales ~= false
	EasyPrescienceDB.autoAssignRescue = EasyPrescienceDB.autoAssignRescue ~= false
	EasyPrescienceDB.autoAssignSpatialParadox = EasyPrescienceDB.autoAssignSpatialParadox ~= false
	EasyPrescienceDB.announceSelectionsInChat = EasyPrescienceDB.announceSelectionsInChat == true
	local preferredClass = type(EasyPrescienceDB.spatialParadoxPreferredClass) == "string" and EasyPrescienceDB.spatialParadoxPreferredClass:upper() or "PRIEST"
	EasyPrescienceDB.spatialParadoxPreferredClass = preferredClass
	if type(EasyPrescienceDB.minimap) ~= "table" then
		EasyPrescienceDB.minimap = {}
	end
	if type(EasyPrescienceDB.minimap.angle) ~= "number" then
		EasyPrescienceDB.minimap.angle = 225
	end
	if EasyPrescienceDB.minimap.hide == nil then
		EasyPrescienceDB.minimap.hide = false
	end
end

local function MacroIndexByName(name)
	local idx = GetMacroIndexByName(name)
	if not idx or idx == 0 then return nil end
	return idx
end

local function BuildPrescienceMacroBody()
	local conditions = {}

	if EasyPrescienceDB.prescienceNoModEnabled then
		local noModUnit = GetAssignmentUnit(EasyPrescienceDB.targets.NOMOD)
		if noModUnit then
			conditions[#conditions + 1] = "[nomod,@" .. noModUnit .. ",help,nodead]"
		end
	end

	for _, key in ipairs(MODIFIER_KEYS) do
		local unitToken = GetAssignmentUnit(EasyPrescienceDB.targets[key])
		if unitToken then
			conditions[#conditions + 1] = "[mod:" .. key:lower() .. ",@" .. unitToken .. ",help,nodead]"
		end
	end

	conditions[#conditions + 1] = "[@mouseover,help,nodead]"
	conditions[#conditions + 1] = "[]"

	return table.concat({
		"#showtooltip Prescience",
		"/cast " .. table.concat(conditions, "") .. " Prescience",
	}, "\n")
end

local function BuildDirectTargetMacroBody(spellName, targetName)
	local normalizedTarget = GetAssignmentUnit(targetName)
	local conditions = {}
	if normalizedTarget then
		conditions[#conditions + 1] = "[@" .. normalizedTarget .. ",help,nodead]"
	end
	conditions[#conditions + 1] = "[@mouseover,help,nodead]"
	conditions[#conditions + 1] = "[]"

	return table.concat({
		"#showtooltip " .. spellName,
		"/cast " .. table.concat(conditions, "") .. " " .. spellName,
	}, "\n")
end

local function BuildSingleModifierTargetMacroBody(spellName, modifierKey, targetName)
	local normalizedTarget = GetAssignmentUnit(targetName)
	local normalizedModifier = IsModifierKey(modifierKey) and modifierKey:lower() or "alt"
	local conditions = {}
	if normalizedTarget then
		conditions[#conditions + 1] = "[mod:" .. normalizedModifier .. ",@" .. normalizedTarget .. ",help,nodead]"
	end
	conditions[#conditions + 1] = "[mod:" .. normalizedModifier .. "]"
	conditions[#conditions + 1] = "[nomod,@mouseover,help,nodead]"
	conditions[#conditions + 1] = "[nomod]"

	return table.concat({
		"#showtooltip " .. spellName,
		"/cast " .. table.concat(conditions, "") .. " " .. spellName,
	}, "\n")
end

local function GetSpellIDByName(spellName)
	local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellName)
	if type(info) == "table" and type(info.spellID) == "number" then
		return info.spellID
	end

	local legacySpellID = GetSpellInfo and select(7, GetSpellInfo(spellName))
	if type(legacySpellID) == "number" then
		return legacySpellID
	end

	return nil
end

local function IsSpellAvailable(spellName)
	local spellID = GetSpellIDByName(spellName)
	if not spellID then return false end
	if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
	if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then return true end
	return false
end

local function GetSpatialParadoxMacroSpellName()
	if IsSpellAvailable(SPATIAL_PARADOX_SPELL_NAME) then
		return SPATIAL_PARADOX_SPELL_NAME
	end
	if IsSpellAvailable(TIME_SPIRAL_SPELL_NAME) then
		return TIME_SPIRAL_SPELL_NAME
	end
	return SPATIAL_PARADOX_SPELL_NAME
end

local function BuildBlisteringScalesMacroBody()
	return BuildDirectTargetMacroBody("Blistering Scales", EasyPrescienceDB.blisteringScalesTarget)
end

local function BuildRescueMacroBody()
	return BuildSingleModifierTargetMacroBody("Rescue", EasyPrescienceDB.rescueModifier, EasyPrescienceDB.rescueTarget)
end

local function BuildSpatialParadoxMacroBody()
	return BuildSingleModifierTargetMacroBody(GetSpatialParadoxMacroSpellName(), EasyPrescienceDB.spatialParadoxModifier, EasyPrescienceDB.spatialParadoxTarget)
end

local function BuildVerdantEmbraceMacroBody()
	local normalizedTarget = GetAssignmentUnit(EasyPrescienceDB.verdantEmbraceTarget)
	local normalizedModifier = IsModifierKey(EasyPrescienceDB.verdantEmbraceModifier) and EasyPrescienceDB.verdantEmbraceModifier:lower() or "alt"
	local conditions = {}
	if normalizedTarget then
		conditions[#conditions + 1] = "[mod:" .. normalizedModifier .. ",@" .. normalizedTarget .. ",help,nodead]"
	end
	conditions[#conditions + 1] = "[mod:" .. normalizedModifier .. "]"
	conditions[#conditions + 1] = "[nomod,@mouseover,help,nodead]"
	conditions[#conditions + 1] = "[nomod,help,nodead]"
	conditions[#conditions + 1] = "[nomod,@player]"

	return table.concat({
		"#showtooltip " .. VERDANT_EMBRACE_SPELL_NAME,
		"/cast " .. table.concat(conditions, "") .. " " .. VERDANT_EMBRACE_SPELL_NAME,
	}, "\n")
end

local function GetManagedMacros()
	if managedMacros then return managedMacros end

	managedMacros = {
		{
			id = "prescience",
			label = "Prescience",
			macroField = "macroName",
			defaultMacroName = DEFAULT_MACRO_NAME,
			buildBody = BuildPrescienceMacroBody,
		},
		{
			id = "blistering",
			label = "Blistering Scales",
			macroField = "blisteringScalesMacroName",
			defaultMacroName = DEFAULT_BLISTERING_SCALES_MACRO_NAME,
			buildBody = BuildBlisteringScalesMacroBody,
		},
		{
			id = "rescue",
			label = "Rescue",
			macroField = "rescueMacroName",
			defaultMacroName = DEFAULT_RESCUE_MACRO_NAME,
			buildBody = BuildRescueMacroBody,
		},
		{
			id = "spatialParadox",
			label = "Spatial Paradox / Time Spiral",
			macroField = "spatialParadoxMacroName",
			defaultMacroName = DEFAULT_SPATIAL_PARADOX_MACRO_NAME,
			buildBody = BuildSpatialParadoxMacroBody,
		},
		{
			id = "verdantEmbrace",
			label = "Verdant Embrace",
			macroField = "verdantEmbraceMacroName",
			defaultMacroName = DEFAULT_VERDANT_EMBRACE_MACRO_NAME,
			buildBody = BuildVerdantEmbraceMacroBody,
		},
	}

	return managedMacros
end

local function GetManagedMacroSpecByID(id)
	for _, spec in ipairs(GetManagedMacros()) do
		if spec.id == id then
			return spec
		end
	end
end

local function EnsureMacroExists(name, body)
	local idx = MacroIndexByName(name)
	if idx then return idx end

	if InCombatLockdown() then
		Err("Can't create macros in combat.")
		return nil
	end

	local numGlobal, numPerChar = GetNumMacros()
	local maxGlobal = MAX_ACCOUNT_MACROS or 120
	local maxPerChar = MAX_CHARACTER_MACROS or 18

	if numGlobal >= maxGlobal and numPerChar >= maxPerChar then
		Err("No macro slots available (global and character are full).")
		return nil
	end

	local perChar = numPerChar < maxPerChar and 1 or 0
	local icon = 134400
	local newIdx = CreateMacro(name, icon, body, perChar)
	if not newIdx or newIdx == 0 then
		Err("Failed to create macro:", name)
		return nil
	end

	Msg("Created macro:", name)
	return newIdx
end

local function ReconcileMacro(spec, silent)
	local name = EasyPrescienceDB[spec.macroField]
	local body = spec.buildBody()
	local idx = EnsureMacroExists(name, body)
	if not idx then return end

	local _, _, current = GetMacroInfo(idx)
	if current ~= body then
		EditMacro(idx, nil, nil, body)
		if not silent then
			Msg("Macro updated:", name)
		end
	end
end

local function ReconcileManagedMacros(silent)
	EnsureDB()

	if InCombatLockdown() then
		Err("Can't review macros in combat.")
		return
	end

	for _, spec in ipairs(GetManagedMacros()) do
		ReconcileMacro(spec, silent)
	end
end

local function ReconcileManagedMacroByID(id, silent)
	local spec = GetManagedMacroSpecByID(id)
	if not spec then return end
	ReconcileMacro(spec, silent)
end

local function DeleteManagedMacros()
	EnsureDB()

	if InCombatLockdown() then
		Err("Can't delete macros in combat.")
		return
	end

	for _, spec in ipairs(GetManagedMacros()) do
		local name = EasyPrescienceDB[spec.macroField]
		local idx = MacroIndexByName(name)
		if idx then
			DeleteMacro(idx)
			Msg("Deleted macro:", name)
		end
	end
end

local function ClearAllAssignments(silent)
	EnsureDB()

	for _, key in ipairs(PRESCIENCE_ASSIGNMENT_KEYS) do
		EasyPrescienceDB.targets[key] = nil
	end

	for _, field in ipairs({ "blisteringScalesTarget", "rescueTarget", "spatialParadoxTarget", "verdantEmbraceTarget" }) do
		EasyPrescienceDB[field] = nil
	end

	ReconcileManagedMacros(true)
	RefreshOptions()

	if not silent then
		Msg("All assignments cleared.")
	end
end

function RefreshOptions()
	for _, refresh in ipairs(optionsRefreshers) do
		refresh()
	end
end

local function SetModifierTarget(modifierKey, assignment, silent)
	modifierKey = type(modifierKey) == "string" and modifierKey:upper() or nil
	if not IsPrescienceAssignmentKey(modifierKey) then return end

	EnsureDB()
	EasyPrescienceDB.targets[modifierKey] = NormalizeStoredAssignment(assignment)
	ReconcileManagedMacroByID("prescience", silent)
	RefreshOptions()

	if not silent then
		Msg(DISPLAY_KEYS[modifierKey] .. " =", GetAssignmentDisplayValue(EasyPrescienceDB.targets[modifierKey]))
	end
end

local function SetDirectTarget(field, value, macroID, label, silent)
	EnsureDB()
	EasyPrescienceDB[field] = NormalizeStoredAssignment(value)
	ReconcileManagedMacroByID(macroID, silent)
	RefreshOptions()

	if not silent then
		if EasyPrescienceDB[field] then
			Msg(label .. " =", GetAssignmentDisplayValue(EasyPrescienceDB[field]))
		else
			Msg(label .. " cleared")
		end
	end
end

local function SetSpellModifier(field, value, macroID, label, silent)
	if not IsModifierKey(value) then return end

	EnsureDB()
	EasyPrescienceDB[field] = value
	ReconcileManagedMacroByID(macroID, silent)
	RefreshOptions()

	if not silent then
		Msg(label .. " modifier =", DISPLAY_KEYS[value])
	end
end

local function SetMacroName(field, value, macroID, silent)
	local current = EasyPrescienceDB[field]
	local normalized = NormalizeMacroName(value, MACRO_DEFAULTS[field])
	if not normalized then return end

	EnsureDB()
	EasyPrescienceDB[field] = normalized
	ReconcileManagedMacroByID(macroID, silent)
	RefreshOptions()

	if not silent and current ~= normalized then
		Msg("Macro name set:", normalized)
	end
end

local function SetPrescienceNoModEnabled(enabled, silent)
	EnsureDB()
	EasyPrescienceDB.prescienceNoModEnabled = enabled == true
	ReconcileManagedMacros(true)
	RefreshOptions()

	if not silent then
		if EasyPrescienceDB.prescienceNoModEnabled then
			Msg("Prescience No Mod target enabled.")
		else
			Msg("Prescience No Mod target disabled.")
		end
	end
end

local function SetAutoAssignEnabled(enabled, silent)
	EnsureDB()
	EasyPrescienceDB.useAutoAssign = enabled == true
	if EasyPrescienceDB.useAutoAssign then
		ApplyAutoAssignments()
	else
		RefreshOptions()
	end

	if not silent then
		Msg("Use auto assign " .. (EasyPrescienceDB.useAutoAssign and "enabled." or "disabled."))
	end
end

local function SetAutoAssignUtilityEnabled(field, enabled, silent)
	local labels = {
		autoAssignPrescience = "Prescience",
		autoAssignBlisteringScales = "Blistering Scales",
		autoAssignRescue = "Rescue",
		autoAssignSpatialParadox = "Spatial Paradox",
	}
	EnsureDB()
	EasyPrescienceDB[field] = enabled == true
	if EasyPrescienceDB.useAutoAssign and EasyPrescienceDB[field] then
		ApplyAutoAssignments()
	else
		RefreshOptions()
	end

	if not silent then
		Msg((labels[field] or field) .. " auto assign " .. (EasyPrescienceDB[field] and "enabled." or "disabled."))
	end
end

local function SetAnnounceSelectionsInChat(enabled, silent)
	EnsureDB()
	EasyPrescienceDB.announceSelectionsInChat = enabled == true
	RefreshOptions()

	if not silent then
		Msg("Chat selection summary " .. (EasyPrescienceDB.announceSelectionsInChat and "enabled." or "disabled."))
	end
end

local function SetSpatialParadoxPreferredClass(value, silent)
	value = type(value) == "string" and value:upper() or "PRIEST"
	EnsureDB()
	EasyPrescienceDB.spatialParadoxPreferredClass = value
	if EasyPrescienceDB.useAutoAssign and EasyPrescienceDB.autoAssignSpatialParadox then
		ApplyAutoAssignments()
	else
		RefreshOptions()
	end

	if not silent then
		Msg("Spatial Paradox preferred class =", GetClassDisplayName(value))
	end
end

local function UpdateAssignmentForRoster(assignment, label, silent)
	assignment = NormalizeStoredAssignment(assignment)
	if not assignment then
		return nil, false, nil
	end

	local oldUnit = assignment.unit
	local resolvedUnit = FindGroupUnitByGUID(assignment.guid)

	if not resolvedUnit and assignment.name then
		resolvedUnit = ResolveAssignmentUnitByName(assignment.name)
	end

	if not resolvedUnit then
		if not silent then
			Msg(label .. " assignment cleared because that player is no longer in your current party or raid.")
		end
		return nil, true, "cleared"
	end

	local updated = BuildAssignmentData(resolvedUnit) or {
		unit = resolvedUnit,
		guid = assignment.guid,
		name = assignment.name,
	}

	if oldUnit ~= updated.unit and not silent then
		Msg(label .. " reassigned to " .. GetAssignmentDisplayValue(updated) .. " after roster changes.")
	end

	local changed = oldUnit ~= updated.unit or assignment.guid ~= updated.guid or assignment.name ~= updated.name
	return updated, changed, oldUnit ~= updated.unit and "reassigned" or nil
end

local function SyncAssignmentsToRoster(silent)
	EnsureDB()

	local changed = false
	local details = {
		cleared = {},
		reassigned = {},
	}

	for _, key in ipairs(PRESCIENCE_ASSIGNMENT_KEYS) do
		local label = "Prescience " .. DISPLAY_KEYS[key]
		local updated, didChange, reason = UpdateAssignmentForRoster(EasyPrescienceDB.targets[key], label, silent)
		EasyPrescienceDB.targets[key] = updated
		changed = changed or didChange
		if reason == "cleared" then
			details.cleared[#details.cleared + 1] = label
		elseif reason == "reassigned" then
			details.reassigned[#details.reassigned + 1] = label
		end
	end

	local fieldSpecs = {
		{ field = "blisteringScalesTarget", label = "Blistering Scales" },
		{ field = "rescueTarget", label = "Rescue" },
		{ field = "spatialParadoxTarget", label = "Spatial Paradox / Time Spiral" },
		{ field = "verdantEmbraceTarget", label = "Verdant Embrace" },
	}

	for _, spec in ipairs(fieldSpecs) do
		local updated, didChange, reason = UpdateAssignmentForRoster(EasyPrescienceDB[spec.field], spec.label, silent)
		EasyPrescienceDB[spec.field] = updated
		changed = changed or didChange
		if reason == "cleared" then
			details.cleared[#details.cleared + 1] = spec.label
		elseif reason == "reassigned" then
			details.reassigned[#details.reassigned + 1] = spec.label
		end
	end

	if changed then
		ReconcileManagedMacros(true)
	end

	RefreshOptions()
	return changed, details
end

local function CollectGroupUnits()
	local units = {}

	if UnitExists("player") then
		units[#units + 1] = "player"
	end

	if IsInRaid() then
		for index = 1, 40 do
			local unit = "raid" .. index
			if UnitExists(unit) then
				units[#units + 1] = unit
			end
		end
	elseif IsInGroup() then
		for index = 1, 4 do
			local unit = "party" .. index
			if UnitExists(unit) then
				units[#units + 1] = unit
			end
		end
	end

	return units
end

local function UnitClassToken(unit)
	local _, classToken = UnitClass(unit)
	return classToken
end

local function IsHealerClass(classToken)
	return classToken == "PRIEST"
		or classToken == "PALADIN"
		or classToken == "DRUID"
		or classToken == "SHAMAN"
		or classToken == "MONK"
		or classToken == "EVOKER"
end

local function GetRoleUnits(role, includePlayer)
	local units = {}
	for _, unit in ipairs(CollectGroupUnits()) do
		if includePlayer or not UnitIsUnit(unit, "player") then
			if UnitGroupRolesAssigned(unit) == role then
				units[#units + 1] = unit
			end
		end
	end
	return units
end

local function FindMainTankUnit()
	for _, unit in ipairs(CollectGroupUnits()) do
		if GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) then
			return unit
		end
	end
end

local function FindFirstTankUnit()
	local tanks = GetRoleUnits("TANK", true)
	return tanks[1]
end

local function FindHealerUnit(preferredClass)
	local preferred = {}
	local fallback = {}

	for _, unit in ipairs(GetRoleUnits("HEALER", false)) do
		local classToken = UnitClassToken(unit)
		fallback[#fallback + 1] = unit
		if preferredClass ~= "ANY" and classToken == preferredClass then
			preferred[#preferred + 1] = unit
		end
	end

	if #preferred > 0 then
		return preferred[random(#preferred)]
	end

	if preferredClass == "ANY" then
		local healerClasses = {}
		for _, unit in ipairs(fallback) do
			if IsHealerClass(UnitClassToken(unit)) then
				healerClasses[#healerClasses + 1] = unit
			end
		end
		if #healerClasses > 0 then
			return healerClasses[random(#healerClasses)]
		end
	end

	if #fallback > 0 then
		return fallback[random(#fallback)]
	end
end

local function FindDamageUnitsExcludingPlayer(limit)
	local result = {}
	for _, unit in ipairs(GetRoleUnits("DAMAGER", false)) do
		result[#result + 1] = unit
		if limit and #result >= limit then
			break
		end
	end
	return result
end

local function BuildAutoAssignSummary()
	local summary = {}

	if EasyPrescienceDB.autoAssignPrescience then
		local prescienceParts = {}
		if EasyPrescienceDB.prescienceNoModEnabled then
			prescienceParts[#prescienceParts + 1] = "No Mod=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets.NOMOD))
		end
		prescienceParts[#prescienceParts + 1] = "Shift=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets.SHIFT))
		prescienceParts[#prescienceParts + 1] = "Alt=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets.ALT))
		prescienceParts[#prescienceParts + 1] = "Ctrl=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets.CTRL))
		summary[#summary + 1] = "Prescience: " .. table.concat(prescienceParts, ", ")
	end

	if EasyPrescienceDB.autoAssignBlisteringScales then
		summary[#summary + 1] = "Blistering Scales: " .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.blisteringScalesTarget))
	end

	if EasyPrescienceDB.autoAssignRescue then
		summary[#summary + 1] = "Rescue: " .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.rescueTarget))
	end

	if EasyPrescienceDB.autoAssignSpatialParadox then
		summary[#summary + 1] = "Spatial Paradox: " .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.spatialParadoxTarget))
	end

	return table.concat(summary, " | ")
end

ApplyAutoAssignments = function(suppressMessages)
	EnsureDB()

	if not EasyPrescienceDB.useAutoAssign then
		return false, {}
	end

	local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
	if groupSize <= 0 then
		return false, {}
	end

	local changes = {}
	local changed = false

	local function SetAutoField(field, newAssignment, label, macroID)
		newAssignment = NormalizeStoredAssignment(newAssignment)
		local oldDisplay = GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB[field]))
		local newDisplay = GetStatusValue(GetAssignmentDisplayValue(newAssignment))
		local oldUnit = GetAssignmentUnit(EasyPrescienceDB[field])
		local newUnit = GetAssignmentUnit(newAssignment)

		if oldUnit ~= newUnit or oldDisplay ~= newDisplay then
			EasyPrescienceDB[field] = newAssignment
			ReconcileManagedMacroByID(macroID, true)
			changes[#changes + 1] = label .. " -> " .. newDisplay
			changed = true
		end
	end

	local function SetAutoPrescience(key, newAssignment)
		newAssignment = NormalizeStoredAssignment(newAssignment)
		local oldDisplay = GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets[key]))
		local newDisplay = GetStatusValue(GetAssignmentDisplayValue(newAssignment))
		local oldUnit = GetAssignmentUnit(EasyPrescienceDB.targets[key])
		local newUnit = GetAssignmentUnit(newAssignment)

		if oldUnit ~= newUnit or oldDisplay ~= newDisplay then
			EasyPrescienceDB.targets[key] = newAssignment
			ReconcileManagedMacroByID("prescience", true)
			changes[#changes + 1] = "Prescience " .. DISPLAY_KEYS[key] .. " -> " .. newDisplay
			changed = true
		end
	end

	if IsInRaid() then
		if EasyPrescienceDB.autoAssignBlisteringScales then
			local tankUnit = FindMainTankUnit() or FindFirstTankUnit()
			SetAutoField("blisteringScalesTarget", BuildAssignmentData(tankUnit), "Blistering Scales", "blistering")
		end

		if EasyPrescienceDB.autoAssignSpatialParadox then
			local healerUnit = FindHealerUnit(EasyPrescienceDB.spatialParadoxPreferredClass)
			SetAutoField("spatialParadoxTarget", BuildAssignmentData(healerUnit), "Spatial Paradox", "spatialParadox")
		end
	elseif IsInGroup() then
		if EasyPrescienceDB.autoAssignBlisteringScales then
			SetAutoField("blisteringScalesTarget", BuildAssignmentData(FindFirstTankUnit()), "Blistering Scales", "blistering")
		end

		if EasyPrescienceDB.autoAssignRescue then
			SetAutoField("rescueTarget", BuildAssignmentData(FindHealerUnit("ANY")), "Rescue", "rescue")
		end

		if EasyPrescienceDB.autoAssignPrescience then
			local damageUnits = FindDamageUnitsExcludingPlayer(2)
			local shiftUnit = damageUnits[1]
			local altUnit = damageUnits[2]

			if EasyPrescienceDB.prescienceNoModEnabled then
				SetAutoPrescience("NOMOD", nil)
			end
			SetAutoPrescience("SHIFT", BuildAssignmentData(shiftUnit))
			SetAutoPrescience("ALT", BuildAssignmentData(altUnit))
			SetAutoPrescience("CTRL", nil)
		end
	end

	if changed then
		RefreshOptions()
		if not suppressMessages then
			Msg("Auto-assigned: " .. table.concat(changes, ", "))
		end
		if EasyPrescienceDB.announceSelectionsInChat and not suppressMessages then
			Msg(BuildAutoAssignSummary())
		end
	end

	return changed, changes
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

local function ResolveAssignmentUnit(ownerRegion, contextData)
	local unit = ResolveUnit(ownerRegion, contextData)
	local unitToken = ResolveGroupUnitToken(unit)
	if unitToken then
		return BuildAssignmentData(unitToken)
	end

	return ResolveAssignmentDataByName(GetContextName(contextData))
end

local function InjectMenu(ownerRegion, rootDescription, contextData)
	local assignment = ResolveAssignmentUnit(ownerRegion, contextData)
	if not assignment then return end
	local isSelfAssignment = GetAssignmentUnit(assignment) == "player"

	rootDescription:CreateDivider()
	rootDescription:CreateTitle("EasyPrescience")

	if EasyPrescienceDB.prescienceNoModEnabled then
		rootDescription:CreateButton("Set on No Mod", function()
			SetModifierTarget("NOMOD", assignment)
		end)
	end

	for _, key in ipairs(MODIFIER_KEYS) do
		local modifierKey = key
		rootDescription:CreateButton("Set on " .. DISPLAY_KEYS[modifierKey], function()
			SetModifierTarget(modifierKey, assignment)
		end)
	end

	if not isSelfAssignment then
		rootDescription:CreateButton("Set Blistering Scales", function()
			SetDirectTarget("blisteringScalesTarget", assignment, "blistering", "Blistering Scales")
		end)

		rootDescription:CreateButton("Set Rescue", function()
			SetDirectTarget("rescueTarget", assignment, "rescue", "Rescue")
		end)

		rootDescription:CreateButton("Set Spatial Paradox", function()
			SetDirectTarget("spatialParadoxTarget", assignment, "spatialParadox", "Spatial Paradox")
		end)

		rootDescription:CreateButton("Set Verdant Embrace", function()
			SetDirectTarget("verdantEmbraceTarget", assignment, "verdantEmbrace", "Verdant Embrace")
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

local function CreateLabel(parent, text, x, y, width)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", x, y)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	if width then
		label:SetWidth(width)
	end
	return label
end

local function CreateEditBox(parent, width)
	local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	editBox:SetSize(width, 24)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject("ChatFontNormal")
	return editBox
end

local function CreateMacroRow(parent, y, labelText, getValue, setValue, defaultValue)
	local label = CreateLabel(parent, labelText, 16, y, 180)

	local editBox = CreateEditBox(parent, 180)
	editBox:SetPoint("TOPLEFT", label, "TOPRIGHT", 8, 2)
	editBox:SetMaxLetters(MAX_MACRO_NAME_LENGTH)
	editBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	editBox:SetScript("OnEditFocusLost", function(self)
		setValue(self:GetText())
	end)

	local resetButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	resetButton:SetSize(80, 22)
	resetButton:SetPoint("LEFT", editBox, "RIGHT", 10, 0)
	resetButton:SetText("Default")
	resetButton:SetScript("OnClick", function()
		setValue(defaultValue)
	end)

	optionsRefreshers[#optionsRefreshers + 1] = function()
		editBox:SetText(getValue() or "")
	end

	return y - 34
end

local function CreateModifierRow(parent, y, labelText, getValue, setValue)
	local label = CreateLabel(parent, labelText, 16, y, 180)

	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", label, "TOPRIGHT", -12, 8)
	UIDropDownMenu_SetWidth(dropdown, 120)

	UIDropDownMenu_Initialize(dropdown, function(self, level)
		for _, option in ipairs(GetNonPrescienceModifierOptions()) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option.label
			info.func = function()
				setValue(option.value)
			end
			info.checked = getValue() == option.value
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	optionsRefreshers[#optionsRefreshers + 1] = function()
		UIDropDownMenu_SetText(dropdown, DISPLAY_KEYS[getValue()] or "Select")
	end

	return y - 34
end

local function CreateChoiceRow(parent, y, labelText, width, options, getValue, setValue)
	local label = CreateLabel(parent, labelText, 16, y, 180)

	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", label, "TOPRIGHT", -12, 8)
	UIDropDownMenu_SetWidth(dropdown, width or 140)

	UIDropDownMenu_Initialize(dropdown, function(self, level)
		for _, option in ipairs(options) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option.label
			info.func = function()
				setValue(option.value)
			end
			info.checked = getValue() == option.value
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	optionsRefreshers[#optionsRefreshers + 1] = function()
		for _, option in ipairs(options) do
			if option.value == getValue() then
				UIDropDownMenu_SetText(dropdown, option.label)
				return
			end
		end
		UIDropDownMenu_SetText(dropdown, "Select")
	end

	return y - 34
end

local function CreateCheckboxRow(parent, y, labelText, getValue, setValue, helpText)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", 12, y + 4)
	check.text:SetText(labelText)

	if helpText then
		local helpLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		helpLabel:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 4, -2)
		helpLabel:SetWidth(620)
		helpLabel:SetJustifyH("LEFT")
		helpLabel:SetText(helpText)
	end

	check:SetScript("OnClick", function(self)
		setValue(self:GetChecked() == true)
	end)

	optionsRefreshers[#optionsRefreshers + 1] = function()
		check:SetChecked(getValue() == true)
	end

	return y - (helpText and 44 or 30)
end

local function UpdateMinimapButtonPosition()
	if not minimapButton then return end

	local angle = EasyPrescienceDB.minimap and EasyPrescienceDB.minimap.angle or 225
	local radians = math.rad(angle)
	local radius = 80
	local x = math.cos(radians) * radius
	local y = math.sin(radians) * radius

	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function RefreshMinimapButtonVisibility()
	if not minimapButton then return end

	if EasyPrescienceDB.minimap and EasyPrescienceDB.minimap.hide then
		minimapButton:Hide()
	else
		minimapButton:Show()
		UpdateMinimapButtonPosition()
	end
end

local function SetMinimapButtonShown(enabled, silent)
	EnsureDB()
	EasyPrescienceDB.minimap.hide = enabled ~= true
	RefreshMinimapButtonVisibility()
	RefreshOptions()

	if not silent then
		Msg("Minimap button " .. (enabled and "shown." or "hidden."))
	end
end

OpenSettingsPanel = function()
	if not optionsPanel then
		RegisterOptionsPanel()
	end

	if Settings and Settings.OpenToCategory and optionsCategoryID then
		Settings.OpenToCategory(optionsCategoryID)
	else
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
	end
end

local function CreateMinimapButton()
	if minimapButton then return end

	local button = CreateFrame("Button", ADDON .. "MinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetMovable(true)
	button:SetClampedToScreen(true)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\AddOns\\EasyPrescience\\icon.png")
	icon:SetAllPoints(button)
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	highlight:SetBlendMode("ADD")
	highlight:SetSize(34, 34)
	highlight:SetPoint("CENTER", 0, 1)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(ADDON)
		GameTooltip:AddLine("Left Click to print current assignments in chat.", 1, 1, 1)
		GameTooltip:AddLine("Shift-Left Click to open settings.", 1, 1, 1)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	button:SetScript("OnClick", function(_, buttonName)
		if buttonName == "LeftButton" and IsShiftKeyDown() then
			OpenSettingsPanel()
		else
			HandleSlashStatus()
		end
	end)

	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local cursorX, cursorY = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			local centerX, centerY = Minimap:GetCenter()
			local deltaX = cursorX / scale - centerX
			local deltaY = cursorY / scale - centerY
			local angle = math.deg(math.atan2(deltaY, deltaX))
			EasyPrescienceDB.minimap.angle = angle
			UpdateMinimapButtonPosition()
		end)
	end)

	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	minimapButton = button
	RefreshMinimapButtonVisibility()
end

RegisterOptionsPanel = function()
	if optionsPanel then return end

	optionsPanel = CreateFrame("Frame", ADDON .. "OptionsPanel", UIParent)
	optionsPanel.name = ADDON
	optionsPanel:Hide()

	local scrollFrame = CreateFrame("ScrollFrame", nil, optionsPanel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 8, -8)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(700, 1)
	scrollFrame:SetScrollChild(content)

	local y = -16
	local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, y)
	title:SetText(ADDON)
	y = y - 26

	local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", 16, y)
	subtitle:SetWidth(640)
	subtitle:SetJustifyH("LEFT")
	subtitle:SetText("Configure macro names, assignment behavior, and managed macros from the Blizzard AddOns settings panel. Targets can be assigned from the unit context menu and are stored as group unit slots.")
	y = y - 44

	CreateLabel(content, "Macro Names", 16, y)
	y = y - 26

	y = CreateCheckboxRow(content, y, "Show minimap button", function()
		return not (EasyPrescienceDB.minimap and EasyPrescienceDB.minimap.hide)
	end, function(value)
		SetMinimapButtonShown(value)
	end, "Show or hide the minimap button used to open EasyPrescience settings.")

	y = y - 8

	y = CreateMacroRow(content, y, "Prescience", function()
		return EasyPrescienceDB.macroName
	end, function(value)
		SetMacroName("macroName", value, "prescience")
	end, DEFAULT_MACRO_NAME)

	y = CreateMacroRow(content, y, "Blistering Scales", function()
		return EasyPrescienceDB.blisteringScalesMacroName
	end, function(value)
		SetMacroName("blisteringScalesMacroName", value, "blistering")
	end, DEFAULT_BLISTERING_SCALES_MACRO_NAME)

	y = CreateMacroRow(content, y, "Rescue", function()
		return EasyPrescienceDB.rescueMacroName
	end, function(value)
		SetMacroName("rescueMacroName", value, "rescue")
	end, DEFAULT_RESCUE_MACRO_NAME)

	y = CreateMacroRow(content, y, "Spatial / Time Spiral", function()
		return EasyPrescienceDB.spatialParadoxMacroName
	end, function(value)
		SetMacroName("spatialParadoxMacroName", value, "spatialParadox")
	end, DEFAULT_SPATIAL_PARADOX_MACRO_NAME)

	y = CreateMacroRow(content, y, "Verdant Embrace", function()
		return EasyPrescienceDB.verdantEmbraceMacroName
	end, function(value)
		SetMacroName("verdantEmbraceMacroName", value, "verdantEmbrace")
	end, DEFAULT_VERDANT_EMBRACE_MACRO_NAME)

	y = y - 8
	CreateLabel(content, "Prescience", 16, y)
	y = y - 26

	y = CreateCheckboxRow(content, y, "Enable assigned No Mod target", function()
		return EasyPrescienceDB.prescienceNoModEnabled
	end, function(value)
		SetPrescienceNoModEnabled(value)
	end, "When enabled, Prescience with no modifier casts on the player assigned with 'Set on No Mod'. When disabled, no modifier keeps the normal spell behavior.")

	y = y - 14
	CreateLabel(content, "Auto Assign", 16, y)
	y = y - 26

	y = CreateCheckboxRow(content, y, "Enable auto assignment", function()
		return EasyPrescienceDB.useAutoAssign
	end, function(value)
		SetAutoAssignEnabled(value)
	end, "Automatically assign supported targets when you join or update a party or raid. Disabled by default.")

	y = CreateCheckboxRow(content, y, "Show auto-assigned targets in chat", function()
		return EasyPrescienceDB.announceSelectionsInChat
	end, function(value)
		SetAnnounceSelectionsInChat(value)
	end, "Print the current auto-assigned targets to chat whenever automatic assignments change.")

	y = CreateCheckboxRow(content, y, "Auto-assign Prescience", function()
		return EasyPrescienceDB.autoAssignPrescience
	end, function(value)
		SetAutoAssignUtilityEnabled("autoAssignPrescience", value)
	end, "In 5-player groups, assign Prescience to the two other damage dealers instead of yourself.")

	y = CreateCheckboxRow(content, y, "Auto-assign Blistering Scales", function()
		return EasyPrescienceDB.autoAssignBlisteringScales
	end, function(value)
		SetAutoAssignUtilityEnabled("autoAssignBlisteringScales", value)
	end, "In parties, prefer the tank. In raids, prefer the main tank or the first tank if no main tank is assigned.")

	y = CreateCheckboxRow(content, y, "Auto-assign Rescue", function()
		return EasyPrescienceDB.autoAssignRescue
	end, function(value)
		SetAutoAssignUtilityEnabled("autoAssignRescue", value)
	end, "In 5-player groups, assign Rescue to the healer automatically.")

	y = CreateCheckboxRow(content, y, "Auto-assign Spatial Paradox", function()
		return EasyPrescienceDB.autoAssignSpatialParadox
	end, function(value)
		SetAutoAssignUtilityEnabled("autoAssignSpatialParadox", value)
	end, "In raids, assign Spatial Paradox to a healer and prefer the selected class when available.")

	y = y - 10
	y = CreateChoiceRow(content, y, "Preferred Spatial Paradox class", 160, GetSpatialParadoxPreferredClassOptions(), function()
		return EasyPrescienceDB.spatialParadoxPreferredClass
	end, function(value)
		SetSpatialParadoxPreferredClass(value)
	end)

	y = y - 14
	CreateLabel(content, "Spell Modifiers", 16, y)
	y = y - 26

	y = CreateModifierRow(content, y, "Rescue", function()
		return EasyPrescienceDB.rescueModifier
	end, function(value)
		SetSpellModifier("rescueModifier", value, "rescue", "Rescue")
	end)

	y = CreateModifierRow(content, y, "Spatial / Time Spiral", function()
		return EasyPrescienceDB.spatialParadoxModifier
	end, function(value)
		SetSpellModifier("spatialParadoxModifier", value, "spatialParadox", "Spatial Paradox")
	end)

	y = CreateModifierRow(content, y, "Verdant Embrace", function()
		return EasyPrescienceDB.verdantEmbraceModifier
	end, function(value)
		SetSpellModifier("verdantEmbraceModifier", value, "verdantEmbrace", "Verdant Embrace")
	end)

	y = y - 8
	CreateLabel(content, "Actions", 16, y)
	y = y - 28

	local reconcileButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	reconcileButton:SetSize(180, 24)
	reconcileButton:SetPoint("TOPLEFT", 16, y)
	reconcileButton:SetText("Review Macros")
	reconcileButton:SetScript("OnClick", function()
		ClearAllAssignments(true)
		ReconcileManagedMacros()
	end)

	local refreshLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	refreshLabel:SetPoint("LEFT", reconcileButton, "RIGHT", 12, 0)
	refreshLabel:SetWidth(420)
	refreshLabel:SetJustifyH("LEFT")
	refreshLabel:SetText("This clears all assigned targets, then reviews every managed macro, recreates anything missing, and overwrites outdated or manually edited macro bodies.")
	y = y - 46

	local helpLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	helpLabel:SetPoint("TOPLEFT", 16, y)
	helpLabel:SetWidth(640)
	helpLabel:SetJustifyH("LEFT")
	helpLabel:SetText("Use the right-click unit menu to assign targets. EasyPrescience stores group unit slots such as party1 and raid3 instead of player names, then rebuilds macros automatically. Spatial Paradox automatically switches to Time Spiral when that talent is selected and updates again when talents change.")
	y = y - 44

	local deleteButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	deleteButton:SetSize(180, 24)
	deleteButton:SetPoint("TOPLEFT", 16, y)
	deleteButton:SetText("Delete All Macros")
	deleteButton:SetScript("OnClick", function()
		DeleteManagedMacros()
	end)

	local deleteLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	deleteLabel:SetPoint("LEFT", deleteButton, "RIGHT", 12, 0)
	deleteLabel:SetWidth(420)
	deleteLabel:SetJustifyH("LEFT")
	deleteLabel:SetText("Delete every macro managed by EasyPrescience to make uninstalling the addon easier.")
	y = y - 38

	y = y - 12

	content:SetHeight(-y + 20)

	optionsPanel:SetScript("OnShow", RefreshOptions)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, ADDON)
		Settings.RegisterAddOnCategory(category)
		if type(category) == "table" then
			if type(category.GetID) == "function" then
				optionsCategoryID = category:GetID()
			elseif type(category.ID) == "number" then
				optionsCategoryID = category.ID
			end
		elseif type(category) == "number" then
			optionsCategoryID = category
		end
	else
		InterfaceOptions_AddCategory(optionsPanel)
	end
end

HandleSlashStatus = function()
	EnsureDB()
	Msg("Options: Blizzard Settings -> AddOns -> " .. ADDON)
	Msg("Auto assign: " .. (EasyPrescienceDB.useAutoAssign and "On" or "Off")
		.. " | Chat selections: " .. (EasyPrescienceDB.announceSelectionsInChat and "On" or "Off")
		.. " | Spatial pref: " .. GetClassDisplayName(EasyPrescienceDB.spatialParadoxPreferredClass))
	Msg("Macros: Prescience=" .. GetStatusValue(EasyPrescienceDB.macroName)
		.. ", Blistering=" .. GetStatusValue(EasyPrescienceDB.blisteringScalesMacroName)
		.. ", Rescue=" .. GetStatusValue(EasyPrescienceDB.rescueMacroName)
		.. ", Spatial=" .. GetStatusValue(EasyPrescienceDB.spatialParadoxMacroName)
		.. ", Verdant=" .. GetStatusValue(EasyPrescienceDB.verdantEmbraceMacroName))
	local prescienceSummary = {}
	if EasyPrescienceDB.prescienceNoModEnabled then
		prescienceSummary[#prescienceSummary + 1] = "No Mod=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets.NOMOD))
	else
		prescienceSummary[#prescienceSummary + 1] = "No Mod=Disabled"
	end
	prescienceSummary[#prescienceSummary + 1] = "Shift=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets.SHIFT))
	prescienceSummary[#prescienceSummary + 1] = "Alt=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets.ALT))
	prescienceSummary[#prescienceSummary + 1] = "Ctrl=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.targets.CTRL))
	Msg("Prescience: " .. table.concat(prescienceSummary, ", "))
	Msg("Utilities: Blistering=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.blisteringScalesTarget))
		.. ", Rescue=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.rescueTarget))
		.. " [" .. DISPLAY_KEYS[EasyPrescienceDB.rescueModifier] .. "]"
		.. ", Spatial=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.spatialParadoxTarget))
		.. " [" .. DISPLAY_KEYS[EasyPrescienceDB.spatialParadoxModifier] .. "]"
		.. ", Verdant=" .. GetStatusValue(GetAssignmentDisplayValue(EasyPrescienceDB.verdantEmbraceTarget))
		.. " [" .. DISPLAY_KEYS[EasyPrescienceDB.verdantEmbraceModifier] .. "]")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function(_, event)
	EnsureDB()

	if event == "PLAYER_LOGIN" then
		HookMenus()
		RegisterOptionsPanel()
		CreateMinimapButton()
		SyncAssignmentsToRoster(true)
		ApplyAutoAssignments()
		ReconcileManagedMacros(true)
		return
	end

	if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
		HookMenus()
		local _, rosterDetails = SyncAssignmentsToRoster(event ~= "GROUP_ROSTER_UPDATE")
		local autoChanged, autoChanges = ApplyAutoAssignments(event == "GROUP_ROSTER_UPDATE")
		if event == "GROUP_ROSTER_UPDATE" and rosterDetails then
			if #rosterDetails.cleared > 0 and autoChanged then
				Msg("Reassigned after group changes: " .. table.concat(autoChanges, ", "))
				if EasyPrescienceDB.announceSelectionsInChat then
					Msg(BuildAutoAssignSummary())
				end
			elseif #rosterDetails.cleared > 0 then
				Msg("Targets left your group, so these assignments were cleared: " .. table.concat(rosterDetails.cleared, ", "))
			elseif #rosterDetails.reassigned > 0 then
				Msg("Updated assignments after roster changes: " .. table.concat(rosterDetails.reassigned, ", "))
			end
		end
		return
	end

	if event == "SPELLS_CHANGED" then
		ReconcileManagedMacroByID("spatialParadox", true)
		ReconcileManagedMacroByID("verdantEmbrace", true)
		RefreshOptions()
	end
end)

SLASH_EASYPRESCIENCE1 = "/ep"
SlashCmdList.EASYPRESCIENCE = function(msg)
	EnsureDB()
	msg = Trim(msg) or ""
	local command, rest = msg:match("^(%S+)%s*(.*)$")
	command = command and command:lower() or ""

	if command == "" then
		HandleSlashStatus()
		return
	end

	if command == "autoassign" then
		local value = rest:lower()
		if value == "on" or value == "1" or value == "true" then
			SetAutoAssignEnabled(true)
		elseif value == "off" or value == "0" or value == "false" then
			SetAutoAssignEnabled(false)
		else
			Msg("Use: /ep autoassign on|off")
		end
		return
	end

	if command == "chatselections" then
		local value = rest:lower()
		if value == "on" or value == "1" or value == "true" then
			SetAnnounceSelectionsInChat(true)
		elseif value == "off" or value == "0" or value == "false" then
			SetAnnounceSelectionsInChat(false)
		else
			Msg("Use: /ep chatselections on|off")
		end
		return
	end

	if command == "macro" and rest ~= "" then
		SetMacroName("macroName", rest, "prescience")
		return
	end

	if command == "blisteringmacro" and rest ~= "" then
		SetMacroName("blisteringScalesMacroName", rest, "blistering")
		return
	end

	if command == "rescuemacro" and rest ~= "" then
		SetMacroName("rescueMacroName", rest, "rescue")
		return
	end

	if command == "spatialmacro" and rest ~= "" then
		SetMacroName("spatialParadoxMacroName", rest, "spatialParadox")
		return
	end

	if command == "verdantmacro" and rest ~= "" then
		SetMacroName("verdantEmbraceMacroName", rest, "verdantEmbrace")
		return
	end

	if command == "clear" and rest ~= "" then
		local key = rest:upper()
		if key == "NOMOD" then
			SetModifierTarget("NOMOD", nil)
			return
		end
		if IsModifierKey(key) then
			SetModifierTarget(key, nil)
			return
		end
		if key == "BLISTERING" then
			SetDirectTarget("blisteringScalesTarget", nil, "blistering", "Blistering Scales")
			return
		end
		if key == "RESCUE" then
			SetDirectTarget("rescueTarget", nil, "rescue", "Rescue")
			return
		end
		if key == "SPATIAL" then
			SetDirectTarget("spatialParadoxTarget", nil, "spatialParadox", "Spatial Paradox")
			return
		end
		if key == "VERDANT" then
			SetDirectTarget("verdantEmbraceTarget", nil, "verdantEmbrace", "Verdant Embrace")
			return
		end
		Err("Invalid clear target. Use: nomod, shift, alt, ctrl, blistering, rescue, spatial, or verdant.")
		return
	end

	if command == "update" or command == "review" then
		ReconcileManagedMacros()
		return
	end

	if command == "deletemacros" then
		DeleteManagedMacros()
		return
	end

	Err("Unknown command. Type /ep or use Blizzard Settings -> AddOns -> " .. ADDON)
end

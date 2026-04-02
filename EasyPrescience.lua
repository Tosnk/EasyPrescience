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
local managedMacros
local RefreshOptions

local function GetNonPrescienceModifierOptions()
	return {
		{ value = "SHIFT", label = "Shift" },
		{ value = "ALT", label = "Alt" },
		{ value = "CTRL", label = "Ctrl" },
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
	if EasyPrescienceDB.schemaVersion == 7 then return end

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
	EasyPrescienceDB.schemaVersion = 7
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

local function UpdateAssignmentForRoster(assignment, label, silent)
	assignment = NormalizeStoredAssignment(assignment)
	if not assignment then
		return nil, false
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
		return nil, true
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
	return updated, changed
end

local function SyncAssignmentsToRoster(silent)
	EnsureDB()

	local changed = false

	for _, key in ipairs(PRESCIENCE_ASSIGNMENT_KEYS) do
		local updated, didChange = UpdateAssignmentForRoster(EasyPrescienceDB.targets[key], "Prescience " .. DISPLAY_KEYS[key], silent)
		EasyPrescienceDB.targets[key] = updated
		changed = changed or didChange
	end

	local fieldSpecs = {
		{ field = "blisteringScalesTarget", label = "Blistering Scales" },
		{ field = "rescueTarget", label = "Rescue" },
		{ field = "spatialParadoxTarget", label = "Spatial Paradox / Time Spiral" },
		{ field = "verdantEmbraceTarget", label = "Verdant Embrace" },
	}

	for _, spec in ipairs(fieldSpecs) do
		local updated, didChange = UpdateAssignmentForRoster(EasyPrescienceDB[spec.field], spec.label, silent)
		EasyPrescienceDB[spec.field] = updated
		changed = changed or didChange
	end

	if changed then
		ReconcileManagedMacros(true)
	end

	RefreshOptions()
	return changed
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

local function RegisterOptionsPanel()
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
	subtitle:SetText("Configure macro names, support spell modifiers, and review all managed macros from the Blizzard AddOns settings panel. Assignments are now captured from the unit context menu and stored as group unit slots.")
	y = y - 40

	CreateLabel(content, "Macro Names", 16, y)
	y = y - 26

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
	CreateLabel(content, "Support Spell Modifiers", 16, y)
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

	y = y - 14
	CreateLabel(content, "Current Assignments", 16, y)
	y = y - 26

	local assignmentsLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	assignmentsLabel:SetPoint("TOPLEFT", 16, y)
	assignmentsLabel:SetWidth(640)
	assignmentsLabel:SetJustifyH("LEFT")

	optionsRefreshers[#optionsRefreshers + 1] = function()
		assignmentsLabel:SetText(table.concat({
			"Prescience No Mod: " .. GetAssignmentDisplayValue(EasyPrescienceDB.targets.NOMOD),
			"Prescience Shift: " .. GetAssignmentDisplayValue(EasyPrescienceDB.targets.SHIFT),
			"Prescience Alt: " .. GetAssignmentDisplayValue(EasyPrescienceDB.targets.ALT),
			"Prescience Ctrl: " .. GetAssignmentDisplayValue(EasyPrescienceDB.targets.CTRL),
			"Blistering Scales: " .. GetAssignmentDisplayValue(EasyPrescienceDB.blisteringScalesTarget),
			"Rescue: " .. GetAssignmentDisplayValue(EasyPrescienceDB.rescueTarget),
			"Spatial Paradox / Time Spiral: " .. GetAssignmentDisplayValue(EasyPrescienceDB.spatialParadoxTarget),
			"Verdant Embrace: " .. GetAssignmentDisplayValue(EasyPrescienceDB.verdantEmbraceTarget),
		}, "\n"))
	end

	y = y - 144
	CreateLabel(content, "Actions", 16, y)
	y = y - 28

	local reconcileButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	reconcileButton:SetSize(180, 24)
	reconcileButton:SetPoint("TOPLEFT", 16, y)
	reconcileButton:SetText("Review All Macros")
	reconcileButton:SetScript("OnClick", function()
		ReconcileManagedMacros()
	end)

	local refreshLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	refreshLabel:SetPoint("LEFT", reconcileButton, "RIGHT", 12, 0)
	refreshLabel:SetWidth(420)
	refreshLabel:SetJustifyH("LEFT")
	refreshLabel:SetText("This reviews all managed macros, recreates anything missing, and overwrites outdated or manually edited macro bodies.")
	y = y - 46

	local helpLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	helpLabel:SetPoint("TOPLEFT", 16, y)
	helpLabel:SetWidth(640)
	helpLabel:SetJustifyH("LEFT")
	helpLabel:SetText("Use the right-click unit menu to assign targets. EasyPrescience stores group unit slots like party1 and raid3 instead of player names, then rebuilds macros automatically. Spatial Paradox automatically swaps to Time Spiral when that talent is selected and updates again when talents change.")
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
	deleteLabel:SetText("Deletes every macro managed by EasyPrescience so uninstalling the addon is easier.")
	y = y - 38

	y = y - 12

	content:SetHeight(-y + 20)

	optionsPanel:SetScript("OnShow", RefreshOptions)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, ADDON)
		Settings.RegisterAddOnCategory(category)
	else
		InterfaceOptions_AddCategory(optionsPanel)
	end
end

local function HandleSlashStatus()
	EnsureDB()
	Msg("Options are available in Blizzard Settings -> AddOns -> " .. ADDON)
	for _, spec in ipairs(GetManagedMacros()) do
		Msg(spec.label .. " macro =", EasyPrescienceDB[spec.macroField])
	end
	Msg("Prescience No Mod target =", GetAssignmentDisplayValue(EasyPrescienceDB.targets.NOMOD))
	Msg("Prescience No Mod enabled =", EasyPrescienceDB.prescienceNoModEnabled and "Yes" or "No")
	for _, key in ipairs(MODIFIER_KEYS) do
		Msg("Prescience " .. DISPLAY_KEYS[key] .. " =", GetAssignmentDisplayValue(EasyPrescienceDB.targets[key]))
	end
	Msg("Blistering Scales =", GetAssignmentDisplayValue(EasyPrescienceDB.blisteringScalesTarget))
	Msg("Rescue =", GetAssignmentDisplayValue(EasyPrescienceDB.rescueTarget))
	Msg("Rescue modifier =", DISPLAY_KEYS[EasyPrescienceDB.rescueModifier])
	Msg("Spatial Paradox =", GetAssignmentDisplayValue(EasyPrescienceDB.spatialParadoxTarget))
	Msg("Spatial Paradox modifier =", DISPLAY_KEYS[EasyPrescienceDB.spatialParadoxModifier])
	Msg("Verdant Embrace =", GetAssignmentDisplayValue(EasyPrescienceDB.verdantEmbraceTarget))
	Msg("Verdant Embrace modifier =", DISPLAY_KEYS[EasyPrescienceDB.verdantEmbraceModifier])
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
		SyncAssignmentsToRoster(true)
		ReconcileManagedMacros(true)
		return
	end

	if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
		HookMenus()
		SyncAssignmentsToRoster(event ~= "GROUP_ROSTER_UPDATE")
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

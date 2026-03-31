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

local function FullUnitName(unit)
	if not unit or not UnitExists(unit) then return nil end
	return NormalizeName(GetUnitName(unit, true))
end

local function EnsureTargetsTable()
	if type(EasyPrescienceDB.targets) ~= "table" then
		EasyPrescienceDB.targets = {}
	end

	for _, key in ipairs(MODIFIER_KEYS) do
		EasyPrescienceDB.targets[key] = NormalizeName(EasyPrescienceDB.targets[key])
	end
end

local function MigrateLegacyData()
	if EasyPrescienceDB.schemaVersion == 5 then return end

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
	EasyPrescienceDB.blisteringScalesTarget = NormalizeName(EasyPrescienceDB.blisteringScalesTarget)
	EasyPrescienceDB.rescueTarget = NormalizeName(EasyPrescienceDB.rescueTarget)
	EasyPrescienceDB.spatialParadoxTarget = NormalizeName(EasyPrescienceDB.spatialParadoxTarget)
	EasyPrescienceDB.verdantEmbraceTarget = NormalizeName(EasyPrescienceDB.verdantEmbraceTarget)
	EasyPrescienceDB.blisteringScalesModifier = IsModifierKey(EasyPrescienceDB.blisteringScalesModifier) and EasyPrescienceDB.blisteringScalesModifier or "ALT"
	EasyPrescienceDB.rescueModifier = IsModifierKey(EasyPrescienceDB.rescueModifier) and EasyPrescienceDB.rescueModifier or "ALT"
	EasyPrescienceDB.spatialParadoxModifier = IsModifierKey(EasyPrescienceDB.spatialParadoxModifier) and EasyPrescienceDB.spatialParadoxModifier or "ALT"
	EasyPrescienceDB.verdantEmbraceModifier = IsModifierKey(EasyPrescienceDB.verdantEmbraceModifier) and EasyPrescienceDB.verdantEmbraceModifier or "ALT"
	EasyPrescienceDB.schemaVersion = 5
end

local function EnsureDB()
	EasyPrescienceDB.macroName = NormalizeMacroName(EasyPrescienceDB.macroName, DEFAULT_MACRO_NAME)
	EasyPrescienceDB.blisteringScalesMacroName = NormalizeMacroName(EasyPrescienceDB.blisteringScalesMacroName, DEFAULT_BLISTERING_SCALES_MACRO_NAME)
	EasyPrescienceDB.rescueMacroName = NormalizeMacroName(EasyPrescienceDB.rescueMacroName, DEFAULT_RESCUE_MACRO_NAME)
	EasyPrescienceDB.spatialParadoxMacroName = NormalizeMacroName(EasyPrescienceDB.spatialParadoxMacroName, DEFAULT_SPATIAL_PARADOX_MACRO_NAME)
	EasyPrescienceDB.verdantEmbraceMacroName = NormalizeMacroName(EasyPrescienceDB.verdantEmbraceMacroName, DEFAULT_VERDANT_EMBRACE_MACRO_NAME)
	EnsureTargetsTable()
	MigrateLegacyData()
	EasyPrescienceDB.blisteringScalesTarget = NormalizeName(EasyPrescienceDB.blisteringScalesTarget)
	EasyPrescienceDB.rescueTarget = NormalizeName(EasyPrescienceDB.rescueTarget)
	EasyPrescienceDB.spatialParadoxTarget = NormalizeName(EasyPrescienceDB.spatialParadoxTarget)
	EasyPrescienceDB.verdantEmbraceTarget = NormalizeName(EasyPrescienceDB.verdantEmbraceTarget)
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

local function BuildDirectTargetMacroBody(spellName, targetName)
	local normalizedTarget = NormalizeName(targetName)
	local condition = normalizedTarget and ("[@" .. normalizedTarget .. ",help,nodead]") or "[]"

	return table.concat({
		"#showtooltip " .. spellName,
		"/cast " .. condition .. " " .. spellName,
	}, "\n")
end

local function BuildSingleModifierTargetMacroBody(spellName, modifierKey, targetName)
	local normalizedTarget = NormalizeName(targetName)
	local normalizedModifier = IsModifierKey(modifierKey) and modifierKey:lower() or "alt"
	local condition = normalizedTarget and ("[mod:" .. normalizedModifier .. ",@" .. normalizedTarget .. ",help,nodead]") or ""

	return table.concat({
		"#showtooltip " .. spellName,
		"/cast " .. condition .. "[] " .. spellName,
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
	return BuildSingleModifierTargetMacroBody("Blistering Scales", EasyPrescienceDB.blisteringScalesModifier, EasyPrescienceDB.blisteringScalesTarget)
end

local function BuildRescueMacroBody()
	return BuildSingleModifierTargetMacroBody("Rescue", EasyPrescienceDB.rescueModifier, EasyPrescienceDB.rescueTarget)
end

local function BuildSpatialParadoxMacroBody()
	return BuildSingleModifierTargetMacroBody(GetSpatialParadoxMacroSpellName(), EasyPrescienceDB.spatialParadoxModifier, EasyPrescienceDB.spatialParadoxTarget)
end

local function BuildVerdantEmbraceMacroBody()
	return BuildSingleModifierTargetMacroBody(VERDANT_EMBRACE_SPELL_NAME, EasyPrescienceDB.verdantEmbraceModifier, EasyPrescienceDB.verdantEmbraceTarget)
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

local function CleanupStoredTargets()
	EnsureDB()

	for _, key in ipairs(MODIFIER_KEYS) do
		EasyPrescienceDB.targets[key] = NormalizeName(EasyPrescienceDB.targets[key])
	end

	EasyPrescienceDB.blisteringScalesTarget = NormalizeName(EasyPrescienceDB.blisteringScalesTarget)
	EasyPrescienceDB.rescueTarget = NormalizeName(EasyPrescienceDB.rescueTarget)
	EasyPrescienceDB.spatialParadoxTarget = NormalizeName(EasyPrescienceDB.spatialParadoxTarget)
	EasyPrescienceDB.verdantEmbraceTarget = NormalizeName(EasyPrescienceDB.verdantEmbraceTarget)

	RefreshOptions()
	Msg("Stored targets cleaned up.")
end

local function RefreshOptions()
	for _, refresh in ipairs(optionsRefreshers) do
		refresh()
	end
end

local function SetModifierTarget(modifierKey, fullName, silent)
	modifierKey = type(modifierKey) == "string" and modifierKey:upper() or nil
	if not IsModifierKey(modifierKey) then return end

	EnsureDB()
	EasyPrescienceDB.targets[modifierKey] = NormalizeName(fullName)
	ReconcileManagedMacroByID("prescience", silent)
	RefreshOptions()

	if not silent then
		Msg(DISPLAY_KEYS[modifierKey] .. " =", EasyPrescienceDB.targets[modifierKey] or "")
	end
end

local function SetDirectTarget(field, value, macroID, label, silent)
	EnsureDB()
	EasyPrescienceDB[field] = NormalizeName(value)
	ReconcileManagedMacroByID(macroID, silent)
	RefreshOptions()

	if not silent then
		if EasyPrescienceDB[field] then
			Msg(label .. " =", EasyPrescienceDB[field])
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

	rootDescription:CreateButton("Set Blistering Scales", function()
		SetDirectTarget("blisteringScalesTarget", targetName, "blistering", "Blistering Scales")
	end)

	rootDescription:CreateButton("Set Rescue", function()
		SetDirectTarget("rescueTarget", targetName, "rescue", "Rescue")
	end)

	rootDescription:CreateButton("Set Spatial Paradox", function()
		SetDirectTarget("spatialParadoxTarget", targetName, "spatialParadox", "Spatial Paradox")
	end)

	rootDescription:CreateButton("Set Verdant Embrace", function()
		SetDirectTarget("verdantEmbraceTarget", targetName, "verdantEmbrace", "Verdant Embrace")
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

local function BuildRosterChoices(currentValue)
	local seen = {}
	local names = {}

	local function addName(name)
		name = NormalizeName(name)
		if not name or seen[name] then return end
		seen[name] = true
		names[#names + 1] = name
	end

	addName(currentValue)
	addName(FullUnitName("player"))
	addName(FullUnitName("target"))
	addName(FullUnitName("focus"))

	if IsInRaid() then
		for index = 1, 40 do
			addName(FullUnitName("raid" .. index))
		end
	elseif IsInGroup() then
		for index = 1, 4 do
			addName(FullUnitName("party" .. index))
		end
	end

	for index = 1, 5 do
		addName(FullUnitName("arena" .. index))
	end

	table.sort(names)
	return names
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

local function CreateTargetRow(parent, y, labelText, getValue, setValue)
	local label = CreateLabel(parent, labelText, 16, y, 180)

	local editBox = CreateEditBox(parent, 180)
	editBox:SetPoint("TOPLEFT", label, "TOPRIGHT", 8, 2)
	editBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	editBox:SetScript("OnEditFocusLost", function(self)
		setValue(self:GetText())
	end)

	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", editBox, "TOPRIGHT", -12, 8)
	UIDropDownMenu_SetWidth(dropdown, 150)
	UIDropDownMenu_SetText(dropdown, "Select")

	UIDropDownMenu_Initialize(dropdown, function(self, level)
		for _, name in ipairs(BuildRosterChoices(getValue())) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = name
			info.func = function()
				setValue(name)
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	optionsRefreshers[#optionsRefreshers + 1] = function()
		editBox:SetText(getValue() or "")
		UIDropDownMenu_SetText(dropdown, getValue() or "Select")
	end

	return y - 34
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
	subtitle:SetText("Configure macro names, stored targets, and review all managed macros from the Blizzard AddOns settings panel.")
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

	y = y - 14
	CreateLabel(content, "Support Spell Modifiers", 16, y)
	y = y - 26

	y = CreateModifierRow(content, y, "Blistering Scales", function()
		return EasyPrescienceDB.blisteringScalesModifier
	end, function(value)
		SetSpellModifier("blisteringScalesModifier", value, "blistering", "Blistering Scales")
	end)

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
	CreateLabel(content, "Stored Targets", 16, y)
	y = y - 26

	y = CreateTargetRow(content, y, "Prescience Shift", function()
		return EasyPrescienceDB.targets.SHIFT
	end, function(value)
		SetModifierTarget("SHIFT", value)
	end)

	y = CreateTargetRow(content, y, "Prescience Alt", function()
		return EasyPrescienceDB.targets.ALT
	end, function(value)
		SetModifierTarget("ALT", value)
	end)

	y = CreateTargetRow(content, y, "Prescience Ctrl", function()
		return EasyPrescienceDB.targets.CTRL
	end, function(value)
		SetModifierTarget("CTRL", value)
	end)

	y = CreateTargetRow(content, y, "Blistering Scales", function()
		return EasyPrescienceDB.blisteringScalesTarget
	end, function(value)
		SetDirectTarget("blisteringScalesTarget", value, "blistering", "Blistering Scales")
	end)

	y = CreateTargetRow(content, y, "Rescue", function()
		return EasyPrescienceDB.rescueTarget
	end, function(value)
		SetDirectTarget("rescueTarget", value, "rescue", "Rescue")
	end)

	y = CreateTargetRow(content, y, "Spatial Paradox", function()
		return EasyPrescienceDB.spatialParadoxTarget
	end, function(value)
		SetDirectTarget("spatialParadoxTarget", value, "spatialParadox", "Spatial Paradox")
	end)

	y = CreateTargetRow(content, y, "Verdant Embrace", function()
		return EasyPrescienceDB.verdantEmbraceTarget
	end, function(value)
		SetDirectTarget("verdantEmbraceTarget", value, "verdantEmbrace", "Verdant Embrace")
	end)

	y = y - 14
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
	helpLabel:SetText("Slash commands still work, but everything configurable is now available here. Spatial Paradox automatically swaps to Time Spiral when that talent is selected and updates again when talents change.")
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

	local cleanupButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	cleanupButton:SetSize(180, 24)
	cleanupButton:SetPoint("TOPLEFT", 16, y)
	cleanupButton:SetText("Cleanup Stored Targets")
	cleanupButton:SetScript("OnClick", function()
		CleanupStoredTargets()
	end)

	local cleanupLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	cleanupLabel:SetPoint("LEFT", cleanupButton, "RIGHT", 12, 0)
	cleanupLabel:SetWidth(420)
	cleanupLabel:SetJustifyH("LEFT")
	cleanupLabel:SetText("Normalizes saved player targets and refreshes the settings display.")
	y = y - 50

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
	for _, key in ipairs(MODIFIER_KEYS) do
		Msg("Prescience " .. DISPLAY_KEYS[key] .. " =", EasyPrescienceDB.targets[key] or "")
	end
	Msg("Blistering Scales =", EasyPrescienceDB.blisteringScalesTarget or "")
	Msg("Blistering Scales modifier =", DISPLAY_KEYS[EasyPrescienceDB.blisteringScalesModifier])
	Msg("Rescue =", EasyPrescienceDB.rescueTarget or "")
	Msg("Rescue modifier =", DISPLAY_KEYS[EasyPrescienceDB.rescueModifier])
	Msg("Spatial Paradox =", EasyPrescienceDB.spatialParadoxTarget or "")
	Msg("Spatial Paradox modifier =", DISPLAY_KEYS[EasyPrescienceDB.spatialParadoxModifier])
	Msg("Verdant Embrace =", EasyPrescienceDB.verdantEmbraceTarget or "")
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
		ReconcileManagedMacros(true)
		return
	end

	if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
		HookMenus()
		RefreshOptions()
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

	if command == "set" and rest ~= "" then
		local key, name = rest:match("^(%S+)%s+(.+)$")
		key = key and key:upper() or nil
		if not IsModifierKey(key) then
			Err("Invalid modifier. Use: shift, alt, or ctrl.")
			return
		end
		SetModifierTarget(key, name)
		return
	end

	if command == "blistering" and rest ~= "" then
		SetDirectTarget("blisteringScalesTarget", rest, "blistering", "Blistering Scales")
		return
	end

	if command == "rescue" and rest ~= "" then
		SetDirectTarget("rescueTarget", rest, "rescue", "Rescue")
		return
	end

	if command == "spatial" and rest ~= "" then
		SetDirectTarget("spatialParadoxTarget", rest, "spatialParadox", "Spatial Paradox")
		return
	end

	if command == "verdant" and rest ~= "" then
		SetDirectTarget("verdantEmbraceTarget", rest, "verdantEmbrace", "Verdant Embrace")
		return
	end

	if command == "clear" and rest ~= "" then
		local key = rest:upper()
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
		Err("Invalid clear target. Use: shift, alt, ctrl, blistering, rescue, spatial, or verdant.")
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

	if command == "cleanuptargets" then
		CleanupStoredTargets()
		return
	end

	Err("Unknown command. Type /ep or use Blizzard Settings -> AddOns -> " .. ADDON)
end

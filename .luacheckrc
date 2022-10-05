std = "lua51"
max_line_length = false
exclude_files = {
	"**/Libs",
	"**.release"
}
only = {
	"011", -- syntax
	"1", -- globals
}
ignore = {
	"11/SLASH_.*", -- slash handlers
	"1/[A-Z][A-Z][A-Z0-9_]+", -- three letter+ constants
}
globals = {
	-- wow std api
	"abs",
	"acos",
	"asin",
	"atan",
	"atan2",
	"bit",
	"ceil",
	"cos",
	"date",
	"debuglocals",
	"debugprofilestart",
	"debugprofilestop",
	"debugstack",
	"deg",
	"difftime",
	"exp",
	"fastrandom",
	"floor",
	"forceinsecure",
	"foreach",
	"foreachi",
	"format",
	"frexp",
	"geterrorhandler",
	"getn",
	"gmatch",
	"gsub",
	"hooksecurefunc",
	"issecure",
	"issecurevariable",
	"ldexp",
	"log",
	"log10",
	"max",
	"min",
	"mod",
	"rad",
	"math_random",
	"scrub",
	"securecall",
	"seterrorhandler",
	"sin",
	"sort",
	"sqrt",
	"strbyte",
	"strchar",
	"strcmputf8i",
	"strconcat",
	"strfind",
	"string.join",
	"strjoin",
	"strlen",
	"strlenutf8",
	"strlower",
	"strmatch",
	"strrep",
	"strrev",
	"strsplit",
	"strsub",
	"strtrim",
	"strupper",
	"table.wipe",
	"tan",
	"time",
	"table_insert",
	"table_remove",
	"wipe",

	-- framexml
	"getprinthandler",
	"hash_SlashCmdList",
	"setprinthandler",
	"tContains",
	"tDeleteItem",
	"tInvert",
	"tostringall",

	-- everything else
	-- Legion/TombOfSargeras/Kiljaeden.lua
	"AceGUIWidgetLSMlists",
	"AlertFrame",
	"Ambiguate",
	"ArenaCastingBarFrameTemplate",
	"ArenaEnemyFrames_CheckEffectiveEnableState",
	"ArenaEnemyFrames_Disable",
	"ArenaEnemyFrames",
	"AuraUtil",
	"BackdropTemplateMixin",
	"BasicMessageDialog",
	"BattleGroundEnemies",
	"BetterDate",
	"BigDebuffs",
	"BNGetFriendIndex",
	"BNIsSelf",
	"BNSendWhisper",
	"BossBanner",
	"ButtonFrameTemplate_HidePortrait",
	"C_BattleNet",
	"C_ChatInfo",
	"C_Covenants",
	"C_CVar",
	"C_EncounterJournal",
	"C_FriendList",
	"C_GossipInfo",
	"C_Map",
	"C_NamePlate",
	"C_PvP",
	"C_RaidLocks",
	"C_Scenario",
	"C_Spell",
	"C_Timer",
	"C_UIWidgetManager",
	"CastingBarFrame_OnLoad",
	"CastingBarFrame_SetUnit",
	"ChatFrame_ImportAllListsToHash",
	"ChatTypeInfo",
	"CheckInteractDistance",
	"CinematicFrame_CancelCinematic",
	"ClickCastFrames",
	"CloseDropDownMenus",
	"CombatLog_String_GetIcon",
	"CombatLogGetCurrentEventInfo",
	"COMPACT_UNIT_FRAME_PROFILE_DISPLAYHEALPREDICTION",
	"CompactUnitFrame_UpdateHealPrediction",
	"CreateFrame",
	"DebuffTypeColor",
	"EJ_GetCreatureInfo",
	"EJ_GetEncounterInfo",
	"EJ_GetTierInfo",
	"ElvUI",
	"EnableAddOn",
	"FauxScrollFrame_GetOffset",
	"FauxScrollFrame_OnVerticalScroll",
	"FauxScrollFrame_Update",
	"FCF_OpenTemporaryWindow",
	"FCF_SetTabPosition",
	"FCF_SetWindowName",
	"FCF_UnDockFrame",
	"FlashClientIcon",
	"GameFontHighlight",
	"GameFontNormal",
	"GameTooltip_Hide",
	"GameTooltip",
	"GetAddOnDependencies",
	"GetAddOnEnableState",
	"GetAddOnInfo",
	"GetAddOnMetadata",
	"GetAddOnOptionalDependencies",
	"GetArenaOpponentSpec",
	"GetBattlefieldArenaFaction",
	"GetBattlefieldScore",
	"GetBattlefieldTeamInfo",
	"GetBuildInfo",
	"GetClassInfo",
	"GetDifficultyInfo",
	"GetFlyoutInfo",
	"GetFlyoutSlotInfo",
	"GetFramesRegisteredForEvent",
	"GetInstanceInfo",
	"GetItemCount",
	"GetItemIcon",
	"GetItemInfo",
	"GetLocale",
	"GetLooseMacroIcons",
	"GetLooseMacroItemIcons",
	"GetMacroIcons",
	"GetMacroItemIcons",
	"GetMaxPlayerLevel",
	"GetNumAddOns",
	"GetNumArenaOpponents",
	"GetNumArenaOpponentSpecs",
	"GetNumBattlefieldScores",
	"GetNumClasses",
	"GetNumGroupMembers",
	"GetNumSpecializationsForClassID",
	"GetNumSpellTabs",
	"GetNumTrackingTypes",
	"GetPartyAssignment",
	"GetPlayerFacing",
	"GetProfessionInfo",
	"GetProfessions",
	"GetRaidRosterInfo", -- Classic/AQ40/Cthun.lua
	"GetRaidTargetIndex",
	"GetRealmName",
	"GetRealZoneText",
	"GetScreenWidth",
	"GetSpecialization",
	"GetSpecializationInfoByID",
	"GetSpecializationInfoForClassID",
	"GetSpecializationRole",
	"GetSpellBookItemInfo",
	"GetSpellBookItemName",
	"GetSpellBookItemTexture",
	"GetSpellCooldown",
	"GetSpellDescription",
	"GetSpellInfo",
	"GetSpellLink",
	"GetSpellorMacroIconInfo",
	"GetSpellTabInfo",
	"GetSpellTexture",
	"GetSubZoneText",
	"GetTexCoordsForRoleSmallCircle",
	"GetTime",
	"GetTrackedAchievements",
	"GetTrackingInfo",
	"GetUnitName",
	"IconSelectorFrameMixin",
	"InCombatLockdown",
	"IsAddOnLoaded",
	"IsAddOnLoadOnDemand",
	"IsAltKeyDown",
	"IsControlKeyDown",
	"IsEncounterInProgress",
	"IsGuildMember",
	"IsHarmfulSpell",
	"IsHelpfulSpell",
	"IsInGroup",
	"IsInInstance",
	"IsInRaid",
	"IsItemInRange",
	"IsLoggedIn",
	"IsPartyLFG",
	"IsSpellKnown",
	"IsTestBuild",
	"LFGDungeonReadyPopup",
	"LibStub",
	"LoadAddOn",
	"LOCALE_deDE",
	"LOCALE_esES",
	"LOCALE_esMX",
	"LOCALE_frFR",
	"LOCALE_itIT",
	"LOCALE_koKR",
	"LOCALE_ptBR",
	"LOCALE_ptPT",
	"LOCALE_ruRU",
	"LOCALE_zhCN",
	"LOCALE_zhTW",
	"LoggingCombat",
	"LOST_HEALTH",
	"MAX_ARENA_ENEMIES",
	"Minimap",
	"Mixin",
	"MovieFrame",
	"NO",
	"ObjectiveTrackerFrame",
	"PlayerFrame",
	"PlayerHasToy",
	"PlaySound",
	"PlaySoundFile",
	"PowerBarColor",
	"PVPMatchScoreboard",
	"RaidBossEmoteFrame",
	"RaidNotice_AddMessage",
	"RaidWarningFrame",
	"RegisterUnitWatch",
	"RequestBattlefieldScoreData",
	"RequestTicker",
	"RolePollPopup",
	"SecondsToTime",
	"SendChatMessage",
	"SetBattlefieldScoreFaction",
	"SetMapToCurrentZone",
	"SetRaidTarget",
	"SetRaidTargetIconTexture",
	"SetTracking",
	"SlashCmdList",
	"SpellGetVisibilityInfo",
	"SpellIsPriorityAura",
	"SpellIsSelfBuff",
	"StaticPopup_Show",
	"StaticPopupDialogs",
	"StopSound",
	"TargetFrame",
	"TargetFrameToT",
	"Tukui",
	"UIDropDownMenu_AddButton",
	"UIDropDownMenu_Initialize",
	"UIDropDownMenu_SetText",
	"UIDropDownMenu_SetWidth",
	"UIErrorsFrame",
	"UIParent",
	"UnitAffectingCombat",
	"UnitAura",
	"UnitCanAttack",
	"UnitCastingInfo",
	"UnitChannelInfo",
	"UnitChannelInfo",
	"UnitClass",
	"UnitDebuff",
	"UnitDetailedThreatSituation",
	"UnitExists",
	"UnitFactionGroup",
	"UnitGetTotalAbsorbs",
	"UnitGroupRolesAssigned",
	"UnitGUID",
	"UnitHealth",
	"UnitHealthMax",
	"UnitInParty",
	"UnitInRaid",
	"UnitInVehicle",
	"UnitIsConnected",
	"UnitIsCorpse",
	"UnitIsDead",
	"UnitIsDeadOrGhost",
	"UnitIsEnemy", -- Multiple old modules
	"UnitIsFriend", -- MoP/SiegeOfOrgrimmar/TheFallenProtectors.lua
	"UnitIsGhost",
	"UnitIsGroupAssistant",
	"UnitIsGroupLeader",
	"UnitIsPlayer",
	"UnitIsUnit",
	"UnitLevel",
	"UnitName",
	"UnitPhaseReason",
	"UnitPlayerControlled",
	"UnitPosition",
	"UnitPower",
	"UnitPowerMax",
	"UnitPowerType", -- Multiple old modules
	"UnitRace",
	"UnitRealmRelationship",
	"UnitSetRole",
	"UnitThreatSituation", -- Cataclysm/Bastion/Sinestra.lua
	"WorldMapFrame",
	"YES",
}
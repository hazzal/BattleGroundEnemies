local AddonName, Data = ...
local L = Data.L
local LSM = LibStub("LibSharedMedia-3.0")
local DRList = LibStub("DRList-1.0")
local LibRaces = LibStub("LibRaces-1.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local LibChangelog = LibStub("LibChangelog")

local IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local IsClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local IsTBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local IsWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

local HasSpeccs = not (IsClassic or IsTBCC or IsWrath)
local HasRBG = not (IsClassic or IsTBCC or IsWrath)

local MaxLevel = GetMaxPlayerLevel()


local LGIST
if HasSpeccs then
	LGIST=LibStub:GetLibrary("LibGroupInSpecT-1.1")
end

LSM:Register("font", "PT Sans Narrow Bold", [[Interface\AddOns\BattleGroundEnemies\Fonts\PT Sans Narrow Bold.ttf]])
LSM:Register("statusbar", "UI-StatusBar", "Interface\\TargetingFrame\\UI-StatusBar")

local BattleGroundEnemies = CreateFrame("Frame", "BattleGroundEnemies")
BattleGroundEnemies.Counter = {}

--todo, fix the testmode when the user is in a group
--todo, maybe get rid of all the onhide scripts and anchor BGE frame to UIParent
--todo add priorized auras (buffs and debuffs) like BigDebuffs

-- for Clique Support
ClickCastFrames = ClickCastFrames or {}


--upvalues
local _G = _G
local math_floor = math.floor
local gsub = gsub
local math_random = math.random
local math_max = math.max
local pairs = pairs
local print = print
local table_insert = table.insert
local table_remove = table.remove
local time = time
local type = type
local unpack = unpack

local AuraUtil = AuraUtil
local C_PvP = C_PvP
local CreateFrame = CreateFrame
local CTimerNewTicker = C_Timer.NewTicker
local GetArenaCrowdControlInfo = C_PvP.GetArenaCrowdControlInfo
local GetArenaOpponentSpec = GetArenaOpponentSpec
local GetBattlefieldArenaFaction = GetBattlefieldArenaFaction
local GetBattlefieldScore = GetBattlefieldScore
local GetBattlefieldTeamInfo = GetBattlefieldTeamInfo
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetItemIcon = GetItemIcon
local GetNumBattlefieldScores = GetNumBattlefieldScores
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local GetTime = GetTime
local GetUnitName = GetUnitName
local InCombatLockdown = InCombatLockdown
local IsInBrawl = C_PvP.IsInBrawl
local isInGroup =  IsInGroup
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local IsItemInRange = IsItemInRange
local IsRatedBattleground = C_PvP.IsRatedBattleground
local PowerBarColor = PowerBarColor --table
local RequestBattlefieldScoreData = RequestBattlefieldScoreData
local RequestCrowdControlSpell = C_PvP.RequestCrowdControlSpell
local SetBattlefieldScoreFaction = SetBattlefieldScoreFaction
local UnitExists = UnitExists
local UnitFactionGroup = UnitFactionGroup
local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsGhost = UnitIsGhost
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitRace = UnitRace
local UnitRealmRelationship = UnitRealmRelationship

if not GetUnitName then
	GetUnitName = function(unit, showServerName)
		local name, server = UnitName(unit);

		if ( server and server ~= "" ) then
			if ( showServerName ) then
				return name.."-"..server;
			else
				local relationship = UnitRealmRelationship(unit);
				if (relationship == LE_REALM_RELATION_VIRTUAL) then
					return name;
				else
					return name..FOREIGN_SERVER_LABEL;
				end
			end
		else
			return name;
		end
	end
end

--variables used in multiple functions, if a variable is only used by one function its declared above that function
--BattleGroundEnemies.BattlegroundBuff --contains the battleground specific enemy buff to watchout for of the current active battlefield
BattleGroundEnemies.BattleGroundDebuffs = {} --contains battleground specific debbuffs to watchout for of the current active battlefield
BattleGroundEnemies.IsRatedBG = false
BattleGroundEnemies.CurrentMapID = false --contains the map id of the current active battleground
BattleGroundEnemies.ButtonModules = {} --contains moduleFrames, key is the module name

local playerFaction = UnitFactionGroup("player")
local PlayerButton --the button of the Player himself
local PlayerLevel = UnitLevel("player")
local IsInArena --wheter or not the player is in a arena map
local specCache = {} -- key = GUID, value = specName (localized)

local function CreateFakeAura(playerButton, filter)
	local foundA = Data.FoundAuras[filter]

	local auraTable
	local addDRAura
	if filter == "HARMFUL" then
		addDRAura = math_random(1,5) == 1 -- 20% probability to get diminishing Aura Applied
	end

	local unitCaster, canApplyAura, castByPlayer

	if addDRAura and #foundA.foundDRAuras > 0 then

		auraTable = foundA.foundDRAuras
	else
		local addPlayerAura = math_random(1,5) == 1 --20% probablility to add a player Aura if no DR was applied
		if addPlayerAura then
			unitCaster = "player"
			canApplyAura = true
			castByPlayer = true

			auraTable = foundA.foundPlayerAuras
		else

			auraTable = foundA.foundNonPlayerAuras
		end
	end
	if not auraTable or (#auraTable <1 ) then return end
	local whichAura = math_random(1, #auraTable)
	local auraToSend = auraTable[whichAura]

	local newAura = {
		name 					= GetSpellInfo(auraToSend.spellID),
		icon 					= auraToSend.icon,
		count 					= auraToSend.count,
		debuffType 				= auraToSend.debuffType,
		duration 				= auraToSend.duration,
		expirationTime 			= GetTime() + auraToSend.duration,
		unitCaster 				= unitCaster or auraToSend.unitCaster,
		canStealOrPurge 		= auraToSend.canStealOrPurge,
		nameplateShowPersonal	= auraToSend.nameplateShowPersonal,
		spellID 				= auraToSend.spellID,
		canApplyAura 			= canApplyAura or auraToSend.canApplyAura,
		isBossAura 				= auraToSend.isBossAura,
		castByPlayer 			= castByPlayer or auraToSend.castByPlayer,
		nameplateShowAll 		= auraToSend.nameplateShowAll,
		timeMod					= auraToSend.timeMod,
	}

	return newAura
end


local FakePlayerAuras = {} --key = playerbutton, value = {}
local FakePlayerDRs = {} --key = playerButtonTabe, value = {categoryname = {state = 0, expirationTime}}
local function FakeUnitAura(playerButton, index, filter)
	local currentTime = GetTime()

	FakePlayerAuras[playerButton] = FakePlayerAuras[playerButton] or {}
	FakePlayerAuras[playerButton][filter] = FakePlayerAuras[playerButton][filter] or {}
	FakePlayerDRs[playerButton] = FakePlayerDRs[playerButton] or {}

	local createNewAura = math_random(1, 13) == 1 -- 1/13 probability to create a new Aura
	if createNewAura then
		local newFakeAura = CreateFakeAura(playerButton, filter)
		if newFakeAura then
			local dontAddNewAura
			for i = 1, #FakePlayerAuras[playerButton][filter] do
				local fakeAura = FakePlayerAuras[playerButton][filter][i]
				if fakeAura.spellID == newFakeAura.spellID then

					local category = DRList:GetCategoryBySpellID(IsClassic and fakeAura.name or fakeAura.spellID)
					-- we already are showing this spell, check if this spell is a DR
					if category then
						FakePlayerDRs[playerButton][category] = FakePlayerDRs[playerButton][category] or {}
						FakePlayerDRs[playerButton][category].status = FakePlayerDRs[playerButton][category].status or 0
						--remove set the expired time of the existing DR aura to the past so it will be removed
						fakeAura.expirationTime = currentTime - 1

						--we removed the aura so we already increased the dr state. Lets say we had a full duration sheep on us(state 0), we removed it, new one will be half duration(state 1)
						local status = FakePlayerDRs[playerButton][category].status + 1
						if status <= 2 then
							local duration = newFakeAura.duration / 2^status
							newFakeAura.duration = duration
							fakeAura.expirationTime = currentTime + duration
						else
							dontAddNewAura = true -- we are at full DR and we can't apply the aura for a fourth time
						end

						break
					else
						dontAddNewAura = true --we tried to apply the same spell twice but its not a DR, dont add it, we dont wan't to clutter it
					break
					end
				end
			end

			if not dontAddNewAura then
				table_insert(FakePlayerAuras[playerButton][filter], newFakeAura)
			end

		end
	end



	-- remove all expired auras
	for i = #FakePlayerAuras[playerButton][filter], 1, -1 do
		local fakeAura = FakePlayerAuras[playerButton][filter][i]
		if fakeAura.expirationTime < currentTime then
			local category = DRList:GetCategoryBySpellID(IsClassic and fakeAura.name or fakeAura.spellID)
			if category then
				FakePlayerDRs[playerButton][category] = FakePlayerDRs[playerButton][category] or {}

				local resetDuration = DRList:GetResetTime(category)
				if FakePlayerDRs[playerButton][category].expirationTime and currentTime - FakePlayerDRs[playerButton][category].expirationTime > resetDuration then
					FakePlayerDRs[playerButton][category].status = 0
				else
					FakePlayerDRs[playerButton][category].expirationTime = fakeAura.expirationTime + resetDuration
					FakePlayerDRs[playerButton][category].status = (FakePlayerDRs[playerButton][category].status or 0) + 1
				end
			end

			table_remove(FakePlayerAuras[playerButton][filter], i)
			playerButton:AuraRemoved(fakeAura.spellID, fakeAura.name)
		end
	end



	local aura = FakePlayerAuras[playerButton][filter][index]
	if not aura then return end

	return aura.name, aura.icon, aura.count, aura.debuffType, aura.duration, aura.expirationTime, aura.unitCaster, aura.canStealOrPurge, aura.nameplateShowPersonal, aura.spellID, aura.canApplyAura, aura.isBossAura, aura.castByPlayer, aura.nameplateShowAll, aura.timeMod
end

local maxHealths = {}  --key = playerbutton, value = {}
local deadPlayers = {}
local function FakeUnitHealthMax(playerButton)
	if not maxHealths[playerButton] then
		local myMaxHealth = UnitHealthMax("player")
		local playerMaxHealthDifference = math_random(-15, 15) -- the player has the same health as me +/- 15%
		local playerMaxHealth = myMaxHealth * (1 + (playerMaxHealthDifference/100))
		maxHealths[playerButton] = playerMaxHealth
	end
	return maxHealths[playerButton]
end

local function FakeUnitHealth(playerButton)
	local now = GetTime()
	if deadPlayers[playerButton] then
		--this player is dead, check if we can revive him
		if deadPlayers[playerButton] + 26 < now then -- he died more than 26 seconds ago
			deadPlayers[playerButton] = nil
		else
			return 0-- let the player be dead
		end
	end
	local maxHealth = FakeUnitHealthMax(playerButton)

	local health = math_random(0, 100)
	if health == 0 then
		deadPlayers[playerButton] = now
		playerButton:PlayerDied()
		return 0
	else
		return math_floor((health/100) * maxHealth)
	end
end

-- returns true if <frame> or one of the frames that <frame> is dependent on is anchored to <otherFrame> and nil otherwise
-- dont ancher to otherframe is
function BattleGroundEnemies:IsFrameDependentOnFrame(frame, otherFrame)
	if frame == nil then
		return false
	end

	if otherFrame == nil then
		return false
	end

	if frame == otherFrame then
		return true
	end

	local points = frame:GetNumPoints()
	for i = 1, points do
		local _, relFrame = frame:GetPoint(i)
		if relFrame and self:IsFrameDependentOnFrame(relFrame, otherFrame) then
			return true
		end
	end
end




local enemyButtonFunctions = {}
do
	function enemyButtonFunctions:FetchAnAllyUnitID()
		local unitIDs = self.UnitIDs
		if unitIDs.Ally then
			unitIDs.Active = unitIDs.Ally
			unitIDs.HasAllyUnitID = true
			self:NewUnitID()
		else
			self:DeleteActiveUnitID()
		end
	end

	--Remove from OnUpdate
	function enemyButtonFunctions:DeleteActiveUnitID() --Delete from OnUpdate
		--BattleGroundEnemies:Debug("DeleteActiveUnitID")
		local unitIDs = self.UnitIDs
		unitIDs.Active = false
		self:UpdateRange(false)


		unitIDs.HasAllyUnitID = false
	end

	function enemyButtonFunctions:FetchAnotherUnitID(key, value)
		local unitIDs = self.UnitIDs
		if key then
			unitIDs[key] = value
		end

		unitIDs.Active = unitIDs.Arena or unitIDs.Nameplate or unitIDs.Target or unitIDs.Focus
		if unitIDs.Active then
			unitIDs.HasAllyUnitID = false
			self:NewUnitID()
		else
			self:FetchAnAllyUnitID()
		end
	end

	function enemyButtonFunctions:NowTargetedBy(allyButton)
		local unitIDs = self.UnitIDs
		if not unitIDs.Ally then
			unitIDs.Ally = allyButton.TargetUnitID
			self:FetchAnotherUnitID()
		end

		unitIDs.TargetedByEnemy[allyButton] = true
		self:UpdateTargetIndicators()
	end

	function enemyButtonFunctions:NoLongerTargetedBy(allyButton)
		local unitIDs = self.UnitIDs


		if allyButton.TargetUnitID == unitIDs.Ally then
			unitIDs.Ally = false
			for allyButton in pairs(unitIDs.TargetedByEnemy) do
				if not allyButton.TargetUnitID == "target" then
					unitIDs.Ally = allyButton.TargetUnitID
					break
				end
			end
		end

		if allyButton.TargetUnitID == unitIDs.Active then
			self:FetchAnAllyUnitID()
		end

		unitIDs.TargetedByEnemy[allyButton] = nil
		self:UpdateTargetIndicators()
	end

end


local buttonFunctions = {}

do


	function buttonFunctions:OnDragStart()
		return BattleGroundEnemies.db.profile.Locked or self:GetParent():StartMoving()
	end


	function buttonFunctions:OnDragStop()
		local parent = self:GetParent()
		parent:StopMovingOrSizing()
		if not InCombatLockdown() then
			local scale = self:GetEffectiveScale()
			self.bgSizeConfig.Position_X = parent:GetLeft() * scale
			self.bgSizeConfig.Position_Y = parent:GetTop() * scale
		end
	end

	function buttonFunctions:SetSpecAndRole()
		if self.PlayerSpecName then
			local specData = Data.Classes[self.PlayerClass][self.PlayerSpecName]
			self.PlayerSpecID = specData.specID
			self.PlayerRoleNumber = specData.roleNumber
			self.PlayerRoleID = specData.roleID
		end
		self:DispatchEvent("SetSpecAndRole")
	end

	function buttonFunctions:UpdateRaidTargetIcon()
		local unit = self:GetUnitID()
		if unit then
			local index = GetRaidTargetIndex(unit)
			if index then
				if index == 8 and (not self.HasIcon or self.HasIcon ~= 8) then
					if BattleGroundEnemies.IsRatedBG and BattleGroundEnemies.db.profile.RBG.TargetCalling_NotificationEnable then
						local path = LSM:Fetch("sound", BattleGroundEnemies.db.profile.RBG.TargetCalling_NotificationSound, true)
						if path then
							PlaySoundFile(path, "Master")
						end
					end
				end
				self.HasIcon = index
			else
				self.HasIcon = nil
			end
		else
			self.HasIcon = nil
		end
		self:DispatchEvent("UpdateRaidTargetIcon")
	end

	function buttonFunctions:NewUnitID(unitID, targetUnitID)
		if self.PlayerIsEnemy then
			local activeUnitID = self.UnitIDs.Active
			if not UnitExists(activeUnitID) then return end
			self:UpdateRaidTargetIcon()
			self:UpdateAll(activeUnitID)
		else
			self.unit = unitID
			self.TargetUnitID = targetUnitID
			if not InCombatLockdown() then
				self:SetAttribute('unit', unitID)
				BattleGroundEnemies.Allies:SortPlayers()
			else
				C_Timer.After(1, function() return BattleGroundEnemies:GROUP_ROSTER_UPDATE() end)
			end
		end
		self:DispatchEvent("NewUnitID", unitID)
	end

	function buttonFunctions:SetModulePositions()
		if not self:GetRect() then return end --the position of the button is not set yet
		local i = 1
		repeat -- we basically run this roop to get out of the anchring hell (making sure all the frames that a module is depending on is set)
			local allModulesSet = true
			for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
				local moduleConfigOnButton = self.bgSizeConfig.ButtonModules[moduleName]
				local moduleFrameOnButton = self[moduleName]
				moduleFrameOnButton.config = moduleConfigOnButton

				local config = moduleFrameOnButton.config
				if not config then return end


				if config.Points then
					if i == 1 then moduleFrameOnButton:ClearAllPoints() end

					for j = 1, #config.Points do
						local pointConfig = config.Points[j]

						local relativeFrame = self:GetAnchor(pointConfig.RelativeFrame)
						if not (relativeFrame:GetNumPoints() > 0) then
							-- the module we are depending on hasn't been set yet
							allModulesSet = false


						else
							if not relativeFrame then return print("error", relativeFrame, "doesnt exist") end
							moduleFrameOnButton:SetPoint(pointConfig.Point, relativeFrame, pointConfig.RelativePoint, pointConfig.OffsetX or 0, pointConfig.OffsetY or 0)


						end
						if moduleFrame.flags.Height == "Dynamic" then moduleFrameOnButton:SetHeight(0.001) end --set a dummy, otherweise other modules attached to this module wont get set correctly
						if moduleFrame.flags.Width == "Dynamic" then moduleFrameOnButton:SetWidth(0.001) end --set a dummy, otherweise other modules attached to this module wont get set correctly
					end
				end
				if config.Parent then
					moduleFrameOnButton:SetParent(self:GetAnchor(config.Parent))
				end


				if not moduleFrameOnButton.Enabled and moduleFrame.flags.SetZeroWidthWhenDisabled then
					moduleFrameOnButton:SetWidth(0.001)
				else
					if config.UseButtonHeightAsWidth then
						moduleFrameOnButton:SetWidth(self:GetHeight())
					else
						if config.Width then
							moduleFrameOnButton:SetWidth(config.Width)
						end
					end
				end


				if not moduleFrameOnButton.Enabled and moduleFrame.flags.SetZeroHeightWhenDisabled then
					moduleFrameOnButton:SetHeight(0.001)
				else
					if config.UseButtonHeightAsHeight then
						moduleFrameOnButton:SetHeight(self:GetHeight())
					else
						if config.Height then
							moduleFrameOnButton:SetHeight(config.Height)
						end
					end
				end
			end

			self.MyTarget:SetParent(self.healthBar)
			self.MyTarget:SetPoint("TOPLEFT", self.healthBar, "TOPLEFT")
			self.MyTarget:SetPoint("BOTTOMRIGHT", self.Power, "BOTTOMRIGHT")
			self.MyFocus:SetParent(self.healthBar)
			self.MyFocus:SetPoint("TOPLEFT", self.healthBar, "TOPLEFT")
			self.MyFocus:SetPoint("BOTTOMRIGHT", self.Power, "BOTTOMRIGHT")

			i = i + 1
			if i > 5 then print("something went wrong in SetModulePositions") end
		until allModulesSet or i > 5
	end

	function buttonFunctions:ApplyButtonSettings()
		self.config = self:GetParent().config
		self.bgSizeConfig = self:GetParent().bgSizeConfig
		local conf = self.bgSizeConfig

		self:SetWidth(conf.BarWidth)
		self:SetHeight(conf.BarHeight)

		self:ApplyRangeIndicatorSettings()

		-- auras on spec

		--MyTarget, indicating the current target of the player
		self.MyTarget:SetBackdropBorderColor(unpack(BattleGroundEnemies.db.profile.MyTarget_Color))

		--MyFocus, indicating the current focus of the player
		self.MyFocus:SetBackdropBorderColor(unpack(BattleGroundEnemies.db.profile.MyFocus_Color))

		wipe(self.ButtonEvents)
		for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
			local moduleConfigOnButton = self.bgSizeConfig.ButtonModules[moduleName]
			local moduleFrameOnButton = self[moduleName]
			moduleFrameOnButton.config = moduleConfigOnButton
			if moduleConfigOnButton.Enabled then
				if moduleFrame.events then
					for i = 1, #moduleFrame.events do
						local event = moduleFrame.events[i]
						self.ButtonEvents[event] = self.ButtonEvents[event] or {}

						table_insert(self.ButtonEvents[event], moduleFrameOnButton)
					end
				end
				moduleFrameOnButton.Enabled = true
				moduleFrameOnButton:Show()
				if moduleFrameOnButton.Enable then moduleFrameOnButton:Enable() end
				if moduleFrameOnButton.ApplyAllSettings then moduleFrameOnButton:ApplyAllSettings() end
			else
				moduleFrameOnButton.Enabled = false
				moduleFrameOnButton:Hide()
				if moduleFrameOnButton.Disable then moduleFrameOnButton:Disable() end
				if moduleFrameOnButton.Reset then moduleFrameOnButton:Reset() end
			end
		end

		self:SetModulePositions()

		--Auras
		--self.DebuffContainer:ApplySettings()
		--self.BuffContainer:ApplySettings()
	end





	do
		local mouseButtons = {
			[1] = "LeftButton",
			[2] = "RightButton",
			[3] = "MiddleButton"
		}

		function buttonFunctions:SetBindings()

			if not self.PlayerIsEnemy and BattleGroundEnemies.db.profile[self.PlayerType].UseClique then
				BattleGroundEnemies:Debug("Clique used")
				ClickCastFrames[self] = true
			else
				if ClickCastFrames[self] then
					ClickCastFrames[self] = nil
				end

				self:RegisterForClicks('AnyUp')
				self:SetAttribute('type1','macro')-- type1 = LEFT-Click
				self:SetAttribute('type2','macro')-- type2 = Right-Click
				self:SetAttribute('type3','macro')-- type3 = Middle-Click

				for i = 1, 3 do

					local bindingType = self.config[mouseButtons[i].."Type"]

					if bindingType == "Target" then
						self:SetAttribute('macrotext'..i,
							'/cleartarget\n'..
							'/targetexact '..self.PlayerName
						)
					elseif bindingType == "Focus" then
						self:SetAttribute('macrotext'..i,
							'/targetexact '..self.PlayerName..'\n'..
							'/focus\n'..
							'/targetlasttarget'
						)

					else -- Custom
						local macrotext = (BattleGroundEnemies.db.profile[self.PlayerType][mouseButtons[i].."Value"]):gsub("%%n", self.PlayerName)
						self:SetAttribute('macrotext'..i, macrotext)
					end
				end
			end
		end
	end

	function buttonFunctions:PlayerDied(unitID) --gets health of nameplates, player, target, focus, raid1 to raid40, partymember
		self:DispatchEvent("UnitDied")
		self.isDead = true
	end



	function buttonFunctions:UNIT_HEALTH(unitID) --gets health of nameplates, player, target, focus, raid1 to raid40, partymember
		local healthFunc = UnitHealth
		local healthMaxFunc = UnitHealthMax
		if self.isFakePlayer then
			healthFunc = function(unitID)
				return FakeUnitHealth(self)
			end
			healthMaxFunc = function(unitID)
				return FakeUnitHealthMax(self)
			end
		end

		local health = healthFunc(unitID)
		local maxHealth = healthMaxFunc(unitID)
		self:DispatchEvent("UpdateHealth", unitID, health, maxHealth)
		if unitID then
			if UnitIsDeadOrGhost(unitID) then
				self:PlayerDied()
			else
				self.isDead = false
			end
		else
			-- we are in testmode
			self.isDead = health == 0
		end
	end

	function buttonFunctions:ApplyRangeIndicatorSettings()
		if self.config.RangeIndicator_Enabled then
			if self.config.RangeIndicator_Everything then
				for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
					self[frameName]:SetAlpha(1)
				end
				self:SetAlpha(self.wasInRange and 1 or self.config.RangeIndicator_Alpha)
			else
				for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
					if enableRange then
						self[frameName]:SetAlpha(self.wasInRange and 1 or self.config.RangeIndicator_Alpha)
					else
						self[frameName]:SetAlpha(1)
					end
				end
				self:SetAlpha(1)
			end
		else
			for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
				self[frameName]:SetAlpha(1)
			end
			self:SetAlpha(1)
		end
	end

	function buttonFunctions:ArenaOpponentShown(unitID)
		if unitID then
			BattleGroundEnemies.ArenaIDToPlayerButton[unitID] = self
			if self.PlayerIsEnemy then
				self:FetchAnotherUnitID("Arena", unitID)
			end
			RequestCrowdControlSpell(unitID)
		end
		self:DispatchEvent("ArenaOpponentShown")
	end

	-- Shows/Hides targeting indicators for a button
	function buttonFunctions:UpdateTargetIndicators()
		self:DispatchEvent("UpdateTargetIndicators")
		BattleGroundEnemies.Counter.UpdateTargetIndicators = (BattleGroundEnemies.Counter.UpdateTargetIndicators or 0) + 1
		local isAlly = false
		local isPlayer = false

		if self == PlayerButton then
			isPlayer = true
		elseif not self.PlayerIsEnemy then
			isAlly = true
		end

		local i = 1
		for enemyButton in pairs(self.UnitIDs.TargetedByEnemy) do
			i = i + 1
		end

		local enemyTargets = i - 1

		if BattleGroundEnemies.IsRatedBG then
			if isAlly then
				if BattleGroundEnemies.db.profile.RBG.EnemiesTargetingAllies_Enabled then
					if enemyTargets >= (BattleGroundEnemies.db.profile.RBG.EnemiesTargetingAllies_Amount or 1)  then
						local path = LSM:Fetch("sound", BattleGroundEnemies.db.profile.RBG.EnemiesTargetingAllies_Sound, true)
						if path then
							PlaySoundFile(path, "Master")
						end
					end
				end
			end
			if isPlayer then
				if BattleGroundEnemies.db.profile.RBG.EnemiesTargetingMe_Enabled then
					if enemyTargets >= BattleGroundEnemies.db.profile.RBG.EnemiesTargetingMe_Amount  then
						local path = LSM:Fetch("sound", BattleGroundEnemies.db.profile.RBG.EnemiesTargetingMe_Sound, true)
						if path then
							PlaySoundFile(path, "Master")
						end
					end
				end
			end
		end
	end

	function buttonFunctions:UpdateRange(inRange)
		BattleGroundEnemies.Counter.UpdateRange = (BattleGroundEnemies.Counter.UpdateRange or 0) + 1
		--BattleGroundEnemies:Information("UpdateRange", inRange, self.PlayerName, self.config.RangeIndicator_Enabled, self.config.RangeIndicator_Alpha)

		if not self.config.RangeIndicator_Enabled then return end

		if inRange ~= self.wasInRange then
			if self.config.RangeIndicator_Everything then
				self:SetAlpha(inRange and 1 or self.config.RangeIndicator_Alpha)
			else
				for frameName, enableRange in pairs(self.config.RangeIndicator_Frames) do
					if enableRange then
						self[frameName]:SetAlpha(inRange and 1 or self.config.RangeIndicator_Alpha)
					else
						self[frameName]:SetAlpha(1)
					end
				end
			end
			self.wasInRange = inRange
		end
	end

	function buttonFunctions:GetUnitID()
		return (self.PlayerIsEnemy and self.UnitIDs.Active) or self.unit
	end


	function buttonFunctions:UpdateAll(unitID)
		self:UpdateRange(IsItemInRange(self.config.RangeIndicator_Range, unitID))
		self:UNIT_HEALTH(unitID)
		self:UNIT_POWER_FREQUENT(unitID)
		self:UNIT_AURA(unitID)
	end


	function buttonFunctions:AuraRemoved(spellID, spellName)
		BattleGroundEnemies.Counter.AuraRemoved = (BattleGroundEnemies.Counter.AuraRemoved or 0) + 1

		self:DispatchEvent("AuraRemoved", spellID, spellName)
		--BattleGroundEnemies:Debug(operation, spellID)
	end


	function buttonFunctions:ShouldSkipAuraUpdate(isFullUpdate, updatedAuraInfos, isRelevantFunc, unitID)
		if isFullUpdate then return false end
		-- Early out if the update cannot affect the frame

		local skipUpdate = false
		if updatedAuraInfos and isRelevantFunc then
			skipUpdate = true
			for i = 1, #updatedAuraInfos do
				local auraInfo = updatedAuraInfos[i]

				if isRelevantFunc(self, unitID, auraInfo) then
					skipUpdate = false
					break
				end
			end
		end
		return skipUpdate
	end

	function buttonFunctions:ShouldDisplayAura(unitID, auraInfo, filter, spellID, unitCaster, canStealOrPurge, canApplyAura, debuffType)
		BattleGroundEnemies.Counter.ShouldDisplayAura = (BattleGroundEnemies.Counter.ShouldDisplayAura or 0) + 1


		if self:DispatchUntilTrue("CareAboutThisAura", unitID, auraInfo, filter, spellID, unitCaster, canStealOrPurge, canApplyAura, debuffType) then return true end
		return false --nobody cares about this aura
	end


	--[[


	updatedAuraInfos = {  Optional table of information about changed auras.


		Key						Type		Description
		canApplyAura			boolean		Whether or not the player can apply this aura.
		debuffType				string		Type of debuff this aura applies. May be an empty string.
		isBossAura				boolean		Whether or not this aura was applied by a boss.
		isFromPlayerOrPlayerPet	boolean		Whether or not this aura was applied by the player or their pet.
		isHarmful				boolean		Whether or not this aura is a debuff.
		isHelpful				boolean		Whether or not this aura is a buff.
		isNameplateOnly			boolean		Whether or not this aura should appear on nameplates.
		isRaid					boolean		Whether or not this aura meets the conditions of the RAID aura filter.
		name					string		The name of the aura.
		nameplateShowAll		boolean		Whether or not this aura should be shown on all nameplates, instead of just the personal one.
		sourceUnit				UnitId		Token of the unit that applied the aura.
		spellId					number		The spell ID of the aura.
	}

	]]
	function buttonFunctions:UNIT_AURA(unitID, isFullUpdate, updatedAuraInfos)
		--[[ local time = GetTime()
		if time - (self.lastAuraScan or 0) < 0.1 then return end
		self.lastAuraScan = time ]]

		if self:ShouldSkipAuraUpdate(isFullUpdate, updatedAuraInfos, self.ShouldDisplayAura, unitID) then
			return
		end

		local filters = {"HELPFUL", "HARMFUL"}
		local batchCount = 20 -- TODO make this a option the player can choose, maximum amount of buffs / debuffs
		local shouldQueryAuras

		for i = 1, #filters do
			local filter = filters[i]

			shouldQueryAuras = self:DispatchUntilTrue("ShouldQueryAuras", unitID, filter) --ask all subscribers/modules if Aura Scanning is necessary for this filter
			if shouldQueryAuras then
				self:DispatchEvent("BeforeUnitAura", unitID, filter)

				if AuraUtil.ForEachAura and not self.isFakePlayer then
					AuraUtil.ForEachAura(unitID, filter, batchCount, function(...)
						self:DispatchEvent("UnitAura", unitID, filter, ...)
					end)
				else
					local auraFunc = UnitAura
					if self.isFakePlayer then
						auraFunc = function(unitID, i, filter)
							return FakeUnitAura(self, i, filter)
						end
					end
					for i = 1, batchCount do
						local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellID, canApplyAura, isBossAura, castByPlayer, nameplateShowAll, timeMod, value1, value2, value3, value4 = auraFunc(unitID, i, filter)

						if not name then break end
						self:DispatchEvent("UnitAura", unitID, filter, name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellID, canApplyAura, isBossAura, castByPlayer, nameplateShowAll, timeMod, value1, value2, value3, value4)
					end
				end
				self:DispatchEvent("AfterUnitAura", filter)
			end
		end
	end


	buttonFunctions.UNIT_HEALTH_FREQUENT = buttonFunctions.UNIT_HEALTH --TBC compability, IsTBCC
	buttonFunctions.UNIT_MAXHEALTH = buttonFunctions.UNIT_HEALTH
	buttonFunctions.UNIT_HEAL_PREDICTION = buttonFunctions.UNIT_HEALTH
	buttonFunctions.UNIT_ABSORB_AMOUNT_CHANGED = buttonFunctions.UNIT_HEALTH
	buttonFunctions.UNIT_HEAL_ABSORB_AMOUNT_CHANGED = buttonFunctions.UNIT_HEALTH


	function buttonFunctions:UNIT_POWER_FREQUENT(unitID, powerToken) --gets power of nameplates, player, target, focus, raid1 to raid40, partymember
		self:DispatchEvent("UNIT_POWER_FREQUENT", unitID, powerToken)
	end

	function buttonFunctions:UpdateTargets()
		BattleGroundEnemies.Counter.UpdateTargets = (BattleGroundEnemies.Counter.UpdateTargets or 0) + 1

		local oldTargetPlayerButton = self.Target
		local newTargetPlayerButton



		if self.PlayerIsEnemy then
			newTargetPlayerButton = BattleGroundEnemies.Allies:GetPlayerbuttonByUnitID((self.UnitIDs.Active or "") .."target")
		else
			newTargetPlayerButton = BattleGroundEnemies.Enemies:GetPlayerbuttonByUnitID(self.TargetUnitID or "")
		end

		if newTargetPlayerButton and oldTargetPlayerButton == newTargetPlayerButton then return end

		if oldTargetPlayerButton then
			oldTargetPlayerButton:NoLongerTargetedBy(self)
		end

		if newTargetPlayerButton then --player targets an existing player and not for example a pet or a NPC
			newTargetPlayerButton:NowTargetedBy(self)
			self.Target = newTargetPlayerButton
			--print(newTargetPlayerButton.DisplayedName, "is now targeted by", self.PlayerName)
		else
			self.Target = false
		end
	end

	function buttonFunctions:DispatchEvent(event, ...)
		if not self.ButtonEvents then return end

		local moduleFrames = self.ButtonEvents[event]

		if not moduleFrames then return end
		for i = 1, #moduleFrames do
			local moduleFrameOnButton = moduleFrames[i]
			if moduleFrameOnButton[event] then
				moduleFrameOnButton[event](moduleFrameOnButton, ...)
			else
				BattleGroundEnemies:OnetimeInformation("Event:", event, "There is no key with the event name for this module",  moduleFrameOnButton.moduleName)
			end
		end
	end

	-- used for the AuraInfo (third return of UNIT_AURA) of UNIT_AURA, we dispatch until one of the consumers (modules) returns true, then we proceed with aura scanning
	function buttonFunctions:DispatchUntilTrue(event, ...)

		local moduleFrames = self.ButtonEvents[event]
		if not moduleFrames then return end

		for i = 1, #moduleFrames do
			local moduleFrameOnButton = moduleFrames[i]
			if moduleFrameOnButton[event] then
				if moduleFrameOnButton[event](moduleFrameOnButton, ...) then return true end
			else
				BattleGroundEnemies:OnetimeInformation("Event:", event, "There is no key with the event name for this module",  moduleFrameOnButton.moduleName)
			end
		end
	end

	function buttonFunctions:GetAnchor(relativeFrame)
		return relativeFrame == "Button" and self or self[relativeFrame]
	end

	-- function buttonFunctions:SetModulePosition(moduleFrameOnButton)
	-- 	local config = moduleFrameOnButton.config
	-- 	if not config then return print("no config exists") end

	-- 	local point, relativeFrame, relativePoint, offsetX, offsetY
	-- 	if config.Points then
	-- 		moduleFrameOnButton:ClearAllPoints()

	-- 		for i = 1, #config.Points do
	-- 			local pointConfig = config.Points[i]

	-- 			relativeFrame = self:GetAnchor(pointConfig.RelativeFrame)
	-- 			if not relativeFrame:GetRect() then
	-- 				-- the module we are depending on hasn't been set yet

	-- 			else
	-- 				if not relativeFrame then return print("error", relativeFrame, "doesnt exist") end
	-- 				moduleFrameOnButton:SetPoint(pointConfig.Point, relativeFrame, pointConfig.RelativePoint, pointConfig.OffsetX or 0, pointConfig.OffsetY or 0)
	-- 			end
	-- 		end
	-- 	end
	-- 	if config.Parent then
	-- 		moduleFrameOnButton:SetParent(self:GetAnchor(config.Parent))
	-- 	end
	-- 	if config.UseButtonHeightAsWidth then
	-- 		moduleFrameOnButton:SetWidth(self:GetHeight())
	-- 	else
	-- 		if config.Width then
	-- 			moduleFrameOnButton:SetWidth(config.Width)
	-- 		end
	-- 	end
	-- 	if config.UseButtonHeightAsHeight then
	-- 		moduleFrameOnButton:SetHeight(self:GetHeight())
	-- 	else
	-- 		if config.Height then
	-- 			moduleFrameOnButton:SetHeight(config.Height)
	-- 		end
	-- 	end
	-- end
end

local allyButtonFunctions = {}
do

	function allyButtonFunctions:NowTargetedBy(enemyButton)
		self.UnitIDs.TargetedByEnemy[enemyButton] = true
		self:UpdateTargetIndicators()
	end

	function allyButtonFunctions:NoLongerTargetedBy(enemyButton)
		self.UnitIDs.TargetedByEnemy[enemyButton] = nil
		self:UpdateTargetIndicators()
	end
end


local function PopulateMainframe(playerType)
	local self = BattleGroundEnemies[playerType]
	self.Players = {} --index = name, value = button(table), contains enemyButtons
	self.CurrentPlayerOrder = {} --index = number, value = playerButton(table)
	self.InactivePlayerButtons = {} --index = number, value = button(table)
	self.NewPlayerDetails = {} -- index = name, value = playerdetails, used for creation of new buttons, use (temporary) table to not create an unnecessary new button if another player left
	self.PlayerType = playerType
	self.NumShownPlayers = 0

	self.config = BattleGroundEnemies.db.profile[playerType]

	function self:ApplyAllSettings()
		--BattleGroundEnemies:Debug(self.PlayerType)
		if BattleGroundEnemies.BGSize then self:ApplyBGSizeSettings() end
	end

	function self:ApplyBGSizeSettings()
		--if not BattleGroundEnemies.BGSize then return end
		self.config = BattleGroundEnemies.db.profile[self.PlayerType]
		if InCombatLockdown() then
			return C_Timer.After(1, function() self:ApplyBGSizeSettings() end)
		end
		self.bgSizeConfig = self.config[tostring(BattleGroundEnemies.BGSize)]

		local conf = self.bgSizeConfig

		self:SetSize(conf.BarWidth, 30)
		self:SetScale(conf.Framescale)

		self:ClearAllPoints()
		if not conf.Position_X and not conf.Position_Y then
			self:SetPoint("CENTER", UIParent, "CENTER")
		else
			local scale = self:GetEffectiveScale()
			self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", conf.Position_X / scale, conf.Position_Y / scale)
		end
		self:SetPlayerCountJustifyV(conf.BarVerticalGrowdirection)

		self.PlayerCount:ApplyFontStringSettings(conf.PlayerCount.Text)

		self:SortPlayers()

		for name, playerButton in pairs(self.Players) do
			playerButton:ApplyButtonSettings()

			playerButton:SetBindings()
		end


		for number, playerButton in pairs(self.InactivePlayerButtons) do
			playerButton:ApplyButtonSettings()
		end

		self:UpdatePlayerCount()
		self:UpdateVisibility()
	end

	function self:UpdateVisibility()
		if self.config.Enabled and BattleGroundEnemies.BGSize and self.bgSizeConfig.Enabled then
			self:Show()
		else
			self:Hide()
		end

		if not (BattleGroundEnemies.Allies:IsShown() or BattleGroundEnemies.Enemies:IsShown()) then -- if neither the enemies or allies frame is enabled for that size also hide the main frame, this stops the request frame from updating
			self:Hide()
		end
	end


	function self:UpdatePlayerCount(currentCount)
		currentCount = currentCount or 0
		currentCount =  math.max(self.NumShownPlayers, currentCount)



		BattleGroundEnemies:UpdateBGSize()

		local isEnemy = self.PlayerType == "Enemies"
		BattleGroundEnemies.EnemyFaction = BattleGroundEnemies.EnemyFaction or (playerFaction == "Horde" and 1 or 0)

		if self.bgSizeConfig and self.bgSizeConfig.PlayerCount.Enabled then
			self.PlayerCount:Show()
			self.PlayerCount:SetText(format(isEnemy == (BattleGroundEnemies.EnemyFaction == 0) and PLAYER_COUNT_HORDE or PLAYER_COUNT_ALLIANCE, currentCount))
		else
			self.PlayerCount:Hide()
		end

	end

	function self:GetPlayerbuttonByUnitID(unitID)
		local uName = GetUnitName(unitID, true)

		return self.Players[uName]
	end


	function self:SetPlayerCountJustifyV(direction)
		if direction == "downwards" then
			self.PlayerCount:SetJustifyV("BOTTOM")
		else
			self.PlayerCount:SetJustifyV("TOP")
		end
	end

	function self:SetupButtonForNewPlayer(playerDetails)
		local playerButton = self.InactivePlayerButtons[#self.InactivePlayerButtons]
		if playerButton then --recycle a previous used button

			table_remove(self.InactivePlayerButtons, #self.InactivePlayerButtons)
			--Cleanup previous shown stuff of another player
			playerButton.MyTarget:Hide()	--reset possible shown target indicator frame
			playerButton.MyFocus:Hide()	--reset possible shown target indicator frame
			--playerButton.BuffContainer:Reset()
			--playerButton.DebuffContainer:Reset()

			for moduleName, moduleFrameOnButton in pairs(BattleGroundEnemies.ButtonModules) do
				if playerButton[moduleName] and playerButton[moduleName].Reset then
					playerButton[moduleName]:Reset()
				end
			end


			if playerButton.UnitIDs then
				wipe(playerButton.UnitIDs.TargetedByEnemy)
				playerButton:UpdateTargetIndicators()
				if playerButton.PlayerIsEnemy then
					playerButton:DeleteActiveUnitID()
				end
			end

			playerButton.unitID = nil
			playerButton.unit = nil
			playerButton.PlayerArenaUnitID = nil


		else --no recycleable buttons remaining => create a new one
			playerButton = CreateFrame('Button', nil, self, 'SecureUnitButtonTemplate')
			playerButton:Hide()
			-- setmetatable(playerButton, self)
			-- self.__index = self


			playerButton.ButtonEvents = playerButton.ButtonEvents or {}
			playerButton.UnitIDs = {TargetedByEnemy = {}}


			playerButton.PlayerType = self.PlayerType
			playerButton.PlayerIsEnemy = playerButton.PlayerType == "Enemies" and true or false

			playerButton:SetScript("OnSizeChanged", function(self, width, height)
				--self.DRContainer:SetWidthOfAuraFrames(height)
				self:DispatchEvent("PlayerButtonSizeChanged", width, height)
			end)

			Mixin(playerButton, buttonFunctions)

			if playerButton.PlayerIsEnemy then
				Mixin(playerButton, enemyButtonFunctions)
			else
				Mixin(playerButton, allyButtonFunctions)
				RegisterUnitWatch(playerButton, true)
			end

			playerButton.Counter = {}
			playerButton:SetScript("OnEvent", function(self, event, ...)
				self.Counter[event] = (self.Counter[event] or 0) + 1

				self[event](self, ...) end)
			playerButton:SetScript("OnShow", function()
				playerButton.isShown = true
			end)
			playerButton:SetScript("OnHide", function()
				playerButton.isShown = false
			end)

			-- events/scripts
			playerButton:RegisterForDrag('LeftButton')
			playerButton:SetClampedToScreen(true)

			playerButton:SetScript('OnDragStart', playerButton.OnDragStart)
			playerButton:SetScript('OnDragStop', playerButton.OnDragStop)


			playerButton.RangeIndicator_Frame = CreateFrame("Frame", nil, playerButton)
			--playerButton.RangeIndicator_Frame:SetFrameLevel(playerButton:GetFrameLevel())
			-- playerButton.RangeIndicator = playerButton.RangeIndicator_Frame


			--MyTarget, indicating the current target of the player
			playerButton.MyTarget = CreateFrame('Frame', nil, playerButton.healthBar, BackdropTemplateMixin and "BackdropTemplate")
			playerButton.MyTarget:SetBackdrop({
				bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
				edgeFile = 'Interface/Buttons/WHITE8X8', --drawlayer "BORDER"
				edgeSize = 1
			})
			playerButton.MyTarget:SetBackdropColor(0, 0, 0, 0)
			playerButton.MyTarget:Hide()

			--MyFocus, indicating the current focus of the player
			playerButton.MyFocus = CreateFrame('Frame', nil, playerButton.healthBar, BackdropTemplateMixin and "BackdropTemplate")
			playerButton.MyFocus:SetBackdrop({
				bgFile = "Interface/Buttons/WHITE8X8", --drawlayer "BACKGROUND"
				edgeFile = 'Interface/Buttons/WHITE8X8', --drawlayer "BORDER"
				edgeSize = 1
			})
			playerButton.MyFocus:SetBackdropColor(0, 0, 0, 0)
			playerButton.MyFocus:Hide()

			-- symbolic target indicator
			playerButton.TargetIndicators = {}

			-- Auras
			playerButton.ButtonModules = {}
			for moduleName, moduleFrame in pairs(BattleGroundEnemies.ButtonModules) do
				if moduleFrame.AttachToPlayerButton then
					moduleFrame:AttachToPlayerButton(playerButton)
					if not playerButton[moduleName] then print("something went wrong here after AttachToPlayerButton", moduleName) end
					playerButton[moduleName].moduleName = moduleName
				end
			end

			--playerButton.BuffContainer = BattleGroundEnemies.Objects.AuraContainer.New(playerButton, "buff")
			--playerButton.DebuffContainer = BattleGroundEnemies.Objects.AuraContainer.New(playerButton, "debuff")

			playerButton:ApplyButtonSettings()
		end

		Mixin(playerButton, playerDetails)

		playerButton:SetSpecAndRole()

		self.UnitIDs = {TargetedByEnemy = {}}
		if playerButton.PlayerIsEnemy then
			playerButton:UpdateRange(false)
		else
			playerButton:UpdateRange(true)
		end

		playerButton:DispatchEvent("OnNewPlayer")

		playerButton:SetBindings()

		playerButton:Show()

		self.Players[playerButton.PlayerName] = playerButton

		return playerButton
	end

	function self:RemovePlayer(playerButton)
		if playerButton == PlayerButton then return end -- dont remove the Player itself


		local targetEnemyButton = playerButton.Target
		if targetEnemyButton then -- if that no longer exiting ally targeted something update the button of its target
			targetEnemyButton:NoLongerTargetedBy(playerButton)
		end

		playerButton:Hide()

		table_insert(self.InactivePlayerButtons, playerButton)
		self.Players[playerButton.PlayerName] = nil

		self:SortPlayers()
	end

	function self:RemoveAllPlayers()
		for playerName, playerButton in pairs(self.Players) do
			self:RemovePlayer(playerButton)
		end
	end

	function self:ButtonPositioning()
		local orderedPlayers = self.CurrentPlayerOrder
		local config = self.bgSizeConfig
		local columns = config.BarColumns


		local verticalSpacing = config.BarVerticalSpacing
		local growDownwards = (config.BarVerticalGrowdirection == "downwards")

		local horizontalSpacing = config.BarHorizontalSpacing

		local growRightwards = (config.BarHorizontalGrowdirection == "rightwards")

		local playerCount = #orderedPlayers

		local rowsPerColumn =  math.ceil(playerCount/columns)

		local playerNumber = 1
		local previousButton = self

		local firstButtonInColumn
		for columNumber = 1, columns do
			for rowNumber = 1, rowsPerColumn do

				if playerNumber > playerCount then break end

				local playerButton = orderedPlayers[playerNumber]
				if playerButton then -- this really should never happen
					playerButton.Position = playerNumber

					playerButton:ClearAllPoints()


					if rowNumber == 1 and columNumber ~= 1 then
						if growRightwards then
							playerButton:SetPoint("TOPLEFT", firstButtonInColumn, "TOPRIGHT", horizontalSpacing, 0)
						else --growLeftwards
							playerButton:SetPoint("TOPRIGHT", firstButtonInColumn, "TOPLEFT", -horizontalSpacing, 0)
						end
					else
						if growDownwards then
							playerButton:SetPoint("TOPLEFT", previousButton, "BOTTOMLEFT", 0, -verticalSpacing)
						else --growUpwards
							playerButton:SetPoint("BOTTOMLEFT", previousButton, "TOPLEFT", 0, verticalSpacing)
						end
					end

					if rowNumber == 1 then
						firstButtonInColumn = playerButton
					end

					playerNumber = playerNumber + 1


					--print("playerButton:GetRect", playerButton:GetRect(), playerButton)
					playerButton:SetModulePositions()


					previousButton = playerButton
				end
			end
		end
	end

	function self:CreateOrUpdatePlayer(name, race, classTag, specName, additionalData)
		local playerButton = self.Players[name]
		if playerButton then	--already existing
			if specName and specName ~= "" then --  hasSpeccs --only update if a specname exists, this way we dont remove the spec if we update via GROUP_ROSTER_UPDATE and the spec has not been cached yet
				if playerButton.PlayerSpecName ~= specName then--its possible to change specName in battleground
					playerButton.PlayerSpecName = specName
					playerButton:SetSpecAndRole()
				end
			end
			if additionalData then
				Mixin(playerButton, additionalData)
			end

			playerButton.Status = 1 --1 means found, already existing
		else
			self.NewPlayerDetails[name] = { -- details of this new player
				PlayerClass = string.upper(classTag), --apparently it can happen that we get a lowercase "druid" from GetBattlefieldScore() in TBCC, IsTBCC
				PlayerName = name,
				PlayerRace = race and LibRaces:GetRaceToken(race) or "Unknown", --delivers a locale independent token for relentless check
				PlayerSpecName = specName ~= "" and specName or false, --set to false since we use Mixin() and Mixin doesnt mixin nil values and therefore we dont overwrite values with nil
				PlayerClassColor = RAID_CLASS_COLORS[classTag],
				PlayerLevel = false,
			}
			if additionalData then
				Mixin(self.NewPlayerDetails[name], additionalData)
			end
		end
	end

	--Rückwärts um keine Probleme mit table_remove zu bekommen, wenn man mehr als einen Spieler in einem Schleifendurchlauf entfernt,
				-- da ansonsten die enemyButton.Position nicht mehr passen (sie sind zu hoch)
	function self:DeleteAndCreateNewPlayers()
		for playerName, playerButton in pairs(self.Players) do
			if playerButton.Status == 2 then --no longer existing
				self:RemovePlayer(playerButton)

			else -- == 1 -- set to 2 for the next comparison
				playerButton.Status = 2
			end
		end

		local i = 0
		for name, playerDetails in pairs(self.NewPlayerDetails) do
			local playerButton = self:SetupButtonForNewPlayer(playerDetails)
			i = i + 1
			playerButton.Status = 2
		end
		if i > 0 then
			self:SortPlayers()
		end
	end

	do
		local BlizzardsSortOrder = {}
		for i = 1, #CLASS_SORT_ORDER do -- Constants.lua
			BlizzardsSortOrder[CLASS_SORT_ORDER[i]] = i --key = ENGLISH CLASS NAME, value = number
		end

		local function PlayerSortingByRoleClassName(playerA, playerB)-- a and b are playerButtons
			if playerA.PlayerRoleNumber and playerB.PlayerRoleNumber then
				if playerA.PlayerRoleNumber == playerB.PlayerRoleNumber then
					if BlizzardsSortOrder[ playerA.PlayerClass ] == BlizzardsSortOrder[ playerB.PlayerClass ] then
						if playerA.PlayerName < playerB.PlayerName then return true end
					elseif BlizzardsSortOrder[ playerA.PlayerClass ] < BlizzardsSortOrder[ playerB.PlayerClass ] then return true end
				elseif playerA.PlayerRoleNumber < playerB.PlayerRoleNumber then return true end
			else
				if BlizzardsSortOrder[ playerA.PlayerClass ] == BlizzardsSortOrder[ playerB.PlayerClass ] then
					if playerA.PlayerName < playerB.PlayerName then return true end
				elseif BlizzardsSortOrder[ playerA.PlayerClass ] < BlizzardsSortOrder[ playerB.PlayerClass ] then return true end
			end
		end

		local function PlayerSortingByArenaUnitID(playerA, playerB)-- a and b are playerButtons
			if playerA.PlayerArenaUnitID <= playerB.PlayerArenaUnitID then
				return true
			end
		end

		local function CRFSort_Group_(playerA, playerB) -- this is basically a adapted CRFSort_Group to make the sorting in arena
			if not (playerA and playerB) then return end
			if not (playerA.unit and playerB.unit) then return true end
			if ( playerA.unit == "player" ) then
				return true;
			elseif ( playerB.unit == "player" ) then
				return false;
			else
				return playerA.unit < playerB.unit;	--String compare is OK since we don't go above 1 digit for party.
			end
		end

		function self:SortPlayers()
			local numShownPlayers = 0
			local newPlayerOrder = {}
			for playerName, playerButton in pairs(self.Players) do
				newPlayerOrder[#newPlayerOrder + 1] = playerButton
				numShownPlayers = numShownPlayers + 1
			end

			if IsInArena and not IsInBrawl() then
				if (self.PlayerType == "Enemies") then
					table.sort(newPlayerOrder, PlayerSortingByArenaUnitID)
				else
					table.sort(newPlayerOrder, CRFSort_Group_)
				end
			else
				table.sort(newPlayerOrder, PlayerSortingByRoleClassName)
			end

			local orderChanged
			for i = 1, math_max(#newPlayerOrder, #self.CurrentPlayerOrder) do
				if newPlayerOrder[i] ~= self.CurrentPlayerOrder[i] then
					orderChanged = true
					break
				end
			end

			self.NumShownPlayers = numShownPlayers
			self:UpdatePlayerCount()
			if orderChanged then
				self.CurrentPlayerOrder = newPlayerOrder
				self:ButtonPositioning()
			end
		end
	end


	self:SetClampedToScreen(true)
	self:SetMovable(true)
	self:SetUserPlaced(true)
	self:SetResizable(true)
	self:SetToplevel(true)

	self.PlayerCount = BattleGroundEnemies.MyCreateFontString(self)
	self.PlayerCount:SetAllPoints()
	self.PlayerCount:SetJustifyH("LEFT")
end


--BattleGroundEnemies.EnemyFaction
--BattleGroundEnemies.AllyFaction

--each module can heave one of the different types
--dynamicContainer == the container is only as big as the children its made of, the container sets only 1 point
--buttonHeightLengthVariable = a attachment that has the height of the button and a variable width (the module will set the width itself). when unused sets to 0.01 width
--buttonHeightSquare = a attachment that has the height of the button and the same width, when unused sets to 0.01 width
--HeightAndWidthVariable

function BattleGroundEnemies:NewButtonModule(moduleName, localizedModuleName, flags, defaultSettings, options, events)

	if self.ButtonModules[moduleName] then return error("module "..moduleName.." is already registered") end
	local moduleFrame = CreateFrame("Frame", nil, UIParent)
	moduleFrame.moduleName = moduleName
	moduleFrame.localizedModuleName = localizedModuleName
	moduleFrame.defaultSettings = defaultSettings or {}
	moduleFrame.options = options or {}
	moduleFrame.flags = flags or {}
	moduleFrame.events = events


	local t = {"Enemies", "Allies"}
	local BGSizes = {"5", "15", "40"}
	for i = 1, #t do
		local tt = t[i]
		for j = 1, #BGSizes do
			local BGSize = BGSizes[j]
			Data.defaultSettings.profile[tt][BGSize].ButtonModules = Data.defaultSettings.profile[tt][BGSize].ButtonModules or {}
			Data.defaultSettings.profile[tt][BGSize].ButtonModules[moduleName] = Data.defaultSettings.profile[tt][BGSize].ButtonModules[moduleName] or {}
			Mixin(Data.defaultSettings.profile[tt][BGSize].ButtonModules[moduleName], defaultSettings)
		end
	end

	moduleFrame:SetScript("OnEvent", function(self, event, ...)
		BattleGroundEnemies:Debug("BattleGroundEnemies module event", moduleName, event, ...)
		self[event](self, ...)
	end)

	moduleFrame.Debug = function(self, ...)
		BattleGroundEnemies:Debug("UnitInCombat module debug", moduleName, ...)
	end

	self.ButtonModules[moduleName] = moduleFrame
	return moduleFrame
end

function BattleGroundEnemies:GetBigDebuffsPriority(spellID)
	if not (BattleGroundEnemies.db.profile.UseBigDebuffsPriority and BigDebuffs) then return end
	local priority = BigDebuffs:GetDebuffPriority(spellID)
	if not priority then return end
	if priority == 0 then return end
	return priority
end




BattleGroundEnemies:SetScript("OnEvent", function(self, event, ...)
	self.Counter[event] = (self.Counter[event] or 0) + 1
	--BattleGroundEnemies:Debug("BattleGroundEnemies OnEvent", event, ...)
	self[event](self, ...)
end)
BattleGroundEnemies:Hide()

function BattleGroundEnemies:ShowTooltip(owner, func)
	if self.db.profile.ShowTooltips then
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 0, 0)
		func()
		GameTooltip:Show()
	end
end


function BattleGroundEnemies:GetColoredName(playerDetails)
	local name = playerDetails.PlayerName
	local classTag = playerDetails.PlayerClass
	local tbl = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classTag] or RAID_CLASS_COLORS[classTag] or GRAY_FONT_COLOR
	return ("|cFF%02x%02x%02x%s|r"):format(tbl.r*255, tbl.g*255, tbl.b*255, name)
end

local function FindAuraBySpellID(unitID, spellID, filter)
	if not unitID or not spellID then return end

	for i = 1, 40 do
		local name, _, amount, debuffType, duration, expirationTime, unitCaster, _, _, id, _, _, _, _, _, value2, value3, value4 = UnitAura(unitID, i, filter)
		if not id then return end -- no more auras

		if spellID == id then
			return i, name, _, amount, debuffType, duration, expirationTime, unitCaster, _, _, id, _, _, _, _, _, value2, value3, value4
		end
	end
end

-- for classic, IsClassic
local function FindAuraBySpellName(unitID, spellName, filter)
	if not unitID or not spellName then return end

	for i = 1, 40 do
		local name, _, amount, debuffType, duration, expirationTime, unitCaster, _, _, id, _, _, _, _, _, value2, value3, value4 = UnitAura(unitID, i, filter)
		if not name then return end -- no more auras

		if spellName == name then
			return i, name, _, amount, debuffType, duration, expirationTime, unitCaster, _, _, id, _, _, _, _, _, value2, value3, value4
		end
	end
end




-- BattleGroundEnemies.Fake_ARENA_OPPONENT_UPDATE()
-- 	BattleGroundEnemies:ARENA_OPPONENT_UPDATE()
-- end

function BattleGroundEnemies:ShowAuraTooltip(playerButton, displayedAura)
	if not displayedAura then return end

	local spellID = displayedAura.SpellID
	if not spellID then return end

	local filter = displayedAura.Filter
	local unitID = playerButton:GetUnitID()

	if unitID and filter then
		local index = FindAuraBySpellID(unitID, spellID, filter)
		if index then
			return GameTooltip:SetUnitAura(unitID, index, filter)
		else
			GameTooltip:SetSpellByID(spellID)
		end
	else
		GameTooltip:SetSpellByID(spellID)
	end
end




local randomTrinkets = {} -- key = number, value = spellID
local randomRacials = {} -- key = number, value = spellID
local FakePlayersOnUpdateFrame = CreateFrame("frame")
FakePlayersOnUpdateFrame:Hide()


local function SetupTrinketAndRacialData()
	do
		local count = 1
		for triggerSpellID, trinketData in pairs(Data.TrinketData) do
			if type(triggerSpellID) == "string" then   --support for classic, IsClassic
				randomTrinkets[count] = triggerSpellID
				count = count + 1
			else
				if GetSpellInfo(triggerSpellID) then
					randomTrinkets[count] = triggerSpellID
					count = count + 1
				end
			end
		end
	end

	do
		local count = 1
		for racialSpelliD, data in pairs(Data.RacialSpellIDtoCooldown) do
			if GetSpellInfo(racialSpelliD) then
				randomRacials[count] = racialSpelliD
				count = count + 1
			end
		end
	end
end

function BattleGroundEnemies.ToggleTestmodeOnUpdate()
	FakePlayersOnUpdateFrame:SetShown(not FakePlayersOnUpdateFrame:IsShown())
end

function BattleGroundEnemies.ToggleTestmode()
	if BattleGroundEnemies.TestmodeActive then --disable testmode
		BattleGroundEnemies:DisableTestMode()
	else --enable Testmode
		BattleGroundEnemies:EnableTestMode()
	end
end


function BattleGroundEnemies:DisableTestMode()
	self.Enemies:RemoveAllPlayers()
	FakePlayersOnUpdateFrame:Hide()
	self:Hide()
	self.TestmodeActive = false
	self:GROUP_ROSTER_UPDATE() -- to build up the players with the real allies
end

do
	local counter

	function BattleGroundEnemies:FillFakePlayerData(BGSize, amount, mianFrame, playerType, role)
		for i = 1, amount do
			local name, classTag, specName

			if HasSpeccs then
				local randomSpec
				randomSpec = Data.RolesToSpec[role][math_random(1, #Data.RolesToSpec[role])]
				classTag = randomSpec.classTag
				specName = randomSpec.specName
			else
				classTag = Data.ClassList[math_random(1, #Data.ClassList)]
			end
			name = L[playerType]..counter.."-Realm"..counter

			mianFrame:CreateOrUpdatePlayer(name, nil, classTag, specName,
			{
				isFakePlayer = true,
				PlayerLevel = i==1 and MaxLevel or math_random(MaxLevel - 10, MaxLevel -1)
			})

			counter = counter + 1
		end
	end

	function BattleGroundEnemies:CreateFakePlayers(count)
		for number, mainFrame in pairs({self.Allies, self.Enemies}) do
			local continue = true
			if number == 1 and self.db.profile.Testmode_UseTeammates then
				continue = false
			end
			if continue then
				wipe(mainFrame.NewPlayerDetails)

				local healerAmount = math_random(2, 3)
				local tankAmount = math_random(1)
				local damagerAmount = count - healerAmount - tankAmount


				if mainFrame == self.Allies then
					local myRole
					if HasSpeccs then
						myRole = Data.Classes[self.PlayerDetails.PlayerClass][specCache[self.PlayerDetails.GUID]].roledID
					else
						myRole = "DAMAGER"
					end
					if myRole == "HEALER" then
						healerAmount = healerAmount - 1
					elseif myRole == "TANK" then
						tankAmount = tankAmount - 1
					else
						damagerAmount = damagerAmount - 1
					end
				end


				mainFrame:RemoveAllPlayers()

				counter = 1
				BattleGroundEnemies:FillFakePlayerData(self.BGSize, healerAmount, mainFrame, mainFrame.PlayerType == "Enemies" and "Enemy" or "Ally", "HEALER")
				BattleGroundEnemies:FillFakePlayerData(self.BGSize, tankAmount, mainFrame, mainFrame.PlayerType == "Enemies" and "Enemy" or "Ally", "TANK")
				BattleGroundEnemies:FillFakePlayerData(self.BGSize, damagerAmount, mainFrame, mainFrame.PlayerType == "Enemies" and "Enemy" or "Ally", "DAMAGER")





				mainFrame:DeleteAndCreateNewPlayers()

				for name, playerButton in pairs(mainFrame.Players) do
					if IsRetail then
						playerButton.Covenant:DisplayCovenant(math_random(1, #Data.CovenantIcons))
					end
				end
			end
		end
	end

	Data.FoundAuras = {
		HELPFUL = {
			foundPlayerAuras = {},
			foundNonPlayerAuras = {},
		},
		HARMFUL = {
			foundPlayerAuras = {},
			foundNonPlayerAuras = {},
			foundDRAuras = {}
		}
	}

	local TestmodeRanOnce = false
	function BattleGroundEnemies:EnableTestMode()
		self.TestmodeActive = true

		if not TestmodeRanOnce then
			SetupTrinketAndRacialData()
			TestmodeRanOnce = true
		end

		wipe(FakePlayerAuras)
		wipe(FakePlayerDRs)

		local mapIDs = {}
		for mapID, data in pairs(Data.BattlegroundspezificBuffs) do
			mapIDs[#mapIDs + 1] = mapID
		end
		local mandomm = math_random(1, #mapIDs)
		local randomMapID = mapIDs[mandomm]

		self.BattlegroundBuff = Data.BattlegroundspezificBuffs[randomMapID]



		local filters = {"HELPFUL", "HARMFUL"}
		for i = 1, #filters do
			local filter = filters[i]

			local auras = Data.FakeAuras[filter]
			local foundA = Data.FoundAuras[filter]
			local playerSpells = {}
			local numTabs = GetNumSpellTabs()
			for i = 1, numTabs do
				local name, texture, offset, numSpells = GetSpellTabInfo(i)
				for j = 1, numSpells do
					local id = j + offset
					local spellName, _, spelliD = GetSpellBookItemName(id, 'spell')
					if spelliD and IsSpellKnown(spelliD) then
						playerSpells[spelliD] = true
					end
				end
			end

			for spellId, auraDetails in pairs(auras) do
				if GetSpellInfo(spellId) then
					if filter == "HARMFUL" and DRList:GetCategoryBySpellID(IsClassic and auraDetails.name or spellId) then
						foundA.foundDRAuras[#foundA.foundDRAuras + 1] = auraDetails
					elseif playerSpells[spellId] then
						foundA.foundPlayerAuras[#foundA.foundPlayerAuras + 1] = auraDetails
						-- this buff could be applied from the player
					else
						foundA.foundNonPlayerAuras[#foundA.foundNonPlayerAuras + 1] = auraDetails
					end
				end
			end
		end


		self:CreateFakePlayers(BattleGroundEnemies.db.profile.Testmode_BGSize or 5)

		self:Show()

		FakePlayersOnUpdateFrame:Show()
	end
end


do
	local holdsflag
	local TimeSinceLastOnUpdate = 0
	local UpdatePeroid = 1 --update every second

	local function FakeOnUpdate(self, elapsed) --OnUpdate runs if the frame FakePlayersOnUpdateFrame is shown
		TimeSinceLastOnUpdate = TimeSinceLastOnUpdate + elapsed
		if TimeSinceLastOnUpdate > UpdatePeroid then

			for number, playerType in pairs({BattleGroundEnemies.Allies, BattleGroundEnemies.Enemies}) do

				local settings = playerType.bgSizeConfig

				local targetCounts = 0
				local hasFlag = false
				for name, playerButton in pairs(playerType.Players) do
					if playerButton.isFakePlayer then
						local n = math_random(1,10)
						--self:Debug("number", number)

						--self:Debug(playerButton.ObjectiveAndRespawn.Cooldown:GetCooldownDuration())

						if not playerButton.isDead then
							if BattleGroundEnemies.BGSize == 15 and n == 1 and not hasFlag then --this guy has a objective now
								-- hide old flag carrier
								local oldFlagholder = holdsflag
								if oldFlagholder then
									oldFlagholder:DispatchEvent("ArenaOpponentHidden")
								end

								playerButton:ArenaOpponentShown()

								holdsflag = playerButton
								hasFlag = true

							elseif n == 3 and playerButton.Racial.Cooldown:GetCooldownDuration() == 0 then -- racial used
								playerButton.Racial:RacialCheck(randomRacials[math_random(1, #randomRacials)])
							elseif n == 4 and playerButton.Trinket.Cooldown:GetCooldownDuration() == 0 then -- trinket used
								BattleGroundEnemies.CombatLogevents.SPELL_CAST_SUCCESS(BattleGroundEnemies, playerButton.PlayerName, nil, randomTrinkets[math_random(1, #randomTrinkets)])
							elseif n == 6 then --power simulation
								playerButton.Power:SetValue(math_random(0, 100)/100)
							end

							playerButton:UNIT_AURA()
							-- targetcounter simulation
							if targetCounts < 15 then
								local targetCounter = math_random(0,3)
								if targetCounts + targetCounter <= 15 then
									playerButton.TargetIndicatorNumeric:SetText(targetCounter)
								end
							end
						end
						playerButton:UNIT_HEALTH()

						if n == 6 then --toggle range
							if playerType.config.RangeIndicator_Enabled then
								playerButton:UpdateRange((playerButton.oldAlpha ~= 1) and true or false)
							end
						end
					end


				end
			end

			TimeSinceLastOnUpdate = 0
		end
	end
	FakePlayersOnUpdateFrame:SetScript("OnUpdate", FakeOnUpdate)
end







BattleGroundEnemies.Objects = {}


local RequestFrame = CreateFrame("Frame", nil, BattleGroundEnemies)
RequestFrame:Hide()
do
	local TimeSinceLastOnUpdate = 0
	local UpdatePeroid = 2 --update every second
	local function RequestTicker(self, elapsed) --OnUpdate runs if the frame RequestFrame is shown
		TimeSinceLastOnUpdate = TimeSinceLastOnUpdate + elapsed
		if TimeSinceLastOnUpdate > UpdatePeroid then
			RequestBattlefieldScoreData()
			TimeSinceLastOnUpdate = 0
		end
	end
	RequestFrame:SetScript("OnUpdate", RequestTicker)
end



local function CreatedebugFrame()
	local f = FCF_OpenTemporaryWindow("FILTERED")
	f:SetMaxLines(2500)
	FCF_UnDockFrame(f);
	f:ClearAllPoints();
	f:SetPoint("CENTER", "UIParent", "CENTER", 0, 0);
	FCF_SetTabPosition(f, 0);
	f:Show();
	f.Tab = _G[f:GetName().."Tab"]
	f.Tab.conversationIcon:Hide()
	FCF_SetWindowName(f, "BGE_DebugFrame")

	return f
end

BattleGroundEnemies.ArenaIDToPlayerButton = {} --key = arenaID: arenaX, value = playerButton of that unitID

BattleGroundEnemies.Enemies = CreateFrame("Frame", nil, BattleGroundEnemies)
BattleGroundEnemies.Enemies.Counter = {}


BattleGroundEnemies.Enemies:Hide()
BattleGroundEnemies.Enemies:SetScript("OnEvent", function(self, event, ...)
	self.Counter[event] = (self.Counter[event] or 0) + 1
	--BattleGroundEnemies:Debug("Enemies OnEvent", event, ...)
	self[event](self, ...)
end)


BattleGroundEnemies.Allies = CreateFrame("Frame", nil, BattleGroundEnemies) --index = name, value = table
BattleGroundEnemies.Allies.Counter = {}
BattleGroundEnemies.Allies.GUIDToAllyname = {}


BattleGroundEnemies.Allies:Hide()
BattleGroundEnemies.Allies:SetScript("OnEvent", function(self, event, ...)
	self.Counter[event] = (self.Counter[event] or 0) + 1

	--BattleGroundEnemies:Debug("Allies OnEvent", event, ...)
	self[event](self, ...)
end)








function BattleGroundEnemies.Allies:GroupInSpecT_Update(event, GUID, unitID, info)
	if not GUID or not info.class then return end

	specCache[GUID] = info.spec_name_localized

	BattleGroundEnemies:GROUP_ROSTER_UPDATE()
end




BattleGroundEnemies:RegisterEvent("PLAYER_LOGIN") --Fired on reload UI and on initial loading screen




function BattleGroundEnemies:UI_SCALE_CHANGED()
	if not InCombatLockdown() then
		self:SetScale(UIParent:GetScale())
	else
		C_Timer.After(1, function() BattleGroundEnemies:UI_SCALE_CHANGED() end)
	end
end

UIParent:HookScript("OnShow", function() BattleGroundEnemies:SetAlpha(1) end)

UIParent:HookScript("OnHide", function() BattleGroundEnemies:SetAlpha(0) end)


BattleGroundEnemies:SetScale(UIParent:GetScale())

BattleGroundEnemies.GeneralEvents = {
	"UPDATE_BATTLEFIELD_SCORE", --stopping the onupdate script should do it but other addons make "UPDATE_BATTLEFIELD_SCORE" trigger aswell
	"COMBAT_LOG_EVENT_UNFILTERED",
	"UPDATE_MOUSEOVER_UNIT",
	"PLAYER_TARGET_CHANGED",
	"PLAYER_FOCUS_CHANGED",
	"ARENA_OPPONENT_UPDATE", --fires when a arena enemy appears and a frame is ready to be shown
	"ARENA_CROWD_CONTROL_SPELL_UPDATE", --fires when data requested by C_PvP.RequestCrowdControlSpell(unitID) is available
	"ARENA_COOLDOWNS_UPDATE", --fires when a arenaX enemy used a trinket or racial to break cc, C_PvP.GetArenaCrowdControlInfo(unitID) shoudl be called afterwards to get used CCs
	"RAID_TARGET_UPDATE",
	"UNIT_TARGET",
	"PLAYER_ALIVE",
	"PLAYER_UNGHOST",
	"UNIT_AURA",
	"UNIT_HEALTH",
	"UNIT_MAXHEALTH",
	"UNIT_POWER_FREQUENT"
}

BattleGroundEnemies.RetailEvents = {
	"UNIT_HEAL_PREDICTION",
	"UNIT_ABSORB_AMOUNT_CHANGED",
	"UNIT_HEAL_ABSORB_AMOUNT_CHANGED"
}

BattleGroundEnemies.ClassicEvents = {
	"UNIT_HEALTH_FREQUENT",
}

BattleGroundEnemies.WrathEvents = {
	"UNIT_HEALTH_FREQUENT"
}


function BattleGroundEnemies:RegisterEvents()
	for i = 1, #self.GeneralEvents do
		self:RegisterEvent(self.GeneralEvents[i])
	end
	if IsClassic then
		for i = 1, #self.ClassicEvents do
			self:RegisterEvent(self.ClassicEvents[i])
		end
	end
	if IsWrath then
		for i = 1, #self.WrathEvents do
			self:RegisterEvent(self.WrathEvents[i])
		end
	end
	if IsRetail then
		for i = 1, #self.RetailEvents do
			self:RegisterEvent(self.RetailEvents[i])
		end
	end
end

function BattleGroundEnemies:UnregisterEvents()
	for i = 1, #self.GeneralEvents do
		self:UnregisterEvent(self.GeneralEvents[i])
	end
	if IsClassic then
		for i = 1, #self.ClassicEvents do
			self:UnregisterEvent(self.ClassicEvents[i])
		end
	end
	if IsWrath then
		for i = 1, #self.WrathEvents do
			self:UnregisterEvent(self.WrathEvents[i])
		end
	end
	if IsRetail then
		for i = 1, #self.RetailEvents do
			self:UnregisterEvent(self.RetailEvents[i])
		end
	end
end

BattleGroundEnemies:SetScript("OnShow", function(self)
	self:RegisterEvents()
	if self.TestmodeActive then
		RequestFrame:Hide()
	else
		RequestFrame:Show()
	end
end)


BattleGroundEnemies:SetScript("OnHide", function(self)
	self:UnregisterEvents()
end)

do
	local TimeSinceLastOnUpdate = 0
	local UpdatePeroid = 0.1 --update every 0.1 seconds
	function BattleGroundEnemies.Enemies:RealPlayersOnUpdate(elapsed)
		TimeSinceLastOnUpdate = TimeSinceLastOnUpdate + elapsed
		if TimeSinceLastOnUpdate > UpdatePeroid then
			if BattleGroundEnemies.PlayerIsAlive then

				for playerName, enemyButton in pairs(self.Players) do
					local unitIDs = enemyButton.UnitIDs
					local activeUnitID = unitIDs.Active

					if activeUnitID and UnitExists(activeUnitID) then

						-- we don't get health update events of targets of allies, so we have to use a onUpdate for that
						if unitIDs.HasAllyUnitID then
							enemyButton:UNIT_POWER_FREQUENT(activeUnitID)
							enemyButton:UNIT_HEALTH(activeUnitID)
							--enemyButton:UNIT_AURA(activeUnitID, true) todo probably overkill
						end

						--Updates stuff that doesn't have events
						enemyButton:UpdateRange(IsItemInRange(self.config.RangeIndicator_Range, activeUnitID))
						enemyButton:UpdateTargets()
					end
				end
			end
			TimeSinceLastOnUpdate = 0
		end
	end
end

BattleGroundEnemies.Enemies:SetScript("OnShow", function(self)
	if not BattleGroundEnemies.TestmodeActive then
		self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		self:RegisterEvent("UNIT_NAME_UPDATE")
		if HasSpeccs then
			self:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
		end

		self:SetScript("OnUpdate", self.RealPlayersOnUpdate)
	else
		self:SetScript("OnUpdate", nil)
	end
end)

BattleGroundEnemies.Enemies:SetScript("OnHide", BattleGroundEnemies.Enemies.UnregisterAllEvents)

do
	local TimeSinceLastOnUpdate = 0
	local UpdatePeroid = 0.1 --update every 0.1 seconds
	function BattleGroundEnemies.Allies:RealPlayersOnUpdate(elapsed)
		--BattleGroundEnemies:Debug("läuft")
		TimeSinceLastOnUpdate = TimeSinceLastOnUpdate + elapsed
		if TimeSinceLastOnUpdate > UpdatePeroid then
			if BattleGroundEnemies.PlayerIsAlive then
				for name, allyButton in pairs(self.Players) do
					if allyButton ~= PlayerButton then
					--BattleGroundEnemies:Debug(IsItemInRange(self.config.RangeIndicator_Range, allyButton.unit), self.config.RangeIndicator_Range, allyButton.unit)
						allyButton:UpdateRange(IsItemInRange(self.config.RangeIndicator_Range, allyButton.unit))
					else
						allyButton:UpdateRange(true)
					end
				end
			end
			TimeSinceLastOnUpdate = 0
		end
	end
end

BattleGroundEnemies.Allies:SetScript("OnShow", function(self)
	if not BattleGroundEnemies.TestmodeActive then
		self:SetScript("OnUpdate", self.RealPlayersOnUpdate)
	else
		self:SetScript("OnUpdate", nil)
	end
end)

BattleGroundEnemies.Allies:SetScript("OnHide", BattleGroundEnemies.Allies.UnregisterAllEvents)


-- if lets say raid1 leaves all remaining players get shifted up, so raid2 is the new raid1, raid 3 gets raid2 etc.



local function EnableShadowColor(fontString, enableShadow, shadowColor)
	if shadowColor then fontString:SetShadowColor(unpack(shadowColor)) end
	if enableShadow then
		fontString:SetShadowOffset(1, -1)
	else
		fontString:SetShadowOffset(0, 0)
	end
end

function BattleGroundEnemies.CropImage(texture, width, height, hasTexcoords)
	local left, right, top, bottom = 0.075, 0.925, 0.075, 0.925
	local ratio = height / width
	if ratio > 1 then --crop the sides
		ratio = 1/ratio
		texture:SetTexCoord( (left) + ((1- ratio) / 2), right - ((1- ratio) / 2), top, bottom)
	elseif ratio == 1 then
		texture:SetTexCoord(left, right, top, bottom)
	else
		-- crop the height
		texture:SetTexCoord(left, right, top + ((1- ratio) / 2), bottom - ( (1- ratio) / 2))
	end
end

local function ApplyFontStringSettings(self, settings)
	self:SetFont(LSM:Fetch("font", BattleGroundEnemies.db.profile.Font), settings.FontSize, settings.FontOutline)

	if settings.FontColor then
		self:SetTextColor(unpack(settings.FontColor))
	end

	if settings.JustifyH then
		self:SetJustifyH(settings.JustifyH)
	end

	if settings.JustifyV then
		self:SetJustifyV(settings.JustifyV)
	end

	self:EnableShadowColor(settings.EnableShadow, settings.ShadowColor)
end

local function ApplyCooldownSettings(self, config, cdReverse, setDrawSwipe, swipeColor)
	self:SetReverse(cdReverse)
	self:SetDrawSwipe(setDrawSwipe)
	if swipeColor then self:SetSwipeColor(unpack(swipeColor)) end
	self:SetHideCountdownNumbers(not config.ShowNumber)
	if self.Text then
		self.Text:ApplyFontStringSettings(config)
	end
end



function BattleGroundEnemies.MyCreateFontString(parent)
	local fontString = parent:CreateFontString(nil, "OVERLAY")
	fontString.ApplyFontStringSettings = ApplyFontStringSettings
	fontString.EnableShadowColor = EnableShadowColor
	fontString:SetDrawLayer('OVERLAY', 2)
	return fontString
end

function BattleGroundEnemies.GrabFontString(frame)
	for _, region in pairs{frame:GetRegions()} do
		if region:GetObjectType() == "FontString" then
			return region
		end
	end
end

function BattleGroundEnemies.AttachCooldownSettings(cooldown)
	cooldown.ApplyCooldownSettings = ApplyCooldownSettings
	-- Find fontstring of the cooldown
	local fontstring = BattleGroundEnemies.GrabFontString(cooldown)
	if fontstring then
		cooldown.Text = fontstring
		cooldown.Text.ApplyFontStringSettings = ApplyFontStringSettings
		cooldown.Text.EnableShadowColor = EnableShadowColor
	end
end



function BattleGroundEnemies.MyCreateCooldown(parent)
	local cooldown = CreateFrame("Cooldown", nil, parent)
	cooldown:SetAllPoints()
	cooldown:SetSwipeTexture('Interface/Buttons/WHITE8X8')

	BattleGroundEnemies.AttachCooldownSettings(cooldown)

	return cooldown
end


function BattleGroundEnemies:BGSizeChanged(newBGSize)
	self.BGSize = newBGSize
	--self:Debug(newBGSize)
	self.Enemies:ApplyBGSizeSettings()
	self.Allies:ApplyBGSizeSettings()
end

function BattleGroundEnemies:UpdateBGSize()
	local MaxNumPlayers = math_max(self.Allies.NumShownPlayers, self.Enemies.NumShownPlayers)
	if MaxNumPlayers then
		if MaxNumPlayers > 15 then
			if not self.BGSize or self.BGSize ~= 40 then
				self:BGSizeChanged(40)
			end
		else
			if MaxNumPlayers <= 5 then
				if not self.BGSize or self.BGSize ~= 5 then --arena
					self:BGSizeChanged(5)
				end
			else
				if not self.BGSize or self.BGSize ~= 15 then
					self:BGSizeChanged(15)
				end
			end
		end
	end
end



do


	local function PVPMatchScoreboard_OnHide()
		if PVPMatchScoreboard.selectedTab ~= 1 then
			-- user was looking at another tab than all players
			SetBattlefieldScoreFaction() -- request a UPDATE_BATTLEFIELD_SCORE
		end
	end




	function BattleGroundEnemies:PLAYER_LOGIN()
		self.PlayerDetails = {
			PlayerName = UnitName("player"),
			PlayerClass = select(2, UnitClass("player")),
			IsGroupLeader = UnitIsGroupLeader("player"),
			isGroupAssistant = UnitIsGroupAssistant("player"),
			unit = "player",
			GUID = UnitGUID("player")
		}


		self.db = LibStub("AceDB-3.0"):New("BattleGroundEnemiesDB", Data.defaultSettings, true)

		self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
		self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
		self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")


		LibChangelog:Register(AddonName, Data.changelog, self.db.profile, "lastReadVersion", "onlyShowWhenNewVersion")

		LibChangelog:ShowChangelog(AddonName)


		PopulateMainframe("Allies")
		PopulateMainframe("Enemies")

		if LGIST then -- the libary doesnt work in TBCC, IsTBCC
			LGIST.RegisterCallback(BattleGroundEnemies.Allies, "GroupInSpecT_Update")
		end

		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("PLAYER_ENTERING_WORLD") -- fired on reload UI and on every loading screen (for switching zones, intances etc)
		self:RegisterEvent("PARTY_LEADER_CHANGED")
		self:RegisterEvent("UI_SCALE_CHANGED")

		self:SetupOptions()

		AceConfigDialog:SetDefaultSize("BattleGroundEnemies", 709, 532)

		AceConfigDialog:AddToBlizOptions("BattleGroundEnemies", "BattleGroundEnemies")

		if PVPMatchScoreboard then -- for TBCC, IsTBCC
			PVPMatchScoreboard:HookScript("OnHide", PVPMatchScoreboard_OnHide)
		end

		--DBObjectLib:ResetProfile(noChildren, noCallbacks)


		self:GROUP_ROSTER_UPDATE()  --Scan again, the user could have reloaded the UI so GROUP_ROSTER_UPDATE didnt fire

		self:UnregisterEvent("PLAYER_LOGIN")
	end
end

function BattleGroundEnemies.Enemies:ChangeName(oldName, newName)  --only used in arena when players switch from "arenaX" to a real name
	local playerButton = self.Players[oldName]
	if playerButton then
		playerButton.PlayerName = newName
		playerButton:DispatchEvent("OnNewPlayer")

		self.Players[newName] = playerButton
		self.Players[oldName] = nil
	end
end


function BattleGroundEnemies.Enemies:CreateOrUpdateArenaEnemyPlayer(unitID, name, race, classTag, specName)
	local playerName
	if name and name ~= UNKNOWN then
		-- player has a real name, check if he is already shown as arenaX

		BattleGroundEnemies.Enemies:ChangeName(unitID, name)
		playerName = name
	else
		-- use the unitID
		playerName = unitID
	end
	self:CreateOrUpdatePlayer(playerName, race, classTag, specName, {PlayerArenaUnitID = unitID})


	local playerButton = self.Players[playerName]
	if playerButton then
		if playerButton.PlayerArenaUnitID ~= unitID then--just in case the arena unitID changes
			playerButton.PlayerArenaUnitID = unitID
		end
	end
end

local activeCreateArenaEnemiesTimer
function BattleGroundEnemies.Enemies:CreateArenaEnemies()
	if not IsInArena or IsInBrawl() then return end
	if InCombatLockdown() then
		if not activeCreateArenaEnemiesTimer then
			activeCreateArenaEnemiesTimer = true
			C_Timer.After(2, function()
				activeCreateArenaEnemiesTimer = false
				BattleGroundEnemies.Enemies:CreateArenaEnemies()
			end)
		end
		return
	end
	wipe(self.NewPlayerDetails)
	local foundEnemies = 0
	for i = 1, MAX_ARENA_ENEMIES or 5 do
		local unitID = "arena"..i
		local name = GetUnitName(unitID, true)

		local _, classTag, specName

		local specName, classTag
		if HasSpeccs then
			local specID, gender = GetArenaOpponentSpec(i)


			if (specID and specID > 0) then
				_, specName, _, _, _, classTag, _ = GetSpecializationInfoByID(specID, gender)
			end
		else
			classTag = select(2, UnitClass(unitID))
		end



		local raceName = UnitRace(unitID)

		if (specName or not HasSpeccs) and classTag then
			self:CreateOrUpdateArenaEnemyPlayer(unitID, name, raceName or "placeholder", classTag, specName)
			foundEnemies = foundEnemies + 1
		end
	end

	self:DeleteAndCreateNewPlayers()
end

BattleGroundEnemies.Enemies.ARENA_PREP_OPPONENT_SPECIALIZATIONS = BattleGroundEnemies.Enemies.CreateArenaEnemies -- for Prepframe, not available in TBC

function BattleGroundEnemies.Enemies:UNIT_NAME_UPDATE(unitID)
	local name = GetUnitName(unitID, true)
	self:ChangeName(unitID, name)
end


function BattleGroundEnemies.Enemies:NAME_PLATE_UNIT_ADDED(unitID)
	local enemyButton = self:GetPlayerbuttonByUnitID(unitID)
	if enemyButton then
		enemyButton:FetchAnotherUnitID("Nameplate", unitID)
	end
end

function BattleGroundEnemies.Enemies:NAME_PLATE_UNIT_REMOVED(unitID)
	--self:Debug(unitID)
	local enemyButton = self:GetPlayerbuttonByUnitID(unitID)
	if enemyButton then
		enemyButton:FetchAnotherUnitID("Nameplate", false)
	end
end






--Notes about UnitIDs
--priority of unitIDs:
--1. Arena, detected by UNIT_HEALTH (health upate), ARENA_OPPONENT_UPDATE (this units exist, don't exist anymore), we need to check for UnitExists() since there is a small time frame after the objective isn't on that target anymore where UnitExists returns false for that unitID
--2. nameplates, detected by UNIT_HEALTH, NAME_PLATE_UNIT_ADDED, NAME_PLATE_UNIT_REMOVED
--3. player's target
--4. player's focus
--5. ally targets, UNIT_TARGET fires if the target changes, we need to check for UnitExists() since there is a small time frame after an ally lost that enemy where UnitExists returns false for that unitID



function BattleGroundEnemies:NotifyChange()
	AceConfigRegistry:NotifyChange("BattleGroundEnemies")
	self:ProfileChanged()
end

function BattleGroundEnemies:ProfileChanged()
	self:SetupOptions()
	self:ApplyAllSettings()
end


local timer = nil
function BattleGroundEnemies:ApplyAllSettings()
	if timer then timer:Cancel() end -- use a timer to apply changes after 0.2 second, this prevents the UI from getting laggy when the user uses a slider option
	timer = CTimerNewTicker(0.2, function()
		BattleGroundEnemies.Enemies:ApplyAllSettings()
		BattleGroundEnemies.Allies:ApplyAllSettings()
		timer = nil
	end, 1)
end

BattleGroundEnemies.DebugText = BattleGroundEnemies.DebugText or ""
function BattleGroundEnemies:Debug(...)
	if self.db and self.db.profile.Debug then

		if not self.debugFrame then
			self.debugFrame = CreatedebugFrame()
		end

		local args = {...}
		local text = ""

		local timestampFormat = "[%I:%M:%S] " --timestamp format
		local stamp = BetterDate(timestampFormat, time())
		text = stamp

		for i = 1, #args do
			text = text.. " ".. tostring(args[i])
		end

		self.debugFrame:AddMessage(text)
	end
end

local sentMessages = {}

function BattleGroundEnemies:OnetimeInformation(...)
	local message = table.concat({...}, ", ")
	if sentMessages[message] then return end
	print("|cff0099ffBattleGroundEnemies:|r", message)
	sentMessages[message] = true
end

function BattleGroundEnemies:Information(...)
	print("|cff0099ffBattleGroundEnemies:|r", ...)
end


--fires when a arena enemy appears and a frame is ready to be shown
function BattleGroundEnemies:ARENA_OPPONENT_UPDATE(unitID, unitEvent)
	--unitEvent can be: "seen", "unseen", "destroyed", "cleared"
	--self:Debug("ARENA_OPPONENT_UPDATE", unitID, unitEvent, UnitName(unitID))

	if unitEvent == "cleared" then --"unseen", "cleared" or "destroyed"
		local playerButton = self.ArenaIDToPlayerButton[unitID]
		if playerButton then
			--BattleGroundEnemies:Debug("ARENA_OPPONENT_UPDATE", playerButton.DisplayedName, "ObjectiveLost")

			self.ArenaIDToPlayerButton[unitID] = nil
			playerButton.ObjectiveAndRespawn:Reset()

			if playerButton.PlayerIsEnemy then -- then this button is an ally button
				playerButton:FetchAnotherUnitID("Arena", false)
			end
			playerButton:DispatchEvent("ArenaOpponentHidden")
		end
	else
		self.Enemies:CreateArenaEnemies()

		--"seen", "unseen" or "destroyed"
		--self:Debug(UnitName(unitID))
		local playerButton = self:GetPlayerbuttonByUnitID(unitID)
		if playerButton then
			--self:Debug("Button exists")
			playerButton:ArenaOpponentShown(unitID)
		end
	end
end

function BattleGroundEnemies:GetPlayerbuttonByUnitID(unitID)
	local uName = GetUnitName(unitID, true)
	return self.Enemies.Players[uName] or self.Allies.Players[uName]
end

function BattleGroundEnemies:GetPlayerbuttonByName(name)
	return self.Enemies.Players[name] or self.Allies.Players[name]
end

local CombatLogevents = {}
BattleGroundEnemies.CombatLogevents = CombatLogevents

--[[ function CombatLogevents.SPELL_AURA_APPLIED(self, srcName, destName, spellID, spellName, auraType, amount)
	local playerButton = self:GetPlayerbuttonByName(destName)
	if playerButton and playerButton.isShown then
		playerButton:AuraApplied(spellID, spellName, srcName, auraType, amount)
	end
end ]]

-- fires when the stack of a aura increases
--[[ function CombatLogevents.SPELL_AURA_APPLIED_DOSE(self, srcName, destName, spellID, spellName, auraType, amount)
	local playerButton = self:GetPlayerbuttonByName(destName)
	if playerButton and playerButton.isShown then
		playerButton:AuraApplied(spellID, spellName, srcName, auraType, amount)
	end
end ]]
-- fires when the stack of a aura decreases
--[[ function CombatLogevents.SPELL_AURA_REMOVED_DOSE(self, srcName, destName, spellID, spellName, auraType, amount)
	local playerButton = self:GetPlayerbuttonByName(destName)
	if playerButton and playerButton.isShown then
		playerButton:AuraApplied(spellID, spellName, srcName, auraType, amount)
	end
end ]]


function CombatLogevents.SPELL_AURA_REFRESH(self, srcName, destName, spellID, spellName, auraType, amount)
	local playerButton = self:GetPlayerbuttonByName(destName)
	if playerButton and playerButton.isShown then
		playerButton:AuraRemoved(spellID, spellName)
	end
end

function CombatLogevents.SPELL_AURA_REMOVED(self, srcName, destName, spellID, spellName, auraType)
	local playerButton = self:GetPlayerbuttonByName(destName)
	if playerButton and playerButton.isShown then
		playerButton:AuraRemoved(spellID, spellName)
	end
end

--CombatLogevents.SPELL_DISPEL = CombatLogevents.SPELL_AURA_REMOVED

function CombatLogevents.SPELL_CAST_SUCCESS(self, srcName, destName, spellID)
	local playerButton = self:GetPlayerbuttonByName(srcName)
	if playerButton and playerButton.isShown then
		playerButton:DispatchEvent("SPELL_CAST_SUCCESS", srcName, destName, spellID)

		local defaultInterruptDuration = Data.Interruptdurations[spellID]
		if defaultInterruptDuration then -- check if enemy got interupted
			if playerButton.PlayerIsEnemy then
				local activeUnitID = playerButton.UnitIDs.Active
				if activeUnitID then
					if UnitExists(activeUnitID) then
						local _,_,_,_,_,_,_, notInterruptible = UnitChannelInfo(activeUnitID)  --This guy was channeling something and we casted a interrupt on him
						if notInterruptible == false then --spell is interruptable
							playerButton:DispatchEvent("GotInterrupted", spellID, defaultInterruptDuration)
						end
					end
				end
			elseif playerButton.unit then -- its an ally, check if it has an unitID assigned
				local _,_,_,_,_,_,_, notInterruptible = UnitChannelInfo(playerButton.unit) --This guy was channeling something and we casted a interrupt on him
				if notInterruptible == false then --spell is interruptable
					playerButton:DispatchEvent("GotInterrupted", spellID, defaultInterruptDuration)
				end
			end
		end
	end
end

function CombatLogevents.SPELL_INTERRUPT(self, _, destName, spellID, _, _)
	local playerButton = self:GetPlayerbuttonByName(destName)
	if playerButton and playerButton.isShown then
		local defaultInterruptDuration = Data.Interruptdurations[spellID]
		if defaultInterruptDuration then
			playerButton:DispatchEvent("GotInterrupted", spellID, defaultInterruptDuration)
		end
	end
end

CombatLogevents.Counter = {}
function CombatLogevents.UNIT_DIED(self, _, destName, _, _, _)
	--self:Debug("subevent", destName, "UNIT_DIED")
	local playerButton = self:GetPlayerbuttonByName(destName)
	if playerButton then
		playerButton:PlayerDied()
	end
end


function BattleGroundEnemies:COMBAT_LOG_EVENT_UNFILTERED()
	local timestamp,subevent,hide,srcGUID,srcName,srcF1,srcF2,destGUID,destName,destF1,destF2,spellID,spellName,spellSchool, auraType = CombatLogGetCurrentEventInfo()
	--self:Debug(timestamp,subevent,hide,srcGUID,srcName,srcF1,srcF2,destGUID,destName,destF1,destF2,spellID,spellName,spellSchool, auraType)
	local covenantID = Data.CovenantSpells[spellID]
	if covenantID then
		local playerButton = self:GetPlayerbuttonByName(srcName)
		if playerButton then
			-- this player used a covenant ability show an icon for that
			playerButton.Covenant:DisplayCovenant(covenantID)
		end
	end
	if CombatLogevents[subevent] then
		-- IsClassic: spellID is always 0, so we have to work with the spellname :( but at least UnitAura() shows spellIDs
		CombatLogevents.Counter[subevent] = (CombatLogevents.Counter[subevent] or 0) + 1
		return CombatLogevents[subevent](self, srcName, destName, spellID, spellName, auraType)
	end
end

local function IamTargetcaller()
	return (BattleGroundEnemies.PlayerDetails.isGroupLeader and #BattleGroundEnemies.Allies.assistants == 0) or (not BattleGroundEnemies.PlayerDetails.isGroupLeader and BattleGroundEnemies.PlayerDetails.isGroupAssistant)
end

do
	local oldTarget
	function BattleGroundEnemies:PLAYER_TARGET_CHANGED()
		local playerButton = self:GetPlayerbuttonByUnitID("target")

		if oldTarget then
			if oldTarget.PlayerIsEnemy then
				oldTarget.UnitIDs.TargetedByEnemy[PlayerButton] = nil
				oldTarget:UpdateTargetIndicators()
				oldTarget:FetchAnotherUnitID("Target", false)
			end
			oldTarget.MyTarget:Hide()
		end

		if playerButton then --ally targets an existing enemy
			if playerButton.PlayerIsEnemy and PlayerButton then
				playerButton.UnitIDs.TargetedByEnemy[PlayerButton] = true
				playerButton:UpdateTargetIndicators()
				playerButton:FetchAnotherUnitID("Target", "target")
			end
			playerButton.MyTarget:Show()
			oldTarget = playerButton


			if BattleGroundEnemies.IsRatedBG and self.db.profile.RBG.TargetCalling_SetMark and IamTargetcaller() then  -- i am the target caller
				SetRaidTarget("target", 8)
			end
		else
			oldTarget = false
		end
	end
end

do
	local oldFocus
	function BattleGroundEnemies:PLAYER_FOCUS_CHANGED()
		if not PlayerButton then return end

		local playerButton = self:GetPlayerbuttonByUnitID("focus")
		if oldFocus then
			if oldFocus.PlayerIsEnemy then
				oldFocus:FetchAnotherUnitID("Focus", false)
			end
			oldFocus.MyFocus:Hide()
		end
		if playerButton then
			if playerButton.PlayerIsEnemy then
				playerButton:FetchAnotherUnitID("Focus", "focus")
			end
			playerButton.MyFocus:Show()
			oldFocus = playerButton
		else
			oldFocus = false
		end
	end
end


function BattleGroundEnemies:UPDATE_MOUSEOVER_UNIT()
	local enemyButton = self.Enemies:GetPlayerbuttonByUnitID("mouseover")
	if enemyButton then --unit is a shown enemy
		enemyButton:UpdateAll("mouseover")
	end
end




-- function BattleGroundEnemies:LOSS_OF_CONTROL_ADDED()
	-- local numEvents = C_LossOfControl.GetNumEvents()
	-- for i = 1, numEvents do
		-- local locType, spellID, text, iconTexture, startTime, timeRemaining, duration, lockoutSchool, priority, displayType = C_LossOfControl.GetEventInfo(i)
		-- --self:Debug(C_LossOfControl.GetEventInfo(i))
		-- if not self.LOSS_OF_CONTROL then self.LOSS_OF_CONTROL = {} end
		-- self.LOSS_OF_CONTROL[spellID] = locType
	-- end
-- end


--fires when data requested by C_PvP.RequestCrowdControlSpell(unitID) is available
function BattleGroundEnemies:ARENA_CROWD_CONTROL_SPELL_UPDATE(unitID, ...)
	local playerButton = self:GetPlayerbuttonByUnitID(unitID)
	if not playerButton then playerButton = self:GetPlayerbuttonByName(unitID) end -- the event fires before the name is set on the frame, so at this point the name is still the unitID
	if playerButton then
		if IsClassic or IsTBCC or IsWrath then
			local spellID, itemID = ...
			if(itemID ~= 0) then
				local itemTexture = GetItemIcon(itemID);
				playerButton.Trinket:DisplayTrinket(spellID, itemTexture)
			else
				local spellTexture, spellTextureNoOverride = GetSpellTexture(spellID);
				playerButton.Trinket:DisplayTrinket(spellID, spellTextureNoOverride)
			end
		else
			local spellID = ...
			local spellTexture, spellTextureNoOverride = GetSpellTexture(spellID);
			playerButton.Trinket:DisplayTrinket(spellID, spellTextureNoOverride)
		end
	end

	--if spellID ~= 72757 then --cogwheel (30 sec cooldown trigger by racial)
	--end
end


--fires when a arenaX enemy used a trinket or racial to break cc, C_PvP.GetArenaCrowdControlInfo(unitID) shoudl be called afterwards to get used CCs
--this event is kinda stupid, it doesn't say which unit used which cooldown, it justs says that somebody used some sort of trinket
function BattleGroundEnemies:ARENA_COOLDOWNS_UPDATE()

	--if not self.db.profile.Trinket then return end
	for i = 1, 5 do
		local unitID = "arena"..i
		local playerButton = self:GetPlayerbuttonByUnitID(unitID)
		if playerButton then


			if IsClassic or IsTBCC or IsWrath then
				local spellID, itemID, startTime, duration = GetArenaCrowdControlInfo(unitID)
				if spellID then

					if(itemID ~= 0) then
						local itemTexture = GetItemIcon(itemID)
						playerButton.Trinket:DisplayTrinket(spellID, itemTexture)
					else
						local spellTexture, spellTextureNoOverride = GetSpellTexture(spellID)
						playerButton.Trinket:DisplayTrinket(spellID, spellTextureNoOverride)
					end

					playerButton.Trinket:SetTrinketCooldown(startTime/1000.0, duration/1000.0)
				end
			else
				local spellID, startTime, duration = C_PvP.GetArenaCrowdControlInfo(unitID)
				if spellID then
					local spellTexture, spellTextureNoOverride = GetSpellTexture(spellID)
					playerButton.Trinket:DisplayTrinket(spellID, spellTextureNoOverride)
					playerButton.Trinket:SetTrinketCooldown(startTime/1000.0, duration/1000.0)
				end
			end
		end
	end
end

function BattleGroundEnemies:RAID_TARGET_UPDATE()
	for name, playerButton in pairs(self.Allies.Players) do
		playerButton:UpdateRaidTargetIcon()
	end
	for name, playerButton in pairs(self.Enemies.Players) do
		playerButton:UpdateRaidTargetIcon()
	end
end


function BattleGroundEnemies:UNIT_AURA(unitID, isFullUpdate, updatedAuraInfos)
	local playerButton = self:GetPlayerbuttonByUnitID(unitID)
	if playerButton and playerButton.isShown then
		playerButton:UNIT_AURA(unitID, isFullUpdate, updatedAuraInfos)
	end
end

function BattleGroundEnemies:UNIT_HEALTH(unitID) --gets health of nameplates, player, target, focus, raid1 to raid40, partymember
	local playerButton = self:GetPlayerbuttonByUnitID(unitID)
	if playerButton and playerButton.isShown then --unit is a shown player
		playerButton:UNIT_HEALTH(unitID)
	end
end

BattleGroundEnemies.UNIT_HEALTH_FREQUENT = BattleGroundEnemies.UNIT_HEALTH --used to be used only in tbc, now its only used in classic and wrath
BattleGroundEnemies.UNIT_MAXHEALTH = BattleGroundEnemies.UNIT_HEALTH
BattleGroundEnemies.UNIT_HEAL_PREDICTION = BattleGroundEnemies.UNIT_HEALTH
BattleGroundEnemies.UNIT_ABSORB_AMOUNT_CHANGED = BattleGroundEnemies.UNIT_HEALTH
BattleGroundEnemies.UNIT_HEAL_ABSORB_AMOUNT_CHANGED = BattleGroundEnemies.UNIT_HEALTH


function BattleGroundEnemies:UNIT_POWER_FREQUENT(unitID, powerToken) --gets power of nameplates, player, target, focus, raid1 to raid40, partymember
	local playerButton = self:GetPlayerbuttonByUnitID(unitID)
	if playerButton and playerButton.isShown then --unit is a shown enemy
		playerButton:UNIT_POWER_FREQUENT(unitID, powerToken)
	end
end


function BattleGroundEnemies:PlayerAlive()
	--recheck the targets of groupmembers
	for allyName, allyButton in pairs(self.Allies.Players) do
		allyButton:UpdateTargets()
	end
	self.PlayerIsAlive = true
end

function BattleGroundEnemies:PLAYER_ALIVE()
	if UnitIsGhost("player") then --Releases his ghost to a graveyard.
		self.PlayerIsAlive = false
	else --alive (revived while not being a ghost)
		self:PlayerAlive()
	end
end

function BattleGroundEnemies:UNIT_TARGET(unitID)
	--self:Debug("unitID:", unitID, "unitname:", UnitName(unitID), "unittarget:", UnitName(unitID.."target"))

	local playerButton = self:GetPlayerbuttonByUnitID(unitID)
	if playerButton and playerButton ~= PlayerButton then
		playerButton:UpdateTargets()
	end
end


BattleGroundEnemies.PLAYER_UNGHOST = BattleGroundEnemies.PlayerAlive --player is alive again





do
	do
		function BattleGroundEnemies:ToggleArenaFrames()
			if not self then self = BattleGroundEnemies end

			if not InCombatLockdown() then
				if self.db.profile.DisableArenaFrames then
					if self.CurrentMapID then
						return ArenaEnemyFrames_Disable and ArenaEnemyFrames_Disable(ArenaEnemyFrames)
					else
						if ArenaEnemyFrames_CheckEffectiveEnableState then ArenaEnemyFrames_CheckEffectiveEnableState(ArenaEnemyFrames) end
					end
				else
					if ArenaEnemyFrames_CheckEffectiveEnableState then ArenaEnemyFrames_CheckEffectiveEnableState(ArenaEnemyFrames) end
				end
			else
				C_Timer.After(0.1, self.ToggleArenaFrames)
			end
		end


		local numArenaOpponents

		local function ArenaEnemiesAtBeginn()
			BattleGroundEnemies.Enemies:CreateArenaEnemies()
			if #BattleGroundEnemies.Enemies.CurrentPlayerOrder > 1 or #BattleGroundEnemies.Allies.CurrentPlayerOrder > 1 then --this ensures that we checked for enmys and the flag carrier will be shown (if its an enemy)
				for i = 1,  numArenaOpponents do
					local unitID = "arena"..i
					--BattleGroundEnemies:Debug(UnitName(unitID))
					local playerButton = BattleGroundEnemies:GetPlayerbuttonByUnitID(unitID)
					if playerButton then
						--BattleGroundEnemies:Debug("Button exists")
						playerButton:ArenaOpponentShown(unitID)
					end
				end
			else
				C_Timer.After(2, ArenaEnemiesAtBeginn)
			end
		end



		local function parseBattlefieldScore(index)
			if C_PvP and C_PvP.GetScoreInfo then
				local scoreInfo = C_PvP.GetScoreInfo(index)
				if not scoreInfo then return end
				if not type(scoreInfo) == "table" then return end
				return scoreInfo.name, scoreInfo.faction, scoreInfo.raceName, scoreInfo.classToken, scoreInfo.talentSpec
			else
				local _, name, faction, race, classTag, specName
				if HasSpeccs then
					--name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class, classToken, damageDone, healingDone = GetBattlefieldScore(index)
					name, _, _, _, _, faction, race, _, classTag, _, _, _, _, _, _, specName = GetBattlefieldScore(index)
				else
					name, _, _, _, _, faction, _, race, _, classTag = GetBattlefieldScore(index)
				end
				return name, faction, race, classTag, specName
			end
		end

		function BattleGroundEnemies:UPDATE_BATTLEFIELD_SCORE()
			-- self:Debug(GetCurrentMapAreaID())
			-- self:Debug("UPDATE_BATTLEFIELD_SCORE")
			-- self:Debug("GetBattlefieldArenaFaction", GetBattlefieldArenaFaction())
			-- self:Debug("C_PvP.IsInBrawl", C_PvP.IsInBrawl())
			-- self:Debug("GetCurrentMapAreaID", GetCurrentMapAreaID())
			-- self:Debug("horde players:", GetBattlefieldTeamInfo(0))
			-- self:Debug("alliance players:", GetBattlefieldTeamInfo(1))



			if not self.CurrentMapID then
				local wmf = WorldMapFrame
				if wmf and not wmf:IsShown() then
				--	SetMapToCurrentZone() apparently removed in 8.0
					local mapID = GetBestMapForUnit('player')

					--self:Debug(mapID)
					if (mapID == -1 or mapID == 0) and not IsInArena then --if this values occur GetCurrentMapAreaID() doesn't return valid values yet.
						return
					end
					self.CurrentMapID = mapID
				end


				numArenaOpponents = GetNumArenaOpponents()-- returns valid data on PLAYER_ENTERING_WORLD
					--self:Debug(numArenaOpponents)
				if numArenaOpponents > 0 then
					C_Timer.After(2, ArenaEnemiesAtBeginn)
				end


				--self:Debug("test")
				if IsInArena and not IsInBrawl() then

				--	self:Hide() --stopp the OnUpdateScript
					return -- we are in a arena, UPDATE_BATTLEFIELD_SCORE is not the event we need
				end

				if GetBattlefieldArenaFaction then
					local MyBgFaction = GetBattlefieldArenaFaction()  -- returns the playered faction 0 for horde, 1 for alliance, doesnt exist in TBC
					self:Debug("MyBgFaction:", MyBgFaction)
					if MyBgFaction == 0 then -- i am Horde
						self.EnemyFaction = 1 --Enemy is Alliance
						self.AllyFaction = 0
					else
						self.EnemyFaction = 0 --Enemy is Horde
						self.AllyFaction = 1
					end
				else
					self.EnemyFaction = 0 -- set a dummy value, we get data later from GetBattlefieldScore()
					self.AllyFaction = 1 -- set a dummy value, we get data later from GetBattlefieldScore()
				end

				if Data.BattlegroundspezificBuffs[self.CurrentMapID] then
					self.BattlegroundBuff = Data.BattlegroundspezificBuffs[self.CurrentMapID]
				end

				BattleGroundEnemies.BattleGroundDebuffs = Data.BattlegroundspezificDebuffs[self.CurrentMapID]


				BattleGroundEnemies:ToggleArenaFrames()

				if HasRBG then
					C_Timer.After(5, function() --Delay this check, since its happening sometimes that this data is not ready yet
						self.IsRatedBG = IsRatedBattleground()
					end)
				end

				--self:Debug("IsRatedBG", IsRatedBG)
			end

			local _, _, _, _, numEnemies = GetBattlefieldTeamInfo(self.EnemyFaction)
			local _, _, _, _, numAllies = GetBattlefieldTeamInfo(self.AllyFaction)

			self:Debug("numEnemies:", numEnemies)
			self:Debug("numAllies:", numAllies)

			if InCombatLockdown() then return end

			self.Enemies:UpdatePlayerCount(numEnemies)
			self.Allies:UpdatePlayerCount(numAllies)




			wipe(self.Enemies.NewPlayerDetails) --use a local table to not create an unnecessary new button if another player left
			wipe(self.Allies.NewPlayerDetails) --use a local table to not create an unnecessary new button if another player left

			local numScores = GetNumBattlefieldScores()
			self:Debug("numScores:", numScores)

			local foundAllies = 0
			local foundEnemies = 0
			for i = 1, numScores do
				local name, faction, race, classTag, specName = parseBattlefieldScore(i)

				--self:Debug("player", "name:", name, "faction:", faction, "race:", race, "classTag:", classTag, "specName:", specName)
				--name = name-realm, faction = 0 or 1, race = localized race e.g. "Mensch",classTag = e.g. "PALADIN", spec = localized specname e.g. "holy"
				--locale dependent are: race, specName

				if faction and name and classTag then
					--if name == PlayerDetails.PlayerName then EnemyFaction = EnemyFaction == 1 and 0 or 1 return end --support for the new brawl because GetBattlefieldArenaFaction() returns wrong data on that BG
					 if name == self.PlayerDetails.PlayerName and faction == self.EnemyFaction then
						self.EnemyFaction = self.AllyFaction
						self.AllyFaction = faction

						return
					end
					if faction == self.EnemyFaction then
						self.Enemies:CreateOrUpdatePlayer(name, race, classTag, specName)
						foundEnemies = foundEnemies + 1
					else
						self.Allies:CreateOrUpdatePlayer(name, race, classTag, specName)
						foundAllies = foundAllies + 1
					end
				end
			end

			if foundEnemies == 0 then
				if numEnemies ~= 0 then
					self:Debug("Missing Enemies, probably the ally tab is selected")
				end
			else
				self.Enemies:DeleteAndCreateNewPlayers()
			end

			if foundAllies == 0 then
				if numAllies ~= 0 then
					self:Debug("Missing Allies, probably the enemy tab is selected")
				end
			else
				self.Allies:DeleteAndCreateNewPlayers()
			end
		end--functions end
	end-- do-end block end for locals of the function UPDATE_BATTLEFIELD_SCORE


	function BattleGroundEnemies.Allies:AddGroupMember(name, isLeader, isAssistant, classTag, unitID)
		local raceName, raceFile, raceID = UnitRace(unitID)

		local GUID = UnitGUID(unitID)
		local additionalData = {
			isGroupLeader = isLeader,
			isGroupAssistant = isAssistant,
			unitID = unitID,
			GUID = GUID
		}

		if name and raceName and classTag then
			local specName
			if HasSpeccs then
				specName = specCache[GUID]
			end

			self:CreateOrUpdatePlayer(name, raceName, classTag, specName, additionalData)
		end

		self.GUIDToAllyname[GUID] = name

		if isLeader then
			self.groupLeader = name
		end
		if isAssistant then
			table_insert(self.assistants, name)
		end
	end

	function BattleGroundEnemies.Allies:UpdateAllUnitIDs()
		for allyName, allyButton in pairs(self.Players) do
			if allyButton then
				if allyButton.PlayerName ~= BattleGroundEnemies.PlayerDetails.PlayerName then
					local unitID = allyButton.unitID
					if not unitID then return end

					if allyButton.unit ~= unitID then --it happens that numGroupMembers is higher than the value of the maximal players for that battleground, for example 15 in a 10 man bg, thats why we wipe AllyUnitIDToAllyDetails
						-- ally has a new unitID now
						local targetUnitID = unitID.."target"

						--self:Debug("player", groupMember.PlayerName, "has a new unit and targeted something")

						local targetEnemyButton = allyButton.Target
						if targetEnemyButton then

							--self:Debug("player", groupMember.PlayerName, "has a new unit and targeted something")
							if targetEnemyButton.UnitIDs.Active == allyButton.TargetUnitID then
								targetEnemyButton.UnitIDs.Active = targetUnitID
							end
							if targetEnemyButton.UnitIDs.Ally == allyButton.TargetUnitID then
								targetEnemyButton:FetchAnotherUnitID("Ally", targetUnitID)
							end
						end

						allyButton:NewUnitID(unitID, targetUnitID)
					end
				else
					allyButton:NewUnitID("player", "target")
					PlayerButton = allyButton
				end
			end
		end
	end

	local ticker
	local lastRun = GetTime()
	function BattleGroundEnemies:GROUP_ROSTER_UPDATE()

		wipe(self.Allies.NewPlayerDetails)
		self.Allies.groupLeader = nil
		self.Allies.assistants = {}

		--if not IsInGroup() then return end  --IsInGroup returns true when user is in a Raid and In a 5 man group

		self:RequestEverythingFromGroupmembers()

		if self.TestmodeActive then return end

		-- GetRaidRosterInfo also works when in a party (not raid) but i am not 100% sure how the party unitID maps to the index in GetRaidRosterInfo()

		local numGroupMembers = GetNumGroupMembers()
		self.Allies:UpdatePlayerCount(numGroupMembers)

		if IsInRaid() then
			local unitIDPrefix = "raid"

			for i = 1, numGroupMembers do -- the player itself only shows up here when he is in a raid
				local name, rank, subgroup, level, localizedClass, classTag, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)

				if name and rank and classTag then
					self.Allies:AddGroupMember(name, rank == 2, rank == 1, classTag, unitIDPrefix..i)
				end
			end
		else
			-- we are in a party, 5 man group
			local unitIDPrefix = "party"

			for i = 1, numGroupMembers do
				local unitID = unitIDPrefix..i
				local name = GetUnitName(unitID, true)

				local classTag = select(2, UnitClass(unitID))

				if name and classTag then
					self.Allies:AddGroupMember(name, UnitIsGroupLeader(unitID), UnitIsGroupAssistant(unitID), classTag, unitID)
				end
			end

			self.PlayerDetails.isGroupLeader = UnitIsGroupLeader("player")
			self.PlayerDetails.isGroupAssistant = UnitIsGroupAssistant("player")
			self.Allies:AddGroupMember(self.PlayerDetails.PlayerName, self.PlayerDetails.isGroupLeader, self.PlayerDetails.isGroupAssistant, self.PlayerDetails.PlayerClass, "player")
		end


		if InCombatLockdown() then
			C_Timer.After(1, function() BattleGroundEnemies:GROUP_ROSTER_UPDATE() end)
		else
			self.Allies:DeleteAndCreateNewPlayers()
			self.Allies:UpdateAllUnitIDs()
		end
	end

	BattleGroundEnemies.PARTY_LEADER_CHANGED = BattleGroundEnemies.GROUP_ROSTER_UPDATE


	function BattleGroundEnemies:PLAYER_ENTERING_WORLD()
		if self.TestmodeActive then --disable testmode
			self:DisableTestMode()
		end

		self.CurrentMapID = false

		local _, zone = IsInInstance()

		if zone == "pvp" or zone == "arena" then
			self:Show()
			if zone == "arena" then
				IsInArena = true
				if not IsInBrawl() then
					self.Enemies:RemoveAllPlayers()
				end
			end


			-- self:Debug("PLAYER_ENTERING_WORLD")
			-- self:Debug("GetBattlefieldArenaFaction", GetBattlefieldArenaFaction())
			-- self:Debug("C_PvP.IsInBrawl", C_PvP.IsInBrawl())
			-- self:Debug("GetCurrentMapAreaID", GetCurrentMapAreaID())

			self.PlayerIsAlive = true
		else
			self:ToggleArenaFrames()
			IsInArena = false
			self:Hide()
		end
	end
end
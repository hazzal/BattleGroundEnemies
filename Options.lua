local addonName, Data = ...
local GetAddOnMetadata = GetAddOnMetadata

local L = LibStub("AceLocale-3.0"):GetLocale("BattleGroundEnemies")
local LSM = LibStub("LibSharedMedia-3.0")
local DRData = LibStub("DRData-1.0")


local function getOption(option)
	local value = option.arg and BattleGroundEnemies.db.profile[option.arg] or BattleGroundEnemies.db.profile[option[#option]]
	if type(value) == "table" then
		return unpack(value)
	else
		return value
	end
end

local function setOption(option, value)
	-- local setting = BattleGroundEnemies.db
	-- for i = 1, #option do
		-- setting = setting[option[i]]
	-- end
	-- setting = value
	-- print(option.arg, value, option[0], option[1], option[2], option[3], option[4])
	local key = option[#option]
	-- print(key, value)
	-- print(unpack(value))
	BattleGroundEnemies.db.profile[key] = value
end
		
local function UpdateButtons(option, value, subtablename, subsubtablename, func, farg1, farg2, farg3, farg4)
	for name, enemyButton in pairs(BattleGroundEnemies.Enemys) do
		local buttonobject = enemyButton
		if subtablename then buttonobject = buttonobject[subtablename] end
		if subsubtablename then buttonobject = buttonobject[subsubtablename] end
		buttonobject[func](buttonobject, farg1, farg2, farg3, farg4)
	end
	for number, enemyButton in ipairs(BattleGroundEnemies.InactiveEnemyButtons) do
		local buttonobject = enemyButton
		if subtablename then buttonobject = buttonobject[subtablename] end
		if subsubtablename then buttonobject = buttonobject[subsubtablename] end
		buttonobject[func](buttonobject, farg1, farg2, farg3, farg4)
	end
	setOption(option, value)
end


function BattleGroundEnemies:SetupOptions()
	self.options = {
		type = "group",
		name = "BattleGroundEnemies " .. GetAddOnMetadata(addonName, "Version"),
		childGroups = "tab",
		get = getOption,
		set = setOption,
		args = {
			GeneralSettings = {
				type = "group",
				name = L.GeneralSettings,
				desc = L.GeneralSettings_Desc,
				order = 1,
				args = {
					Locked = {
						type = "toggle",
						name = L.Locked,
						desc = L.Locked_Desc,
						order = 1
					},
					Framescale = {
						type = "range",
						name = L.Framescale,
						desc = L.Framescale_Desc,
						disabled = InCombatLockdown,
						set = function(option, value) 
							self:SetScale(value)
							setOption(option, value)
						end,
						min = 0.3,
						max = 2,
						step = 0.05,
						order = 2
					},
					MaxPlayers = {
						type = "range",
						name = L.MaxPlayers,
						desc = L.MaxPlayers_Desc,
						min = 1,
						max = 15,
						step = 1,
						order = 3
					},
					DisableArenaFrames = {
						type = "toggle",
						name = L.DisableArenaFrames,
						desc = L.DisableArenaFrames_Desc,
						set = function(option, value) 
							setOption(option, value)
							self:ToggleArenaFrames()
						end,
						order = 4
					},
					Font = {
						type = "select",
						name = L.Font,
						desc = L.Font_Desc,
						set = function(option, value)
							for name, enemyButton in pairs(self.Enemys) do
								enemyButton.Name:SetFont(LSM:Fetch("font", value), self.db.profile.Name_Fontsize)
								enemyButton.TargetCounter.Text:SetFont(LSM:Fetch("font", value), self.db.profile.NumericTargetindicator_Fontsize)
								enemyButton.ObjectiveAndRespawn.AuraText:SetFont(LSM:Fetch("font", value), self.db.profile.ObjectiveAndRespawn_Fontsize)
							end
							for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
								enemyButton.Name:SetFont(LSM:Fetch("font", value), self.db.profile.Name_Fontsize)
								enemyButton.TargetCounter.Text:SetFont(LSM:Fetch("font", value), self.db.profile.NumericTargetindicator_Fontsize)
								enemyButton.ObjectiveAndRespawn.AuraText:SetFont(LSM:Fetch("font", value), self.db.profile.ObjectiveAndRespawn_Fontsize)
							end
							setOption(option, value)
						end,
						dialogControl = "LSM30_Font",
						values = AceGUIWidgetLSMlists.font,
						order = 5
					},
				

					-- RoleIcon_Enabled = {
						-- type = "toggle",
						-- name = L.RoleIcon_Enabled,
						-- desc = L.RoleIcon_Enabled_Desc,
						-- set = function(option, ...)
							-- UpdateButtons(option, value, "Role", "Icon", "SetShown", value)
						-- end,
						-- order = 6
					-- },
		
					Growdirection = {
						type = "select",
						name = L.Growdirection,
						desc = L.Growdirection_Desc,
						set = function(option, value) 
							local previousButton = self
							for number, name in ipairs(self.EnemySortingTable) do
					
								local enemyButton = self.Enemys[name]
								enemyButton:SetPosition(value, previousButton, self.db.profile.SpaceBetweenRows)
								previousButton = enemyButton
							end
							if value == "downwards" then
								self.EnemyCount:SetJustifyV("BOTTOM")
							else
								self.EnemyCount:SetJustifyV("TOP")
							end
							setOption(option, value)
						end,
						values = {upwards = "upwards", downwards = "downwards"},
						order = 9
					},
					Fake = {
						type = "description",
						name = " ",
						fontSize = "large",
						width = "full",
						order = 10
					},
					EnemyCount = {
						type = "group",
						name = L.EnemyCount_Enabled,
						inline = true,
						order = 11,
						args = {
							EnemyCount_Enabled = {
								type = "toggle",
								name = L.EnemyCount_Enabled,
								desc = L.EnemyCount_Enabled_Desc,
								set = function(option, value)
									self.EnemyCount:SetShown(value)
									setOption(option, value)
								end,
								order = 1
							},
							EnemyCount_Fontsize = {
								type = "range",
								name = L.EnemyCount_Fontsize,
								desc = L.EnemyCount_Fontsize_Desc,
								disabled = function() return not self.db.profile.EnemyCount_Enabled end,
								set = function(option, value) 
									self.EnemyCount:SetFont(LSM:Fetch("font", self.db.profile.Font), value)
									setOption(option, value)
								end,
								min = 1,
								max = 40,
								step = 1,
								width = "normal",
								order = 2
							},
							Fake = {
								type = "description",
								name = " ",
								width = "half",
								order = 3
							},
							EnemyCount_Textcolor = {
								type = "color",
								name = L.EnemyCount_Textcolor,
								desc = L.EnemyCount_Textcolor_Desc,
								disabled = function() return not self.db.profile.EnemyCount_Enabled end,
								set = function(option, ...)
									local color = {...} 
									self.EnemyCount:SetTextColor(...)
									setOption(option, color)
								end,
								width = "half",
								order = 4
							}
						}
					}
				}
			},
			BarSettings = {
				type = "group",
				name = L.BarSettings,
				desc = L.BarSettings_Desc,
				--childGroups = "tab",
				order = 2,
				args = {
					
					BarWidth = {
						type = "range",
						name = L.BarWidth,
						desc = L.BarWidth_Desc,
						disabled = InCombatLockdown,
						set = function(option, value)
							self:SetWidth(value)
							setOption(option, value)
						end,
						min = 1,
						max = 400,
						step = 1,
						order = 1
					},
					BarHeight = {
						type = "range",
						name = L.BarHeight,
						desc = L.BarHeight_Desc,
						disabled = InCombatLockdown,
						set = function(option, value) 
							local previousButton
							for name, enemyButton in pairs(self.Enemys) do
								enemyButton:SetHeight(value)
								self:CropImage(enemyButton.Spec.Icon, self.db.profile.BarHeight, value)
								self:CropImage(enemyButton.ObjectiveAndRespawn.Icon, self.db.profile.BarHeight, value)
							end
							for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
								enemyButton:SetHeight(value)
								self:CropImage(enemyButton.Spec.Icon, self.db.profile.BarHeight, value)
								self:CropImage(enemyButton.ObjectiveAndRespawn.Icon, self.db.profile.BarHeight, value)
							end
							setOption(option, value)
						end,
						min = 1,
						max = 40,
						step = 1,
						order = 2
					},
					SpaceBetweenRows = {
						type = "range",
						name = L.SpaceBetweenRows,
						desc = L.SpaceBetweenRows_Desc,
						set = function(option, value) 
							local previousButton
							for number, name in ipairs(self.EnemySortingTable) do
								if number == 1 then previousButton = self end
					
								local enemyButton = self.Enemys[name]
								enemyButton:SetPosition(self.db.profile.Growdirection, previousButton, value)
								previousButton = enemyButton
							end
							setOption(option, value)
						end,
						min = 0,
						max = 20,
						step = 1,
						order = 3
					},
					RangeIndicator_Enabled = {
						type = "toggle",
						name = L.RangeIndicator_Enabled,
						desc = L.RangeIndicator_Enabled_Desc,
						set = function(option, value) 
							UpdateButtons(option, value, nil, nil, "SetAlpha", value and 0.55 or 1)
						end,
						order = 4
					},
					RangeIndicator_Range = {
						type = "select",
						name = L.RangeIndicator_Range,
						desc = L.RangeIndicator_Range_Desc,
						disabled = function() return not self.db.profile.RangeIndicator_Enabled end,
						get = function() return Data.ItemIDToRange[self.db.profile.RangeIndicator_Range] end,
						set = function(option, value)
							value = Data.RangeToItemID[value]
							setOption(option, value)
						end,
						values = Data.RangeToRange,
						order = 5
					},
					RangeIndicator_Alpha = {
						type = "range",
						name = L.RangeIndicator_Alpha,
						desc = L.RangeIndicator_Alpha_Desc,
						disabled = function() return not self.db.profile.RangeIndicator_Enabled end,
						min = 0,
						max = 1,
						step = 0.05,
						order = 6
					},
					MyTarget_Color = {
						type = "color",
						name = L.MyTarget_Color,
						desc = L.MyTarget_Color_Desc,
						set = function(option, ...)
							local color = {...} 
							UpdateButtons(option, color, "MyTarget", nil, "SetBackdropBorderColor", ...)
						end,
						order = 7
					},
					MyFocus_Color = {
						type = "color",
						name = L.MyFocus_Color,
						desc = L.MyFocus_Color_Desc,
						set = function(option, ...)
							local color = {...} 
							UpdateButtons(option, color, "MyFocus", nil, "SetBackdropBorderColor", ...)
						end,
						order = 8
					},
					HealthBarSettings = {
						type = "group",
						name = L.HealthBarSettings,
						desc = L.HealthBarSettings_Desc,
						order = 9,
						args = {
							General = {
								type = "group",
								name = "General",
								desc = "",
								--inline = true,
								order = 1,
								args = {
									BarTexture = {
										type = "select",
										name = L.BarTexture,
										desc = L.BarTexture_Desc,
										set = function(option, value)
											UpdateButtons(option, value, "Health", nil, "SetStatusBarTexture", LSM:Fetch("statusbar", value))
										end,
										dialogControl = 'LSM30_Statusbar',
										values = AceGUIWidgetLSMlists.statusbar,
										width = "normal",
										order = 1
									},
									Fake = {
										type = "description",
										name = " ",
										width = "half",
										order = 2
									},
									BarBackground = {
										type = "color",
										name = L.BarBackground,
										desc = L.BarBackground_Desc,
										set = function(option, ...)
											local color = {...} 
											UpdateButtons(option, color, "Health", "Background", "SetVertexColor", ...)
										end,
										width = "normal",
										order = 3
									}
								}
							},
							Fake = {
								type = "description",
								name = " ",
								fontSize = "large",
								order = 2
							},
							Name = {
								type = "group",
								name = L.Name,
								desc = L.Name_Desc,
								order = 3,
								args = {
									Name_Fontsize = {
										type = "range",
										name = L.Name_Fontsize,
										desc = L.Name_Fontsize_Desc,
										set = function(option, value)
											UpdateButtons(option, value, "Name", nil, "SetFont", LSM:Fetch("font", self.db.profile.Font), value)
										end,
										min = 6,
										max = 20,
										step = 1,
										width = "normal",
										order = 1
									},
									Fake = {
										type = "description",
										name = " ",
										width = "half",
										order = 2
									},
									Name_Textcolor = {
										type = "color",
										name = L.Name_Textcolor,
										desc = L.Name_Textcolor_Desc,
										set = function(option, ...)
											local color = {...} 
											UpdateButtons(option, color, "Name", nil, "SetTextColor", ...)
										end,
										width = "half",
										order = 3
									},
									Fake2 = {
										type = "description",
										name = " ",
										fontSize = "large",
										width = "full",
										order = 4
									},
									ConvertCyrillic = {
										type = "toggle",
										name = L.ConvertCyrillic,
										desc = L.ConvertCyrillic_Desc,
										set = function(option, value)
											for name, enemyButton in pairs(self.Enemys) do
												local displayedName = name
												if value then
													displayedName = ""
													for i = 1, name:utf8len() do
														local c = name:utf8sub(i,i)
										
														if Data.CyrillicToRomanian[c] then
															if i == 1 then
																displayedName = displayedName..Data.CyrillicToRomanian[c]:upper()
															else
																displayedName = displayedName..Data.CyrillicToRomanian[c]
															end
														else
															displayedName = displayedName..c
														end
													end
												end
												enemyButton.PlayerDetails.DisplayedName = displayedName
												
												if self.db.profile.ShowRealmnames then
													enemyButton.Name:SetText(displayedName)
												else
													enemyButton.Name:SetText(displayedName:match("[^%-]*"))
												end
											end
											setOption(option, value)
										end,
										width = "normal",
										order = 5
									},
									ShowRealmnames = {
										type = "toggle",
										name = L.ShowRealmnames,
										desc = L.ShowRealmnames_Desc,
										set = function(option, value)
											for name, enemyButton in pairs(self.Enemys) do
												local displayedName = enemyButton.PlayerDetails.DisplayedName
												
												if value then
													enemyButton.Name:SetText(displayedName)
												else
													enemyButton.Name:SetText(displayedName:match("[^%-]*"))
												end
											end
											setOption(option, value)
										end,
										width = "normal",
										order = 6
									}
								}
							},
							Fake2 = {
								type = "description",
								name = " ",
								fontSize = "large",
								order = 4
							},
							TargetIndicator = {
								type = "group",
								name = L.TargetIndicator,
								desc = L.TargetIndicator_Desc,
								--childGroups = "select",
								--inline = true,
								order = 5,
								args = {
									NumericTargetindicator_Enabled = {
										type = "toggle",
										name = L.NumericTargetindicator_Enabled,
										desc = L.NumericTargetindicator_Enabled_Desc,
										set = function(option, value)
											UpdateButtons(option, value, "TargetCounter", nil, "SetShown", value)
										end,
										width = "full",
										order = 1
									},
									NumericTargetindicator_Fontsize = {
										type = "range",
										name = L.NumericTargetindicator_Fontsize,
										desc = L.NumericTargetindicator_Fontsize_Desc,
										disabled = function() return not self.db.profile.NumericTargetindicator_Enabled end,
										set = function(option, value)
											UpdateButtons(option, value, "TargetCounter", "Text", "SetFont", LSM:Fetch("font", self.db.profile.Font), value)
										end,
										min = 6,
										max = 20,
										step = 1,
										width = "normal",
										order = 2
									},
									Fake = {
										type = "description",
										name = " ",
										width = "half",
										order = 3
									},
									NumericTargetindicator_Textcolor = {
										type = "color",
										name = L.NumericTargetindicator_Textcolor,
										desc = L.NumericTargetindicator_Textcolor_Desc,
										disabled = function() return not self.db.profile.NumericTargetindicator_Enabled end,
										set = function(option, ...)
											local color = {...} 
											UpdateButtons(option, color, "TargetCounter", "Text", "SetTextColor", ...)
										end,
										width = "half",
										order = 4
									},
									Fake2 = {
										type = "description",
										name = " ",
										fontSize = "large",
										width = "full",
										order = 5
									},
									SymbolicTargetindicator_Enabled = {
										type = "toggle",
										name = L.SymbolicTargetindicator_Enabled,
										desc = L.SymbolicTargetindicator_Enabled_Desc,
										set = function(option, value)
											for name, enemyButton in pairs(self.Enemys) do
												local targetIndicator = enemyButton.TargetIndicators
												for i = 1, #enemyButton.TargetIndicators do
													enemyButton.TargetIndicators[i]:SetShown(value)
												end
											end
											for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
												local targetIndicator = enemyButton.TargetIndicators
												for i = 1, #enemyButton.TargetIndicators do
													enemyButton.TargetIndicators[i]:SetShown(value)
												end
											end
											setOption(option, value)
										end,
										width = "full",
										order = 6
									}
								}
							}
						}
					},	
					TrinketSettings = {
						type = "group",
						name = L.TrinketSettings,
						desc = L.TrinketSettings_Desc,
						order = 10,
						args = {
							Trinket_Enabled = {
								type = "toggle",
								name = L.Trinket_Enabled,
								desc = L.Trinket_Enabled_Desc,
								set = function(option, value)
									UpdateButtons(option, value, "Trinket", nil, "SetShown", value)
								end,
								order = 1
							},
							Trinket_ShowNumbers = {
								type = "toggle",
								name = L.Trinket_ShowNumbers,
								desc = L.Trinket_ShowNumbers_Desc,
								disabled = function() return not self.db.profile.Trinket_Enabled end,
								set = function(option, value)
									UpdateButtons(option, value, "Trinket", "Cooldown", "SetHideCountdownNumbers", not value)
								end,
								order = 2
							}
						}
					},
					RacialSettings = {
						type = "group",
						name = L.RacialSettings,
						desc = L.RacialSettings_Desc,
						order = 11,
						args = {
							Racial_Enabled = {
								type = "toggle",
								name = L.Racial_Enabled,
								desc = L.Racial_Enabled_Desc,
								set = function(option, value)
									UpdateButtons(option, value, "Racial", nil, "SetShown", value)
								end,
								order = 1
							},
							Racial_ShowNumbers = {
								type = "toggle",
								name = L.Racial_ShowNumbers,
								desc = L.Racial_ShowNumbers_Desc,
								disabled = function() return not self.db.profile.Racial_Enabled end,
								set = function(option, value)
									UpdateButtons(option, value, "Racial", "Cooldown", "SetHideCountdownNumbers", not value)
								end,
								order = 3
							}
						}
					},
					SpecSettings = {
						type = "group",
						name = L.SpecSettings,
						desc = L.SpecSettings_Desc,
						order = 12,
						args = {
							Spec_Width = {
								type = "range",
								name = L.Spec_Width,
								desc = L.Spec_Width_Desc,
								set = function(option, value)
									for name, enemyButton in pairs(BattleGroundEnemies.Enemys) do
										self:CropImage(enemyButton.Spec.Icon, self.db.profile.BarHeight, value)
										enemyButton.Spec:SetWidth(value)
									end
									setOption(option, value)
								end,
								min = 1,
								max = 50,
								step = 1,
								order = 1
							}
						}
					},
					ObjectiveAndRespawnSettings = {
						type = "group",
						name = L.ObjectiveAndRespawnSettings,
						desc = L.ObjectiveAndRespawnSettings_Desc,
						order = 13,
						args = {
							ObjectiveAndRespawn_ObjectiveEnabled = {
								type = "toggle",
								name = L.ObjectiveAndRespawn_ObjectiveEnabled,
								desc = L.ObjectiveAndRespawn_ObjectiveEnabled_Desc,
								set = function(option, value)
									for name, enemyButton in pairs(BattleGroundEnemies.Enemys) do
										if value then
											if enemyButton.ObjectiveAndRespawn.Icon:GetTexture() then
												enemyButton.ObjectiveAndRespawn:Show()
											end
										else
											enemyButton.ObjectiveAndRespawn:Hide()
										end
									end
									setOption(option, value)
								end,
								order = 1
							},
							ObjectiveAndRespawn_Width = {
								type = "range",
								name = L.ObjectiveAndRespawn_Width,
								desc = L.ObjectiveAndRespawn_Width_Desc,
								disabled = function() return not self.db.profile.ObjectiveAndRespawn_ObjectiveEnabled end,
								set = function(option, value)
									UpdateButtons(option, value, "ObjectiveAndRespawn", nil, "SetWidth", value)
									for name, enemyButton in pairs(BattleGroundEnemies.Enemys) do
										self:CropImage(enemyButton.ObjectiveAndRespawn.Icon, self.db.profile.BarHeight, value)
										enemyButton.ObjectiveAndRespawn:SetWidth(value)
									end
									setOption(option, value)
								end,
								min = 1,
								max = 50,
								step = 1,
								order = 2
							},
							ObjectiveAndRespawn_Fontsize = {
								type = "range",
								name = L.ObjectiveAndRespawn_Fontsize,
								desc = L.ObjectiveAndRespawn_Fontsize_Desc,
								disabled = function() return not self.db.profile.ObjectiveAndRespawn_ObjectiveEnabled end,
								set = function(option, value)
									UpdateButtons(option, value, "ObjectiveAndRespawn", "AuraText", "SetFont", LSM:Fetch("font", self.db.profile.Font), value)
								end,
								min = 10,
								max = 20,
								step = 1,
								width = "normal",
								order = 3
							},
							Fake = {
								type = "description",
								name = " ",
								width = "half",
								order = 4
							},
							ObjectiveAndRespawn_Textcolor = {
								type = "color",
								name = L.ObjectiveAndRespawn_Textcolor,
								desc = L.ObjectiveAndRespawn_Textcolor_Desc,
								disabled = function() return not self.db.profile.ObjectiveAndRespawn_ObjectiveEnabled end,
								set = function(option, ...)
									local color = {...} 
									UpdateButtons(option, color, "ObjectiveAndRespawn", "AuraText", "SetTextColor", ...)
								end,
								width = "half",
								order = 5
							}
						}
					},
					DrTrackingSettings = {
						type = "group",
						name = L.DrTrackingSettings,
						desc = L.DrTrackingSettings_Desc,
						order = 14,
						args = {
							DrTracking_Enabled = {
								type = "toggle",
								name = L.DrTracking_Enabled,
								desc = L.DrTracking_Enabled_Desc,
								order = 1
							},
							DrTracking_ShowNumbers = {
								type = "toggle",
								name = L.DrTracking_ShowNumbers,
								desc = L.DrTracking_ShowNumbers_Desc,
								disabled = function() return not self.db.profile.DrTracking_Enabled end,
								set = function(option, value)
									for name, enemyButton in pairs(self.Enemys) do
										for categorie, v in pairs(DRData:GetCategories()) do
											enemyButton.DR[categorie].Cooldown:SetHideCountdownNumbers(not value)
										end
									end
									for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
										for categorie, v in pairs(DRData:GetCategories()) do
											enemyButton.DR[categorie].Cooldown:SetHideCountdownNumbers(not value)
										end
									end
									setOption(option, value)
								end,
								order = 2
							},
							DrTracking_Spacing = {
								type = "range",
								name = L.DrTracking_Spacing,
								desc = L.DrTracking_Spacing_Desc,
								disabled = function() return not self.db.profile.DrTracking_Enabled end,
								set = function(option, value)
									for name, enemyButton in pairs(self.Enemys) do
										enemyButton:DrPositioning()
									end
									for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
										enemyButton:DrPositioning()
									end
									setOption(option, value)
								end,
								order = 3
							}
						}
					},
					MyDebuffSettings = {
						type = "group",
						name = L.MyDebuffSettings,
						desc = L.MyDebuffSettings_Desc,
						order = 15,
						args = {
							MyDebuffs_Enabled = {
								type = "toggle",
								name = L.MyDebuffs_Enabled,
								desc = L.MyDebuffs_Enabled_Desc,
								order = 1
							},
							MyDebuffs_ShowNumbers = {
								type = "toggle",
								name = L.MyDebuffs_ShowNumbers,
								desc = L.MyDebuffs_ShowNumbers_Desc,
								disabled = function() return not self.db.profile.MyDebuffs_Enabled end,
								set = function(option, value)
									for name, enemyButton in pairs(self.Enemys) do
										for spellID, frame in pairs(enemyButton.MyDebuffs) do
											myDebuffFrame.Cooldown:SetHideCountdownNumbers(not value)
										end
									end
									for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
										for spellID, frame in pairs(enemyButton.MyDebuffs) do
											myDebuffFrame.Cooldown:SetHideCountdownNumbers(not value)
										end
									end
									setOption(option, value)
								end,
								order = 2
							},
							MyDebuffs_Fontsize = {
								type = "range",
								name = L.MyDebuffs_Fontsize,
								desc = L.MyDebuffs_Fontsize_Desc,
								disabled = function() return not self.db.profile.MyDebuffs_Enabled end,
								set = function(option, value)
									for name, enemyButton in pairs(self.Enemys) do
										for spellID, frame in pairs(enemyButton.MyDebuffs) do
											frame.Stacks:SetFont(LSM:Fetch("font", BattleGroundEnemies.db.profile.Font), value)
										end
									end
									for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
										for spellID, frame in pairs(enemyButton.MyDebuffs) do
											frame.Stacks:SetFont(LSM:Fetch("font", BattleGroundEnemies.db.profile.Font), value)
										end
									end
									setOption(option, value)
								end,
								min = 10,
								max = 20,
								step = 1,
								order = 3
							},
							Fake = {
								type = "description",
								name = " ",
								width = "half",
								order = 4
								
							},
							MyDebuffs_Textcolor = {
								type = "color",
								name = L.MyDebuffs_Textcolor,
								desc = L.MyDebuffs_Textcolor_Desc,
								disabled = function() return not self.db.profile.MyDebuffs_Enabled end,
								set = function(option, ...)
									local color = {...} 
									for name, enemyButton in pairs(self.Enemys) do
										for spellID, frame in pairs(enemyButton.MyDebuffs) do
											frame.Stacks:SetTextColor(...)
										end
									end
									for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
										for spellID, frame in pairs(enemyButton.MyDebuffs) do
											frame.Stacks:SetTextColor(...)
										end
									end
									setOption(option, color)
								end,
								width = "half",
								order = 5
							},
							MyDebuffs_Spacing = {
								type = "range",
								name = L.MyDebuffs_Spacing,
								desc = L.MyDebuffs_Spacing_Desc,
								disabled = function() return not self.db.profile.MyDebuffs_Enabled end,
								set = function(option, value)
									for name, enemyButton in pairs(self.Enemys) do
										enemyButton:DebuffPositioning()
									end
									for number, enemyButton in ipairs(self.InactiveEnemyButtons) do
										enemyButton:DebuffPositioning()
									end
									setOption(option, value)
								end,
								order = 6
							}
						}
					},
					RBGSpecificSettings = {
						type = "group",
						name = L.RBGSpecificSettings,
						desc = L.RBGSpecificSettings_Desc,
						--inline = true,
						order = 16,
						args = {
							Notificatoins_Enabled = {
								type = "toggle",
								name = L.Notificatoins_Enabled,
								desc = L.Notificatoins_Enabled_Desc,
								--inline = true,
								order = 1
							},
							-- PositiveSound = {
								-- type = "select",
								-- name = L.PositiveSound,
								-- desc = L.PositiveSound_Desc,
								-- disabled = function() return not self.db.profile.Notificatoins_Enabled end,
								-- dialogControl = 'LSM30_Sound',
								-- values = AceGUIWidgetLSMlists.sound,
								-- order = 2
							-- },
							-- NegativeSound = {
								-- type = "select",
								-- name = L.NegativeSound,
								-- desc = L.NegativeSound_Desc,
								-- disabled = function() return not self.db.profile.Notificatoins_Enabled end,
								-- dialogControl = 'LSM30_Sound',
								-- values = AceGUIWidgetLSMlists.sound,
								-- order = 3
							-- },
							ObjectiveAndRespawn_RespawnEnabled = {
								type = "toggle",
								name = L.ObjectiveAndRespawn_RespawnEnabled,
								desc = L.ObjectiveAndRespawn_RespawnEnabled_Desc,
								order = 4
							},
							ObjectiveAndRespawn_ShowNumbers = {
								type = "toggle",
								name = L.ObjectiveAndRespawn_ShowNumbers,
								desc = L.ObjectiveAndRespawn_ShowNumbers_Desc,
								disabled = function() return not self.db.profile.ObjectiveAndRespawn_RespawnEnabled end,
								set = function(option, value)
									UpdateButtons(option, value, "ObjectiveAndRespawn", "Cooldown", "SetHideCountdownNumbers", not value)
								end,
								order = 5
							}
						}
					}
				}
			}
		}
	}


	LibStub("AceConfig-3.0"):RegisterOptionsTable("BattleGroundEnemies", self.options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("BattleGroundEnemies", "BattleGroundEnemies")
end

SLASH_BattleGroundEnemies1, SLASH_BattleGroundEnemies2, SLASH_BattleGroundEnemies3 = "/BattleGroundEnemies", "/bge", "/BattleGroundEnemies"
SlashCmdList["BattleGroundEnemies"] = function(msg)
	local AceDialog = LibStub("AceConfigDialog-3.0")
	if not BattleGroundEnemies.options then
		BattleGroundEnemies:SetupOptions()
		AceDialog:SetDefaultSize("BattleGroundEnemies", 830, 530)
	end
	AceDialog:Open("BattleGroundEnemies")
end
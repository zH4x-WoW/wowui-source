
BATTLEFIELD_TAB_SHOW_DELAY = 0.2;
BATTLEFIELD_TAB_FADE_TIME = 0.15;
DEFAULT_BATTLEFIELD_TAB_ALPHA = 0.75;
DEFAULT_POI_ICON_SIZE = 12;
BATTLEFIELD_MINIMAP_UPDATE_RATE = 0.1;
NUM_BATTLEFIELDMAP_POIS = 0;

local BattlefieldMinimapDefaults = {
	opacity = 0.7,
	locked = true,
	showPlayers = true,
};

BG_VEHICLES = {};


function BattlefieldMinimap_Toggle()
	if ( BattlefieldMinimap:IsShown() ) then
		SetCVar("showBattlefieldMinimap", "0");
		BattlefieldMinimap:Hide();
	else
		local _, instanceType = IsInInstance();
		if ( instanceType == "pvp" ) then
			SetCVar("showBattlefieldMinimap", "1");
			BattlefieldMinimap:Show();
		elseif ( instanceType ~= "arena" ) then
			SetCVar("showBattlefieldMinimap", "2");
			BattlefieldMinimap:Show();
		end
	end
end

function BattlefieldMinimap_OnLoad (self)
	BattlefieldMinimap:SetAttribute("NUM_BATTLEFIELDMAP_OVERLAYS",0);
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("ZONE_CHANGED");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	self:RegisterEvent("PLAYER_LOGOUT");
	self:RegisterEvent("WORLD_MAP_UPDATE");
	self:RegisterEvent("NEW_WMO_CHUNK");

	self.flagsPool = CreateFramePool("FRAME", self, "BattlefieldMapFlagTemplate");

	BattlefieldMinimap.updateTimer = 0;

	BattlefieldMinimapUnitPositionFrame:SetMouseOverUnitExcluded("player", true);
	BattlefieldMinimapUnitPositionFrame:SetPinTexture("player", "Interface\\Minimap\\MinimapArrow");
	BattlefieldMinimapUnitPositionFrame:SetPinSize("player", 24);
	BattlefieldMinimapUnitPositionFrame:SetPinSize("party", 8);
	BattlefieldMinimapUnitPositionFrame:SetPinSize("raid", 8);
end

function BattlefieldMinimap_OnShow(self)
	PlaySound("igQuestLogOpen");
	SetMapToCurrentZone();
	BattlefieldMinimap_Update();
	BattlefieldMinimap_UpdateOpacity(BattlefieldMinimapOptions.opacity);
	BattlefieldMinimapTab:Show();
end

function BattlefieldMinimap_OnHide(self)
	PlaySound("igQuestLogClose");
	BattlefieldMinimapTab:Hide();
	BattlefieldMinimap_ClearTextures();
	CloseDropDownMenus();
end

function BattlefieldMinimap_OnEvent(self, event, ...)
	if ( event == "ADDON_LOADED" ) then
		local arg1 = ...;
		if ( arg1 == "Blizzard_BattlefieldMinimap" ) then
			if ( not BattlefieldMinimapOptions ) then
				BattlefieldMinimapOptions = BattlefieldMinimapDefaults;
			end

			if ( BattlefieldMinimapOptions.position ) then
				BattlefieldMinimapTab:SetPoint("CENTER", "UIParent", "BOTTOMLEFT", BattlefieldMinimapOptions.position.x, BattlefieldMinimapOptions.position.y);
				BattlefieldMinimapTab:SetUserPlaced(true);
			else
				BattlefieldMinimapTab:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMRIGHT", -225-CONTAINER_OFFSET_X, BATTLEFIELD_TAB_OFFSET_Y);
			end

			UIDropDownMenu_Initialize(BattlefieldMinimapTabDropDown, BattlefieldMinimapTabDropDown_Initialize, "MENU");

			OpacityFrameSlider:SetValue(BattlefieldMinimapOptions.opacity);
			BattlefieldMinimap_UpdateOpacity();
			BattlefieldMinimap_UpdateShowPlayers();
		end
	elseif ( event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "NEW_WMO_CHUNK" ) then
		if ( BattlefieldMinimap:IsShown() ) then
			if ( not WorldMapFrame:IsShown() ) then
				SetMapToCurrentZone();
				BattlefieldMinimap_Update();
			end
		end
	elseif ( event == "PLAYER_LOGOUT" ) then
		if ( BattlefieldMinimapTab:IsUserPlaced() ) then
			if ( not BattlefieldMinimapOptions.position ) then
				BattlefieldMinimapOptions.position = {};
			end
			BattlefieldMinimapOptions.position.x, BattlefieldMinimapOptions.position.y = BattlefieldMinimapTab:GetCenter();
			BattlefieldMinimapTab:SetUserPlaced(false);
		else
			BattlefieldMinimapOptions.position = nil;
		end
	elseif ( event == "WORLD_MAP_UPDATE" ) then
		if ( BattlefieldMinimap:IsVisible() ) then
			BattlefieldMinimap_Update();
		end
	end
end

function BattlefieldMinimap_Update()
	-- Fill in map tiles
	local mapFileName, textureHeight, _, isMicroDungeon, microDungeonMapName = GetMapInfo();
	if (isMicroDungeon and (not microDungeonMapName or microDungeonMapName == "")) then
		return;
	end

	if ( not mapFileName ) then
		if ( GetCurrentMapContinent() == WORLDMAP_COSMIC_ID ) then
			mapFileName = "Cosmic";
		else
			-- Temporary Hack (copy of a "temporary" 6 year hack)
			mapFileName = "World";
		end
	end
	local texName;
	local dungeonLevel = GetCurrentMapDungeonLevel();
	if (DungeonUsesTerrainMap()) then
		dungeonLevel = dungeonLevel - 1;
	end

	local path;
	if (not isMicroDungeon) then
		path = "Interface\\WorldMap\\"..mapFileName.."\\"..mapFileName;
	else
		path = "Interface\\WorldMap\\MicroDungeon\\"..mapFileName.."\\"..microDungeonMapName.."\\"..microDungeonMapName;
	end

	if ( dungeonLevel > 0 ) then
		path = path..dungeonLevel.."_";
	end

	local numDetailTiles = GetNumberOfDetailTiles();
	for i=1, numDetailTiles do
		texName = path..i;
		_G["BattlefieldMinimap"..i]:SetTexture(texName);
	end

	-- Setup the POI's
	local iconSize = DEFAULT_POI_ICON_SIZE * GetBattlefieldMapIconScale();
	local numPOIs = GetNumMapLandmarks();
	if ( NUM_BATTLEFIELDMAP_POIS < numPOIs ) then
		for i=NUM_BATTLEFIELDMAP_POIS+1, numPOIs do
			BattlefieldMinimap_CreatePOI(i);
		end
		NUM_BATTLEFIELDMAP_POIS = numPOIs;
	end
	for i=1, NUM_BATTLEFIELDMAP_POIS do
		local battlefieldPOIName = "BattlefieldMinimapPOI"..i;
		local battlefieldPOI = _G[battlefieldPOIName];
		if ( i <= numPOIs ) then
			local landmarkType, name, description, textureIndex, x, y, maplinkID, showInBattleMap = C_WorldMap.GetMapLandmarkInfo(i);
			if ( WorldMap_ShouldShowLandmark(landmarkType) and showInBattleMap ) then
				local x1, x2, y1, y2 = GetPOITextureCoords(textureIndex);
				_G[battlefieldPOIName.."Texture"]:SetTexCoord(x1, x2, y1, y2);
				x = x * BattlefieldMinimap:GetWidth();
				y = -y * BattlefieldMinimap:GetHeight();
				battlefieldPOI:SetPoint("CENTER", "BattlefieldMinimap", "TOPLEFT", x, y );
				battlefieldPOI:SetWidth(iconSize);
				battlefieldPOI:SetHeight(iconSize);
				battlefieldPOI:Show();
			else
				battlefieldPOI:Hide();
			end
		else
			battlefieldPOI:Hide();
		end
	end

	-- Setup the overlays
	local numOverlays = GetNumMapOverlays();
	local textureCount = 0;
	-- Use this value to scale the texture sizes and offsets
	local battlefieldMinimapScale = BattlefieldMinimap1:GetWidth()/256;
	for i=1, numOverlays do
		local textureName, textureWidth, textureHeight, offsetX, offsetY, isShownByMouseOver = GetMapOverlayInfo(i);
		if (textureName ~= "" or textureWidth == 0 or textureHeight == 0) then
			local numTexturesWide = ceil(textureWidth/256);
			local numTexturesTall = ceil(textureHeight/256);
			local neededTextures = textureCount + (numTexturesWide * numTexturesTall);
			local numBattlefieldMapOverlays = BattlefieldMinimap:GetAttribute("NUM_BATTLEFIELDMAP_OVERLAYS");
			if ( neededTextures > numBattlefieldMapOverlays ) then
				for j=numBattlefieldMapOverlays+1, neededTextures do
					BattlefieldMinimap:CreateTexture("BattlefieldMinimapOverlay"..j, "ARTWORK");
				end
				BattlefieldMinimap:SetAttribute("NUM_BATTLEFIELDMAP_OVERLAYS", neededTextures);
			end
			local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight;
			for j=1, numTexturesTall do
				if ( j < numTexturesTall ) then
					texturePixelHeight = 256;
					textureFileHeight = 256;
				else
					texturePixelHeight = mod(textureHeight, 256);
					if ( texturePixelHeight == 0 ) then
						texturePixelHeight = 256;
					end
					textureFileHeight = 16;
					while(textureFileHeight < texturePixelHeight) do
						textureFileHeight = textureFileHeight * 2;
					end
				end
				for k=1, numTexturesWide do
					textureCount = textureCount + 1;
					local texture = _G["BattlefieldMinimapOverlay"..textureCount];
					if ( k < numTexturesWide ) then
						texturePixelWidth = 256;
						textureFileWidth = 256;
					else
						texturePixelWidth = mod(textureWidth, 256);
						if ( texturePixelWidth == 0 ) then
							texturePixelWidth = 256;
						end
						textureFileWidth = 16;
						while(textureFileWidth < texturePixelWidth) do
							textureFileWidth = textureFileWidth * 2;
						end
					end
					texture:SetWidth(texturePixelWidth*battlefieldMinimapScale);
					texture:SetHeight(texturePixelHeight*battlefieldMinimapScale);
					texture:SetTexCoord(0, texturePixelWidth/textureFileWidth, 0, texturePixelHeight/textureFileHeight);
					texture:SetPoint("TOPLEFT", "BattlefieldMinimap", "TOPLEFT", (offsetX + (256 * (k-1)))*battlefieldMinimapScale, -((offsetY + (256 * (j - 1)))*battlefieldMinimapScale));
					texture:SetTexture(textureName..(((j - 1) * numTexturesWide) + k));
					texture:SetAlpha(1 - ( BattlefieldMinimapOptions.opacity or 0 ));

					if isShownByMouseOver == true then
						texture:Hide();
					else
						texture:Show();
					end
				end
			end
		end
	end
	for i=textureCount+1, BattlefieldMinimap:GetAttribute("NUM_BATTLEFIELDMAP_OVERLAYS") do
		_G["BattlefieldMinimapOverlay"..i]:Hide();
	end
end

function BattlefieldMinimap_ClearTextures()
	for i=1, BattlefieldMinimap:GetAttribute("NUM_BATTLEFIELDMAP_OVERLAYS") do
		_G["BattlefieldMinimapOverlay"..i]:SetTexture(nil);
	end
	local numDetailTiles = GetNumberOfDetailTiles();
	for i=1, numDetailTiles do
		_G["BattlefieldMinimap"..i]:SetTexture(nil);
	end
end

function BattlefieldMinimap_CreatePOI(index)
	local frame = CreateFrame("Frame", "BattlefieldMinimapPOI"..index, BattlefieldMinimap);
	frame:SetWidth(DEFAULT_POI_ICON_SIZE);
	frame:SetHeight(DEFAULT_POI_ICON_SIZE);

	local texture = frame:CreateTexture(frame:GetName().."Texture", "BACKGROUND");
	texture:SetAllPoints(frame);
	texture:SetTexture("Interface\\Minimap\\POIIcons");
end

function BattlefieldMinimap_OnUpdate(self, elapsed)
	-- tick mouse hover time for tab
	if ( BattlefieldMinimap.hover ) then
		local xPos, yPos = GetCursorPosition();
		if ( (BattlefieldMinimap.oldX == xPos and BattlefieldMinimap.oldy == yPos) ) then
			BattlefieldMinimap.hoverTime = BattlefieldMinimap.hoverTime + elapsed;
		else
			BattlefieldMinimap.hoverTime = 0;
			BattlefieldMinimap.oldX = xPos;
			BattlefieldMinimap.oldy = yPos;
		end
	end
	-- Throttle updates
	if ( BattlefieldMinimap.updateTimer < 0 ) then
		BattlefieldMinimap.updateTimer = BATTLEFIELD_MINIMAP_UPDATE_RATE;
	else
		BattlefieldMinimap.updateTimer = BattlefieldMinimap.updateTimer - elapsed;
		return;
	end

	BattlefieldMinimapUnitPositionFrame:UpdatePlayerPins();

	-- If resizing the frame then scale everything accordingly
	if ( BattlefieldMinimap.resizing ) then
		local sizeUnit = BattlefieldMinimap:GetWidth()/4;
		local mapPiece;
		local numDetailTiles = GetNumberOfDetailTiles();
		for i=1, numDetailTiles do
			mapPiece = _G["BattlefieldMinimap"..i];
			mapPiece:SetWidth(sizeUnit);
			mapPiece:SetHeight(sizeUnit);
		end
		local numPOIs = GetNumMapLandmarks();
		for i=1, NUM_BATTLEFIELDMAP_POIS, 1 do
			local battlefieldPOIName = "BattlefieldMinimapPOI"..i;
			local battlefieldPOI = _G[battlefieldPOIName];
			if ( i <= numPOIs ) then
				local landmarkType, name, description, textureIndex, x, y, maplinkID, showInBattleMap = C_WorldMap.GetMapLandmarkInfo(i);
				if ( WorldMap_ShouldShowLandmark(landmarkType) and showInBattleMap ) then
					local x1, x2, y1, y2 = GetPOITextureCoords(textureIndex);
					_G[battlefieldPOIName.."Texture"]:SetTexCoord(x1, x2, y1, y2);
					x = x * BattlefieldMinimap:GetWidth();
					y = -y * BattlefieldMinimap:GetHeight();
					battlefieldPOI:SetPoint("CENTER", "BattlefieldMinimap", "TOPLEFT", x, y );
					battlefieldPOI:Show();
				else
					battlefieldPOI:Hide();
				end
			else
				battlefieldPOI:Hide();
			end
		end
	end

	if ( not BattlefieldMinimapOptions.showPlayers ) then
		wipe(BG_VEHICLES);
	else
		-- Position flags
		self.flagsPool:ReleaseAll();
		for flagIndex = 1, GetNumBattlefieldFlagPositions() do
			local flagX, flagY, flagToken = GetBattlefieldFlagPosition(flagIndex);
			if flagX ~= 0 or flagY ~= 0 then
				local flagFrame = self.flagsPool:Acquire();

				flagX = flagX * self:GetWidth();
				flagY = -flagY * self:GetHeight();
				flagFrame:SetPoint("CENTER", self, "TOPLEFT", flagX, flagY);

				flagFrame.Texture:SetTexture("Interface\\WorldStateFrame\\"..flagToken);
				flagFrame:Show();
			end
		end

		-- position vehicles
		local numVehicles = GetNumBattlefieldVehicles();
		local totalVehicles = #BG_VEHICLES;
		local playerBlipFrameLevel = BattlefieldMinimapUnitPositionFrame:GetFrameLevel();
		local index = 0;
		for i=1, numVehicles do
			if (i > totalVehicles) then
				local vehicleName = "BattlefieldMinimap"..i;
				BG_VEHICLES[i] = CreateFrame("FRAME", vehicleName, BattlefieldMinimap, "WorldMapVehicleTemplate");
				BG_VEHICLES[i].texture = _G[vehicleName.."Texture"];
				BG_VEHICLES[i]:SetWidth(30 * GetBattlefieldMapIconScale());
				BG_VEHICLES[i]:SetHeight(30 * GetBattlefieldMapIconScale());
			end
			local vehicleX, vehicleY, unitName, isPossessed, vehicleType, orientation, isPlayer = GetBattlefieldVehicleInfo(i);
			-- If vehicle has position and isn't the player
			if ( vehicleX and not isPlayer)  then
				vehicleX = vehicleX * BattlefieldMinimap:GetWidth();
				vehicleY = -vehicleY * BattlefieldMinimap:GetHeight();
				BG_VEHICLES[i].texture:SetTexture(WorldMap_GetVehicleTexture(vehicleType, isPossessed));
				BG_VEHICLES[i].texture:SetRotation( orientation );
				BG_VEHICLES[i]:SetPoint("CENTER", "BattlefieldMinimap", "TOPLEFT", vehicleX, vehicleY);
				if ( VEHICLE_TEXTURES[vehicleType] and VEHICLE_TEXTURES[vehicleType].belowPlayerBlips ) then
					BG_VEHICLES[i]:SetFrameLevel(playerBlipFrameLevel - 1);
				else
					BG_VEHICLES[i]:SetFrameLevel(playerBlipFrameLevel + 1);
				end
				BG_VEHICLES[i]:Show();
				index = i;	-- save for later
			else
				BG_VEHICLES[i]:Hide();
			end
		end
		if (index < totalVehicles) then
			for i=index+1, totalVehicles do
				BG_VEHICLES[i]:Hide();
			end
		end
	end

	-- Fadein tab if mouse is over
	if ( BattlefieldMinimap:IsMouseOver(45, -10, -5, 5) ) then
		-- If mouse is hovering don't show the tab until the elapsed time reaches the tab show delay
		if ( BattlefieldMinimap.hover ) then
			if ( BattlefieldMinimap.hoverTime > BATTLEFIELD_TAB_SHOW_DELAY ) then
				-- If the battlefieldtab's alpha is less than the current default, then fade it in
				if ( not BattlefieldMinimap.hasBeenFaded and (BattlefieldMinimap.oldAlpha and BattlefieldMinimap.oldAlpha < DEFAULT_BATTLEFIELD_TAB_ALPHA) ) then
					UIFrameFadeIn(BattlefieldMinimapTab, BATTLEFIELD_TAB_FADE_TIME, BattlefieldMinimap.oldAlpha, DEFAULT_BATTLEFIELD_TAB_ALPHA);
					-- Set the fact that the chatFrame has been faded so we don't try to fade it again
					BattlefieldMinimap.hasBeenFaded = 1;
				end
			end
		else
			-- Start hovering counter
			BattlefieldMinimap.hover = 1;
			BattlefieldMinimap.hoverTime = 0;
			BattlefieldMinimap.hasBeenFaded = nil;
			CURSOR_OLD_X, CURSOR_OLD_Y = GetCursorPosition();
			-- Remember the oldAlpha so we can return to it later
			if ( not BattlefieldMinimap.oldAlpha ) then
				BattlefieldMinimap.oldAlpha = BattlefieldMinimapTab:GetAlpha();
			end
		end
	else
		-- If the tab's alpha was less than the current default, then fade it back out to the oldAlpha
		if ( BattlefieldMinimap.hasBeenFaded and BattlefieldMinimap.oldAlpha and BattlefieldMinimap.oldAlpha < DEFAULT_BATTLEFIELD_TAB_ALPHA ) then
			UIFrameFadeOut(BattlefieldMinimapTab, BATTLEFIELD_TAB_FADE_TIME, DEFAULT_BATTLEFIELD_TAB_ALPHA, BattlefieldMinimap.oldAlpha);
			BattlefieldMinimap.hover = nil;
			BattlefieldMinimap.hasBeenFaded = nil;
		end
		BattlefieldMinimap.hoverTime = 0;
	end

	BattlefieldMinimapUnitPositionFrame:UpdateTooltips(GameTooltip);
end

function BattlefieldMinimap_OnMouseUp(self, button, upInside)
	if upInside then
		WorldMap_HandleUnitClick(BattlefieldMinimapUnitPositionFrame:GetCurrentMouseOverUnits(), button);
	end
end

function BattlefieldMinimapTab_OnClick(self, button)
	PlaySound("UChatScrollButton");

	-- If Rightclick bring up the options menu
	if ( button == "RightButton" ) then
		ToggleDropDownMenu(1, nil, BattlefieldMinimapTabDropDown, self:GetName(), 0, 0);
		return;
	end

	-- Close all dropdowns
	CloseDropDownMenus();

	-- If frame is not locked then allow the frame to be dragged or dropped
	if ( self:GetButtonState() == "PUSHED" ) then
		BattlefieldMinimapTab:StopMovingOrSizing();
	else
		-- If locked don't allow any movement
		if ( BattlefieldMinimapOptions.locked ) then
			return;
		else
			BattlefieldMinimapTab:StartMoving();
		end
	end
	ValidateFramePosition(BattlefieldMinimapTab);
end

function BattlefieldMinimapTabDropDown_Initialize()
	local checked;
	local info = UIDropDownMenu_CreateInfo();

	-- Show battlefield players
	info.text = SHOW_BATTLEFIELDMINIMAP_PLAYERS;
	info.func = BattlefieldMinimapTabDropDown_TogglePlayers;
	info.checked = BattlefieldMinimapOptions.showPlayers;
	info.isNotRadio = true;
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

	-- Battlefield minimap lock
	info.text = LOCK_BATTLEFIELDMINIMAP;
	info.func = BattlefieldMinimapTabDropDown_ToggleLock;
	info.checked = BattlefieldMinimapOptions.locked;
	info.isNotRadio = true;
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

	-- Opacity
	info.text = BATTLEFIELDMINIMAP_OPACITY_LABEL;
	info.func = BattlefieldMinimapTabDropDown_ShowOpacity;
	info.notCheckable = true;
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
end

function BattlefieldMinimapTabDropDown_TogglePlayers()
	BattlefieldMinimapOptions.showPlayers = not BattlefieldMinimapOptions.showPlayers;
	BattlefieldMinimap_UpdateShowPlayers();
end

function BattlefieldMinimapTabDropDown_ToggleLock()
	BattlefieldMinimapOptions.locked = not BattlefieldMinimapOptions.locked;
end

function BattlefieldMinimapTabDropDown_ShowOpacity()
	OpacityFrame:ClearAllPoints();
	OpacityFrame:SetPoint("TOPRIGHT", "BattlefieldMinimap", "TOPLEFT", 0, 7);
	OpacityFrame.opacityFunc = BattlefieldMinimap_UpdateOpacity;
	OpacityFrame:Show();
	OpacityFrameSlider:SetValue(BattlefieldMinimapOptions.opacity);
end

function BattlefieldMinimap_UpdateShowPlayers()
	-- showPlayers in this case actually means "show all units who are not the local player", because the player pin is always shown
	BattlefieldMinimapUnitPositionFrame:SetShouldShowUnits("party", BattlefieldMinimapOptions.showPlayers);
	BattlefieldMinimapUnitPositionFrame:SetShouldShowUnits("raid", BattlefieldMinimapOptions.showPlayers);
end

function BattlefieldMinimap_UpdateOpacity(opacity)
	BattlefieldMinimapOptions.opacity = opacity or OpacityFrameSlider:GetValue();
	local alpha = 1.0 - BattlefieldMinimapOptions.opacity;
	BattlefieldMinimapBackground:SetAlpha(alpha);
	local numDetailTiles = GetNumberOfDetailTiles();
	for i=1, numDetailTiles do
		_G["BattlefieldMinimap"..i]:SetAlpha(alpha);
	end
	if ( alpha >= 0.15 ) then
		alpha = alpha - 0.15;
	end
	for i=1, BattlefieldMinimap:GetAttribute("NUM_BATTLEFIELDMAP_OVERLAYS") do
		_G["BattlefieldMinimapOverlay"..i]:SetAlpha(alpha);
	end
	BattlefieldMinimapCloseButton:SetAlpha(alpha);
	BattlefieldMinimapCorner:SetAlpha(alpha);
end
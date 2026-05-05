local ADDON_NAME = ...
local CC = CreateFrame("Frame", "ClefairyClosetCore")

CC.SLOT_BUTTON_SIZE = 42
CC.MODEL_DANCE_ANIMATION_ID = 69
CC.MODEL_DANCE_DELAY = 5.0

-- ------------------------------------------------------------
-- Basic helpers
-- ------------------------------------------------------------
local function CC_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff99ccClefairyCloset:|r " .. tostring(msg))
end

local function CC_CreateFrame(frameType, name, parent, template)
    if template then
        return CreateFrame(frameType, name, parent, template)
    end
    if BackdropTemplateMixin then
        return CreateFrame(frameType, name, parent, "BackdropTemplate")
    end
    return CreateFrame(frameType, name, parent)
end

local function CC_SetBackdrop(frame, r, g, b, a)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(r or 0, g or 0, b or 0, a or 0.85)
end

function CC:GetItemID(link)
    if not link then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    if id then return tonumber(id) end
    return nil
end

function CC:CanEquipNow()
    if InCombatLockdown and InCombatLockdown() then
        CC_Print("Cannot equip full gear sets in combat. Try again after combat.")
        return false
    end
    return true
end

-- ------------------------------------------------------------
-- Equipment slot table
-- id = inventory slot ID
-- key = Blizzard inventory slot token
-- locs = GetItemInfo equipLoc values allowed for this slot
-- ------------------------------------------------------------
CC.SLOTS = {
    { id = 1,  key = "HeadSlot",          label = "Head",      locs = { INVTYPE_HEAD = true } },
    { id = 2,  key = "NeckSlot",          label = "Neck",      locs = { INVTYPE_NECK = true } },
    { id = 3,  key = "ShoulderSlot",      label = "Shoulder",  locs = { INVTYPE_SHOULDER = true } },
    { id = 15, key = "BackSlot",          label = "Back",      locs = { INVTYPE_CLOAK = true } },
    { id = 5,  key = "ChestSlot",         label = "Chest",     locs = { INVTYPE_CHEST = true, INVTYPE_ROBE = true } },
    { id = 4,  key = "ShirtSlot",         label = "Shirt",     locs = { INVTYPE_BODY = true } },
    { id = 19, key = "TabardSlot",        label = "Tabard",    locs = { INVTYPE_TABARD = true } },
    { id = 9,  key = "WristSlot",         label = "Wrist",     locs = { INVTYPE_WRIST = true } },
    { id = 10, key = "HandsSlot",         label = "Hands",     locs = { INVTYPE_HAND = true } },
    { id = 6,  key = "WaistSlot",         label = "Waist",     locs = { INVTYPE_WAIST = true } },
    { id = 7,  key = "LegsSlot",          label = "Legs",      locs = { INVTYPE_LEGS = true } },
    { id = 8,  key = "FeetSlot",          label = "Feet",      locs = { INVTYPE_FEET = true } },
    { id = 11, key = "Finger0Slot",       label = "Finger 1",  locs = { INVTYPE_FINGER = true } },
    { id = 12, key = "Finger1Slot",       label = "Finger 2",  locs = { INVTYPE_FINGER = true } },
    { id = 13, key = "Trinket0Slot",      label = "Trinket 1", locs = { INVTYPE_TRINKET = true } },
    { id = 14, key = "Trinket1Slot",      label = "Trinket 2", locs = { INVTYPE_TRINKET = true } },
    { id = 16, key = "MainHandSlot",      label = "Main Hand", locs = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true } },
    { id = 17, key = "SecondaryHandSlot", label = "Off Hand",  locs = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true } },
    { id = 18, key = "RangedSlot",        label = "Ranged",    locs = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true } },
}

CC.SLOT_BY_ID = {}
for _, slotData in ipairs(CC.SLOTS) do
    CC.SLOT_BY_ID[slotData.id] = slotData
end

-- Character-sheet-ish layout positions
CC.SLOT_POSITIONS = {
    [1]  = { x = 28,  y = -82  },
    [2]  = { x = 28,  y = -126 },
    [3]  = { x = 28,  y = -170 },
    [15] = { x = 28,  y = -214 },
    [5]  = { x = 28,  y = -258 },
    [4]  = { x = 28,  y = -302 },
    [19] = { x = 28,  y = -346 },
    [9]  = { x = 28,  y = -390 },

    [10] = { x = 472, y = -82  },
    [6]  = { x = 472, y = -126 },
    [7]  = { x = 472, y = -170 },
    [8]  = { x = 472, y = -214 },
    [11] = { x = 472, y = -258 },
    [12] = { x = 472, y = -302 },
    [13] = { x = 472, y = -346 },
    [14] = { x = 472, y = -390 },

    [16] = { x = 172, y = -434 },
    [17] = { x = 250, y = -434 },
    [18] = { x = 328, y = -434 },
}

-- ------------------------------------------------------------
-- Bag/item scanning
-- ------------------------------------------------------------
function CC:ItemFitsSlot(link, invSlotID)
    if not link or not invSlotID then return false end

    local slotData = self.SLOT_BY_ID[invSlotID]
    if not slotData then return false end

    local itemName, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if not itemName or not equipLoc then return false end

    return slotData.locs[equipLoc] == true
end

function CC:ScanBagsForSlot(invSlotID)
    local items = {}

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0
        for bagSlot = 1, numSlots do
            local link = GetContainerItemLink(bag, bagSlot)
            if link and self:ItemFitsSlot(link, invSlotID) then
                local texture, count, locked = GetContainerItemInfo(bag, bagSlot)
                local name, _, quality, itemLevel, _, _, _, _, equipLoc, icon = GetItemInfo(link)
                table.insert(items, {
                    bag = bag,
                    bagSlot = bagSlot,
                    link = link,
                    itemID = self:GetItemID(link),
                    name = name or link,
                    quality = quality or 1,
                    itemLevel = itemLevel or 0,
                    equipLoc = equipLoc,
                    icon = texture or icon,
                    locked = locked,
                })
            end
        end
    end

    table.sort(items, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
        return tostring(a.name) < tostring(b.name)
    end)

    return items
end

function CC:FindBagItemByID(itemID)
    if not itemID then return nil, nil end

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0
        for bagSlot = 1, numSlots do
            local link = GetContainerItemLink(bag, bagSlot)
            if link and self:GetItemID(link) == itemID then
                return bag, bagSlot
            end
        end
    end

    return nil, nil
end

function CC:FindEquippedSlotByID(itemID, ignoreInvSlot)
    if not itemID then return nil end

    for _, slotData in ipairs(self.SLOTS) do
        if slotData.id ~= ignoreInvSlot then
            local link = GetInventoryItemLink("player", slotData.id)
            if link and self:GetItemID(link) == itemID then
                return slotData.id
            end
        end
    end

    return nil
end

-- ------------------------------------------------------------
-- Equipping functions
-- ------------------------------------------------------------
function CC:EquipBagSlotToInventorySlot(bag, bagSlot, invSlotID)
    if not self:CanEquipNow() then return false end
    if CursorHasItem and CursorHasItem() then ClearCursor() end

    PickupContainerItem(bag, bagSlot)
    if CursorHasItem and CursorHasItem() then
        PickupInventoryItem(invSlotID)

        -- If the old equipped item is now on the cursor, put it back into the bag slot
        -- that we just emptied by picking up the replacement item.
        if CursorHasItem and CursorHasItem() then
            PickupContainerItem(bag, bagSlot)
        end
    end

    self:UpdateSlotButtons()
    self:SchedulePlayerModelRefresh(0.45, true)
    return true
end

function CC:MoveInventorySlotToInventorySlot(fromSlotID, toSlotID)
    if not self:CanEquipNow() then return false end
    if not fromSlotID or not toSlotID or fromSlotID == toSlotID then return false end
    if CursorHasItem and CursorHasItem() then ClearCursor() end

    PickupInventoryItem(fromSlotID)
    if CursorHasItem and CursorHasItem() then
        PickupInventoryItem(toSlotID)
        if CursorHasItem and CursorHasItem() then
            PickupInventoryItem(fromSlotID)
        end
    end

    self:UpdateSlotButtons()
    self:SchedulePlayerModelRefresh(0.45, true)
    return true
end

function CC:EquipItemIDToSlot(itemID, invSlotID)
    if not itemID or not invSlotID then return false end

    local currentLink = GetInventoryItemLink("player", invSlotID)
    if currentLink and self:GetItemID(currentLink) == itemID then
        return true
    end

    local bag, bagSlot = self:FindBagItemByID(itemID)
    if bag and bagSlot then
        return self:EquipBagSlotToInventorySlot(bag, bagSlot, invSlotID)
    end

    local equippedSlot = self:FindEquippedSlotByID(itemID, invSlotID)
    if equippedSlot then
        return self:MoveInventorySlotToInventorySlot(equippedSlot, invSlotID)
    end

    return false
end

-- ------------------------------------------------------------
-- Saved gear sets
-- ------------------------------------------------------------
function CC:GetSetNames()
    local names = {}
    if not ClefairyClosetDB or not ClefairyClosetDB.sets then return names end

    for name in pairs(ClefairyClosetDB.sets) do
        table.insert(names, name)
    end

    table.sort(names)
    return names
end

function CC:SaveCurrentSet(name)
    if not ClefairyClosetDB then ClefairyClosetDB = {} end
    if not ClefairyClosetDB.sets then ClefairyClosetDB.sets = {} end

    name = tostring(name or "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")

    if name == "" then
        CC_Print("Type a gear set name first.")
        return
    end

    local set = {
        name = name,
        savedAt = time and time() or 0,
        items = {},
    }

    for _, slotData in ipairs(self.SLOTS) do
        local link = GetInventoryItemLink("player", slotData.id)
        if link then
            local itemName = GetItemInfo(link)
            set.items[slotData.id] = {
                itemID = self:GetItemID(link),
                link = link,
                name = itemName or link,
            }
        end
    end

    ClefairyClosetDB.sets[name] = set
    self.selectedSet = name
    self:RefreshSetPanel()
    CC_Print("Saved gear set: " .. name)
end

function CC:DeleteSet(name)
    if not name or not ClefairyClosetDB or not ClefairyClosetDB.sets or not ClefairyClosetDB.sets[name] then
        CC_Print("No set selected.")
        return
    end

    ClefairyClosetDB.sets[name] = nil
    if self.selectedSet == name then self.selectedSet = nil end
    self:RefreshSetPanel()
    CC_Print("Deleted gear set: " .. name)
end

function CC:EquipSet(name)
    if not ClefairyClosetDB or not ClefairyClosetDB.sets or not ClefairyClosetDB.sets[name] then
        CC_Print("Could not find gear set: " .. tostring(name))
        return
    end

    if not self:CanEquipNow() then return end

    local set = ClefairyClosetDB.sets[name]
    self.equipQueue = {}
    self.equipMissing = {}
    self.equipSetName = name

    for _, slotData in ipairs(self.SLOTS) do
        local entry = set.items[slotData.id]
        if entry and entry.itemID then
            local currentLink = GetInventoryItemLink("player", slotData.id)
            local currentID = self:GetItemID(currentLink)
            if currentID ~= entry.itemID then
                table.insert(self.equipQueue, {
                    invSlotID = slotData.id,
                    itemID = entry.itemID,
                    name = entry.name or entry.link or tostring(entry.itemID),
                })
            end
        end
    end

    if #self.equipQueue == 0 then
        CC_Print("Already wearing set: " .. name)
        return
    end

    self.queueElapsed = 0
    self:SetScript("OnUpdate", function(frame, elapsed)
        frame:ProcessEquipQueue(elapsed)
    end)

    CC_Print("Equipping set: " .. name)
end

function CC:ProcessEquipQueue(elapsed)
    self.queueElapsed = (self.queueElapsed or 0) + (elapsed or 0)
    if self.queueElapsed < 0.15 then return end
    self.queueElapsed = 0

    if InCombatLockdown and InCombatLockdown() then
        self:SetScript("OnUpdate", nil)
        CC_Print("Set equip cancelled because combat started.")
        return
    end

    if not self.equipQueue or #self.equipQueue == 0 then
        self:SetScript("OnUpdate", nil)
        self:UpdateSlotButtons()
        self:RefreshSetPanel()
        self:SchedulePlayerModelRefresh(0.55, true)

        if self.equipMissing and #self.equipMissing > 0 then
            CC_Print("Finished with missing items:")
            for _, itemName in ipairs(self.equipMissing) do
                CC_Print("Missing: " .. tostring(itemName))
            end
        else
            CC_Print("Finished equipping: " .. tostring(self.equipSetName or "set"))
        end
        return
    end

    local job = table.remove(self.equipQueue, 1)
    local ok = self:EquipItemIDToSlot(job.itemID, job.invSlotID)
    if not ok then
        table.insert(self.equipMissing, job.name)
    end
end

-- ------------------------------------------------------------
-- Item list popup shown from gear-slot hover/click
-- ------------------------------------------------------------
function CC:IsMouseOverFrame(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then return false end

    if frame.IsMouseOver then
        local ok, result = pcall(function() return frame:IsMouseOver() end)
        if ok then return result end
    end

    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return false end

    local x, y = GetCursorPosition()
    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    x = x / scale
    y = y / scale

    return x >= left and x <= right and y >= bottom and y <= top
end

function CC:IsMouseOverItemListOrAnchor()
    local f = self.itemList
    if not f or not f:IsShown() then return false end

    if self:IsMouseOverFrame(f) then return true end
    if f.currentAnchor and self:IsMouseOverFrame(f.currentAnchor) then return true end

    return false
end

function CC:CancelItemListHide()
    self.itemListHideElapsed = nil
    if self.itemList then
        self.itemList:SetScript("OnUpdate", nil)
    end
end

function CC:ScheduleItemListHide(delay)
    local f = self.itemList
    if not f or not f:IsShown() then return end

    self.itemListHideDelay = delay or 0.20
    self.itemListHideElapsed = 0

    f:SetScript("OnUpdate", function(frame, elapsed)
        CC:ProcessItemListHide(elapsed)
    end)
end

function CC:ProcessItemListHide(elapsed)
    local f = self.itemList
    if not f or not f:IsShown() then
        self:CancelItemListHide()
        return
    end

    self.itemListHideElapsed = (self.itemListHideElapsed or 0) + (elapsed or 0)
    if self.itemListHideElapsed < (self.itemListHideDelay or 0.20) then return end

    if self:IsMouseOverItemListOrAnchor() then
        self.itemListHideElapsed = 0
        return
    end

    f:Hide()
    self:CancelItemListHide()
end

function CC:CreateItemListFrame()
    local f = CC_CreateFrame("Frame", "ClefairyClosetItemList", UIParent)
    f:SetSize(310, 220)
    f:SetFrameStrata("DIALOG")
    CC_SetBackdrop(f, 0.02, 0.02, 0.02, 0.94)
    f:Hide()

    f:EnableMouse(true)
    f:SetScript("OnEnter", function()
        CC:CancelItemListHide()
    end)
    f:SetScript("OnLeave", function()
        CC:ScheduleItemListHide(0.20)
    end)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    f.title:SetText("Bag Items")

    f.rows = {}
    for i = 1, 14 do
        local row = CreateFrame("Button", "ClefairyClosetItemListRow" .. i, f)
        row:SetSize(282, 24)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34 - ((i - 1) * 25))

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")

        row:SetScript("OnEnter", function(button)
            CC:CancelItemListHide()
            if button.itemLink then
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(button.itemLink)
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
            CC:ScheduleItemListHide(0.20)
        end)

        row:SetScript("OnClick", function(button)
            if button.bag and button.bagSlot and button.invSlotID then
                CC:EquipBagSlotToInventorySlot(button.bag, button.bagSlot, button.invSlotID)
                CC:ShowItemListForSlot(button.invSlotID, button.anchorButton)
            end
        end)

        f.rows[i] = row
    end

    self.itemList = f
end

function CC:ShowItemListForSlot(invSlotID, anchorButton)
    if not self.itemList then self:CreateItemListFrame() end
    self:CancelItemListHide()

    local slotData = self.SLOT_BY_ID[invSlotID]
    if not slotData then return end

    local items = self:ScanBagsForSlot(invSlotID)
    local f = self.itemList
    f.currentSlot = invSlotID
    f.currentAnchor = anchorButton
    f.title:SetText(slotData.label .. " bag items")

    f:ClearAllPoints()
    if anchorButton then
        -- Keep the item picker away from the middle of the paper doll.
        -- Left-side armor slots open outward to the left.
        -- Bottom weapon slots open downward.
        -- Right-side armor slots still open outward to the right.
        if invSlotID == 16 or invSlotID == 17 or invSlotID == 18 then
            f:SetPoint("TOP", anchorButton, "BOTTOM", 0, -10)
        else
            local pos = self.SLOT_POSITIONS and self.SLOT_POSITIONS[invSlotID]
            if pos and pos.x < 200 then
                f:SetPoint("TOPRIGHT", anchorButton, "TOPLEFT", -8, 0)
            else
                f:SetPoint("TOPLEFT", anchorButton, "TOPRIGHT", 8, 0)
            end
        end
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    for i = 1, #f.rows do
        local row = f.rows[i]
        local item = items[i]
        if item then
            row.bag = item.bag
            row.bagSlot = item.bagSlot
            row.invSlotID = invSlotID
            row.itemLink = item.link
            row.anchorButton = anchorButton
            row.icon:SetTexture(item.icon)
            row.text:SetText(item.link)
            row:Show()
        else
            row.bag = nil
            row.bagSlot = nil
            row.invSlotID = nil
            row.itemLink = nil
            row.anchorButton = nil
            row:Hide()
        end
    end

    if #items == 0 then
        f.title:SetText(slotData.label .. " bag items - none found")
    end

    f:Show()
end


-- ------------------------------------------------------------
-- Center panel: character model / saved sets view
-- ------------------------------------------------------------
function CC:WirePlayerModel(model)
    if not model then return end

    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function(modelFrame, button)
        if button == "LeftButton" then CC:BeginModelSpin() end
    end)
    model:SetScript("OnMouseUp", function(modelFrame, button)
        if button == "LeftButton" then CC:EndModelSpin() end
    end)
    model:SetScript("OnHide", function()
        CC:EndModelSpin()
    end)
end

function CC:CreatePlayerModelFrame(parentFrame)
    local f = parentFrame or self.mainFrame
    if not f or not f.modelArea then return false end

    local ok, model = pcall(function()
        -- Use an anonymous PlayerModel here. Some 2.5.3 clients cache the
        -- named model's equipment display after item swaps, which can make
        -- the preview show the old/new items crossed. Rebuilding this small
        -- anonymous model after a short delay forces a clean read of the
        -- real currently-equipped gear.
        return CreateFrame("PlayerModel", nil, f.modelArea)
    end)

    if ok and model then
        f.playerModel = model
        f.playerModel:SetAllPoints(f.modelArea)
        self:WirePlayerModel(f.playerModel)
        if f.modelFallbackText then f.modelFallbackText:Hide() end
        return true
    end

    f.playerModel = nil
    if not f.modelFallbackText then
        f.modelFallbackText = f.modelArea:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
        f.modelFallbackText:SetPoint("CENTER", f.modelArea, "CENTER", 0, 0)
        f.modelFallbackText:SetText("Character\nModel\nUnavailable")
    end
    f.modelFallbackText:Show()
    return false
end

function CC:HardRefreshPlayerModel()
    local f = self.mainFrame
    if not f or not f.modelArea then return end
    if f.savedPanel and f.savedPanel:IsShown() then return end

    self:EndModelSpin()

    local oldModel = f.playerModel
    if oldModel then
        oldModel:Hide()
        oldModel:SetScript("OnMouseDown", nil)
        oldModel:SetScript("OnMouseUp", nil)
        oldModel:SetScript("OnHide", nil)
        oldModel:ClearAllPoints()
        oldModel:SetParent(UIParent)
    end

    if not self:CreatePlayerModelFrame(f) then return end
    f.playerModel:Show()

    if f.playerModel.SetUnit then
        pcall(function() f.playerModel:SetUnit("player") end)
    end
    self:ApplyPlayerModelView()
    self:ResetPlayerModelAnimation()
    self:StartPlayerModelDanceTimer()
end

function CC:SchedulePlayerModelRefresh(delay, hardRefresh)
    local f = self.mainFrame
    if not f then return end
    if f.savedPanel and f.savedPanel:IsShown() then return end

    self.pendingModelRefresh = true
    self.pendingModelHardRefresh = self.pendingModelHardRefresh or hardRefresh
    self.pendingModelRefreshElapsed = 0
    self.pendingModelRefreshDelay = delay or 0.35

    if self.modelRefreshDriver then
        self.modelRefreshDriver:Show()
    else
        -- Fallback for very early calls before Initialize creates the driver.
        if hardRefresh then
            self:HardRefreshPlayerModel()
        else
            self:RefreshPlayerModel()
        end
    end
end

function CC:ProcessScheduledModelRefresh(elapsed)
    if not self.pendingModelRefresh then
        if self.modelRefreshDriver then self.modelRefreshDriver:Hide() end
        return
    end

    if self.draggingModel then return end

    self.pendingModelRefreshElapsed = (self.pendingModelRefreshElapsed or 0) + (elapsed or 0)
    if self.pendingModelRefreshElapsed < (self.pendingModelRefreshDelay or 0.35) then return end

    local hardRefresh = self.pendingModelHardRefresh
    self.pendingModelRefresh = nil
    self.pendingModelHardRefresh = nil
    self.pendingModelRefreshElapsed = 0
    if self.modelRefreshDriver then self.modelRefreshDriver:Hide() end

    if hardRefresh then
        self:HardRefreshPlayerModel()
    else
        self:RefreshPlayerModel()
    end
end

function CC:ApplyPlayerModelView()
    local f = self.mainFrame
    if not f or not f.playerModel then return end

    local model = f.playerModel
    local facing = self.modelFacing or 0.05

    -- Important: do NOT call SetCamera/ClearModel/SetPortraitZoom here.
    -- On some 2.5.3 clients those calls can snap PlayerModel into a
    -- head-only portrait zoom after hiding/showing the Saved Sets panel.
    if model.SetCamDistanceScale then pcall(function() model:SetCamDistanceScale(1.0) end) end
    if model.SetPosition then pcall(function() model:SetPosition(0, 0, 0) end) end
    if model.SetFacing then pcall(function() model:SetFacing(facing) end) end
    if model.SetRotation then pcall(function() model:SetRotation(facing) end) end
end

function CC:RefreshPlayerModel()
    local f = self.mainFrame
    if not f or not f.playerModel then return end
    if f.savedPanel and f.savedPanel:IsShown() then return end

    if f.playerModel.SetUnit then pcall(function() f.playerModel:SetUnit("player") end) end
    self:ApplyPlayerModelView()
    self:ResetPlayerModelAnimation()
    self:StartPlayerModelDanceTimer()
end


function CC:ResetPlayerModelAnimation()
    local f = self.mainFrame
    if not f or not f.playerModel then return end

    self.modelIsDancing = false
    if f.playerModel.SetAnimation then
        pcall(function() f.playerModel:SetAnimation(0) end)
    end
end

function CC:StartPlayerModelDanceTimer()
    local f = self.mainFrame
    if not f or not f.playerModel then return end
    if not f:IsShown() then return end
    if f.savedPanel and f.savedPanel:IsShown() then return end

    self.modelDanceElapsed = 0
    self.modelDancePending = true
    if self.modelDanceDriver then
        self.modelDanceDriver:Show()
    end
end

function CC:CancelPlayerModelDanceTimer()
    self.modelDancePending = nil
    self.modelDanceElapsed = 0
    if self.modelDanceDriver then
        self.modelDanceDriver:Hide()
    end
end

function CC:ProcessPlayerModelDance(elapsed)
    if not self.modelDancePending then
        if self.modelDanceDriver then self.modelDanceDriver:Hide() end
        return
    end

    local f = self.mainFrame
    if not f or not f:IsShown() or not f.playerModel or (f.savedPanel and f.savedPanel:IsShown()) then
        self:CancelPlayerModelDanceTimer()
        return
    end

    self.modelDanceElapsed = (self.modelDanceElapsed or 0) + (elapsed or 0)
    if self.modelDanceElapsed < (self.MODEL_DANCE_DELAY or 5.0) then return end

    self.modelDancePending = nil
    self.modelDanceElapsed = 0
    if self.modelDanceDriver then self.modelDanceDriver:Hide() end

    if f.playerModel.SetAnimation then
        pcall(function() f.playerModel:SetAnimation(self.MODEL_DANCE_ANIMATION_ID or 69) end)
        self.modelIsDancing = true
    end
end

function CC:BeginModelSpin()
    local f = self.mainFrame
    if not f or not f.playerModel then return end

    self.draggingModel = true
    self.lastModelCursorX = GetCursorPosition()

    f.playerModel:SetScript("OnUpdate", function(model, elapsed)
        CC:UpdateModelSpin(elapsed)
    end)
end

function CC:UpdateModelSpin(elapsed)
    if not self.draggingModel then return end

    local x = GetCursorPosition()
    local lastX = self.lastModelCursorX or x
    local dx = x - lastX
    self.lastModelCursorX = x

    self.modelFacing = (self.modelFacing or 0.05) + (dx * 0.01)
    if ClefairyClosetDB then ClefairyClosetDB.modelFacing = self.modelFacing end

    self:ApplyPlayerModelView()
end

function CC:EndModelSpin()
    local f = self.mainFrame
    self.draggingModel = false
    self.lastModelCursorX = nil

    if f and f.playerModel then
        f.playerModel:SetScript("OnUpdate", nil)
    end
end

function CC:ShowCharacterModel()
    local f = self.mainFrame
    if not f then return end

    if f.savedPanel then f.savedPanel:Hide() end
    if f.playerModel then f.playerModel:Show() end
    if f.modelFallbackText and (not f.playerModel) then f.modelFallbackText:Show() end
    self:SchedulePlayerModelRefresh(0.05, true)
end

function CC:ShowSavedSets()
    local f = self.mainFrame
    if not f then return end

    self:CancelPlayerModelDanceTimer()
    if f.playerModel then f.playerModel:Hide() end
    if f.modelFallbackText then f.modelFallbackText:Hide() end
    if f.savedPanel then
        self:RefreshSetPanel()
        f.savedPanel:Show()
    end
end

function CC:ToggleSavedSetsView()
    local f = self.mainFrame
    if not f or not f.savedPanel then return end

    if f.savedPanel:IsShown() then
        self:ShowCharacterModel()
    else
        self:ShowSavedSets()
    end
end

-- ------------------------------------------------------------
-- Main UI
-- ------------------------------------------------------------
function CC:CreateMainFrame()
    local f = CC_CreateFrame("Frame", "ClefairyClosetFrame", UIParent)
    f:SetSize(540, 590)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", function()
        CC:EndModelSpin()
        CC:CancelPlayerModelDanceTimer()
    end)
    CC_SetBackdrop(f, 0.04, 0.02, 0.04, 0.92)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -14)
    f.title:SetText("ClefairyCloset")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    f.savedSetsButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.savedSetsButton:SetSize(110, 22)
    f.savedSetsButton:SetPoint("TOP", f.title, "BOTTOM", 0, -8)
    f.savedSetsButton:SetText("Saved Sets")
    f.savedSetsButton:SetScript("OnClick", function()
        CC:ToggleSavedSetsView()
    end)

    -- Center area. Default view is your live player model. Saved Sets temporarily
    -- replaces this same area, then Close returns to the character model.
    f.modelArea = CC_CreateFrame("Frame", nil, f)
    f.modelArea:SetSize(234, 338)
    f.modelArea:SetPoint("TOP", f, "TOP", 0, -76)
    CC_SetBackdrop(f.modelArea, 0, 0, 0, 0.28)

    self:CreatePlayerModelFrame(f)

    f.savedPanel = CC_CreateFrame("Frame", nil, f.modelArea)
    f.savedPanel:SetAllPoints(f.modelArea)
    CC_SetBackdrop(f.savedPanel, 0.02, 0.01, 0.02, 0.95)
    f.savedPanel:Hide()

    f.savedPanelTitle = f.savedPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.savedPanelTitle:SetPoint("TOP", f.savedPanel, "TOP", 0, -12)
    f.savedPanelTitle:SetText("Saved Sets")

    f.savedPanelHint = f.savedPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.savedPanelHint:SetPoint("TOP", f.savedPanelTitle, "BOTTOM", 0, -4)
    f.savedPanelHint:SetText("Click a set to equip it")

    f.savedRows = {}
    for i = 1, 11 do
        local row = CreateFrame("Button", nil, f.savedPanel)
        row:SetSize(196, 20)
        row:SetPoint("TOP", f.savedPanel, "TOP", 0, -48 - ((i - 1) * 22))

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetAllPoints(row)
        row.text:SetJustifyH("CENTER")

        row:SetScript("OnEnter", function(button)
            if button.setName then
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetText(button.setName)
                GameTooltip:AddLine("Click to equip this set.", 1.0, 0.6, 0.9)
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:SetScript("OnClick", function(button)
            if button.setName then
                CC.selectedSet = button.setName
                CC:RefreshSetPanel()
                CC:EquipSet(button.setName)
            end
        end)

        f.savedRows[i] = row
    end

    f.savedPanelEmpty = f.savedPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.savedPanelEmpty:SetPoint("CENTER", f.savedPanel, "CENTER", 0, 10)
    f.savedPanelEmpty:SetText("No saved sets yet")
    f.savedPanelEmpty:Hide()

    f.savedPanelClose = CreateFrame("Button", nil, f.savedPanel, "UIPanelButtonTemplate")
    f.savedPanelClose:SetSize(82, 22)
    f.savedPanelClose:SetPoint("BOTTOM", f.savedPanel, "BOTTOM", 0, 12)
    f.savedPanelClose:SetText("Close")
    f.savedPanelClose:SetScript("OnClick", function()
        CC:ShowCharacterModel()
    end)

    f.nameBox = CreateFrame("EditBox", "ClefairyClosetNameBox", f, "InputBoxTemplate")
    f.nameBox:SetSize(190, 22)
    f.nameBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 28, 24)
    f.nameBox:SetAutoFocus(false)
    f.nameBox:SetText("")

    f.saveButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.saveButton:SetSize(92, 24)
    f.saveButton:SetPoint("LEFT", f.nameBox, "RIGHT", 8, 0)
    f.saveButton:SetText("Save Set")
    f.saveButton:SetScript("OnClick", function()
        CC:SaveCurrentSet(f.nameBox:GetText())
        CC:ShowSavedSets()
    end)

    f.equipButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.equipButton:SetSize(80, 24)
    f.equipButton:SetPoint("LEFT", f.saveButton, "RIGHT", 8, 0)
    f.equipButton:SetText("Equip")
    f.equipButton:SetScript("OnClick", function()
        if CC.selectedSet then
            CC:EquipSet(CC.selectedSet)
        else
            CC_Print("Select a saved set first.")
        end
    end)

    f.deleteButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.deleteButton:SetSize(82, 24)
    f.deleteButton:SetPoint("LEFT", f.equipButton, "RIGHT", 8, 0)
    f.deleteButton:SetText("Delete")
    f.deleteButton:SetScript("OnClick", function()
        if CC.selectedSet then
            CC:DeleteSet(CC.selectedSet)
        else
            CC_Print("Select a saved set first.")
        end
    end)

    f.slotButtons = {}
    for _, slotData in ipairs(self.SLOTS) do
        local pos = self.SLOT_POSITIONS[slotData.id]
        if pos then
            local b = CreateFrame("Button", "ClefairyClosetSlot" .. slotData.id, f)
            b:SetSize(self.SLOT_BUTTON_SIZE or 42, self.SLOT_BUTTON_SIZE or 42)
            b:SetPoint("TOPLEFT", f, "TOPLEFT", pos.x, pos.y)
            b.invSlotID = slotData.id
            b.slotKey = slotData.key
            b.slotLabel = slotData.label
            CC_SetBackdrop(b, 0, 0, 0, 0.65)

            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
            b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)

            b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            if slotData.id == 16 or slotData.id == 17 or slotData.id == 18 then
                -- Weapon labels stay under their icons so Main Hand cannot collide with Off Hand.
                b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
                b.label:SetJustifyH("CENTER")
            elseif pos.x < 200 then
                b.label:SetPoint("LEFT", b, "RIGHT", 6, 0)
                b.label:SetJustifyH("LEFT")
            else
                b.label:SetPoint("RIGHT", b, "LEFT", -6, 0)
                b.label:SetJustifyH("RIGHT")
            end
            b.label:SetText(slotData.label)

            b:SetScript("OnEnter", function(button)
                CC:CancelItemListHide()
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                local hasItem = GameTooltip:SetInventoryItem("player", button.invSlotID)
                if not hasItem then
                    GameTooltip:SetText(button.slotLabel)
                    GameTooltip:AddLine("No item equipped.", 0.8, 0.8, 0.8)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Hover/click shows matching bag items.", 1.0, 0.6, 0.9)
                GameTooltip:Show()
                CC:ShowItemListForSlot(button.invSlotID, button)
            end)

            b:SetScript("OnLeave", function()
                GameTooltip:Hide()
                CC:ScheduleItemListHide(0.25)
            end)

            b:SetScript("OnClick", function(button)
                CC:ShowItemListForSlot(button.invSlotID, button)
            end)

            f.slotButtons[slotData.id] = b
        end
    end

    self.mainFrame = f
    self:UpdateSlotButtons()
    self:RefreshSetPanel()
    self:ShowCharacterModel()
end

function CC:UpdateSlotButtons()
    if not self.mainFrame or not self.mainFrame.slotButtons then return end

    for _, slotData in ipairs(self.SLOTS) do
        local b = self.mainFrame.slotButtons[slotData.id]
        if b then
            local texture = GetInventoryItemTexture("player", slotData.id)
            if not texture and GetInventorySlotInfo then
                local _, emptyTexture = GetInventorySlotInfo(slotData.key)
                texture = emptyTexture
            end
            b.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
end

function CC:RefreshSetPanel()
    if not self.mainFrame or not self.mainFrame.savedRows then return end

    local names = self:GetSetNames()
    if self.mainFrame.savedPanelEmpty then
        if #names == 0 then
            self.mainFrame.savedPanelEmpty:Show()
        else
            self.mainFrame.savedPanelEmpty:Hide()
        end
    end

    for i = 1, #self.mainFrame.savedRows do
        local row = self.mainFrame.savedRows[i]
        local name = names[i]
        if name then
            row.setName = name
            if self.selectedSet == name then
                row.text:SetText("|cff00ff00> " .. name .. " <|r")
            else
                row.text:SetText(name)
            end
            row:Show()
        else
            row.setName = nil
            row.text:SetText("")
            row:Hide()
        end
    end
end

function CC:ToggleMainFrame()
    if not self.mainFrame then self:CreateMainFrame() end
    if self.mainFrame:IsShown() then
        self:CancelPlayerModelDanceTimer()
        self.mainFrame:Hide()
    else
        self:UpdateSlotButtons()
        self:RefreshSetPanel()
        self.mainFrame:Show()
        self:ShowCharacterModel()
    end
end

-- ------------------------------------------------------------
-- Minimap button and right-click set menu
-- ------------------------------------------------------------
function CC:CreateMinimapButton()
    local b = CreateFrame("Button", "ClefairyClosetMinimapButton", Minimap)
    b:SetSize(33, 33)
    b:SetFrameStrata("MEDIUM")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetMovable(true)

    -- Use a TBC-safe druid icon. The achievement tauren icon is not present
    -- on many 2.5.3 clients, which causes the green missing-texture square.
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -6)
    b.icon:SetTexture("Interface\\Icons\\Ability_Druid_Maul")
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- MiniMap-TrackingBorder is offset artwork. Anchoring it like Blizzard's
    -- tracking button keeps the icon centered inside the round frame.
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetSize(54, 54)
    b.border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("ClefairyCloset")
        GameTooltip:AddLine("Left-click: open gear window", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: equip saved set", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    b:SetScript("OnClick", function(button, mouseButton)
        if mouseButton == "RightButton" then
            CC:OpenMinimapMenu()
        else
            CC:ToggleMainFrame()
        end
    end)

    b:SetScript("OnDragStart", function(button)
        button:SetScript("OnUpdate", function(btn)
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale() or 1
            x = x / scale
            y = y / scale
            local cx, cy = Minimap:GetCenter()
            if cx and cy then
                ClefairyClosetDB.minimapX = x - cx
                ClefairyClosetDB.minimapY = y - cy
                CC:UpdateMinimapButtonPosition()
            end
        end)
    end)

    b:SetScript("OnDragStop", function(button)
        button:SetScript("OnUpdate", nil)
    end)

    self.minimapButton = b
    self.menuFrame = CreateFrame("Frame", "ClefairyClosetMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    self:UpdateMinimapButtonPosition()
end

function CC:UpdateMinimapButtonPosition()
    if not self.minimapButton then return end
    if not ClefairyClosetDB then ClefairyClosetDB = {} end

    local x = ClefairyClosetDB.minimapX or -70
    local y = ClefairyClosetDB.minimapY or -70

    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function CC:OpenMinimapMenu()
    if not self.menuFrame then return end

    UIDropDownMenu_Initialize(self.menuFrame, function(frame, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "ClefairyCloset"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Open Gear Window"
        info.notCheckable = true
        info.func = function() CC:ToggleMainFrame() end
        UIDropDownMenu_AddButton(info, level)

        local names = CC:GetSetNames()
        if #names > 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = "Equip Set"
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)

            for _, setName in ipairs(names) do
                local safeName = setName
                info = UIDropDownMenu_CreateInfo()
                info.text = safeName
                info.notCheckable = true
                info.func = function() CC:EquipSet(safeName) end
                UIDropDownMenu_AddButton(info, level)
            end
        else
            info = UIDropDownMenu_CreateInfo()
            info.text = "No saved sets yet"
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")

    ToggleDropDownMenu(1, nil, self.menuFrame, "cursor", 0, 0)
end

-- ------------------------------------------------------------
-- Events / slash commands
-- ------------------------------------------------------------
function CC:Initialize()
    if not ClefairyClosetDB then ClefairyClosetDB = {} end
    if not ClefairyClosetDB.sets then ClefairyClosetDB.sets = {} end
    self.modelFacing = ClefairyClosetDB.modelFacing or 0.05

    self.modelRefreshDriver = CreateFrame("Frame", "ClefairyClosetModelRefreshDriver")
    self.modelRefreshDriver:Hide()
    self.modelRefreshDriver:SetScript("OnUpdate", function(driver, elapsed)
        CC:ProcessScheduledModelRefresh(elapsed)
    end)

    self.modelDanceDriver = CreateFrame("Frame", "ClefairyClosetModelDanceDriver")
    self.modelDanceDriver:Hide()
    self.modelDanceDriver:SetScript("OnUpdate", function(driver, elapsed)
        CC:ProcessPlayerModelDance(elapsed)
    end)

    self:CreateMainFrame()
    self:CreateMinimapButton()
    CC_Print("Loaded. Use /ccloset or click the minimap button.")
end

CC:SetScript("OnEvent", function(frame, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        frame:Initialize()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" then
        frame:UpdateSlotButtons()
        frame:SchedulePlayerModelRefresh(0.45, true)
        if frame.itemList and frame.itemList:IsShown() and frame.itemList.currentSlot then
            frame:ShowItemListForSlot(frame.itemList.currentSlot, frame.itemList.currentAnchor)
        end
    end
end)

CC:RegisterEvent("ADDON_LOADED")
CC:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
CC:RegisterEvent("BAG_UPDATE_DELAYED")
CC:RegisterEvent("BAG_UPDATE")

SLASH_CLEFAIRYCLOSET1 = "/ccloset"
SLASH_CLEFAIRYCLOSET2 = "/clefairycloset"
SLASH_CLEFAIRYCLOSET3 = "/closet"
SlashCmdList["CLEFAIRYCLOSET"] = function(msg)
    msg = tostring(msg or "")

    local _, _, equipName = string.find(msg, "^equip%s+(.+)$")
    if equipName and equipName ~= "" then
        CC:EquipSet(equipName)
        return
    end

    local _, _, saveName = string.find(msg, "^save%s+(.+)$")
    if saveName and saveName ~= "" then
        CC:SaveCurrentSet(saveName)
        return
    end

    if msg == "list" then
        local names = CC:GetSetNames()
        if #names == 0 then
            CC_Print("No saved sets yet.")
        else
            CC_Print("Saved sets:")
            for _, name in ipairs(names) do
                CC_Print("- " .. name)
            end
        end
        return
    end

    if msg == "help" then
        CC_Print("/ccloset - open window")
        CC_Print("/ccloset save SetName - save current gear")
        CC_Print("/ccloset equip SetName - equip saved gear")
        CC_Print("/ccloset list - list saved sets")
        return
    end

    CC:ToggleMainFrame()
end

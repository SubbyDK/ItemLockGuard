-- Global variables for database and state management
ItemLockGuard_LockedItems = ItemLockGuard_LockedItems or {}
local isDisenchanting = false

-- Helper function to print formatted messages to the default chat frame
local function PrintMsg(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[ItemLockGuard]|r " .. msg)
    end
end

-- Extracts a unique ItemID from a standard WoW item link using string parsing
local function GetItemID(link)
    if (not link) then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    return id
end

-- Checks if the Merchant/Vendor window is currently open
local function IsVendorActive()
    return (MerchantFrame and MerchantFrame:IsVisible())
end

-------------------------------------------------------------------------------
-- DISENCHANT DETECTION (Vanilla WoW 1.12 API Logic)
-------------------------------------------------------------------------------
-- In 1.12, there is no direct way to query the cursor spell. 
-- We hook the casting functions to "flag" when Disenchant is activated.

-- Hook: Casting via Spellbook
local _CastSpell = CastSpell
CastSpell = function(id, book)
    local name = GetSpellName(id, book)
    if (name == "Disenchant") then
        isDisenchanting = true
    else
        isDisenchanting = false
    end
    _CastSpell(id, book)
end

-- Hook: Casting via Macros or Scripts
local _CastSpellByName = CastSpellByName
CastSpellByName = function(name, onSelf)
    if (name and string.find(name, "Disenchant")) then
        isDisenchanting = true
    else
        isDisenchanting = false
    end
    _CastSpellByName(name, onSelf)
end

-- Hook: Using an action from the Action Bar
local _UseAction = UseAction
UseAction = function(slot, check, onSelf)
    -- Scan the action tooltip to see if the button is the Disenchant spell
    GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    GameTooltip:SetAction(slot)
    local text = GameTooltipTextLeft1:GetText()
    GameTooltip:Hide()
    
    if (text == "Disenchant") then
        isDisenchanting = true
    end
    _UseAction(slot, check, onSelf)
end

-------------------------------------------------------------------------------
-- EVENTS AND DATABASE LOADING
-------------------------------------------------------------------------------
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("SPELLCAST_STOP") -- Reset flag when spell is finished or cancelled
EventFrame:RegisterEvent("ADDON_LOADED")   -- Handle database initialization

EventFrame:SetScript("OnEvent", function()
    if (event == "SPELLCAST_STOP") then
        isDisenchanting = false
    elseif (event == "ADDON_LOADED" and arg1 == "ItemLockGuard") then
        -- Ensure the database is a valid table upon loading
        if (not ItemLockGuard_LockedItems) or (type(ItemLockGuard_LockedItems) ~= "table") then
            ItemLockGuard_LockedItems = {}
        end
    end
end)

-------------------------------------------------------------------------------
-- CORE PROTECTION LOGIC
-------------------------------------------------------------------------------
-- Determines if an item should be protected based on lock status and current activity
local function IsProtected(link)
    if (not link) then return false end
    
    -- We only block if the user is currently Disenchanting OR at a Merchant/Vendor
    local blockAction = isDisenchanting or IsVendorActive()
    
    if (not blockAction) then return false end

    local id = GetItemID(link)
    if (id and ItemLockGuard_LockedItems[id]) then
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- INTERACTION HOOKS (Blocking Logic)
-------------------------------------------------------------------------------

-- Hook: Interaction with items in Bags (Right-click or Use)
local _UseContainerItem = UseContainerItem
UseContainerItem = function(bag, slot, onSelf)
    if (IsProtected(GetContainerItemLink(bag, slot))) then
        UIErrorsFrame:AddMessage("ITEM IS LOCKED!", 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then SpellStopTargeting() end
        isDisenchanting = false
        return -- Prevents selling or disenchanting
    end
    _UseContainerItem(bag, slot, onSelf)
end

-- Hook: Dragging items or clicking them with a spell cursor (Bags)
local _PickupContainerItem = PickupContainerItem
PickupContainerItem = function(bag, slot)
    if (IsProtected(GetContainerItemLink(bag, slot))) then
        UIErrorsFrame:AddMessage("ITEM IS LOCKED!", 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then SpellStopTargeting() end
        isDisenchanting = false
        return -- Prevents item from being picked up/applied to spell
    end
    _PickupContainerItem(bag, slot)
end

-- Hook: Interaction with equipped gear (Character Frame)
local _UseInventoryItem = UseInventoryItem
UseInventoryItem = function(slot)
    if (IsProtected(GetInventoryItemLink("player", slot))) then
        UIErrorsFrame:AddMessage("ITEM IS LOCKED!", 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then SpellStopTargeting() end
        isDisenchanting = false
        return
    end
    _UseInventoryItem(slot)
end

-- Hook: Picking up or applying spell cursor to equipped gear
local _PickupInventoryItem = PickupInventoryItem
PickupInventoryItem = function(slot)
    if (IsProtected(GetInventoryItemLink("player", slot))) then
        UIErrorsFrame:AddMessage("ITEM IS LOCKED!", 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then SpellStopTargeting() end
        isDisenchanting = false
        return
    end
    _PickupInventoryItem(slot)
end

-------------------------------------------------------------------------------
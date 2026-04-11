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
-- LOCALIZATION
-------------------------------------------------------------------------------
-- Initialize with English defaults to prevent crashes on unknown locales.
-- Will cover:
-- English - United States of America - enUS
-- English - United Kingdom of Great Britain and Northern Ireland - enGB
-- English - Taiwan - enTW
-- English - (Mainland - China) - enCN

local L = {
    ["DISENCHANT"] = "Disenchant",
    ["LOCKED_ERROR"] = "ITEM IS LOCKED!",
    ["MSG_LOCKED"] = "Item |cffff0000Locked|r.",
    ["MSG_UNLOCKED"] = "Item |cff00ff00Unlocked|r.",
};

local locale = GetLocale()

-- Translation table for all supported WoW clients
if (locale == "esES") or (locale == "esMX") then -- Spanish - Spain and Spanish - Mexico
    L["DISENCHANT"] = "Desencantar";
    L["LOCKED_ERROR"] = "¡EL OBJETO ESTÁ BLOQUEADO!";
    L["MSG_LOCKED"] = "Objeto |cffff0000Bloqueado|r.";
    L["MSG_UNLOCKED"] = "Objeto |cff00ff00Desbloqueado|r.";

elseif (locale == "deDE") then -- German - Germany
    L["DISENCHANT"] = "Entzaubern";
    L["LOCKED_ERROR"] = "GEGENSTAND IST GESPERRT!";
    L["MSG_LOCKED"] = "Gegenstand |cffff0000Gesperrt|r.";
    L["MSG_UNLOCKED"] = "Gegenstand |cff00ff00Entsperrt|r.";

elseif (locale == "frFR") then -- French - France
    L["DISENCHANT"] = "Désenchanter";
    L["LOCKED_ERROR"] = "L'OBJET EST VERROUILLÉ !";
    L["MSG_LOCKED"] = "Objet |cffff0000Verrouillé|r.";
    L["MSG_UNLOCKED"] = "Objet |cff00ff00Déverrouillé|r.";

elseif (locale == "ptBR") or (locale == "ptPT") then -- Portuguese - Brazil and Portuguese - Portugal
    L["DISENCHANT"] = "Desencantar";
    L["LOCKED_ERROR"] = "O ITEM ESTÁ BLOQUEADO!";
    L["MSG_LOCKED"] = "Item |cffff0000Bloqueado|r.";
    L["MSG_UNLOCKED"] = "Item |cff00ff00Desbloqueado|r.";

elseif (locale == "ruRU") then -- Russian - Russia
    L["DISENCHANT"] = "Распыление";
    L["LOCKED_ERROR"] = "ПРЕДМЕТ ЗАБЛОКИРОВАН!";
    L["MSG_LOCKED"] = "Предмет |cffff0000Заблокирован|r.";
    L["MSG_UNLOCKED"] = "Предмет |cff00ff00Разблокирован|r.";

elseif (locale == "zhTW") then -- Chinese - Taiwan
    L["DISENCHANT"] = "分解";
    L["LOCKED_ERROR"] = "物品已鎖定！";
    L["MSG_LOCKED"] = "物品 |cffff0000已鎖定|r。";
    L["MSG_UNLOCKED"] = "物品 |cff00ff00已解鎖|r。";

elseif (locale == "zhCN") then -- Chinese - (Mainland - China)
    L["DISENCHANT"] = "分解";
    L["LOCKED_ERROR"] = "物品已锁定！";
    L["MSG_LOCKED"] = "物品 |cffff0000已锁定|r。";
    L["MSG_UNLOCKED"] = "物品 |cff00ff00已解锁|r。";

elseif (locale == "itIT") then -- Italian - Italy
    L["DISENCHANT"] = "Disincanta";
    L["LOCKED_ERROR"] = "L'OGGETTO È BLOCCATO!";
    L["MSG_LOCKED"] = "Oggetto |cffff0000Bloccato|r.";
    L["MSG_UNLOCKED"] = "Oggetto |cff00ff00Sbloccato|r.";

elseif (locale == "koKR") then -- Korean - Republic of Korea
    L["DISENCHANT"] = "마력 추출";
    L["LOCKED_ERROR"] = "아이템이 잠겨 있습니다!";
    L["MSG_LOCKED"] = "아이템 |cffff0000잠금|r.";
    L["MSG_UNLOCKED"] = "아이템 |cff00ff00잠금 해제|r.";
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
    if (name == L["DISENCHANT"]) then
        isDisenchanting = true
    else
        isDisenchanting = false
    end
    _CastSpell(id, book)
end

-- Hook: Casting via Macros or Scripts
local _CastSpellByName = CastSpellByName
CastSpellByName = function(name, onSelf)
    -- Using plain search (true) to avoid pattern matching issues with special characters
    if (name and string.find(name, L["DISENCHANT"], 1, true)) then
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
    
    if (text == L["DISENCHANT"]) then
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
        UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
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
        UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
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
        UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
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
        UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then SpellStopTargeting() end
        isDisenchanting = false
        return
    end
    _PickupInventoryItem(slot)
end

-------------------------------------------------------------------------------
-- TOGGLE LOCK HANDLER (CTRL + Right-Click)
-------------------------------------------------------------------------------
-- Hooks the bag item buttons to allow locking/unlocking via modifiers
local _ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
ContainerFrameItemButton_OnClick = function(button, ignoreShift)
    -- Trigger on CTRL + Right-Button
    if ( button == "RightButton" and IsControlKeyDown() ) then
        local bag = this:GetParent():GetID()
        local slot = this:GetID()
        local link = GetContainerItemLink(bag, slot)
        local id = GetItemID(link)
        
        if (id) then
            -- Double check table existence before writing
            if (not ItemLockGuard_LockedItems) then ItemLockGuard_LockedItems = {} end
            
            -- Toggle the item ID in the database
            if (ItemLockGuard_LockedItems[id]) then
                ItemLockGuard_LockedItems[id] = nil
                PrintMsg(L["MSG_UNLOCKED"])
            else
                ItemLockGuard_LockedItems[id] = true
                PrintMsg(L["MSG_LOCKED"])
            end
            return -- Block standard right-click action (equipping/using)
        end
    end
    -- Call the original Blizzard function for normal clicks
    _ContainerFrameItemButton_OnClick(button, ignoreShift)
end
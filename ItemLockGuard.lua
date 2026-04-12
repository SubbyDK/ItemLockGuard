-- Global variables for database and state management
ItemLockGuard_LockedItems = ItemLockGuard_LockedItems or {}
local isDisenchanting = false
local logInTime = nil
local AddonName = "ItemLockGuard"

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
-- UTILS
-------------------------------------------------------------------------------
local function PrintMsg(msg)
    if (DEFAULT_CHAT_FRAME) then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF8000[" .. AddonName .. "]|r " .. msg)
    end
end

local function GetItemID(link)
    if (not link) then
        return nil
    end
    local _, _, id = string.find(link, "item:(%d+)")
    return id
end

local function IsVendorActive()
    return (MerchantFrame and MerchantFrame:IsVisible())
end

-------------------------------------------------------------------------------
-- VISUALS
-------------------------------------------------------------------------------
local function UpdateButtonOverlay(button, link)
    if (not button) or (type(button) ~= "table") or (not button.CreateTexture) then
        return
    end
    
    if (not button.lockIcon) then
        button.lockIcon = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.lockIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        button.lockIcon:SetWidth(12)
        button.lockIcon:SetHeight(12)
        button.lockIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    end

    local id = GetItemID(link)
    if (id) and (ItemLockGuard_LockedItems[id]) then
        button.lockIcon:SetVertexColor(1, 0.2, 0.2, 1)
        button.lockIcon:Show()
    else
        button.lockIcon:Hide()
    end
end

local function UpdateAllBagIcons()
    -- 1. Scan pfUI & Blizzard Bank/Bags (-1 til 10)
    for bag = -1, 10 do
        for slot = 1, 40 do
            local pfBtn = getglobal("pfBag"..bag.."item"..slot)
            if (pfBtn) and (pfBtn:IsVisible()) then
                UpdateButtonOverlay(pfBtn, GetContainerItemLink(bag, pfBtn:GetID()))
            end
        end
    end

    -- 2. Blizzard Bags (0-4)
    for bag = 0, 4 do
        local frame = getglobal("ContainerFrame"..(bag+1))
        if (frame) and (frame:IsVisible()) then
            for slot = 1, GetContainerNumSlots(bag) do
                local button = getglobal("ContainerFrame"..(bag+1).."Item"..slot)
                if (button) then
                    UpdateButtonOverlay(button, GetContainerItemLink(bag, button:GetID()))
                end
            end
        end
    end

    -- 3. Character Equipment
    if (CharacterFrame) and (CharacterFrame:IsVisible()) then
        local slots = {
            [1]="HeadSlot", [2]="NeckSlot", [3]="ShoulderSlot", [4]="ShirtSlot", [5]="ChestSlot", 
            [6]="WaistSlot", [7]="LegsSlot", [8]="FeetSlot", [9]="WristSlot", [10]="HandsSlot", 
            [11]="Finger0Slot", [12]="Finger1Slot", [13]="Trinket0Slot", [14]="Trinket1Slot", 
            [15]="BackSlot", [16]="MainHandSlot", [17]="SecondaryHandSlot", [18]="RangedSlot", [19]="TabardSlot"
        }
        for i, slotName in pairs(slots) do
            local charBtn = getglobal("Character"..slotName)
            if (charBtn) then 
                UpdateButtonOverlay(charBtn, GetInventoryItemLink("player", i)) 
            end
        end
    end
end

-------------------------------------------------------------------------------
-- CLICK LOGIC
-------------------------------------------------------------------------------
local function ToggleLockByButton(btn)
    if (not btn) then
        return
    end
    local bag = btn:GetParent():GetID()
    local slot = btn:GetID()
    
    local pName = btn:GetParent():GetName()
    if (pName == "pfBag-1") then
        bag = -1
    end

    local link = GetContainerItemLink(bag, slot)
    local id = GetItemID(link)
    
    if (id) then
        ItemLockGuard_LockedItems[id] = not ItemLockGuard_LockedItems[id]
        if (not ItemLockGuard_LockedItems[id]) then
            ItemLockGuard_LockedItems[id] = nil
        end
        PrintMsg(ItemLockGuard_LockedItems[id] and L["MSG_LOCKED"] or L["MSG_UNLOCKED"])
        UpdateAllBagIcons()
        return true
    end
    return false
end

local function ApplyHooksToButtons()
    for bag = -1, 10 do
        for slot = 1, 40 do
            local btn = getglobal("pfBag"..bag.."item"..slot)
            if (btn) and (not btn.ItemLockHooked) then
                local old_OnClick = btn:GetScript("OnClick")
                btn:SetScript("OnClick", function()
                    if (arg1 == "RightButton") and (IsControlKeyDown()) then
                        ToggleLockByButton(this)
                        return
                    end
                    if (old_OnClick) then
                        old_OnClick()
                    end
                end)
                btn.ItemLockHooked = true
            end
        end
    end
end

-------------------------------------------------------------------------------
-- PROTECTION & HOOKS
-------------------------------------------------------------------------------
local function IsProtected(link)
    if (not link) then
        return false
    end
    
    -- Check if protection is needed (DE active or Vendor open)
    if (isDisenchanting) or (IsVendorActive()) then
        local id = GetItemID(link)
        if (id) and (ItemLockGuard_LockedItems[id]) then
            return true
        end
    end
    return false
end

-- Disenchant hooks
local _CastSpell = CastSpell
CastSpell = function(id, book)
    local name = GetSpellName(id, book)
    if (name == L["DISENCHANT"]) then
        isDisenchanting = true
    end
    _CastSpell(id, book)
end

local _CastSpellByName = CastSpellByName
CastSpellByName = function(name, onSelf)
    if (name) and (string.find(name, L["DISENCHANT"], 1, true)) then
        isDisenchanting = true
    end
    _CastSpellByName(name, onSelf)
end

local _UseAction = UseAction
UseAction = function(slot, check, onSelf)
    GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    GameTooltip:SetAction(slot)
    local text = GameTooltipTextLeft1:GetText()
    GameTooltip:Hide()
    if (text == L["DISENCHANT"]) then
        isDisenchanting = true
    end
    _UseAction(slot, check, onSelf)
end

-- Interaction Hooks
local _UseContainerItem = UseContainerItem
UseContainerItem = function(bag, slot, onSelf)
    if (IsProtected(GetContainerItemLink(bag, slot))) then
        UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then
            SpellStopTargeting()
        end
        isDisenchanting = false
        return 
    end
    _UseContainerItem(bag, slot, onSelf)
end

local _PickupContainerItem = PickupContainerItem
PickupContainerItem = function(bag, slot)
    if (IsProtected(GetContainerItemLink(bag, slot))) then
        UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then
            SpellStopTargeting()
        end
        isDisenchanting = false
        return 
    end
    _PickupContainerItem(bag, slot)
end

local _UseInventoryItem = UseInventoryItem
UseInventoryItem = function(slot)
    if (IsProtected(GetInventoryItemLink("player", slot))) then
        UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then
            SpellStopTargeting()
        end
        isDisenchanting = false
        return
    end
    _UseInventoryItem(slot)
end

local _PickupInventoryItem = PickupInventoryItem
PickupInventoryItem = function(slot)
    if (IsProtected(GetInventoryItemLink("player", slot))) then
        UIErrorsFrame:AddMessage(L["LOCKED_ERROR"], 1.0, 0.1, 0.1, 1.0)
        if (SpellIsTargeting()) then
            SpellStopTargeting()
        end
        isDisenchanting = false
        return
    end
    _PickupInventoryItem(slot)
end

-------------------------------------------------------------------------------
-- INITIALIZATION & EVENT LOOP
-------------------------------------------------------------------------------
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("BAG_UPDATE")
EventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
EventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
EventFrame:RegisterEvent("SPELLCAST_STOP")
EventFrame:RegisterEvent("SPELLCAST_INTERRUPTED")

local loopTimer = 0
EventFrame:SetScript("OnEvent", function()
    if (event == "ADDON_LOADED") and (arg1 == AddonName) then
        if (not ItemLockGuard_LockedItems) or (type(ItemLockGuard_LockedItems) ~= "table") then
            ItemLockGuard_LockedItems = {}
        end
        logInTime = GetTime()
    elseif (event == "SPELLCAST_STOP") or (event == "SPELLCAST_INTERRUPTED") then
        isDisenchanting = false
    end
    UpdateAllBagIcons()
    ApplyHooksToButtons()
end)

EventFrame:SetScript("OnUpdate", function()
    if (logInTime) and (GetTime() > logInTime + 3) then
        UpdateAllBagIcons()
        logInTime = nil
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF8000" .. AddonName .. "|r" .. " by " .. "|cFFFFF468" .. "Subby" .. "|r" .. " is loaded.");
    end

    loopTimer = loopTimer + arg1
    if (loopTimer > 0.5) then
        if (BankFrame and BankFrame:IsVisible()) or (CharacterFrame and CharacterFrame:IsVisible()) then
            UpdateAllBagIcons()
            if (BankFrame:IsVisible()) then
                ApplyHooksToButtons()
            end
        end
        loopTimer = 0
    end
end)

local _ContainerFrameItemButton_OnClick = ContainerFrameItemButton_OnClick
ContainerFrameItemButton_OnClick = function(button, ignoreShift)
    if (button == "RightButton" and IsControlKeyDown()) then
        if (ToggleLockByButton(this)) then
            return
        end
    end
    _ContainerFrameItemButton_OnClick(button, ignoreShift)
end
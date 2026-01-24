-- Top Me Off: Auto-organizing add-on for Turtle WoW

-- Reagent configuration: itemId -> { name, target amount }
-- These are purchased from vendors on MERCHANT_SHOW
local REAGENTS = {
    [17032] = { name = "Rune of Portals", target = 10 },
    [17031] = { name = "Rune of Teleportation", target = 10 },
    [17020] = { name = "Arcane Powder", target = 40 },
}

-- Consumables configuration: itemId -> { name, target amount }
-- These are restocked from bank on BANKFRAME_OPENED
local CONSUMABLES = {
    [13446] = { name = "Major Healing Potion", target = 10 },
    [13444] = { name = "Major Mana Potion", target = 10 },
    [13454] = { name = "Greater Arcane Elixir", target = 10 },
}

-- Extract item ID from an item link
local function GetItemIdFromLink(link)
    if not link then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    if id then return tonumber(id) end
    return nil
end

-- Count how many of an item we have in bags
local function CountItemInBags(itemId)
    local count = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link and GetItemIdFromLink(link) == itemId then
                local _, itemCount = GetContainerItemInfo(bag, slot)
                count = count + (itemCount or 0)
            end
        end
    end
    return count
end

-- Find item in merchant inventory, returns index or nil
local function FindMerchantItem(itemId)
    local numItems = GetMerchantNumItems()
    for i = 1, numItems do
        local link = GetMerchantItemLink(i)
        if link and GetItemIdFromLink(link) == itemId then
            return i
        end
    end
    return nil
end

-- Main auto-buy logic
local function TopOffReagents()
    local playerMoney = GetMoney()

    for itemId, info in pairs(REAGENTS) do
        local current = CountItemInBags(itemId)

        if current < info.target then
            local merchantIndex = FindMerchantItem(itemId)

            if merchantIndex then
                local needed = info.target - current
                local name, _, price, quantity = GetMerchantItemInfo(merchantIndex)

                -- price is per stack, quantity is stack size
                -- Calculate price per single item
                local pricePerItem = price / quantity
                local totalCost = pricePerItem * needed

                if playerMoney >= totalCost then
                    DEFAULT_CHAT_FRAME:AddMessage("Top Me Off: You have " .. current .. " " .. info.name .. ", purchasing " .. needed .. " to top you off.")
                    BuyMerchantItem(merchantIndex, needed)
                    playerMoney = playerMoney - totalCost
                else
                    DEFAULT_CHAT_FRAME:AddMessage("Top Me Off: Can't afford " .. needed .. " " .. info.name)
                end
            end
        end
    end
end

-- Count how many of an item we have in bank
local function CountItemInBank(itemId)
    local count = 0
    -- Main bank bag (BANK_CONTAINER = -1, but we use GetContainerNumSlots which works with bag indices)
    -- In 1.12, bank slots are: bag -1 (main 28-slot bank), bags 5-10 (extra bank bags)

    -- Check main bank (container -1 doesn't work with GetContainerNumSlots, use NUM_BANKGENERIC_SLOTS)
    for slot = 1, 28 do
        local link = GetContainerItemLink(BANK_CONTAINER, slot)
        if link and GetItemIdFromLink(link) == itemId then
            local _, itemCount = GetContainerItemInfo(BANK_CONTAINER, slot)
            count = count + (itemCount or 0)
        end
    end

    -- Check bank bags (indices 5-10)
    for bag = 5, 10 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link and GetItemIdFromLink(link) == itemId then
                local _, itemCount = GetContainerItemInfo(bag, slot)
                count = count + (itemCount or 0)
            end
        end
    end

    return count
end

-- Find first stack of an item in bank, returns bag, slot or nil, nil
local function FindItemInBank(itemId)
    -- Check main bank first
    for slot = 1, 28 do
        local link = GetContainerItemLink(BANK_CONTAINER, slot)
        if link and GetItemIdFromLink(link) == itemId then
            return BANK_CONTAINER, slot
        end
    end

    -- Check bank bags
    for bag = 5, 10 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link and GetItemIdFromLink(link) == itemId then
                return bag, slot
            end
        end
    end

    return nil, nil
end

-- Find first empty slot in player bags, returns bag, slot or nil, nil
local function FindEmptyBagSlot()
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if not link then
                return bag, slot
            end
        end
    end
    return nil, nil
end

-- Find existing partial stack of item in bags (to stack onto), returns bag, slot or nil, nil
local function FindItemStackInBags(itemId)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link and GetItemIdFromLink(link) == itemId then
                return bag, slot
            end
        end
    end
    return nil, nil
end

-- Bank restock logic - move consumables from bank to bags
local function TopOffFromBank()
    for itemId, info in pairs(CONSUMABLES) do
        local current = CountItemInBags(itemId)

        if current < info.target then
            local bankBag, bankSlot = FindItemInBank(itemId)

            if bankBag then
                local _, bankStackCount = GetContainerItemInfo(bankBag, bankSlot)
                local needed = info.target - current
                local moving = math.min(needed, bankStackCount or 0)

                -- Try to find existing stack in bags first, fall back to empty slot
                local destBag, destSlot = FindItemStackInBags(itemId)
                if not destBag then
                    destBag, destSlot = FindEmptyBagSlot()
                end

                if destBag then
                    DEFAULT_CHAT_FRAME:AddMessage("Top Me Off: You have " .. current .. " " .. info.name .. ", moving " .. moving .. " from bank to top you off.")

                    -- Split only the needed amount from bank and place in bags
                    SplitContainerItem(bankBag, bankSlot, moving)
                    PickupContainerItem(destBag, destSlot)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("Top Me Off: No bag space for " .. info.name)
                end
            end
        end
    end
end

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        DEFAULT_CHAT_FRAME:AddMessage("Top Me Off loaded.")
    elseif event == "MERCHANT_SHOW" then
        TopOffReagents()
    elseif event == "BANKFRAME_OPENED" then
        TopOffFromBank()
    end
end)

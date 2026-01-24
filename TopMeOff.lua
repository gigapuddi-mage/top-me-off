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
    -- Healing/Mana
    [13446] = { name = "Major Healing Potion", target = 10 },
    [13444] = { name = "Major Mana Potion", target = 10 },
    [60977] = { name = "Danonzo's Tel'Abim Delight", target = 10 },
    [61675] = { name = "Nordanaar Herbal Tea", target = 10 },
    -- Elixirs
    [13454] = { name = "Greater Arcane Elixir", target = 10 },
    [61224] = { name = "Dreamshard Elixir", target = 10 },
    [55048] = { name = "Elixir of Greater Arcane Power", target = 10 },
    [8423]  = { name = "Cerebral Cortex Compound", target = 10 },
    [61423] = { name = "Dreamtonic", target = 10 },
    [20079] = { name = "Spirit of Zanza", target = 10 },
    [3825]  = { name = "Elixir of Fortitude", target = 10 },
    [20007] = { name = "Mageblood Potion", target = 10 },
    [3386]  = { name = "Elixir of Poison Resistance", target = 10 },
    -- Potions
    [9036]  = { name = "Magic Resistance Potion", target = 10 },
    [3387]  = { name = "Limited Invulnerability Potion", target = 10 },
    [61181] = { name = "Potion of Quickness", target = 10 },
    [12450] = { name = "Juju Flurry", target = 10 },
    -- Protection Potions
    [13461] = { name = "Greater Arcane Protection Potion", target = 10 },
    [13458] = { name = "Greater Nature Protection Potion", target = 10 },
    [13457] = { name = "Greater Fire Protection Potion", target = 10 },
    [13459] = { name = "Greater Shadow Protection Potion", target = 10 },
    [13456] = { name = "Greater Frost Protection Potion", target = 10 },
    -- Wizard Oils
    [23123] = { name = "Blessed Wizard Oil", target = 10 },
    [20749] = { name = "Brilliant Wizard Oil", target = 2 },  -- unstackable (has charges)
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
    -- Get max stack size from item info
    local _, _, _, _, _, _, _, maxStack = GetItemInfo(itemId)
    maxStack = tonumber(maxStack) or 1

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link and GetItemIdFromLink(link) == itemId then
                local _, count = GetContainerItemInfo(bag, slot)
                -- Skip if stack is full
                if (count or 0) < maxStack then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

-- Find all stacks of an item in bank, returns array of {bag, slot, count}
local function FindAllItemStacksInBank(itemId)
    local stacks = {}

    -- Check main bank first
    for slot = 1, 28 do
        local link = GetContainerItemLink(BANK_CONTAINER, slot)
        if link and GetItemIdFromLink(link) == itemId then
            local _, count = GetContainerItemInfo(BANK_CONTAINER, slot)
            table.insert(stacks, { bag = BANK_CONTAINER, slot = slot, count = count or 0 })
        end
    end

    -- Check bank bags
    for bag = 5, 10 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link and GetItemIdFromLink(link) == itemId then
                local _, count = GetContainerItemInfo(bag, slot)
                table.insert(stacks, { bag = bag, slot = slot, count = count or 0 })
            end
        end
    end

    return stacks
end

-- Bank restock logic - move consumables from bank to bags
local function TopOffFromBank()
    for itemId, info in pairs(CONSUMABLES) do
        local current = CountItemInBags(itemId)

        if current < info.target then
            local needed = info.target - current
            local totalMoved = 0
            local stacks = FindAllItemStacksInBank(itemId)

            for _, stack in ipairs(stacks) do
                if totalMoved >= needed then break end

                local stillNeeded = needed - totalMoved
                local moving = math.min(stillNeeded, stack.count)

                -- Try to find existing stack in bags first, fall back to empty slot
                local destBag, destSlot = FindItemStackInBags(itemId)
                if not destBag then
                    destBag, destSlot = FindEmptyBagSlot()
                end

                if destBag then
                    DEFAULT_CHAT_FRAME:AddMessage("Top Me Off: You have " .. (current + totalMoved) .. " " .. info.name .. ", moving " .. moving .. " from bank to top you off.")

                    -- Split only the needed amount from bank and place in bags
                    SplitContainerItem(stack.bag, stack.slot, moving)
                    PickupContainerItem(destBag, destSlot)

                    totalMoved = totalMoved + moving
                else
                    DEFAULT_CHAT_FRAME:AddMessage("Top Me Off: No bag space for " .. info.name)
                    break
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

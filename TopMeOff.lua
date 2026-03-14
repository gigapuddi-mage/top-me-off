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
    [60977] = { name = "Danonzo's Tel'Abim Delight", target = 20 },
    [61675] = { name = "Nordanaar Herbal Tea", target = 20 },
    -- Elixirs
    [13454] = { name = "Greater Arcane Elixir", target = 10 },
    [61224] = { name = "Dreamshard Elixir", target = 10 },
    [55048] = { name = "Elixir of Greater Arcane Power", target = 10 },
    [8423]  = { name = "Cerebral Cortex Compound", target = 20 },
    [61423] = { name = "Dreamtonic", target = 10 },
    [20079] = { name = "Spirit of Zanza", target = 20 },
    [3825]  = { name = "Elixir of Fortitude", target = 10 },
    [20007] = { name = "Mageblood Potion", target = 10 },
    [3386]  = { name = "Elixir of Poison Resistance", target = 10 },
    -- Potions
    [9036]  = { name = "Magic Resistance Potion", target = 10 },
    [3387]  = { name = "Limited Invulnerability Potion", target = 10 },
    [61181] = { name = "Potion of Quickness", target = 10 },
    [12450] = { name = "Juju Flurry", target = 20 },
    -- Protection Potions
    [13461] = { name = "Greater Arcane Protection Potion", target = 10 },
    [13458] = { name = "Greater Nature Protection Potion", target = 10 },
    [13457] = { name = "Greater Fire Protection Potion", target = 10 },
    [13459] = { name = "Greater Shadow Protection Potion", target = 10 },
    [13456] = { name = "Greater Frost Protection Potion", target = 10 },
    -- Other
    [14530] = { name = "Heavy Runecloth Bandage", target = 20 },
    [17056] = { name = "Light Feather", target = 20 },
    [6657]  = { name = "Savory Deviate Delight", target = 20 },
    -- Wizard Oils
    [23123] = { name = "Blessed Wizard Oil", target = 20 },
    [20749] = { name = "Brilliant Wizard Oil", target = 1 },  -- unstackable (has charges)
}

-- Ordered consumable display list (for PrintBankSummary)
local CONSUMABLE_CATEGORIES = {
    { header = "Healing/Mana", items = { 13446, 13444, 60977, 61675 } },
    { header = "Elixirs", items = { 13454, 61224, 55048, 8423, 61423, 20079, 3825, 20007, 3386 } },
    { header = "Potions", items = { 9036, 3387, 61181, 12450 } },
    { header = "Protection Potions", items = { 13461, 13458, 13457, 13459, 13456 } },
    { header = "Other", items = { 14530, 17056, 6657 } },
    { header = "Wizard Oils", items = { 23123, 20749 } },
}

-- Settings
local TMO_VERBOSE = false

-- Colors (hex format for AddMessage)
local COLOR_SUCCESS = "|cff00ff00"  -- Green
local COLOR_WARNING = "|cffffff00"  -- Yellow
local COLOR_ERROR = "|cffff0000"    -- Red
local COLOR_INFO = "|cffffffff"     -- White
local COLOR_RESET = "|r"

-- Messaging helpers
local function TMO_Print(msg, color)
    color = color or COLOR_INFO
    DEFAULT_CHAT_FRAME:AddMessage(color .. "Top Me Off: " .. msg .. COLOR_RESET)
end

local function TMO_PrintVerbose(msg, color)
    if TMO_VERBOSE then
        TMO_Print(msg, color)
    end
end

-- Format money as "Xg Ys Zc"
local function FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local cop = math.mod(copper, 100)
    if gold > 0 then
        return gold .. "g " .. silver .. "s " .. cop .. "c"
    elseif silver > 0 then
        return silver .. "s " .. cop .. "c"
    else
        return cop .. "c"
    end
end

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
    local totalSpent = 0
    local itemsPurchased = 0
    local cantAfford = {}

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
                    TMO_PrintVerbose("Purchasing " .. needed .. " " .. info.name, COLOR_SUCCESS)
                    BuyMerchantItem(merchantIndex, needed)
                    playerMoney = playerMoney - totalCost
                    totalSpent = totalSpent + totalCost
                    itemsPurchased = itemsPurchased + 1
                else
                    table.insert(cantAfford, info.name)
                end
            end
        end
    end

    -- Summary
    if itemsPurchased > 0 then
        TMO_Print("Purchased " .. itemsPurchased .. " reagent type(s) for " .. FormatMoney(totalSpent), COLOR_SUCCESS)
    else
        TMO_PrintVerbose("Reagents already stocked", COLOR_INFO)
    end

    -- Errors
    for _, name in ipairs(cantAfford) do
        TMO_Print("Can't afford: " .. name, COLOR_ERROR)
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
    -- Get max stack size from item info (default to 20 if item not cached)
    local _, _, _, _, _, _, _, maxStack = GetItemInfo(itemId)
    maxStack = tonumber(maxStack) or 20

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

-- Print a color-coded summary of all consumables when bank opens
local function PrintBankSummary()
    DEFAULT_CHAT_FRAME:AddMessage(COLOR_INFO .. "--- Top Me Off ---" .. COLOR_RESET)

    for _, category in ipairs(CONSUMABLE_CATEGORIES) do
        DEFAULT_CHAT_FRAME:AddMessage(COLOR_INFO .. "  " .. category.header .. COLOR_RESET)

        for _, itemId in ipairs(category.items) do
            local info = CONSUMABLES[itemId]
            if info then
                local bagCount = CountItemInBags(itemId)
                local bankCount = CountItemInBank(itemId)
                local color
                if bagCount >= info.target then
                    color = COLOR_SUCCESS
                elseif bankCount > 0 then
                    color = COLOR_WARNING
                else
                    color = COLOR_ERROR
                end
                DEFAULT_CHAT_FRAME:AddMessage(color .. "    " .. info.name .. ": " .. bagCount .. "/" .. info.target .. " bags | " .. bankCount .. " bank" .. COLOR_RESET)
            end
        end
    end
end

-- Bank restock logic - move consumables from bank to bags
local function TopOffFromBank()
    local itemsRestocked = 0
    local bankShortages = {}
    local noSpace = {}

    for itemId, info in pairs(CONSUMABLES) do
        local current = CountItemInBags(itemId)

        if current < info.target then
            local needed = info.target - current
            local bankCount = CountItemInBank(itemId)

            if bankCount == 0 then
                table.insert(bankShortages, { name = info.name, inBank = 0, needed = needed })
            else
                if bankCount < needed then
                    table.insert(bankShortages, { name = info.name, inBank = bankCount, needed = needed })
                end

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
                        TMO_PrintVerbose("Moving " .. moving .. " " .. info.name .. " from bank", COLOR_SUCCESS)

                        -- Split only the needed amount from bank and place in bags
                        SplitContainerItem(stack.bag, stack.slot, moving)
                        PickupContainerItem(destBag, destSlot)

                        totalMoved = totalMoved + moving
                    else
                        table.insert(noSpace, info.name)
                        break
                    end
                end

                if totalMoved > 0 then
                    itemsRestocked = itemsRestocked + 1
                end
            end
        end
    end

    -- Summary
    if itemsRestocked > 0 then
        TMO_Print("Restocked " .. itemsRestocked .. " item type(s) from bank", COLOR_SUCCESS)
    else
        TMO_PrintVerbose("Already fully stocked", COLOR_INFO)
    end

    -- Bank shortages
    for _, shortage in ipairs(bankShortages) do
        if shortage.inBank == 0 then
            TMO_Print("Out of stock: " .. shortage.name, COLOR_WARNING)
        else
            TMO_Print("Bank low: " .. shortage.name .. " (" .. shortage.inBank .. " in bank, need " .. shortage.needed .. ")", COLOR_WARNING)
        end
    end

    -- No space errors
    for _, name in ipairs(noSpace) do
        TMO_Print("No bag space: " .. name, COLOR_ERROR)
    end
end

-- Slash commands
SLASH_TOPMEOFF1 = "/topmeoff"
SLASH_TOPMEOFF2 = "/tmo"
SlashCmdList["TOPMEOFF"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "verbose" then
        TMO_VERBOSE = not TMO_VERBOSE
        TMO_Print("Verbose mode: " .. (TMO_VERBOSE and "ON" or "OFF"), COLOR_INFO)
    elseif msg == "status" then
        TMO_Print("--- Reagent Status ---", COLOR_INFO)
        for itemId, info in pairs(REAGENTS) do
            local current = CountItemInBags(itemId)
            local color = current >= info.target and COLOR_SUCCESS or COLOR_WARNING
            TMO_Print(info.name .. ": " .. current .. "/" .. info.target, color)
        end

        TMO_Print("--- Consumable Status ---", COLOR_INFO)
        for itemId, info in pairs(CONSUMABLES) do
            local current = CountItemInBags(itemId)
            local bankCount = CountItemInBank(itemId)
            local color = current >= info.target and COLOR_SUCCESS or COLOR_WARNING
            TMO_Print(info.name .. ": " .. current .. "/" .. info.target .. " (bank: " .. bankCount .. ")", color)
        end
    else
        TMO_Print("Commands: /topmeoff status | /topmeoff verbose", COLOR_INFO)
    end
end

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        TMO_Print("Loaded. Type /topmeoff for commands.", COLOR_INFO)
    elseif event == "MERCHANT_SHOW" then
        TopOffReagents()
    elseif event == "BANKFRAME_OPENED" then
        PrintBankSummary()
        TopOffFromBank()
    end
end)

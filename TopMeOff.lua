-- Top Me Off: Auto-organizing add-on for Turtle WoW

-- Reagent configuration: itemId -> { name, target amount }
local REAGENTS = {
    [17032] = { name = "Rune of Portals", target = 10 },
    [17031] = { name = "Rune of Teleportation", target = 10 },
    [17020] = { name = "Arcane Powder", target = 20 },
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
                    BuyMerchantItem(merchantIndex, needed)
                    playerMoney = playerMoney - totalCost
                    DEFAULT_CHAT_FRAME:AddMessage("Top Me Off: Bought " .. needed .. " " .. info.name)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("Top Me Off: Can't afford " .. needed .. " " .. info.name)
                end
            end
        end
    end
end

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        DEFAULT_CHAT_FRAME:AddMessage("Top Me Off loaded.")
    elseif event == "MERCHANT_SHOW" then
        TopOffReagents()
    end
end)

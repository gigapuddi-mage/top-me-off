-- Top Me Off: Auto-organizing add-on for Turtle WoW

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        DEFAULT_CHAT_FRAME:AddMessage("Top Me Off loaded.")
    end
end)

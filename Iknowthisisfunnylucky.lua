local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/phntmhub/Phantom-hub/refs/heads/main/ObsidianUi.lua"))()

local Window = Library:CreateWindow({
    Title = "Be a Lucky Block",
    Footer = "by Phantom Hub",
    Center = true,
    AutoShow = true,
    ToggleKeybind = Enum.KeyCode.LeftControl
})

local MainTab       = Window:AddTab("Main",     "box")
local UpgradesTab   = Window:AddTab("Upgrades", "gauge")
local BrainrotsTab  = Window:AddTab("Brainrots","bot")
local StatsTab      = Window:AddTab("Stats",    "chart-column")
local SettingsTab   = Window:AddTab("Settings", "settings")

local MainLeft      = MainTab:AddLeftGroupbox("Automation")
local MainRight     = MainTab:AddRightGroupbox("Lucky Block")
local UpgradesLeft  = UpgradesTab:AddLeftGroupbox("Speed Upgrades")
local BrainrotsLeft = BrainrotsTab:AddLeftGroupbox("Boss Tools")
local BrainrotsRight= BrainrotsTab:AddRightGroupbox("Farming")
local StatsLeft     = StatsTab:AddLeftGroupbox("Speeds & Stats")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local knitPath = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.7.0"):WaitForChild("knit"):WaitForChild("Services")

local claimGift = knitPath:WaitForChild("PlaytimeRewardService"):WaitForChild("RF"):WaitForChild("ClaimGift")
local rebirth = knitPath:WaitForChild("RebirthService"):WaitForChild("RF"):WaitForChild("Rebirth")
local claimPass = knitPath:WaitForChild("SeasonPassService"):WaitForChild("RF"):WaitForChild("ClaimPassReward")
local redeem = knitPath:WaitForChild("CodesService"):WaitForChild("RF"):WaitForChild("RedeemCode")
local buySkin = knitPath:WaitForChild("SkinService"):WaitForChild("RF"):WaitForChild("BuySkin")
local upgrade = knitPath:WaitForChild("UpgradesService"):WaitForChild("RF"):WaitForChild("Upgrade")

local autoClaiming = false
MainLeft:AddToggle("ACPR", {
    Text = "Auto Claim Playtime Rewards",
    Default = false,
    Callback = function(state)
        autoClaiming = state
        if not state then return end
        task.spawn(function()
            while autoClaiming do
                for reward = 1, 12 do
                    if not autoClaiming then break end
                    pcall(function() claimGift:InvokeServer(reward) end)
                    task.wait(0.25)
                end
                task.wait(1)
            end
        end)
    end
})

local rebirthRunning = false
MainLeft:AddToggle("AR", {
    Text = "Auto Rebirth",
    Default = false,
    Callback = function(state)
        rebirthRunning = state
        if not state then return end
        task.spawn(function()
            while rebirthRunning do
                pcall(function() rebirth:InvokeServer() end)
                task.wait(1)
            end
        end)
    end
})

local eventPassRunning = false
MainLeft:AddToggle("ACEPR", {
    Text = "Auto Claim Event Pass Rewards",
    Default = false,
    Callback = function(state)
        eventPassRunning = state
        if not state then return end
        task.spawn(function()
            while eventPassRunning do
                local gui = player:WaitForChild("PlayerGui"):WaitForChild("Windows"):WaitForChild("Event"):WaitForChild("Frame"):WaitForChild("Frame"):WaitForChild("Windows"):WaitForChild("Pass"):WaitForChild("Main"):WaitForChild("ScrollingFrame")
                for i = 1, 10 do
                    if not eventPassRunning then break end
                    local item = gui:FindFirstChild(tostring(i))
                    if item and item:FindFirstChild("Frame") and item.Frame:FindFirstChild("Free") then
                        local free = item.Frame.Free
                        local locked = free:FindFirstChild("Locked")
                        local claimed = free:FindFirstChild("Claimed")
                        while eventPassRunning and locked and locked.Visible do task.wait(0.2) end
                        if eventPassRunning and claimed and claimed.Visible then continue end
                        if eventPassRunning and locked and not locked.Visible then
                            pcall(function() claimPass:InvokeServer("Free", i) end)
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end
})

MainLeft:AddButton({
    Text = "Redeem All Codes",
    Func = function()
        local codes = {"release"}
        for _, code in ipairs(codes) do
            pcall(function() redeem:InvokeServer(code) end)
            task.wait(1)
        end
    end
})

local suffix = {K=1e3,M=1e6,B=1e9,T=1e12,Qa=1e15,Qi=1e18,Sx=1e21,Sp=1e24,Oc=1e27,No=1e30,Dc=1e33}
local function parseCash(text)
    text = text:gsub("%$",""):gsub(",",""):gsub("%s+","")
    local num = tonumber(text:match("[%d%.]+"))
    local suf = text:match("%a+")
    if not num then return 0 end
    if suf and suffix[suf] then return num * suffix[suf] end
    return num
end

local skins = {"prestige_mogging_luckyblock","mogging_luckyblock","colossus_luckyblock","inferno_luckyblock","divine_luckyblock","spirit_luckyblock","cyborg_luckyblock","void_luckyblock","gliched_luckyblock","lava_luckyblock","freezy_luckyblock","fairy_luckyblock"}
local ablRunning = false
MainRight:AddToggle("ABL", {
    Text = "Auto Buy Best Luckyblock",
    Default = false,
    Callback = function(state)
        ablRunning = state
        if not state then return end
        task.spawn(function()
            while ablRunning do
                local scroll = player.PlayerGui:FindFirstChild("Windows") and player.PlayerGui.Windows:FindFirstChild("PickaxeShop") and player.PlayerGui.Windows.PickaxeShop:FindFirstChild("ShopContainer") and player.PlayerGui.Windows.PickaxeShop.ShopContainer:FindFirstChild("ScrollingFrame")
                if scroll then
                    local cash = player.leaderstats.Cash.Value
                    local bestSkin, bestPrice = nil, 0
                    for i = 1, #skins do
                        local item = scroll:FindFirstChild(skins[i])
                        local buyBtn = item and item:FindFirstChild("Main") and item.Main:FindFirstChild("Buy") and item.Main.Buy:FindFirstChild("BuyButton")
                        if buyBtn and buyBtn.Visible then
                            local price = parseCash(buyBtn.Cash.Text)
                            if cash >= price and price > bestPrice then
                                bestSkin, bestPrice = skins[i], price
                            end
                        end
                    end
                    if bestSkin then pcall(function() buySkin:InvokeServer(bestSkin) end) end
                end
                task.wait(0.5)
            end
        end)
    end
})

MainRight:AddButton({
    Text = "Sell Held Brainrot",
    Func = function()
        local tool = (player.Character or player.CharacterAdded:Wait()):FindFirstChildOfClass("Tool")
        if not tool or not tool:GetAttribute("EntityId") then return end
        knitPath.InventoryService.RF.SellBrainrot:InvokeServer(tool:GetAttribute("EntityId"))
    end
})

local storedBossParts = {}
local bossFolder = workspace:WaitForChild("BossTouchDetectors")

BrainrotsLeft:AddToggle("RBTD", {
    Text = "Remove Bad Boss Touch Detectors",
    Default = false,
    Tooltip = "Disables obstacles but keeps the Final Boss (base14) active",
    Callback = function(state)
        if state then
            for _, obj in ipairs(bossFolder:GetChildren()) do
                if obj.Name ~= "base14" and obj:IsA("BasePart") then
                    storedBossParts[obj.Name] = obj
                    obj.Parent = nil
                end
            end
        else
            for name, obj in pairs(storedBossParts) do
                if obj then obj.Parent = bossFolder end
            end
            storedBossParts = {}
        end
    end
})

BrainrotsLeft:AddButton({
    Text = "Teleport to End",
    Func = function()
        local target = workspace:WaitForChild("CollectZones"):WaitForChild("base14")
        local ownedModel = nil
        
        for _, obj in ipairs(workspace.RunningModels:GetChildren()) do
            if obj:GetAttribute("OwnerId") == player.UserId then 
                ownedModel = obj 
                break 
            end
        end

        if ownedModel then
            if ownedModel.PrimaryPart then 
                ownedModel:SetPrimaryPartCFrame(target.CFrame) 
            else 
                local p = ownedModel:FindFirstChildWhichIsA("BasePart") 
                if p then p.CFrame = target.CFrame end 
            end

            task.wait(0.7)

            if ownedModel and ownedModel.Parent == workspace.RunningModels then
                local dropPos = target.CFrame * CFrame.new(0, -5, 0)
                if ownedModel.PrimaryPart then 
                    ownedModel:SetPrimaryPartCFrame(dropPos)
                else 
                    local p = ownedModel:FindFirstChildWhichIsA("BasePart") 
                    if p then p.CFrame = dropPos end 
                end
            end
        end
    end
})

local autoFarmRunning = false
BrainrotsRight:AddToggle("AutoFarmToggle", {
    Text = "Auto Farm Best Brainrots",
    Default = false,
    Callback = function(state)
        autoFarmRunning = state
        if not state then return end
        task.spawn(function()
            while autoFarmRunning do
                local character = player.Character or player.CharacterAdded:Wait()
                local root = character:WaitForChild("HumanoidRootPart")
                local humanoid = character:WaitForChild("Humanoid")
                local target = workspace.CollectZones.base14
                
                root.CFrame = CFrame.new(715, 39, -2122)
                task.wait(0.3)
                humanoid:MoveTo(Vector3.new(710, 39, -2122))
                
                local ownedModel = nil
                repeat
                    task.wait(0.2)
                    for _, obj in ipairs(workspace.RunningModels:GetChildren()) do
                        if obj:GetAttribute("OwnerId") == player.UserId then ownedModel = obj break end
                    end
                until ownedModel ~= nil or not autoFarmRunning
                
                if not autoFarmRunning then break end
                
                if ownedModel.PrimaryPart then ownedModel:SetPrimaryPartCFrame(target.CFrame)
                else local p = ownedModel:FindFirstChildWhichIsA("BasePart") if p then p.CFrame = target.CFrame end end
                
                task.wait(0.7)
                
                if ownedModel and ownedModel.Parent == workspace.RunningModels then
                    local dropPos = target.CFrame * CFrame.new(0, -5, 0)
                    if ownedModel.PrimaryPart then ownedModel:SetPrimaryPartCFrame(dropPos)
                    else local p = ownedModel:FindFirstChildWhichIsA("BasePart") if p then p.CFrame = dropPos end end
                end
                
                repeat task.wait(0.3) until not autoFarmRunning or (not ownedModel or ownedModel.Parent ~= workspace.RunningModels)
                if not autoFarmRunning then break end
                
                local oldChar = player.Character
                repeat task.wait(0.2) until not autoFarmRunning or (player.Character ~= oldChar and player.Character ~= nil)
                task.wait(0.4)
                
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    player.Character.HumanoidRootPart.CFrame = CFrame.new(737, 39, -2118)
                end
                task.wait(2.1)
            end
        end)
    end
})

local upgradeAmount, upgradeDelay, upgradeRunning = 1, 0.5, false
UpgradesLeft:AddInput("IMS", {Text = "Speed Amount", Default = "1", Numeric = true, Callback = function(v) upgradeAmount = tonumber(v) or 1 end})
UpgradesLeft:AddSlider("SMS", {Text = "Upgrade Interval", Default = 1, Min = 0, Max = 5, Rounding = 1, Callback = function(v) upgradeDelay = v end})
UpgradesLeft:AddToggle("AMS", {
    Text = "Auto Upgrade Speed",
    Default = false,
    Callback = function(state)
        upgradeRunning = state
        if not state then return end
        task.spawn(function()
            while upgradeRunning do
                pcall(function() upgrade:InvokeServer("MovementSpeed", upgradeAmount) end)
                task.wait(upgradeDelay)
            end
        end)
    end
})

local speedRunning, sliderValue, originalSpeed, currentModel = false, 1000, nil, nil
local playerSpeedRunning, playerSpeedValue = false, 16

local function getMyModel()
    for _, model in ipairs(workspace.RunningModels:GetChildren()) do
        if model:GetAttribute("OwnerId") == player.UserId then return model end
    end
    return nil
end

StatsLeft:AddToggle("MovementToggle", {
    Text = "Enable Lucky Block Speed",
    Default = false,
    Callback = function(state)
        speedRunning = state
        if not state then
            local m = getMyModel()
            if m and originalSpeed then m:SetAttribute("MovementSpeed", originalSpeed) end
            originalSpeed, currentModel = nil, nil
        end
    end
})
StatsLeft:AddSlider("MovementSlider", {Text = "Block Speed", Default = 1000, Min = 50, Max = 3000, Rounding = 0, Callback = function(v) sliderValue = v end})

StatsLeft:AddToggle("PlayerSpeedToggle", {
    Text = "Enable Custom WalkSpeed",
    Default = false,
    Callback = function(state)
        playerSpeedRunning = state
        if not state then
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = 16 end
        end
    end
})

-- ✅ Updated: Max speed raised to 100,000
StatsLeft:AddSlider("PlayerSpeedSlider", {Text = "Player Speed", Default = 16, Min = 16, Max = 100000, Rounding = 0, Callback = function(v) playerSpeedValue = v end})

task.spawn(function()
    while true do
        if speedRunning then
            local model = getMyModel()
            if model then
                if model ~= currentModel then 
                    currentModel = model 
                    originalSpeed = model:GetAttribute("MovementSpeed") 
                end
                model:SetAttribute("MovementSpeed", sliderValue)
            end
        end
        
        if playerSpeedRunning then
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            if hum and hum.WalkSpeed ~= playerSpeedValue then
                hum.WalkSpeed = playerSpeedValue
            end
        end
        
        task.wait(0.1)
    end
end)

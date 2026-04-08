loadstring(game:HttpGet('https://raw.githubusercontent.com/phntmhub/Phantom-hub/refs/heads/main/ObsidianUi.lua'))()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/phntmhub/Phantom-hub/refs/heads/main/ObsidianUi.lua"))()

local Window = Library:CreateWindow({
    Title = "Bite By Night Executor" .. (isMobile and " [Mobile]" or ""),
    Footer = "by Phantom Hub",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ToggleKeybind = Enum.KeyCode.RightControl,
    EnableSidebarResize = true,
    NotifySide = "Right",
    ShowCustomCursor = not isMobile,
    UnlockMouseWhileOpen = not isMobile,
})

Library:SetStyle("Curved")
Library:SetTheme("Dark")
Library:SetColors({
    Background = Color3.fromRGB(12, 12, 18),
    Main = Color3.fromRGB(22, 22, 32),
    Tab = Color3.fromRGB(22, 22, 32),
    Accent = Color3.fromRGB(0, 180, 220),
    Slider = Color3.fromRGB(0, 180, 220),
    Outline = Color3.fromRGB(35, 35, 50),
    Font = Color3.fromRGB(230, 230, 250),
})

local menuOpen = true
local toggleButton

if isMobile then
    toggleButton = Instance.new("ScreenGui")
    toggleButton.Name = "PhantomHubToggle"
    toggleButton.ResetOnSpawn = false
    toggleButton.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toggleButton.Parent = player.PlayerGui
    
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ToggleButton"
    buttonFrame.Size = UDim2.new(0, 60, 0, 60)
    buttonFrame.Position = UDim2.new(0, 10, 0.5, -30)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
    buttonFrame.BackgroundTransparency = 0.2
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Active = true
    buttonFrame.Parent = toggleButton
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = buttonFrame
    
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, 0, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "PH"
    icon.TextColor3 = Color3.fromRGB(255, 255, 255)
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.Parent = buttonFrame
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local hasMoved = false
    
    buttonFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            hasMoved = false
            dragStart = input.Position
            startPos = buttonFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 10 then hasMoved = true end
            buttonFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    buttonFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and not hasMoved then
            menuOpen = not menuOpen
            if menuOpen then Window:Restore() icon.Text = "PH" else Window:Minimize() icon.Text = "+" end
        end
    end)
end

local TabKiller = Window:AddTab("Killer", "skull", "Killer Abilities")
local TabAutoFarm = Window:AddTab("Auto Farm", "wrench", "Automation Features")
local TabNavigation = Window:AddTab("Navigation", "globe", "Teleport & Movement")
local TabESP = Window:AddTab("ESP", "eye", "Object Highlighting")
local TabPlayer = Window:AddTab("Player", "zap", "Player Modifications")
local TabSettings = Window:AddTab("Settings", "settings", "UI Customization")

local KillerGroup1 = TabKiller:AddLeftGroupbox("Combat")
local KillerGroup2 = TabKiller:AddRightGroupbox("Targeting")

local AutoGroup1 = TabAutoFarm:AddLeftGroupbox("Auto Tasks")
local AutoGroup2 = TabAutoFarm:AddRightGroupbox("Auto Combat")

local NavGroup1 = TabNavigation:AddLeftGroupbox("Locations")
local NavGroup2 = TabNavigation:AddRightGroupbox("Options")

local ESPGroup1 = TabESP:AddLeftGroupbox("ESP Features")
local ESPGroup2 = TabESP:AddRightGroupbox("ESP Settings")

local PlayerGroup1 = TabPlayer:AddLeftGroupbox("Movement")
local PlayerGroup2 = TabPlayer:AddRightGroupbox("Abilities")

local SettingsGroup1 = TabSettings:AddLeftGroupbox("Colors & Style")
local SettingsGroup2 = TabSettings:AddRightGroupbox("Window & Display")

local stealthLevel = 0.5
local generatorIndex = 1
local targetName = ""
local targetMode = "Closest"
local savedAccentColor = Color3.fromRGB(0, 180, 220)
local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMPPOWER = 50
local tpKill = false
local tpKillConn = nil
local tpKillCooldown = {}
local lastTpTime = 0
local tpCooldownTime = 3

local function setAccentColor(color)
    savedAccentColor = color
    Library:SetColors({ Accent = color, Slider = color })
end

local function applyThemeKeepAccent(themeName)
    Library:SetTheme(themeName)
    Library:SetColors({ Accent = savedAccentColor, Slider = savedAccentColor })
end

local function getHumanoid()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function tweenTeleport(targetCFrame, duration)
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    return tween
end

local function getGeneratorPart(genModel)
    if genModel.PrimaryPart and genModel.PrimaryPart:IsA("BasePart") then
        return genModel.PrimaryPart
    end
    local part = genModel:FindFirstChildWhichIsA("BasePart")
    if part then return part end
    for _, obj in ipairs(genModel:GetDescendants()) do
        if obj:IsA("BasePart") then return obj end
    end
    return nil
end

local function teleportToGradual(part)
    if not part then return end
    local pos = part.Position + (part.CFrame.LookVector * math.random(3, 7))
    pos = pos + Vector3.new(math.random(-2,2), math.random(-1,1), math.random(-2,2))
    local duration = math.random(0.3,0.8) * (1 + (1 - stealthLevel) * 2)
    tweenTeleport(CFrame.new(pos), duration)
end

local function getOrderedGenerators()
    local map = Workspace:FindFirstChild("MAPS") and Workspace.MAPS:FindFirstChild("GAME MAP")
    if not map then return {} end
    local folder = map:FindFirstChild("Generators")
    if not folder then return {} end
    local models = {}
    for _, v in ipairs(folder:GetChildren()) do
        if v:IsA("Model") then table.insert(models, v) end
    end
    table.sort(models, function(a,b)
        local ao = a:GetAttribute("Order") or 0
        local bo = b:GetAttribute("Order") or 0
        return ao < bo
    end)
    return models
end

local function getNearestSurvivor()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local alive = Workspace:FindFirstChild("PLAYERS") and Workspace.PLAYERS:FindFirstChild("ALIVE")
    if not alive then return nil end
    local closest, closestDist = nil, math.huge
    for _, model in ipairs(alive:GetChildren()) do
        if model:IsA("Model") then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (root.Position - hrp.Position).Magnitude
                if dist < closestDist then closestDist = dist closest = model end
            end
        end
    end
    return closest
end

local function getSurvivorByName(name)
    local alive = Workspace:FindFirstChild("PLAYERS") and Workspace.PLAYERS:FindFirstChild("ALIVE")
    if alive then return alive:FindFirstChild(name) end
    return nil
end

KillerGroup1:AddToggle("TeleportKill", { Text="Teleport Kill", Default=false, Callback=function(v)
    tpKill = v
    if tpKillConn then tpKillConn:Disconnect() tpKillConn = nil end
    if v then
        lastTpTime = 0
        tpKillConn = RunService.Heartbeat:Connect(function()
            if not tpKill then return end
            if tick() - lastTpTime < tpCooldownTime then return end
            local char = player.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local targetChar
            if targetMode == "Closest" then
                targetChar = getNearestSurvivor()
            elseif targetMode == "Specific" and targetName ~= "" then
                targetChar = getSurvivorByName(targetName)
            end
            if targetChar then
                local hrp = targetChar:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if tpKillCooldown[targetChar] and tick() - tpKillCooldown[targetChar] < 5 then return end
                    local offset = CFrame.new(math.random(-2,2), 0, math.random(2,4))
                    local duration = math.random(0.3, 1.0) * (1 + (1 - stealthLevel) * 2)
                    tweenTeleport(hrp.CFrame * offset, duration)
                    lastTpTime = tick()
                    task.delay(duration + 0.2, function()
                        if not tpKill then return end
                        local killEvent = ReplicatedStorage:FindFirstChild("KillEvent")
                        if killEvent then
                            pcall(function()
                                killEvent:FireServer(targetChar)
                                tpKillCooldown[targetChar] = tick()
                            end)
                        end
                    end)
                end
            end
        end)
        Library:Notify({ Title="Teleport Kill", Content="Enabled", Time=2 })
    else
        tpKillCooldown = {}
        Library:Notify({ Title="Teleport Kill", Content="Disabled", Time=2 })
    end
end })

KillerGroup2:AddInput("TargetName", { Text="Target Player", Placeholder="Enter username", Finished=true, Callback=function(v) targetName = v end })
KillerGroup2:AddDropdown("TargetMode", { Text="Target Mode", Values={"Closest","Specific"}, Default="Closest", Callback=function(v) targetMode = v end })
KillerGroup1:AddSlider("TpCooldown", { Text="Teleport Cooldown", Default=3, Min=1, Max=10, Suffix=" sec", Callback=function(v) tpCooldownTime = v end })

NavGroup1:AddButton({ Text = "Teleport to Generator", Func = function()
    local gens = getOrderedGenerators()
    if #gens == 0 then
        Library:Notify({ Title = "Error", Content = "No generators found", Time = 2 })
        return
    end
    if generatorIndex > #gens then generatorIndex = 1 end
    local gen = gens[generatorIndex]
    local part = getGeneratorPart(gen)
    if not part then
        Library:Notify({ Title = "Error", Content = "Generator has no valid part", Time = 2 })
        return
    end
    teleportToGradual(part)
    Library:Notify({ Title = "Navigation", Content = "Teleported to Generator #" .. generatorIndex, Time = 2 })
    generatorIndex = generatorIndex + 1
    if generatorIndex > #gens then generatorIndex = 1 end
end })

NavGroup1:AddButton({ Text = "Teleport to Safe Zone", Func = function()
    local targetPos = Vector3.new(443,72,81) + Vector3.new(math.random(-3,3),0,math.random(-3,3))
    local duration = math.random(0.3,0.8) * (1 + (1 - stealthLevel) * 2)
    tweenTeleport(CFrame.new(targetPos), duration)
    Library:Notify({ Title = "Navigation", Content="Teleported to safe zone", Time=2 })
end })

NavGroup2:AddSlider("StealthTeleport", { Text="Stealth Level", Default=50, Min=0, Max=100, Suffix="%", Callback=function(v) stealthLevel=v/100 end })

local gameESP = {}
local espConnections = { Survivor={}, Killer={}, Generator={}, Exit={}, Battery={}, Trap={} }
local espEnabled = { Survivor=false, Killer=false, Generator=false, Exit=false, Battery=false, Trap=false }

local function addHighlight(obj, color, espType)
    if not obj or gameESP[obj] then return end
    local h = Instance.new("Highlight")
    h.FillColor = color
    h.FillTransparency = 0.5
    h.OutlineColor = color
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = obj
    h.Parent = obj
    gameESP[obj] = { highlight = h, type = espType }
end

local function removeHighlight(obj)
    if gameESP[obj] then
        if gameESP[obj].highlight then gameESP[obj].highlight:Destroy() end
        gameESP[obj] = nil
    end
end

local function clearESPByType(espType)
    for obj, data in pairs(gameESP) do
        if data.type == espType then
            if data.highlight then data.highlight:Destroy() end
            gameESP[obj] = nil
        end
    end
    for _, conn in ipairs(espConnections[espType]) do if conn then conn:Disconnect() end end
    espConnections[espType] = {}
end

ESPGroup1:AddToggle("SurvivorESP", { Text="Survivor ESP", Default=false, Callback=function(v)
    espEnabled.Survivor = v
    if v then
        local alive = Workspace:FindFirstChild("PLAYERS") and Workspace.PLAYERS:FindFirstChild("ALIVE")
        if alive then
            for _, model in ipairs(alive:GetChildren()) do
                if model:IsA("Model") then addHighlight(model, Color3.fromRGB(80,180,255), "Survivor") end
            end
            local addConn = alive.ChildAdded:Connect(function(model)
                if espEnabled.Survivor and model:IsA("Model") then addHighlight(model, Color3.fromRGB(80,180,255), "Survivor") end
            end)
            local removeConn = alive.ChildRemoved:Connect(function(model) removeHighlight(model) end)
            table.insert(espConnections.Survivor, addConn)
            table.insert(espConnections.Survivor, removeConn)
        end
        Library:Notify({ Title="Survivor ESP", Content="Enabled", Time=2 })
    else
        clearESPByType("Survivor")
        Library:Notify({ Title="Survivor ESP", Content="Disabled", Time=2 })
    end
end })

ESPGroup1:AddToggle("KillerESP", { Text="Killer ESP", Default=false, Callback=function(v)
    espEnabled.Killer = v
    if v then
        local killers = Workspace:FindFirstChild("PLAYERS") and Workspace.PLAYERS:FindFirstChild("KILLER")
        if killers then
            for _, model in ipairs(killers:GetChildren()) do
                if model:IsA("Model") then addHighlight(model, Color3.fromRGB(255,80,80), "Killer") end
            end
            local addConn = killers.ChildAdded:Connect(function(model)
                if espEnabled.Killer and model:IsA("Model") then addHighlight(model, Color3.fromRGB(255,80,80), "Killer") end
            end)
            local removeConn = killers.ChildRemoved:Connect(function(model) removeHighlight(model) end)
            table.insert(espConnections.Killer, addConn)
            table.insert(espConnections.Killer, removeConn)
        end
        Library:Notify({ Title="Killer ESP", Content="Enabled", Time=2 })
    else
        clearESPByType("Killer")
        Library:Notify({ Title="Killer ESP", Content="Disabled", Time=2 })
    end
end })

ESPGroup1:AddToggle("GeneratorESP", { Text="Generator ESP", Default=false, Callback=function(v)
    espEnabled.Generator = v
    if v then
        local map = Workspace:FindFirstChild("MAPS") and Workspace.MAPS:FindFirstChild("GAME MAP")
        if map then
            local folder = map:FindFirstChild("Generators")
            if folder then
                for _, model in ipairs(folder:GetChildren()) do
                    if model:IsA("Model") then addHighlight(model, Color3.fromRGB(0,255,100), "Generator") end
                end
                local addConn = folder.ChildAdded:Connect(function(model)
                    if espEnabled.Generator and model:IsA("Model") then addHighlight(model, Color3.fromRGB(0,255,100), "Generator") end
                end)
                local removeConn = folder.ChildRemoved:Connect(function(model) removeHighlight(model) end)
                table.insert(espConnections.Generator, addConn)
                table.insert(espConnections.Generator, removeConn)
            end
        end
        Library:Notify({ Title="Generator ESP", Content="Enabled", Time=2 })
    else
        clearESPByType("Generator")
        Library:Notify({ Title="Generator ESP", Content="Disabled", Time=2 })
    end
end })

ESPGroup1:AddToggle("ExitESP", { Text="Exit ESP", Default=false, Callback=function(v)
    espEnabled.Exit = v
    if v then
        local map = Workspace:FindFirstChild("MAPS") and Workspace.MAPS:FindFirstChild("GAME MAP")
        if map then
            local escapes = map:FindFirstChild("Escapes")
            if escapes then
                for _, obj in ipairs(escapes:GetChildren()) do
                    if obj:IsA("BasePart") then addHighlight(obj, Color3.fromRGB(255,200,0), "Exit")
                    elseif obj:IsA("Model") then
                        addHighlight(obj, Color3.fromRGB(255,200,0), "Exit")
                        for _, part in ipairs(obj:GetDescendants()) do
                            if part:IsA("BasePart") then addHighlight(part, Color3.fromRGB(255,200,0), "Exit") end
                        end
                    end
                end
                local addConn = escapes.ChildAdded:Connect(function(obj)
                    if espEnabled.Exit then
                        if obj:IsA("BasePart") then addHighlight(obj, Color3.fromRGB(255,200,0), "Exit")
                        elseif obj:IsA("Model") then
                            addHighlight(obj, Color3.fromRGB(255,200,0), "Exit")
                            for _, part in ipairs(obj:GetDescendants()) do
                                if part:IsA("BasePart") then addHighlight(part, Color3.fromRGB(255,200,0), "Exit") end
                            end
                        end
                    end
                end)
                local removeConn = escapes.ChildRemoved:Connect(function(part) removeHighlight(part) end)
                table.insert(espConnections.Exit, addConn)
                table.insert(espConnections.Exit, removeConn)
            end
        end
        Library:Notify({ Title="Exit ESP", Content="Enabled", Time=2 })
    else
        clearESPByType("Exit")
        Library:Notify({ Title="Exit ESP", Content="Disabled", Time=2 })
    end
end })

ESPGroup1:AddToggle("BatteryESP", { Text="Battery ESP", Default=false, Callback=function(v)
    espEnabled.Battery = v
    if v then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if (obj:IsA("MeshPart") or obj:IsA("BasePart")) and obj.Name:lower():find("batter") then
                addHighlight(obj, Color3.fromRGB(0,255,255), "Battery")
            end
        end
        local addConn = Workspace.DescendantAdded:Connect(function(obj)
            if espEnabled.Battery and (obj:IsA("MeshPart") or obj:IsA("BasePart")) and obj.Name:lower():find("batter") then
                addHighlight(obj, Color3.fromRGB(0,255,255), "Battery")
            end
        end)
        local removeConn = Workspace.DescendantRemoving:Connect(function(obj)
            if gameESP[obj] and gameESP[obj].type == "Battery" then
                if gameESP[obj].highlight then gameESP[obj].highlight:Destroy() end
                gameESP[obj] = nil
            end
        end)
        table.insert(espConnections.Battery, addConn)
        table.insert(espConnections.Battery, removeConn)
        Library:Notify({ Title="Battery ESP", Content="Enabled", Time=2 })
    else
        clearESPByType("Battery")
        Library:Notify({ Title="Battery ESP", Content="Disabled", Time=2 })
    end
end })

ESPGroup1:AddToggle("TrapESP", { Text="Trap ESP", Default=false, Callback=function(v)
    espEnabled.Trap = v
    if v then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local name = obj.Name:lower()
            if obj:IsA("BasePart") and (name:find("trap") or name:find("bear") or name:find("snare") or name:find("mine")) then
                addHighlight(obj, Color3.fromRGB(255,100,0), "Trap")
            elseif obj:IsA("Model") and (name:find("trap") or name:find("bear") or name:find("snare") or name:find("mine")) then
                addHighlight(obj, Color3.fromRGB(255,100,0), "Trap")
            end
        end
        local addConn = Workspace.DescendantAdded:Connect(function(obj)
            if espEnabled.Trap then
                local name = obj.Name:lower()
                if (obj:IsA("BasePart") or obj:IsA("Model")) and (name:find("trap") or name:find("bear") or name:find("snare") or name:find("mine")) then
                    addHighlight(obj, Color3.fromRGB(255,100,0), "Trap")
                end
            end
        end)
        local removeConn = Workspace.DescendantRemoving:Connect(function(obj)
            if gameESP[obj] and gameESP[obj].type == "Trap" then
                if gameESP[obj].highlight then gameESP[obj].highlight:Destroy() end
                gameESP[obj] = nil
            end
        end)
        table.insert(espConnections.Trap, addConn)
        table.insert(espConnections.Trap, removeConn)
        Library:Notify({ Title="Trap ESP", Content="Enabled", Time=2 })
    else
        clearESPByType("Trap")
        Library:Notify({ Title="Trap ESP", Content="Disabled", Time=2 })
    end
end })

ESPGroup2:AddSlider("ESPAlpha", { Text="ESP Transparency", Default=50, Min=10, Max=90, Suffix="%", Callback=function(v)
    for obj, data in pairs(gameESP) do
        if data.highlight then
            data.highlight.FillTransparency = v/100
            data.highlight.OutlineTransparency = v/100 - 0.1
        end
    end
end })

ESPGroup2:AddDropdown("ESPColors", { Text="ESP Color Set", Values={"Default","Bright","Dark","Rainbow"}, Default="Default", Callback=function(v)
    local colors = {
        Default = { Survivor=Color3.fromRGB(80,180,255), Killer=Color3.fromRGB(255,80,80), Generator=Color3.fromRGB(0,255,100), Exit=Color3.fromRGB(255,200,0), Battery=Color3.fromRGB(0,255,255), Trap=Color3.fromRGB(255,100,0) },
        Bright = { Survivor=Color3.fromRGB(120,220,255), Killer=Color3.fromRGB(255,120,120), Generator=Color3.fromRGB(50,255,150), Exit=Color3.fromRGB(255,230,50), Battery=Color3.fromRGB(50,255,255), Trap=Color3.fromRGB(255,150,50) },
        Dark = { Survivor=Color3.fromRGB(50,120,200), Killer=Color3.fromRGB(200,50,50), Generator=Color3.fromRGB(0,200,80), Exit=Color3.fromRGB(200,160,0), Battery=Color3.fromRGB(0,200,200), Trap=Color3.fromRGB(200,80,0) },
        Rainbow = { Survivor=Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)), Killer=Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)), Generator=Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)), Exit=Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)), Battery=Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)), Trap=Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255)) }
    }
    for obj, data in pairs(gameESP) do
        if data.highlight and colors[v][data.type] then
            data.highlight.FillColor = colors[v][data.type]
            data.highlight.OutlineColor = colors[v][data.type]
        end
    end
end })

local autoGen = false
local genConn = nil

AutoGroup1:AddToggle("AutoGenerator", { Text="Auto Repair Generators", Default=false, Callback=function(v)
    autoGen = v
    if genConn then genConn:Disconnect() genConn = nil end
    if v then
        genConn = RunService.RenderStepped:Connect(function()
            if not autoGen then return end
            local gui = player.PlayerGui
            if gui then
                local genFrame = gui:FindFirstChild("Gen")
                if genFrame and genFrame:FindFirstChild("GeneratorMain") then
                    pcall(function() genFrame.GeneratorMain.Event:FireServer(true) end)
                end
            end
        end)
        Library:Notify({ Title="Generator Repair", Content="Enabled", Time=2 })
    else
        Library:Notify({ Title="Generator Repair", Content="Disabled", Time=2 })
    end
end })

local autoBarricade = false
local barricadeConn = nil

AutoGroup1:AddToggle("PerfectBarricade", { Text="Perfect Barricade", Default=false, Callback=function(v)
    autoBarricade = v
    if barricadeConn then barricadeConn:Disconnect() barricadeConn = nil end
    if v then
        barricadeConn = RunService.RenderStepped:Connect(function()
            if not autoBarricade then return end
            pcall(function()
                local playerGui = player:FindFirstChild("PlayerGui")
                if not playerGui then return end
                for _, dot in ipairs(playerGui:GetChildren()) do
                    if (dot.Name == "Dot" or dot:FindFirstChild("Container")) and dot:IsA("ScreenGui") and dot.Enabled then
                        local container = dot:FindFirstChild("Container")
                        if container then
                            local frame = container:FindFirstChild("Frame")
                            if frame then
                                frame.AnchorPoint = Vector2.new(0.5, 0.5)
                                frame.Position = UDim2.new(0.5, 0, 0.5, 0)
                            end
                        end
                    end
                end
            end)
        end)
        Library:Notify({ Title="Perfect Barricade", Content="Enabled", Time=2 })
    else
        Library:Notify({ Title="Perfect Barricade", Content="Disabled", Time=2 })
    end
end })

local autoParryEnabled = false
local autoParryRadius = 15
local autoParryDelay = 0.1
local autoParryPrediction = 0
local parryConns = {}
local parryDebounce = false
local parryCooldown = 0.3

local function tryParry(killerChar)
    if not autoParryEnabled or parryDebounce then return end
    local char = player.Character
    if not char or not char.Parent then return end
    if char.Parent.Name == "KILLER" then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local killerRoot = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
    if root and killerRoot then
        local targetPos = killerRoot.Position
        if autoParryPrediction > 0 then targetPos = targetPos + (killerRoot.AssemblyLinearVelocity * autoParryPrediction) end
        local distance = (root.Position - targetPos).Magnitude
        if distance <= autoParryRadius then
            parryDebounce = true
            task.spawn(function()
                if autoParryDelay > 0 then task.wait(autoParryDelay) end
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)
                task.wait(parryCooldown)
                parryDebounce = false
            end)
        end
    end
end

AutoGroup2:AddToggle("AutoParry", { Text="Auto-Parry", Default=false, Callback=function(v)
    autoParryEnabled = v
    parryDebounce = false
    if v then
        local killerFolder = Workspace:FindFirstChild("PLAYERS") and Workspace.PLAYERS:FindFirstChild("KILLER")
        if killerFolder then
            for _, k in ipairs(killerFolder:GetChildren()) do
                pcall(function() setupKillerParryDetection(k) end)
            end
            table.insert(parryConns, killerFolder.ChildAdded:Connect(function(k)
                pcall(function() setupKillerParryDetection(k) end)
            end))
        end
        Library:Notify({ Title="Auto-Parry", Content="Enabled", Time=2 })
    else
        for _, conn in ipairs(parryConns) do pcall(function() conn:Disconnect() end) end
        table.clear(parryConns)
        Library:Notify({ Title="Auto-Parry", Content="Disabled", Time=2 })
    end
end })

AutoGroup2:AddSlider("ParryRadius", { Text="Parry Radius", Default=15, Min=5, Max=30, Suffix=" studs", Callback=function(v) autoParryRadius = v end })
AutoGroup2:AddSlider("ParryDelay", { Text="Parry Delay", Default=0.1, Min=0, Max=0.5, Suffix=" s", Decimal=2, Callback=function(v) autoParryDelay = v end })
AutoGroup2:AddSlider("ParryCooldown", { Text="Parry Cooldown", Default=0.3, Min=0.1, Max=1.0, Suffix=" s", Decimal=2, Callback=function(v) parryCooldown = v end })
AutoGroup2:AddSlider("ParryPrediction", { Text="Prediction", Default=0, Min=0, Max=1, Suffix=" s", Decimal=2, Callback=function(v) autoParryPrediction = v end })

local infiniteStamina = false
local staminaConn = nil

PlayerGroup2:AddToggle("InfiniteStamina", { Text="Infinite Stamina", Default=false, Callback=function(v)
    infiniteStamina = v
    if staminaConn then staminaConn:Disconnect() staminaConn = nil end
    if v then
        staminaConn = RunService.Heartbeat:Connect(function()
            if not infiniteStamina then return end
            local char = player.Character
            if char then
                char:SetAttribute("Stamina", math.huge)
                char:SetAttribute("MaxStamina", math.huge)
            end
        end)
        Library:Notify({ Title="Infinite Stamina", Content="Enabled", Time=2 })
    else
        local char = player.Character
        if char then
            char:SetAttribute("Stamina", 100)
            char:SetAttribute("MaxStamina", 100)
        end
        Library:Notify({ Title="Infinite Stamina", Content="Disabled", Time=2 })
    end
end })

local speedBoost = false
local speedBoostConn = nil
local speedBoostValue = 32

PlayerGroup1:AddToggle("SpeedBoost", { Text="Speed Boost", Default=false, Callback=function(v)
    speedBoost = v
    if v then
        speedBoostConn = RunService.RenderStepped:Connect(function()
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = speedBoostValue end
                if char:GetAttribute("WalkSpeed") then char:SetAttribute("WalkSpeed", speedBoostValue) end
                if char:GetAttribute("Speed") then char:SetAttribute("Speed", speedBoostValue) end
                local speedValue = char:FindFirstChild("WalkSpeed")
                if speedValue and speedValue:IsA("NumberValue") then speedValue.Value = speedBoostValue end
                local runSpeed = char:FindFirstChild("RunSpeed")
                if runSpeed and runSpeed:IsA("NumberValue") then runSpeed.Value = speedBoostValue end
            end
        end)
        Library:Notify({ Title="Speed Boost", Content="Enabled (" .. speedBoostValue .. ")", Time=2 })
    else
        if speedBoostConn then speedBoostConn:Disconnect() speedBoostConn = nil end
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
            if char:GetAttribute("WalkSpeed") then char:SetAttribute("WalkSpeed", 16) end
            if char:GetAttribute("Speed") then char:SetAttribute("Speed", 16) end
            local speedValue = char:FindFirstChild("WalkSpeed")
            if speedValue and speedValue:IsA("NumberValue") then speedValue.Value = 16 end
            local runSpeed = char:FindFirstChild("RunSpeed")
            if runSpeed and runSpeed:IsA("NumberValue") then runSpeed.Value = 16 end
        end
        Library:Notify({ Title="Speed Boost", Content="Disabled", Time=2 })
    end
end })

PlayerGroup1:AddSlider("SpeedBoostValue", { Text="Boost Speed", Default=32, Min=16, Max=100, Suffix=" speed", Callback=function(v)
    speedBoostValue = v
    if speedBoost then Library:Notify({ Title="Speed Boost", Content="Speed: " .. v, Time=1 }) end
end })

local jumpBoost = false
local jumpBoostConn = nil
local jumpPower = 80

local function applyJumpBoost()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.JumpPower = jumpPower
    hum.UseJumpPower = true
    hum.JumpHeight = jumpPower / 7.5
    pcall(function()
        if char:GetAttribute("JumpPower") ~= nil then char:SetAttribute("JumpPower", jumpPower) end
        if char:GetAttribute("JumpHeight") ~= nil then char:SetAttribute("JumpHeight", jumpPower / 7.5) end
        if char:GetAttribute("JumpBoost") ~= nil then char:SetAttribute("JumpBoost", jumpPower) end
    end)
    for _, name in ipairs({ "JumpPower", "JumpHeight", "JumpBoost" }) do
        local val = char:FindFirstChild(name)
        if val and val:IsA("NumberValue") then val.Value = jumpPower end
        local humVal = hum:FindFirstChild(name)
        if humVal and humVal:IsA("NumberValue") then humVal.Value = jumpPower end
    end
end

local function resetJumpBoost()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.JumpPower = DEFAULT_JUMPPOWER
    hum.JumpHeight = DEFAULT_JUMPPOWER / 7.5
    hum.UseJumpPower = true
    pcall(function()
        if char:GetAttribute("JumpPower") ~= nil then char:SetAttribute("JumpPower", DEFAULT_JUMPPOWER) end
        if char:GetAttribute("JumpHeight") ~= nil then char:SetAttribute("JumpHeight", DEFAULT_JUMPPOWER / 7.5) end
        if char:GetAttribute("JumpBoost") ~= nil then char:SetAttribute("JumpBoost", DEFAULT_JUMPPOWER) end
    end)
end

PlayerGroup1:AddToggle("JumpBoost", { Text="Jump Boost", Default=false, Callback=function(v)
    jumpBoost = v
    if jumpBoostConn then jumpBoostConn:Disconnect() jumpBoostConn = nil end
    if v then
        applyJumpBoost()
        jumpBoostConn = RunService.RenderStepped:Connect(function()
            if not jumpBoost then return end
            applyJumpBoost()
        end)
        Library:Notify({ Title="Jump Boost", Content="Enabled (" .. jumpPower .. ")", Time=2 })
    else
        if jumpBoostConn then jumpBoostConn:Disconnect() jumpBoostConn = nil end
        resetJumpBoost()
        Library:Notify({ Title="Jump Boost", Content="Disabled", Time=2 })
    end
end })

PlayerGroup1:AddSlider("JumpPowerValue", { Text="Jump Power", Default=80, Min=50, Max=200, Suffix=" power", Callback=function(v)
    jumpPower = v
    if jumpBoost then
        applyJumpBoost()
        Library:Notify({ Title="Jump Boost", Content="Power: " .. v, Time=1 })
    end
end })

local noStun = false
local noStunConns = {}

PlayerGroup2:AddToggle("NoStun", { Text="No Stun", Default=false, Callback=function(v)
    noStun = v
    for _, conn in ipairs(noStunConns) do pcall(function() conn:Disconnect() end) end
    table.clear(noStunConns)
    if v then
        local char = player.Character
        if char then
            for _, attr in ipairs({ "Stunned", "Stun", "IsStunned", "StunDuration", "StunnedTime", "HitStun", "DamageStun" }) do
                char:SetAttribute(attr, false)
            end
            table.insert(noStunConns, char.AttributeChanged:Connect(function(attr)
                if noStun and attr:lower():find("stun") then char:SetAttribute(attr, false) end
            end))
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                table.insert(noStunConns, hum.StateChanged:Connect(function(old, new)
                    if noStun and (new == Enum.HumanoidStateType.FallingDown or new == Enum.HumanoidStateType.Ragdoll) then
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end
                end))
            end
        end
        Library:Notify({ Title="No Stun", Content="Enabled", Time=2 })
    else
        Library:Notify({ Title="No Stun", Content="Disabled", Time=2 })
    end
end })

local noclipEnabled = false
local noclipConn = nil

PlayerGroup1:AddToggle("Noclip", { Text="Noclip", Default=false, Callback=function(v)
    noclipEnabled = v
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if v then
        noclipConn = RunService.Stepped:Connect(function()
            if not noclipEnabled then return end
            local char = player.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
        Library:Notify({ Title="Noclip", Content="Enabled", Time=2 })
    else
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
        Library:Notify({ Title="Noclip", Content="Disabled", Time=2 })
    end
end })

local fullBrightEnabled = false
local fbLoop = nil

PlayerGroup2:AddToggle("FullBright", { Text="Full Brightness", Default=false, Callback=function(v)
    fullBrightEnabled = v
    if fbLoop then fbLoop:Disconnect() fbLoop = nil end
    if v then
        fbLoop = RunService.Heartbeat:Connect(function()
            if not fullBrightEnabled then return end
            Lighting.GlobalShadows = false
            Lighting.ClockTime = 14
            Lighting.Brightness = 2
        end)
        Library:Notify({ Title="Full Brightness", Content="Enabled", Time=2 })
    else
        Lighting.GlobalShadows = true
        Lighting.ClockTime = 14
        Lighting.Brightness = 1
        Library:Notify({ Title="Full Brightness", Content="Disabled", Time=2 })
    end
end })

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    task.wait(0.5)
    if speedBoost then
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = speedBoostValue end
    end
    if jumpBoost then applyJumpBoost() end
    if noStun then
        for _, attr in ipairs({ "Stunned", "Stun", "IsStunned", "StunDuration", "StunnedTime", "HitStun", "DamageStun" }) do
            newChar:SetAttribute(attr, false)
        end
    end
    if noclipEnabled then
        for _, part in ipairs(newChar:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

SettingsGroup1:AddDropdown("ThemePicker", { Text="Theme Preset", Values={"Blue","Cyan","Dark","Green","Light","Orange","Pink","Purple","Red"}, Default="Dark", Callback=function(v) applyThemeKeepAccent(v) end })
SettingsGroup1:AddDropdown("StylePicker", { Text="Corner Style", Values={"Square","Curved","Round","Pill"}, Default="Curved", Callback=function(v) Library:SetStyle(v) end })
SettingsGroup1:AddDropdown("AccentPicker", { Text="Accent Color", Values={"Cyan","Blue","Purple","Pink","Red","Orange","Green","Gold"}, Default="Cyan", Callback=function(v)
    local accents = {
        Cyan = Color3.fromRGB(0,200,220), Blue = Color3.fromRGB(50,120,255),
        Purple = Color3.fromRGB(150,80,255), Pink = Color3.fromRGB(255,100,180),
        Red = Color3.fromRGB(255,70,70), Orange = Color3.fromRGB(255,150,50),
        Green = Color3.fromRGB(80,220,120), Gold = Color3.fromRGB(255,200,50),
    }
    setAccentColor(accents[v] or Color3.fromRGB(0,200,220))
end })

local themeButtons = {
    { name="Midnight Blue", accent=Color3.fromRGB(70,130,255), bg=Color3.fromRGB(8,12,28), main=Color3.fromRGB(15,20,45), outline=Color3.fromRGB(30,40,70), font=Color3.fromRGB(200,220,255) },
    { name="Crimson Night", accent=Color3.fromRGB(255,60,80), bg=Color3.fromRGB(20,10,12), main=Color3.fromRGB(35,18,22), outline=Color3.fromRGB(55,30,35), font=Color3.fromRGB(255,210,215) },
    { name="Emerald Forest", accent=Color3.fromRGB(60,230,140), bg=Color3.fromRGB(10,20,15), main=Color3.fromRGB(18,35,28), outline=Color3.fromRGB(30,55,42), font=Color3.fromRGB(210,255,225) },
    { name="Royal Purple", accent=Color3.fromRGB(170,80,255), bg=Color3.fromRGB(16,10,22), main=Color3.fromRGB(28,18,40), outline=Color3.fromRGB(45,30,60), font=Color3.fromRGB(240,220,255) },
    { name="Arctic Frost", accent=Color3.fromRGB(100,210,255), bg=Color3.fromRGB(15,20,25), main=Color3.fromRGB(22,32,42), outline=Color3.fromRGB(38,50,65), font=Color3.fromRGB(220,245,255) },
    { name="Sunset Blaze", accent=Color3.fromRGB(255,150,50), bg=Color3.fromRGB(22,15,12), main=Color3.fromRGB(40,28,22), outline=Color3.fromRGB(60,42,32), font=Color3.fromRGB(255,235,215) },
    { name="Golden Hour", accent=Color3.fromRGB(255,200,60), bg=Color3.fromRGB(20,18,12), main=Color3.fromRGB(35,32,22), outline=Color3.fromRGB(55,50,35), font=Color3.fromRGB(255,245,200) },
    { name="Rose Gold", accent=Color3.fromRGB(255,140,170), bg=Color3.fromRGB(22,15,18), main=Color3.fromRGB(38,25,30), outline=Color3.fromRGB(58,38,45), font=Color3.fromRGB(255,225,235) },
}

for _, theme in ipairs(themeButtons) do
    SettingsGroup1:AddButton({ Text=theme.name, Func=function()
        savedAccentColor = theme.accent
        Library:SetColors({
            Background = theme.bg, Main = theme.main, Tab = theme.main,
            Accent = theme.accent, Slider = theme.accent,
            Outline = theme.outline, Font = theme.font,
        })
    end })
end

SettingsGroup2:AddSlider("StealthLevel", { Text="Stealth Level", Default=50, Min=0, Max=100, Suffix="%", Callback=function(v) stealthLevel = v/100 end })
SettingsGroup2:AddSlider("DPISlider", { Text="DPI Scale", Default=100, Min=75, Max=150, Suffix="%", Callback=function(v) Library:SetDPIScale(v) end })
SettingsGroup2:AddToggle("CustomCursor", { Text="Custom Cursor", Default=not isMobile, Callback=function(v) Library.ShowCustomCursor = v end })
SettingsGroup2:AddButton({ Text="Minimize Window", Func=function() Window:Minimize() end })
SettingsGroup2:AddButton({ Text="Restore Window", Func=function() Window:Restore() end })
SettingsGroup2:AddButton({ Text="Reset to Default", Func=function()
    savedAccentColor = Color3.fromRGB(0,180,220)
    Library:SetTheme("Dark")
    Library:SetStyle("Curved")
    Library:SetColors({ Accent = savedAccentColor, Slider = savedAccentColor })
end })

Library:Notify({ Title="Bite By Night Executor", Content="Loaded! " .. (isMobile and "Tap PH to toggle." or "Press RightControl."), Time=5 })

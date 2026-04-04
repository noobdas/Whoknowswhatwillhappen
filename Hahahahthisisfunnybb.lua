local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local RunService          = game:GetService("RunService")
local Stats               = game:GetService("Stats")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Debris              = game:GetService("Debris")
local CoreGui             = game:GetService("CoreGui")
local TweenService        = game:GetService("TweenService")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService          = game:GetService("GuiService")

local cloneref = cloneref or function(...) return ... end
local service = setmetatable({}, {__index = function(self, key)
    local cache = cloneref(game:GetService(key))
    rawset(self, key, cache)
    return cache
end})

local LocalPlayer = Players.LocalPlayer
local player      = LocalPlayer
local Camera      = workspace.CurrentCamera

local Runtime = workspace:FindFirstChild("Runtime")
workspace.ChildAdded:Connect(function(c)
    if c.Name == "Runtime" then Runtime = c end
end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

local tornadoTimestamp  = tick()
local isTornadoActive   = false
local parryCount        = 0
local Parried           = false
local Training_Parried  = false
local Lerp_Radians      = 0
local Last_Warping      = tick()
local Curving           = tick()

local AutoWalk              = false
local AutoWalkDistanceX     = 10
local AutoWalkDistanceZ     = 10
local PlayerSaftey          = false
local PlayerSaftey_Distance = 10
local RandomTeleports       = false
local TeleportDistanceX     = 10
local TeleportDistanceZ     = 10
local AutoDoubleJump        = false
local ClosestPlayer_var     = false
local BallVelocity          = false
local lagBallActive         = false
local lagBallEnabled        = false
local lagBallRadius         = 25
local lagBallDesyncCFrame   = nil
local lagBallDesyncVelocity = nil
local lagBallGui            = nil
local afkToggle             = false
local afkRunning            = false
local antiLagActive         = false
local auto_rewards_enabled  = false
local reward_interval       = 60
local originalMaterials     = {}
local originalDecalsTextures = {}
local currentJobId          = game.JobId
local Connections_Manager   = {}


local function GetDeviceType()
    if UserInputService.TouchEnabled and not (UserInputService.KeyboardEnabled or UserInputService.MouseEnabled) then
        return "Mobile"
    elseif UserInputService.KeyboardEnabled or UserInputService.MouseEnabled then
        return "PC"
    else
        return "Unknown"
    end
end

local Device = GetDeviceType()
print("Detected device:", Device)

local function stype(obj)
    return typeof(obj) == 'Instance' and obj.ClassName or typeof(obj)
end

local parrydata = {}
local remotesfolder = ReplicatedStorage:QueryDescendants('> Folder#Packages > Folder#_Index >> #net')[1]

local _t
local remote
for _,v in filtergc('table', {}) do
    if not _t and stype(rawget(v, 0)) == 'RemoteEvent' and stype(rawget(v, 1)) == 'RemoteEvent' then
        local i = rawget(v, 3)
        if stype(i) ~= 'table' or stype(rawget(i, 2)) ~= 'string' or stype(rawget(i, 3)) ~= 'number' then
            continue
        end
        _t = v
    end
    if not remote then
        local func = rawget(v, 2)
        local uuid = rawget(v, 3)
        if stype(func) == 'function' and stype(uuid) == 'string' and uuid:match('^%x%x%x%x%x%x%x%x%-') and stype(rawget(v, 0)) == 'table' then
            remote = remotesfolder:FindFirstChild('RE/'..func(uuid:gsub('-', ''), uuid))
        end
    end
    if _t and remote then break end
end

local uuids = {}
for _,v in pairs(_t) do
    if type(v) == 'string' and v:match('%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x') then
        table.insert(uuids, v)
    end
end

local info = rawget(_t, 3)
local selector = rawget(info, 3)
parrydata.uuid = uuids[selector]
parrydata.hash = rawget(info, 2)

local alive_folder = workspace:WaitForChild('Alive')
local function FireParry(cf)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local targets = {}
    for _, v in alive_folder:QueryDescendants('> Model:has(BasePart#HumanoidRootPart)') do
        targets[v.Name] = camera:WorldToScreenPoint(v.HumanoidRootPart.Position)
    end
    remote:FireServer(parrydata.uuid, parrydata.hash, 0.5, cf or camera.CFrame, targets, {camera.ViewportSize.X/2, camera.ViewportSize.Y/2}, false)
end

local Auto_Parry = {}
local closestPlayer = nil

function Auto_Parry.Closest_Player()
    local Max_Distance = math.huge
    local Found_Entity = nil
    local Alive = workspace:FindFirstChild("Alive")
    if not Alive then return nil end
    for _, Entity in pairs(Alive:GetChildren()) do
        if tostring(Entity) ~= tostring(player) and Entity.PrimaryPart then
            local d = player:DistanceFromCharacter(Entity.PrimaryPart.Position)
            if d < Max_Distance then
                Max_Distance = d
                Found_Entity = Entity
            end
        end
    end
    closestPlayer = Found_Entity
    return Found_Entity
end

function Auto_Parry.Get_Entity_Properties()
    Auto_Parry.Closest_Player()
    if not closestPlayer then return false end
    return {
        Velocity  = closestPlayer.PrimaryPart.Velocity,
        Direction = (player.Character.PrimaryPart.Position - closestPlayer.PrimaryPart.Position).Unit,
        Distance  = (player.Character.PrimaryPart.Position - closestPlayer.PrimaryPart.Position).Magnitude,
    }
end

function Auto_Parry.Get_Ball_Properties()
    local Ball = Auto_Parry.Get_Ball()
    if not Ball then return { Velocity = Vector3.zero, Direction = Vector3.zero, Distance = 0, Dot = 0 } end
    local Ball_Direction = (player.Character.PrimaryPart.Position - Ball.Position).Unit
    local Ball_Distance  = (player.Character.PrimaryPart.Position - Ball.Position).Magnitude
    return { Velocity = Vector3.zero, Direction = Ball_Direction, Distance = Ball_Distance, Dot = 0 }
end

function Auto_Parry.Spam_Service(spamData)
    local spamBall = Auto_Parry.Get_Ball()
    if not spamBall then return 0 end
    Auto_Parry.Closest_Player()
    if not closestPlayer then return 0 end
    local spamResult = 0
    local AssemblyLinearVelocity = spamBall.AssemblyLinearVelocity
    local Magnitude = AssemblyLinearVelocity.Magnitude
    local ballApproachDot = (player.Character.PrimaryPart.Position - spamBall.Position).Unit:Dot(AssemblyLinearVelocity.Unit)
    local distToClosestPlayer = player:DistanceFromCharacter(closestPlayer.PrimaryPart.Position)
    local adjustedPing = spamData.Ping + math.min(Magnitude / 6.5, 95) + 3
    if adjustedPing < spamData.Entity_Properties.Distance then return spamResult end
    if adjustedPing < spamData.Ball_Properties.Distance   then return spamResult end
    if adjustedPing < distToClosestPlayer                  then return spamResult end
    local speedPenalty = 5 - math.min(Magnitude / 5, 5)
    return adjustedPing - math.clamp(ballApproachDot, -1, 0) * speedPenalty
end

function Auto_Parry.Get_Balls()
    local Balls = {}
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return Balls end
    for _, inst in pairs(ballsFolder:GetChildren()) do
        if inst:GetAttribute("realBall") then
            inst.CanCollide = false
            table.insert(Balls, inst)
        end
    end
    return Balls
end

function Auto_Parry.Get_Ball()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end
    for _, inst in pairs(ballsFolder:GetChildren()) do
        if inst:GetAttribute("realBall") then
            inst.CanCollide = false
            return inst
        end
    end
    return nil
end

function Auto_Parry.Lobby_Balls()
    local trainingFolder = workspace:FindFirstChild("TrainingBalls")
    if not trainingFolder then return nil end
    for _, inst in pairs(trainingFolder:GetChildren()) do
        if inst:GetAttribute("realBall") then return inst end
    end
    return nil
end

function Auto_Parry.Linear_Interpolation(a, b, t)
    return a + (b - a) * t
end

function Auto_Parry.Is_Curved()
    local Ball = Auto_Parry.Get_Ball()
    if not Ball then return false end
    local Zoomies = Ball:FindFirstChild("zoomies")
    if not Zoomies then return false end
    local char = player.Character
    if not char or not char.PrimaryPart then return false end
    local Velocity             = Zoomies.VectorVelocity
    local Ball_Direction       = Velocity.Unit
    local Direction            = (char.PrimaryPart.Position - Ball.Position).Unit
    local Dot                  = Direction:Dot(Ball_Direction)
    local Speed                = Velocity.Magnitude
    local Speed_Threshold      = math.min(Speed / 100, 40)
    local Direction_Difference = (Ball_Direction - Velocity).Unit
    local Direction_Similarity = Direction:Dot(Direction_Difference)
    local Dot_Difference       = Dot - Direction_Similarity
    local Distance             = (char.PrimaryPart.Position - Ball.Position).Magnitude
    local Pings                = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    local Dot_Threshold        = 0.5 - (Pings / 1000)
    local Reach_Time           = Distance / Speed - (Pings / 1000)
    local Ball_Distance_Threshold = 15 - math.min(Distance / 1000, 15) + Speed_Threshold
    local Clamped_Dot          = math.clamp(Dot, -1, 1)
    local Radians              = math.rad(math.asin(Clamped_Dot))
    Lerp_Radians = Auto_Parry.Linear_Interpolation(Lerp_Radians, Radians, 0.8)
    if Speed > 100 and Reach_Time > Pings / 10 then
        Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 15, 15)
    end
    if Distance < Ball_Distance_Threshold then return false end
    if Dot_Difference < Dot_Threshold then return true end
    if Lerp_Radians < 0.018 then Last_Warping = tick() end
    if (tick() - Last_Warping) < (Reach_Time / 1.5) then return true end
    if (tick() - Curving)      < (Reach_Time / 1.5) then return true end
    return Dot < Dot_Threshold
end

local speedBiasAmount = 8

local function ShouldParry(Ball)
    if not Ball then return false end
    local char = player.Character
    if not char or not char.PrimaryPart then return false end
    local Zoomies = Ball:FindFirstChild("zoomies")
    if not Zoomies then return false end
    if Ball:GetAttribute("target") ~= tostring(player) then return false end
    if Ball:FindFirstChild("ComboCounter") then return false end
    if Ball:FindFirstChild("AeroDynamicSlashVFX") then
        Debris:AddItem(Ball.AeroDynamicSlashVFX, 0)
        tornadoTimestamp = tick()
    end
    if Runtime and Runtime:FindFirstChild("Tornado") then
        local dur = (Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159
        if (tick() - tornadoTimestamp) < dur then return false end
    end
    local Velocity    = Zoomies.VectorVelocity
    local Speed       = Velocity.Magnitude
    local Distance    = (char.PrimaryPart.Position - Ball.Position).Magnitude
    local Ping        = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
    local speedBias   = math.min(Speed / 20, speedBiasAmount)
    local triggerDist = Speed / 2.9 + Ping - speedBias
    local oneBall = Auto_Parry.Get_Ball()
    if oneBall and oneBall:GetAttribute("target") == tostring(player) and Auto_Parry.Is_Curved() then
        return false
    end
    if char.PrimaryPart:FindFirstChild("SingularityCape") then return false end
    return Distance <= triggerDist
end

local autoParryConns = {}
local function cleanupLoop(tbl, name)
    if not tbl[name] then return end
    for _, c in ipairs(tbl[name]) do
        if c and c.Connected then c:Disconnect() end
    end
    tbl[name] = nil
end

local function CreateAutoParryLoop(name, action, instant)
    cleanupLoop(autoParryConns, name)
    local conns = {}
    table.insert(conns, RunService.PreSimulation:Connect(function()
        if not getgenv()[name] then return end
        local char = player.Character
        if not char or not char.PrimaryPart then return end
        if Parried then return end
        for _, Ball in pairs(Auto_Parry.Get_Balls()) do
            if ShouldParry(Ball) then
                action()
                Parried = true
                Ball:GetAttributeChangedSignal("target"):Once(function() Parried = false end)
                parryCount = parryCount + 1
                task.delay(0.5, function()
                    if parryCount > 0 then parryCount = parryCount - 1 end
                end)
                break
            end
        end
    end))
    if instant then
        table.insert(conns, RunService.RenderStepped:Connect(function()
            if not getgenv()[name] then return end
            local Ball = Auto_Parry.Get_Ball()
            if Ball and ShouldParry(Ball) then action() end
        end))
    end
    autoParryConns[name] = conns
end

local autoSpamEnabled  = false
local spamThreshold    = 1
local autoSpamConn     = nil
local manualSpamEnabled = false
local manualSpamConn   = nil
local manualSpamGui    = nil

local function toggleAutoSpam(state)
    if state == autoSpamEnabled then return end
    autoSpamEnabled = state
    if autoSpamEnabled then
        autoSpamConn = RunService.PreSimulation:Connect(function()
            if not autoSpamEnabled then return end
            local char = player.Character
            if not char or not char.PrimaryPart then return end
            local spamBall = Auto_Parry.Get_Ball()
            if not spamBall then return end
            local zoomies = spamBall:FindFirstChild("zoomies")
            if not zoomies then return end
            Auto_Parry.Closest_Player()
            if not closestPlayer then return end
            local rawPing = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            local clampedPing = math.clamp(rawPing / 10, 10, 16)
            local spamContext = {
                Ball_Properties   = Auto_Parry.Get_Ball_Properties(),
                Entity_Properties = Auto_Parry.Get_Entity_Properties(),
                Ping              = clampedPing,
            }
            local spamScore = Auto_Parry.Spam_Service(spamContext)
            local ballDistance = player:DistanceFromCharacter(spamBall.Position)
            local playerDist = player:DistanceFromCharacter(closestPlayer.PrimaryPart.Position)
            local targetModel = workspace.Alive:FindFirstChild(spamBall:GetAttribute("target"))
            if targetModel and spamScore >= playerDist and spamScore >= ballDistance then
                if ballDistance <= spamScore and parryCount > spamThreshold then
                    FireParry(workspace.CurrentCamera.CFrame)
                end
            end
        end)
    else
        if autoSpamConn then
            autoSpamConn:Disconnect()
            autoSpamConn = nil
        end
    end
end

local function updateManualSpamGui()
    if not manualSpamGui then return end
    local btn = manualSpamGui:FindFirstChild("SpamButton", true)
    if not btn then return end
    if manualSpamEnabled then
        btn.Text            = "SPAM ON"
        btn.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
    else
        btn.Text            = "SPAM OFF"
        btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    end
end

local function toggleManualSpam(state)
    if state == manualSpamEnabled then return end
    manualSpamEnabled = state
    updateManualSpamGui()
    if manualSpamEnabled then

        manualSpamConn = RunService.Heartbeat:Connect(function()
            if not manualSpamEnabled then return end
            local char = player.Character
            if not char or not char.PrimaryPart then return end
            FireParry(workspace.CurrentCamera.CFrame)
        end)
    else
        if manualSpamConn then
            manualSpamConn:Disconnect()
            manualSpamConn = nil
        end
    end
end

local function createManualSpamGui()

    if manualSpamGui then manualSpamGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name            = "PhantomManualSpam"
    screenGui.ResetOnSpawn    = false
    screenGui.DisplayOrder    = 999
    screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset  = true
    pcall(function() screenGui.Parent = CoreGui end)

    local frame = Instance.new("Frame")
    frame.Name              = "DragFrame"
    frame.Size              = UDim2.new(0, 160, 0, 70)
    frame.Position          = UDim2.new(0.5, -80, 0, 120)
    frame.BackgroundColor3  = Color3.fromRGB(18, 18, 24)
    frame.BorderSizePixel   = 0
    frame.Active            = true
    frame.Draggable         = true
    frame.Parent            = screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Name              = "Title"
    label.Size              = UDim2.new(1, 0, 0, 20)
    label.Position          = UDim2.new(0, 0, 0, 6)
    label.BackgroundTransparency = 1
    label.Text              = "Manual Spam"
    label.TextColor3        = Color3.fromRGB(200, 200, 255)
    label.Font              = Enum.Font.GothamBold
    label.TextSize          = 11
    label.Parent            = frame

    local btn = Instance.new("TextButton")
    btn.Name                = "SpamButton"
    btn.Size                = UDim2.new(1, -16, 0, 30)
    btn.Position            = UDim2.new(0, 8, 0, 30)
    btn.BackgroundColor3    = Color3.fromRGB(180, 40, 40)
    btn.TextColor3          = Color3.fromRGB(255, 255, 255)
    btn.Font                = Enum.Font.GothamBold
    btn.TextSize            = 13
    btn.Text                = "SPAM OFF"
    btn.BorderSizePixel     = 0
    btn.AutoButtonColor     = false
    btn.Parent              = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    btn.MouseButton1Click:Connect(function()
        toggleManualSpam(not manualSpamEnabled)
    end)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3 = manualSpamEnabled
                and Color3.fromRGB(0, 230, 100)
                or  Color3.fromRGB(210, 60, 60)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        updateManualSpamGui()
    end)

    manualSpamGui = screenGui
    updateManualSpamGui()
end

local isVisualizerActive = false
local visualizerPart = Instance.new("Part")
visualizerPart.Shape       = Enum.PartType.Ball
visualizerPart.Anchored    = true
visualizerPart.CanCollide  = false
visualizerPart.Material    = Enum.Material.ForceField
visualizerPart.Transparency = 0.5
visualizerPart.Size        = Vector3.new(0, 0, 0)
visualizerPart.Parent      = workspace

RunService.RenderStepped:Connect(function()
    if not isVisualizerActive then return end
    local char = player.Character
    if not char or not char.PrimaryPart then return end
    local ball = Auto_Parry.Get_Ball()
    if ball then
        local speed  = (ball:FindFirstChild("zoomies") and ball.zoomies.VectorVelocity.Magnitude) or 0
        local radius = math.clamp(speed / 2.4 + 10, 15, 200)
        visualizerPart.Size   = Vector3.new(radius, radius, radius)
        visualizerPart.CFrame = char.PrimaryPart.CFrame
    else
        visualizerPart.Size = Vector3.new(0, 0, 0)
    end
end)

local bhopConn    = nil
local strafeConn  = nil
local strafe_speed = 2
local noRenderConn = nil

local function toggleBhop(enabled)
    if enabled then
        bhopConn = RunService.PostSimulation:Connect(function()
            local char = player.Character
            if not char then return end
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum:GetState() ~= Enum.HumanoidStateType.Freefall then
                if hum.MoveDirection.Magnitude > 0 and hum.FloorMaterial ~= Enum.Material.Air then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    else
        if bhopConn then bhopConn:Disconnect(); bhopConn = nil end
    end
end

local function toggleStrafe(enabled)
    if enabled then
        strafeConn = RunService.Heartbeat:Connect(function(dt)
            local char = player.Character
            if not char or not char.PrimaryPart then return end
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.MoveDirection.Magnitude ~= 0 then
                char:TranslateBy(hum.MoveDirection * strafe_speed * 2 * dt)
            end
        end)
    else
        if strafeConn then strafeConn:Disconnect(); strafeConn = nil end
    end
end

local function toggleNoRender(enabled)
    pcall(function()
        player.PlayerScripts.EffectScripts.ClientFX.Disabled = enabled
    end)
    if enabled then
        noRenderConn = workspace.Runtime.ChildAdded:Connect(function(child)
            Debris:AddItem(child, 0)
        end)
    else
        if noRenderConn then noRenderConn:Disconnect(); noRenderConn = nil end
    end
end

local function GetClosestPlayer()
    local closestDist = math.huge
    local closestTarget = nil
    local Alive = workspace:FindFirstChild("Alive")
    if not Alive then return nil end
    for _, v in pairs(Alive:GetChildren()) do
        if v:FindFirstChild("HumanoidRootPart") and v ~= player.Character then
            local d = (player.Character.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
            if d < closestDist then closestDist = d; closestTarget = v end
        end
    end
    return closestTarget
end

local function get_humanoid_root_part()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function get_humanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

task.delay(10, function()
    task.spawn(function()
        while task.wait() do
            if PlayerSaftey then
                pcall(function()
                    local char = player.Character
                    if not char or (char.Parent and char.Parent.Name == "Dead") then return end
                    local cp = GetClosestPlayer()
                    if cp and (cp.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude <= PlayerSaftey_Distance then
                        char.HumanoidRootPart.CFrame = cp.HumanoidRootPart.CFrame * CFrame.new(-25, 0, -PlayerSaftey_Distance)
                    end
                end)
            end
        end
    end)
end)

task.spawn(function()
    while task.wait() do
        if AutoWalk then
            pcall(function()
                local character = player.Character
                if not character or (character.Parent and character.Parent.Name == "Dead") then return end
                local targetPos
                local ballsFolder = workspace:FindFirstChild("Balls")
                if ballsFolder then
                    for _, v in pairs(ballsFolder:GetChildren()) do
                        if v:IsA("Part") and v.Velocity.Magnitude > 5 then
                            targetPos = v.Position + Vector3.new(AutoWalkDistanceX, 0, AutoWalkDistanceZ)
                            break
                        end
                    end
                end
                if not targetPos then
                    local Alive = workspace:FindFirstChild("Alive")
                    if Alive then
                        for _, p in pairs(Alive:GetChildren()) do
                            if p ~= character and p:FindFirstChild("HumanoidRootPart") then
                                targetPos = p.HumanoidRootPart.Position + Vector3.new(AutoWalkDistanceX, 0, AutoWalkDistanceZ)
                                break
                            end
                        end
                    end
                end
                if targetPos then character:FindFirstChildOfClass("Humanoid"):MoveTo(targetPos) end
            end)
        end
        if AutoDoubleJump then
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local state = humanoid:GetState()
                if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
                    task.wait(0.1)
                else
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    task.wait(0.3)
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait() do
        if ClosestPlayer_var then
            pcall(function()
                local char = player.Character
                if not char or (char.Parent and char.Parent.Name == "Dead") then return end
                local cp = GetClosestPlayer()
                if cp and cp:FindFirstChild("Head") then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, cp.Head.Position)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(math.random(1, 2)) do
        if RandomTeleports then
            pcall(function()
                local char = player.Character
                if not char or (char.Parent and char.Parent.Name == "Dead") then return end
                local ballsFolder = workspace:FindFirstChild("Balls")
                if ballsFolder then
                    for _, v in pairs(ballsFolder:GetChildren()) do
                        if v:IsA("Part") and v.Velocity.Magnitude > 1 then
                            char.HumanoidRootPart.CFrame = v.CFrame * CFrame.new(TeleportDistanceX, 0, TeleportDistanceZ)
                            break
                        end
                    end
                end
            end)
        end
    end
end)

local function claim_rewards()
    pcall(function()
        if ReplicatedStorage:FindFirstChild("Remote") and ReplicatedStorage.Remote:FindFirstChild("RemoteEvent") then
            local event = ReplicatedStorage.Remote.RemoteEvent:FindFirstChild("ClaimLoginReward")
            if event then event:FireServer() end
        end
    end)
    task.defer(function()
        for day = 1, 30 do
            task.wait()
            pcall(function()
                if ReplicatedStorage.Remote:FindFirstChild("RemoteFunction") then
                    ReplicatedStorage.Remote.RemoteFunction:InvokeServer("ClaimNewDailyLoginReward", day)
                end
            end)
        end
    end)
    task.defer(function()
        for reward = 1, 6 do
            pcall(function() if ReplicatedStorage.Remote:FindFirstChild("RemoteFunction") then ReplicatedStorage.Remote.RemoteFunction:InvokeServer("SpinWheel") end end)
        end
    end)
end

task.defer(function()
    while task.wait(reward_interval) do
        if auto_rewards_enabled then pcall(claim_rewards) end
    end
end)

task.spawn(function()
    while true do task.wait(0.01)
        if getgenv().ASC then pcall(function() ReplicatedStorage.Remote.RemoteFunction:InvokeServer("PromptPurchaseCrate", workspace.Spawn.Crates.NormalSwordCrate) end) end
    end
end)
task.spawn(function()
    while true do task.wait(0.01)
        if getgenv().AEC then pcall(function() ReplicatedStorage.Remote.RemoteFunction:InvokeServer("PromptPurchaseCrate", workspace.Spawn.Crates.NormalExplosionCrate) end) end
    end
end)

local function startAntiAFK()
    if afkRunning then return end
    afkRunning = true
    task.spawn(function()
        while afkToggle do
            for i = 900, 1, -1 do
                if not afkToggle then break end
                task.wait(1)
            end
            if not afkToggle then break end
            for j = 1, 5 do
                local char = player.Character or player.CharacterAdded:Wait()
                local hum  = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.FloorMaterial ~= Enum.Material.Air then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
                task.wait(0.5)
            end
        end
        afkRunning = false
    end)
end

task.defer(function()
    while task.wait(1) do
        if getgenv().night_mode_Enabled then
            TweenService:Create(Lighting, TweenInfo.new(3), {ClockTime = 3.9}):Play()
        else
            TweenService:Create(Lighting, TweenInfo.new(3), {ClockTime = 13.5}):Play()
        end
    end
end)

local function applyFogSettings()
    if getgenv().remove_fog_Enabled then
        Lighting.FogEnd   = 1e10
        Lighting.FogStart = 1e10
        Lighting.FogColor = Color3.new(0, 0, 0)
    end
end
applyFogSettings()
player.CharacterAdded:Connect(function() task.wait(1); applyFogSettings() end)

local function create_ball_velocity_display(ball)
    if ball:FindFirstChild("BallVelocityDisplay") then return ball.BallVelocityDisplay:FindFirstChildOfClass("TextLabel") end
    local bg = Instance.new("BillboardGui", ball)
    bg.Name = "BallVelocityDisplay"; bg.Adornee = ball
    bg.Size = UDim2.new(0, 200, 0, 50); bg.StudsOffset = Vector3.new(0, 5, 0); bg.AlwaysOnTop = true
    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.TextScaled = true
    lbl.TextColor3 = Color3.new(1,1,1); lbl.Font = Enum.Font.Arcade; lbl.Text = ""
    return lbl
end
local lastBall = nil
RunService.RenderStepped:Connect(function()
    if not BallVelocity then
        if lastBall and lastBall:FindFirstChild("BallVelocityDisplay") then lastBall.BallVelocityDisplay:Destroy() end
        lastBall = nil; return
    end
    local ball = Auto_Parry.Get_Ball()
    if ball ~= lastBall then
        if lastBall and lastBall:FindFirstChild("BallVelocityDisplay") then lastBall.BallVelocityDisplay:Destroy() end
        if ball then
            local vt = create_ball_velocity_display(ball)
            lastBall = ball
            RunService.RenderStepped:Connect(function()
                if not BallVelocity then vt.Text = ""; return end
                if ball and vt then
                    vt.Text = string.format("Ball Speed: %.2f", ball.Velocity.Magnitude)
                    local hrp = get_humanoid_root_part()
                    if hrp then
                        local d = (ball.Position - hrp.Position).Magnitude
                        vt.TextColor3 = d > 70 and Color3.fromRGB(0,255,0) or (d > 30 and Color3.fromRGB(255,255,0) or Color3.fromRGB(255,0,0))
                    end
                end
            end)
        end
    end
end)

local function resetCamera() Camera.CameraType = Enum.CameraType.Custom end
local function startViewBallLoop()
    if _G.PhantomViewConn then _G.PhantomViewConn:Disconnect(); _G.PhantomViewConn = nil end
    _G.PhantomViewConn = RunService.RenderStepped:Connect(function()
        local ball = Auto_Parry.Get_Ball()
        if getgenv().PhantomViewBall and ball then
            Camera.CameraType = Enum.CameraType.Scriptable
            local tp = ball.Position + Vector3.new(0, 5, 15)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position:Lerp(tp, 0.05), ball.Position)
        else resetCamera() end
    end)
end

getgenv().FollowSpeed    = 1
getgenv().FollowDistance = 1000
task.spawn(function()
    local currentTween = nil
    while true do
        task.wait(0.001)
        if getgenv().FB then
            local dead = workspace:FindFirstChild("Dead")
            if dead and dead:FindFirstChild(player.Name) then
                if currentTween then currentTween:Pause(); currentTween = nil end
            else
                local ball = Auto_Parry.Get_Ball()
                local char = player.Character
                if ball and char and char.PrimaryPart then
                    if (char.PrimaryPart.Position - ball.Position).Magnitude <= tonumber(getgenv().FollowDistance) then
                        if currentTween then currentTween:Pause() end
                        currentTween = TweenService:Create(char.PrimaryPart,
                            TweenInfo.new(tonumber(getgenv().FollowSpeed), Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
                            {CFrame = ball.CFrame})
                        currentTween:Play()
                    end
                end
            end
        else
            if currentTween then currentTween:Pause(); currentTween = nil end
        end
    end
end)

ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(_, parrySourceModel)
    local Primary_Part = player.Character and player.Character.PrimaryPart
    if not Primary_Part then return end
    local Ball = Auto_Parry.Get_Ball()
    if not Ball then return end
    local Zoomies = Ball:FindFirstChild("zoomies")
    if not Zoomies then return end
    local Speed    = Zoomies.VectorVelocity.Magnitude
    local Distance = (Primary_Part.Position - Ball.Position).Magnitude
    local Pings    = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    local Speed_Threshold         = math.min(Speed / 100, 40)
    local Reach_Time              = Distance / Speed - (Pings / 1000)
    local Ball_Distance_Threshold = 15 - math.min(Distance / 1000, 15) + Speed_Threshold
    if Speed > 100 and Reach_Time > Pings / 10 then
        Ball_Distance_Threshold = math.max(Ball_Distance_Threshold - 15, 15)
    end
    if parrySourceModel ~= Primary_Part and Distance > Ball_Distance_Threshold then
        Curving = tick()
    end
end)

ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function() end)

if Runtime then
    Runtime.ChildAdded:Connect(function(tornadoChild)
        if tornadoChild.Name == "Tornado" then
            tornadoTimestamp = tick()
            isTornadoActive  = true
        end
    end)
end

local BallsFolder = workspace:WaitForChild("Balls")
BallsFolder.ChildAdded:Connect(function()   Parried = false end)
BallsFolder.ChildRemoved:Connect(function() parryCount = 0; Parried = false end)

local function randomPointOnCircle(center, radius)
    local theta = math.random() * 2 * math.pi

    return Vector3.new(
        center.X + radius * math.cos(theta),
        center.Y,
        center.Z + radius * math.sin(theta)
    )
end

local function updateLagBallGui()
    if not lagBallGui then return end
    local btn = lagBallGui:FindFirstChild("LagBallButton", true)
    if not btn then return end
    if lagBallEnabled then
        btn.Text             = "LAG BALL ON"
        btn.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
    else
        btn.Text             = "LAG BALL OFF"
        btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    end
end

local function toggleLagBall(state)
    if state == lagBallEnabled then return end
    lagBallEnabled        = state
    lagBallDesyncCFrame   = nil
    lagBallDesyncVelocity = nil
    updateLagBallGui()
end

local function createLagBallGui()
    if lagBallGui then lagBallGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "PhantomLagBall"
    screenGui.ResetOnSpawn   = false
    screenGui.DisplayOrder   = 999
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    pcall(function() screenGui.Parent = CoreGui end)

    local frame = Instance.new("Frame")
    frame.Name             = "DragFrame"
    frame.Size             = UDim2.new(0, 160, 0, 70)
    frame.Position         = UDim2.new(0.5, -80, 0, 200)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    frame.BorderSizePixel  = 0
    frame.Active           = true
    frame.Draggable        = true
    frame.Parent           = screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Name                 = "Title"
    label.Size                 = UDim2.new(1, 0, 0, 20)
    label.Position             = UDim2.new(0, 0, 0, 6)
    label.BackgroundTransparency = 1
    label.Text                 = "Lag Ball"
    label.TextColor3           = Color3.fromRGB(200, 200, 255)
    label.Font                 = Enum.Font.GothamBold
    label.TextSize             = 11
    label.Parent               = frame

    local btn = Instance.new("TextButton")
    btn.Name             = "LagBallButton"
    btn.Size             = UDim2.new(1, -16, 0, 30)
    btn.Position         = UDim2.new(0, 8, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 13
    btn.Text             = "LAG BALL OFF"
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Parent           = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    btn.MouseButton1Click:Connect(function()
        toggleLagBall(not lagBallEnabled)
    end)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3 = lagBallEnabled
                and Color3.fromRGB(0, 230, 100)
                or  Color3.fromRGB(210, 60, 60)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        updateLagBallGui()
    end)

    lagBallGui = screenGui
    updateLagBallGui()
end

RunService.Stepped:Connect(function()
    if lagBallEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        pcall(function()
            player.Character.HumanoidRootPart:SetNetworkOwner(player)
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if not lagBallEnabled then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local livePos = hrp.Position

    lagBallDesyncCFrame   = hrp.CFrame
    lagBallDesyncVelocity = hrp.AssemblyLinearVelocity

    local target = randomPointOnCircle(livePos, lagBallRadius)

    hrp.CFrame = CFrame.new(target)
    hrp.AssemblyLinearVelocity = Vector3.new(
        math.cos(tick() * 8) * 6000,
        0,
        math.sin(tick() * 8) * 6000
    )
end)

RunService.RenderStepped:Connect(function()
    if not lagBallEnabled then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not lagBallDesyncCFrame then return end

    hrp.CFrame                 = lagBallDesyncCFrame
    hrp.AssemblyLinearVelocity = lagBallDesyncVelocity
end)



local Voidex = loadstring(game:HttpGet("https://raw.githubusercontent.com/nothubman/Voidex-UI-Library/refs/heads/main/Library.lua"))()

local Window = Voidex.new({
    Name            = "Phantom Lite",
    LoadingTitle    = "PHANTOM",
    LoadingSubtitle = "BY NOTTY AND DOPPY",
})

local function Notify(title, content, duration)
    Window:Notify({ Title = title, Content = content, Duration = duration or 4 })
end

Notify("Device Detection", Device == "PC" and "PC Mode Activated" or Device == "Mobile" and "Mobile Mode Activated" or "Unknown device, defaulting to PC mode")

local Tabs = {
    Combat  = Window:AddTab({ Name = "Combat",  Icon = "sword"    }),
    Player  = Window:AddTab({ Name = "Player",  Icon = "user"     }),
    Misc    = Window:AddTab({ Name = "Misc",    Icon = "settings" }),
    Credits = Window:AddTab({ Name = "Credits", Icon = "star"     }),
}

local Combat = Tabs.Combat
local Player = Tabs.Player
local Misc   = Tabs.Misc
local Creds  = Tabs.Credits

Combat:AddSection("Auto Parry")

Combat:AddParagraph({
    Content = "No Manual Parry Needed.",
})

Combat:AddToggle({
    Name     = "Auto Parry",
    Default  = false,
    Callback = function(v)
        getgenv().ap1_notty = v
        if v then
            CreateAutoParryLoop("ap1_notty", FireParry, false)
        else
            cleanupLoop(autoParryConns, "ap1_notty")
        end
    end,
})

Combat:AddToggle({
    Name     = "Auto Spam",
    Default  = false,
    Callback = function(v) toggleAutoSpam(v) end,
})

local thresholdlol = Combat:CreateSlider({ Name = "Spam Threshold", Range = {0, 2}, Callback = function(v) spamThreshold = v end })
thresholdlol:Set(1)
Combat:AddToggle({
    Name     = "Manual Spam",
    Default  = false,
    Callback = function(v)
        if v then
            createManualSpamGui()
            Notify("Manual Spam", "Floating toggle enabled. Drag it anywhere on screen.", 5)
        else
            toggleManualSpam(false)
            if manualSpamGui then
                manualSpamGui:Destroy()
                manualSpamGui = nil
            end
        end
    end,
})

Combat:AddSection("Lobby Auto Parry")

Combat:AddToggle({
    Name     = "Auto Parry (Lobby)",
    Default  = false,
    Callback = function(value)
        if value then
            Connections_Manager["Lobby AP"] = RunService.Heartbeat:Connect(function()
                local Ball = Auto_Parry.Lobby_Balls()
                if not Ball then return end
                local Zoomies = Ball:FindFirstChild("zoomies")
                if not Zoomies then return end
                Ball:GetAttributeChangedSignal("target"):Once(function() Training_Parried = false end)
                if Training_Parried then return end
                local Ball_Target = Ball:GetAttribute("target")
                local Speed       = Zoomies.VectorVelocity.Magnitude
                local Distance    = player:DistanceFromCharacter(Ball.Position)
                local Ping        = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
                local cappedDiff  = math.min(math.max(Speed - 9.5, 0), 650)
                local divisor     = (2.4 + cappedDiff * 0.002) * 1.1
                local Accuracy    = Ping + math.max(Speed / divisor, 9.5)
                if Ball_Target == tostring(player) and Distance <= Accuracy then
                    FireParry()
                    Training_Parried = true
                end
                local t0 = tick()
                repeat RunService.PreSimulation:Wait() until (tick() - t0) >= 1 or not Training_Parried
                Training_Parried = false
            end)
        else
            if Connections_Manager["Lobby AP"] then Connections_Manager["Lobby AP"]:Disconnect(); Connections_Manager["Lobby AP"] = nil end
        end
    end,
})

Combat:AddSection("Visualizer & Ball")

Combat:AddToggle({
    Name     = "Parry Range Visualizer",
    Default  = false,
    Callback = function(v)
        isVisualizerActive = v
        if not v then visualizerPart.Size = Vector3.new(0, 0, 0) end
    end,
})

Combat:AddToggle({
    Name     = "Ball Statistics",
    Default  = false,
    Callback = function(v) BallVelocity = v end,
})

Combat:AddToggle({
    Name     = "View Ball",
    Default  = false,
    Callback = function(v)
        pcall(function()
            getgenv().PhantomViewBall = v
            if v then startViewBallLoop()
            else
                if _G.PhantomViewConn then _G.PhantomViewConn:Disconnect(); _G.PhantomViewConn = nil end
                resetCamera()
            end
        end)
    end,
})

Combat:AddSection("Follow Ball")

Combat:AddToggle({
    Name     = "Follow Ball",
    Default  = false,
    Callback = function(v) getgenv().FB = v end,
})

Combat:CreateSlider({
    Name     = "Follow Speed",
    Range = {1, 50},
    Callback = function(v) getgenv().FollowSpeed = v end,
})

Combat:CreateSlider({
    Name     = "Follow Distance",
    Range = {1, 1000},
    Callback = function(v) getgenv().FollowDistance = v end,
})

Combat:AddSection("Lag Ball")

Combat:AddToggle({
    Name     = "Lag Ball",
    Default  = false,
    Callback = function(v)
        lagBallActive = v
        if v then
            createLagBallGui()
            Notify("Lag Ball", "Floating toggle enabled. Drag it anywhere on screen.", 5)
        else
            toggleLagBall(false)
            if lagBallGui then
                lagBallGui:Destroy()
                lagBallGui = nil
            end
        end
    end,
})

local pingLabel = Combat:AddParagraph({
    Title   = "Live Info",
    Content = "Ping: 0ms  |  Ball Speed: 0",
})
RunService.Heartbeat:Connect(function()
    local ping  = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    local ball  = Auto_Parry.Get_Ball()
    local speed = 0
    if ball then
        local z = ball:FindFirstChild("zoomies")
        if z then speed = math.floor(z.VectorVelocity.Magnitude) end
    end
    pingLabel:Set({ Content = "Ping: " .. ping .. "ms  |  Ball Speed: " .. speed })
end)

Player:AddSection("Movement")

Player:AddToggle({
    Name     = "Auto Walk",
    Default  = false,
    Callback = function(v) AutoWalk = v end,
})

Player:AddToggle({
    Name     = "Auto Jump",
    Default  = false,
    Callback = function(v) AutoDoubleJump = v end,
})

Player:AddToggle({
    Name     = "Player Safety",
    Default  = false,
    Callback = function(v) PlayerSaftey = v end,
})

Player:AddToggle({
    Name     = "Random Teleports",
    Default  = false,
    Callback = function(v) RandomTeleports = v end,
})

Player:AddToggle({
    Name     = "Closest Player Focus",
    Default  = false,
    Callback = function(v) ClosestPlayer_var = v end,
})

Player:CreateSlider({ Name = "Auto Walk X",           Range = {0, 50}, Callback = function(v) AutoWalkDistanceX     = v end })
Player:CreateSlider({ Name = "Auto Walk Z",           Range = {0, 50}, Callback = function(v) AutoWalkDistanceZ     = v end })
Player:CreateSlider({ Name = "Player Safety Distance",Range = {1, 100}, Callback = function(v) PlayerSaftey_Distance = v end })
Player:CreateSlider({ Name = "Teleport X",            Range = {0, 50}, Callback = function(v) TeleportDistanceX     = v end })
Player:CreateSlider({ Name = "Teleport Z",            Range = {0, 50}, Callback = function(v) TeleportDistanceZ     = v end })

Player:AddSection("Rewards")

Player:AddToggle({
    Name     = "Auto Claim Rewards",
    Default  = false,
    Callback = function(v) auto_rewards_enabled = v end,
})

Player:CreateSlider({ Name = "Claim Interval (secs)", Range = {5, 300}, Callback = function(v) reward_interval = v end })

Player:AddButton({
    Name     = "Claim Now",
    Callback = function() claim_rewards(); Notify("Rewards", "Rewards claimed!") end,
})

Player:AddSection("VIP Tag")

Player:AddButton({
    Name     = "Get VIP Tag",
    Callback = function()
        local TCS = game:GetService("TextChatService")
        local SG  = game:GetService("StarterGui")
        local tag = "<font color='#FFFF00'>[VIP]</font> " .. player.Name
        if TCS.ChatVersion == Enum.ChatVersion.LegacyChatService then
            player.Chatted:Connect(function(msg)
                SG:SetCore("ChatMakeSystemMessage", { Text = tag .. ": " .. msg, Color = Color3.new(1,1,1), Font = Enum.Font.SourceSansBold, TextSize = 18 })
            end)
        else
            TCS.OnIncomingMessage = function(message)
                if message.TextSource then
                    local sender = Players:GetPlayerByUserId(message.TextSource.UserId)
                    if sender and sender == player then message.PrefixText = tag end
                end
            end
        end
        Notify("VIP Tag", "VIP tag applied!")
    end,
})

Player:AddSection("Server")

Player:AddButton({
    Name     = "Copy Job ID",
    Callback = function()
        if setclipboard then setclipboard(currentJobId) end
        Notify("Server", "Job ID copied!")
    end,
})

Player:AddTextbox({
    Name            = "Teleport to Job ID",
    PlaceholderText = "Paste Job ID here",
    Default         = "",
    Callback        = function(v, entered)
        if entered and v ~= "" then
            Notify("Server", "Teleporting...")
            task.wait(0.5)
            TeleportService:TeleportToPlaceInstance(game.PlaceId, v, player)
        end
    end,
})

Misc:AddSection("Movement")

Misc:AddToggle({ Name = "BHop",   Default = false, Callback = function(v) toggleBhop(v)   end })
Misc:AddToggle({ Name = "Strafe", Default = false, Callback = function(v) toggleStrafe(v) end })
Misc:CreateSlider({ Name = "Strafe Speed", Range = {1, 40}, Callback = function(v) strafe_speed = v end })

Misc:AddSection("Performance")

Misc:AddToggle({ Name = "No Render (FPS Boost)", Default = false, Callback = function(v) toggleNoRender(v) end })

Misc:AddToggle({
    Name     = "Anti Lag",
    Default  = false,
    Callback = function(state)
        antiLagActive = state
        if state then
            for _, O in ipairs(workspace:GetDescendants()) do
                if O:IsA("BasePart") and not (O:FindFirstAncestorWhichIsA("Model") and O:FindFirstAncestorWhichIsA("Model"):FindFirstChild("Humanoid")) then
                    originalMaterials[O] = O.Material; O.Material = Enum.Material.SmoothPlastic; O.Reflectance = 0
                elseif O:IsA("Decal") or O:IsA("Texture") then
                    table.insert(originalDecalsTextures, {Object=O, Parent=O.Parent}); O.Parent = nil
                elseif O:IsA("ParticleEmitter") or O:IsA("Smoke") or O:IsA("Fire") or O:IsA("Sparkles") then O.Enabled = false end
            end
            workspace.DescendantAdded:Connect(function(O)
                if not antiLagActive then return end
                task.defer(function()
                    if O:IsA("BasePart") and not (O:FindFirstAncestorWhichIsA("Model") and O:FindFirstAncestorWhichIsA("Model"):FindFirstChild("Humanoid")) then
                        originalMaterials[O] = O.Material; O.Material = Enum.Material.SmoothPlastic; O.Reflectance = 0
                    elseif O:IsA("Decal") or O:IsA("Texture") then
                        table.insert(originalDecalsTextures, {Object=O, Parent=O.Parent}); O.Parent = nil
                    elseif O:IsA("ParticleEmitter") or O:IsA("Smoke") or O:IsA("Fire") or O:IsA("Sparkles") then O.Enabled = false end
                end)
            end)
        else
            for O, mat in pairs(originalMaterials) do if O and O:IsA("BasePart") then O.Material = mat end end
            for _, d in pairs(originalDecalsTextures) do if d.Object and d.Parent then d.Object.Parent = d.Parent end end
            originalMaterials = {}; originalDecalsTextures = {}
        end
    end,
})

Misc:AddToggle({ Name = "Night Mode",  Default = false, Callback = function(v) getgenv().night_mode_Enabled   = v end })
Misc:AddToggle({ Name = "Remove Fog",  Default = false, Callback = function(v) getgenv().remove_fog_Enabled   = v; applyFogSettings() end })

Misc:AddSection("Player")

Misc:AddToggle({
    Name     = "Anti AFK",
    Default  = false,
    Callback = function(v) afkToggle = v; if v then startAntiAFK() end end,
})

Misc:AddSection("Crates")

Misc:AddButton({ Name = "Open Sword Crate",     Callback = function() pcall(function() ReplicatedStorage.Remote.RemoteFunction:InvokeServer("PromptPurchaseCrate", workspace.Spawn.Crates.NormalSwordCrate)     end) end })
Misc:AddButton({ Name = "Open Explosion Crate", Callback = function() pcall(function() ReplicatedStorage.Remote.RemoteFunction:InvokeServer("PromptPurchaseCrate", workspace.Spawn.Crates.NormalExplosionCrate) end) end })
Misc:AddToggle({ Name = "Auto Buy Sword Crates",     Default = false, Callback = function(v) getgenv().ASC = v end })
Misc:AddToggle({ Name = "Auto Buy Explosion Crates", Default = false, Callback = function(v) getgenv().AEC = v end })

Creds:AddSection("Credits")

Creds:AddParagraph({
    Content = "Phantom Hub - By Notty and Doppy",
})

Creds:AddParagraph({
    Content = "Logic - Made by Notty",
})

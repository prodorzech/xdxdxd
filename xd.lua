--// Rayfield z wymuszonym szarym motywem
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Wymuś szary kolor paska i tła
local CustomTheme = {
    Background = Color3.fromRGB(30, 30, 30),
    Glow = Color3.fromRGB(0, 0, 0),
    Accent = Color3.fromRGB(80, 80, 80),
    LightAccent = Color3.fromRGB(100, 100, 100),
    DarkAccent = Color3.fromRGB(20, 20, 20),
    Text = Color3.fromRGB(220, 220, 220),
    TextDark = Color3.fromRGB(150, 150, 150),
    Shadow = Color3.fromRGB(0, 0, 0),
}
Rayfield:ApplyTheme(CustomTheme)

local Window = Rayfield:CreateWindow({
    Name = "Lemon Fucks",
    LoadingTitle = "MVP Mafia Presents",
    LoadingSubtitle = "By MVP Mafia",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)
local FlyTab = Window:CreateTab("Fly", 4483362458)

--// Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// Find Tycoon (twój oryginalny kod – nie zmieniam)
local userTycoon = (function()
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Folder") and v.Name:match("Tycoon%d") then
            if v:FindFirstChild("Owner") and v.Owner.Value == LocalPlayer then
                return v
            end
        end
    end
end)()

if not userTycoon then
    Rayfield:Notify({ Title = "Error", Content = "Tycoon not found!", Duration = 5 })
    return
end

--// Zmienne tycoon
local AutoBuy = false
local AutoUpgrade = false
local AutoFruit = false
local Buying = false

--// FLY variables
local flying = false
local flySpeed = 50
local flyKey = Enum.KeyCode.F
local bodyVelocity = nil
local bodyGyro = nil
local flyConnection = nil
local flyMoveConnection = nil
local flyInputEndedConnection = nil

--// Funkcje tycoon (oryginalne)
local function getButtons()
    local Buttons = {}
    for _, obj in ipairs(userTycoon.Purchases:GetDescendants()) do
        if obj:IsA("Model") then
            local shown = obj:GetAttribute("Shown")
            local purchased = obj:GetAttribute("Purchased")
            if shown == true and purchased ~= true then
                local buttonPart = obj:FindFirstChild("Button")
                if buttonPart and buttonPart:IsA("BasePart") then
                    table.insert(Buttons, { Name = obj.Name, Button = buttonPart })
                end
            end
        end
    end
    return Buttons
end

local function buyButton(buttonData)
    if Buying then return end
    Buying = true
    local character = LocalPlayer.Character
    if not character then Buying = false return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then Buying = false return end
    pcall(function()
        firetouchinterest(hrp, buttonData.Button, 0)
        firetouchinterest(hrp, buttonData.Button, 1)
    end)
    Buying = false
end

task.spawn(function()
    while true do
        task.wait(0.0000001)
        if AutoBuy then
            for _, button in ipairs(getButtons()) do
                pcall(function() buyButton(button) end)
            end
        end
    end
end)

local function upgradeMachines()
    for _, obj in ipairs(userTycoon.Purchases:GetDescendants()) do
        if obj:IsA("RemoteFunction") and obj.Name == "Upgrade" then
            pcall(function()
                for level = 1, 100 do obj:InvokeServer(level) end
            end)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.00001)
        if AutoUpgrade then pcall(upgradeMachines) end
    end
end)

local Trees = {}
local function addTree(obj)
    if obj:IsA("Model") and obj.Name == "LemonTree" and not table.find(Trees, obj) then
        table.insert(Trees, obj)
    end
end
local function removeTree(obj)
    local idx = table.find(Trees, obj)
    if idx then table.remove(Trees, idx) end
end

for _, v in ipairs(workspace:GetDescendants()) do addTree(v) end
workspace.DescendantAdded:Connect(addTree)
workspace.DescendantRemoving:Connect(removeTree)

local function noCollisionTree(tree)
    for _, obj in ipairs(tree:GetDescendants()) do
        if obj:IsA("BasePart") then obj.CanCollide = false end
    end
end

local function teleportToTree(tree)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = tree:GetPivot() + Vector3.new(0, 5, 0)
    return true
end

local function collectFruit(tree)
    noCollisionTree(tree)
    if not teleportToTree(tree) then return end
    for _, obj in ipairs(tree:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Fruit" then
            obj.CanCollide = false
            local clickPart = obj:FindFirstChild("ClickPart")
            if clickPart then
                local detector = clickPart:FindFirstChildOfClass("ClickDetector")
                if detector then
                    task.wait(0.45)
                    pcall(function() fireclickdetector(detector) end)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if AutoFruit then
            for _, tree in ipairs(Trees) do
                if not AutoFruit then break end
                if tree and tree.Parent then pcall(function() collectFruit(tree) end) end
            end
        end
    end
end)

--// FLY (poprawione sterowanie W/S)
local function stopFly()
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    if flyConnection then flyConnection:Disconnect() end
    if flyMoveConnection then flyMoveConnection:Disconnect() end
    if flyInputEndedConnection then flyInputEndedConnection:Disconnect() end
    bodyVelocity = nil; bodyGyro = nil; flyConnection = nil; flyMoveConnection = nil; flyInputEndedConnection = nil
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

local function startFly()
    stopFly()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum.PlatformStand = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Parent = hrp

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.Parent = hrp

    local moveVec = Vector3.new()
    local camera = workspace.CurrentCamera
    local keys = { W = false, A = false, S = false, D = false, Space = false, Ctrl = false }
    local function update()
        moveVec = Vector3.new(
            (keys.D and 1 or 0) - (keys.A and 1 or 0),
            (keys.Space and 1 or 0) - (keys.Ctrl and 1 or 0),
            (keys.W and 1 or 0) - (keys.S and 1 or 0)   -- W = przód (+Z), S = tył (-Z)
        )
        if moveVec.Magnitude > 0 then moveVec = moveVec.Unit end
    end

    local function onInputBegan(input, gp)
        if gp then return end
        local k = input.KeyCode
        if k == Enum.KeyCode.W then keys.W = true update()
        elseif k == Enum.KeyCode.A then keys.A = true update()
        elseif k == Enum.KeyCode.S then keys.S = true update()
        elseif k == Enum.KeyCode.D then keys.D = true update()
        elseif k == Enum.KeyCode.Space then keys.Space = true update()
        elseif k == Enum.KeyCode.LeftControl then keys.Ctrl = true update()
        end
    end
    local function onInputEnded(input, gp)
        local k = input.KeyCode
        if k == Enum.KeyCode.W then keys.W = false update()
        elseif k == Enum.KeyCode.A then keys.A = false update()
        elseif k == Enum.KeyCode.S then keys.S = false update()
        elseif k == Enum.KeyCode.D then keys.D = false update()
        elseif k == Enum.KeyCode.Space then keys.Space = false update()
        elseif k == Enum.KeyCode.LeftControl then keys.Ctrl = false update()
        end
    end
    flyMoveConnection = UserInputService.InputBegan:Connect(onInputBegan)
    flyInputEndedConnection = UserInputService.InputEnded:Connect(onInputEnded)

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying then return end
        local newChar = LocalPlayer.Character
        if not newChar or newChar ~= char then
            flying = false
            stopFly()
            return
        end
        local newHrp = newChar:FindFirstChild("HumanoidRootPart")
        if not newHrp then return end
        local camCF = camera.CFrame
        local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
        local right = camCF.RightVector
        local up = Vector3.new(0,1,0)
        local dir = forward * moveVec.Z + right * moveVec.X + up * moveVec.Y
        if dir.Magnitude > 0 then dir = dir.Unit end
        bodyVelocity.Velocity = dir * flySpeed
        bodyGyro.CFrame = CFrame.lookAt(newHrp.Position, newHrp.Position + camCF.LookVector)
    end)
end

local function toggleFly()
    if flying then
        flying = false
        stopFly()
        Rayfield:Notify({ Title = "Fly", Content = "Disabled", Duration = 2 })
    else
        flying = true
        startFly()
        Rayfield:Notify({ Title = "Fly", Content = "Enabled (WASD + Space/Ctrl)", Duration = 2 })
    end
end

-- Keybind do włączania/wyłączania
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == flyKey then toggleFly() end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if flying then
        flying = false
        stopFly()
    end
end)

--// UI
MainTab:CreateToggle({
    Name = "Auto Buy",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(v) AutoBuy = v; Rayfield:Notify({ Title = "Auto Buy", Content = v and "Enabled" or "Disabled", Duration = 3 }) end,
})
MainTab:CreateToggle({
    Name = "Auto Upgrade",
    CurrentValue = false,
    Flag = "AutoUpgrade",
    Callback = function(v) AutoUpgrade = v; Rayfield:Notify({ Title = "Auto Upgrade", Content = v and "Enabled" or "Disabled", Duration = 3 }) end,
})
MainTab:CreateToggle({
    Name = "Auto Fruit",
    CurrentValue = false,
    Flag = "AutoFruit",
    Callback = function(v) AutoFruit = v; Rayfield:Notify({ Title = "Auto Fruit", Content = v and "Enabled" or "Disabled", Duration = 3 }) end,
})
MainTab:CreateButton({
    Name = "Destroy GUI",
    Callback = function() Rayfield:Destroy() end,
})

-- Fly Tab z wyświetlaniem aktualnego klawisza
local keyDisplay = FlyTab:CreateParagraph({
    Title = "Current Fly Key",
    Content = tostring(flyKey):gsub("Enum.KeyCode.", ""),
})

FlyTab:CreateToggle({
    Name = "Fly (Toggle)",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(v)
        if v then if not flying then toggleFly() end else if flying then toggleFly() end end
    end,
})

FlyTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 5,
    Suffix = "studs/s",
    CurrentValue = flySpeed,
    Flag = "FlySpeed",
    Callback = function(v) flySpeed = v end,
})

FlyTab:CreateButton({
    Name = "Change Fly Keybind",
    Callback = function()
        Rayfield:Notify({ Title = "Fly Keybind", Content = "Press any key within 5 seconds...", Duration = 5 })
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            flyKey = input.KeyCode
            keyDisplay:Set({
                Title = "Current Fly Key",
                Content = tostring(flyKey):gsub("Enum.KeyCode.", ""),
            })
            Rayfield:Notify({ Title = "Fly Keybind", Content = "Set to " .. tostring(flyKey), Duration = 3 })
            conn:Disconnect()
        end)
        task.delay(5, function() if conn then conn:Disconnect() end end)
    end,
})

Rayfield:Notify({ Title = "Loaded", Content = "Tycoon + Fly (szary motyw, poprawione W/S)", Duration = 5 })

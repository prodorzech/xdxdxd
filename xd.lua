--[[
    POPRAWIONY SKRYPT LEMON TYCOON
    MVP Mafia
]]

-- Bezpieczne ładowanie Rayfield
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success then
    return
end

-- Tworzenie GUI
local Window = Rayfield:CreateWindow({
    Name = "Lemon Fucks v2",
    LoadingTitle = "MVP Mafia Presents",
    LoadingSubtitle = "By MVP Mafia",
    ConfigurationSaving = { Enabled = false, FolderName = nil, FileName = "LemonFucks" },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)
local FlyTab = Window:CreateTab("Fly", 4483362458)

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Znajdź swój Tycoon
local userTycoon
for _, v in pairs(workspace:GetChildren()) do
    if v:IsA("Folder") and v.Name:match("Tycoon%d") then
        if v:FindFirstChild("Owner") and v.Owner.Value == LocalPlayer then
            userTycoon = v
            break
        end
    end
end

if not userTycoon then
    Rayfield:Notify({ Title = "Error", Content = "Twój Tycoon nie został znaleziony!", Duration = 5 })
    return
end

-- Zmienne
local AutoBuy = false
local AutoUpgrade = false
local AutoFruit = false

-- Zmienne do latania
local flying = false
local flySpeed = 50
local flyKey = Enum.KeyCode.F
local bodyVelocity = nil
local bodyGyro = nil
local flyConnection = nil
local flyMoveConnection = nil
local flyInputEndedConnection = nil

-- Funkcje Tycoon
local function getButtons()
    local Buttons = {}
    for _, obj in ipairs(userTycoon.Purchases:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("Shown") == true and obj:GetAttribute("Purchased") ~= true then
            local buttonPart = obj:FindFirstChild("Button")
            if buttonPart and buttonPart:IsA("BasePart") then
                table.insert(Buttons, buttonPart)
            end
        end
    end
    return Buttons
end

local function buyButton(buttonPart)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if hrp and buttonPart then
        pcall(function()
            firetouchinterest(hrp, buttonPart, 0)
            firetouchinterest(hrp, buttonPart, 1)
        end)
    end
end

local function upgradeMachines()
    for _, obj in ipairs(userTycoon.Purchases:GetDescendants()) do
        if obj:IsA("RemoteFunction") and obj.Name == "Upgrade" then
            pcall(function()
                for level = 1, 100 do
                    obj:InvokeServer(level)
                end
            end)
        end
    end
end

-- Drzewa
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

workspace.DescendantAdded:Connect(addTree)
workspace.DescendantRemoving:Connect(removeTree)
for _, v in ipairs(workspace:GetDescendants()) do addTree(v) end

local function collectFruit(tree)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    pcall(function()
        hrp.CFrame = tree:GetPivot() + Vector3.new(0, 5, 0)
        task.wait()
        for _, obj in ipairs(tree:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == "Fruit" then
                local detector = obj:FindFirstChild("ClickPart", true):FindFirstChildOfClass("ClickDetector")
                if detector then
                    fireclickdetector(detector)
                end
            end
        end
    end)
end

-- Pętle
task.spawn(function()
    while true do
        task.wait()
        if AutoBuy then
            for _, buttonPart in ipairs(getButtons()) do
                pcall(buyButton, buttonPart)
            end
        end
        if AutoUpgrade then
            pcall(upgradeMachines)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if AutoFruit then
            for _, tree in ipairs(Trees) do
                if not AutoFruit then break end
                if tree and tree.Parent then
                    pcall(collectFruit, tree)
                end
            end
        end
    end
end)

-- Latanie
local function stopFly()
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    if flyConnection then flyConnection:Disconnect() end
    if flyMoveConnection then flyMoveConnection:Disconnect() end
    if flyInputEndedConnection then flyInputEndedConnection:Disconnect() end
    bodyVelocity = nil
    bodyGyro = nil
    flyConnection = nil
    flyMoveConnection = nil
    flyInputEndedConnection = nil

    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
    end
end

local function startFly()
    stopFly()
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.PlatformStand = true

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVelocity.Parent = hrp

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.Parent = hrp

    local moveVec = Vector3.new()
    local camera = workspace.CurrentCamera
    local keys = { W = false, A = false, S = false, D = false, Space = false, Ctrl = false }

    local function updateMoveVec()
        moveVec = Vector3.new(
            (keys.D and 1 or 0) - (keys.A and 1 or 0),
            (keys.Space and 1 or 0) - (keys.Ctrl and 1 or 0),
            (keys.W and 1 or 0) - (keys.S and 1 or 0)
        )
        if moveVec.Magnitude > 0 then
            moveVec = moveVec.Unit
        end
    end

    local function onInputBegan(input, gameProcessed)
        if gameProcessed then return end
        local key = input.KeyCode
        if key == Enum.KeyCode.W then keys.W = true updateMoveVec()
        elseif key == Enum.KeyCode.A then keys.A = true updateMoveVec()
        elseif key == Enum.KeyCode.S then keys.S = true updateMoveVec()
        elseif key == Enum.KeyCode.D then keys.D = true updateMoveVec()
        elseif key == Enum.KeyCode.Space then keys.Space = true updateMoveVec()
        elseif key == Enum.KeyCode.LeftControl then keys.Ctrl = true updateMoveVec()
        end
    end

    local function onInputEnded(input, gameProcessed)
        local key = input.KeyCode
        if key == Enum.KeyCode.W then keys.W = false updateMoveVec()
        elseif key == Enum.KeyCode.A then keys.A = false updateMoveVec()
        elseif key == Enum.KeyCode.S then keys.S = false updateMoveVec()
        elseif key == Enum.KeyCode.D then keys.D = false updateMoveVec()
        elseif key == Enum.KeyCode.Space then keys.Space = false updateMoveVec()
        elseif key == Enum.KeyCode.LeftControl then keys.Ctrl = false updateMoveVec()
        end
    end

    flyMoveConnection = UserInputService.InputBegan:Connect(onInputBegan)
    flyInputEndedConnection = UserInputService.InputEnded:Connect(onInputEnded)

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flying then return end
        local newChar = LocalPlayer.Character
        if not newChar or newChar ~= character then
            flying = false
            stopFly()
            return
        end
        local newHrp = newChar:FindFirstChild("HumanoidRootPart")
        if not newHrp then return end

        local cameraCF = camera.CFrame
        local forward = Vector3.new(cameraCF.LookVector.X, 0, cameraCF.LookVector.Z).Unit
        local right = cameraCF.RightVector
        local up = Vector3.new(0, 1, 0)

        local direction = (forward * moveVec.Z) + (right * moveVec.X) + (up * moveVec.Y)
        if direction.Magnitude > 0 then direction = direction.Unit end

        bodyVelocity.Velocity = direction * flySpeed
        bodyGyro.CFrame = CFrame.lookAt(newHrp.Position, newHrp.Position + cameraCF.LookVector)
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == flyKey then
        toggleFly()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    if flying then
        flying = false
        stopFly()
    end
end)

-- Interfejs
MainTab:CreateToggle({
    Name = "Auto Buy",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(Value) AutoBuy = Value
        Rayfield:Notify({ Title = "Auto Buy", Content = Value and "Enabled" or "Disabled", Duration = 3 })
    end,
})

MainTab:CreateToggle({
    Name = "Auto Upgrade",
    CurrentValue = false,
    Flag = "AutoUpgrade",
    Callback = function(Value) AutoUpgrade = Value
        Rayfield:Notify({ Title = "Auto Upgrade", Content = Value and "Enabled" or "Disabled", Duration = 3 })
    end,
})

MainTab:CreateToggle({
    Name = "Auto Fruit",
    CurrentValue = false,
    Flag = "AutoFruit",
    Callback = function(Value) AutoFruit = Value
        Rayfield:Notify({ Title = "Auto Fruit", Content = Value and "Enabled" or "Disabled", Duration = 3 })
    end,
})

MainTab:CreateButton({
    Name = "Destroy GUI",
    Callback = function()
        Rayfield:Destroy()
    end,
})

local keyDisplay = FlyTab:CreateParagraph({
    Title = "Current Fly Key",
    Content = tostring(flyKey):gsub("Enum.KeyCode.", ""),
})

FlyTab:CreateToggle({
    Name = "Fly (Toggle)",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(Value)
        if Value then
            if not flying then toggleFly() end
        else
            if flying then toggleFly() end
        end
    end,
})

FlyTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 5,
    Suffix = "studs/s",
    CurrentValue = flySpeed,
    Flag = "FlySpeed",
    Callback = function(Value) flySpeed = Value end,
})

FlyTab:CreateButton({
    Name = "Change Fly Keybind",
    Callback = function()
        Rayfield:Notify({ Title = "Fly Keybind", Content = "Press any key within 5 seconds...", Duration = 5 })
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
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

Rayfield:Notify({ Title = "Loaded", Content = "Skrypt działa! (W/S poprawione)", Duration = 5 })

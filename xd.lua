--// Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

--// Wymuszenie ciemnoszarego motywu (pasek i tło)
Rayfield:ApplyTheme({
    Background = Color3.fromRGB(25, 25, 25),
    Accent = Color3.fromRGB(80, 80, 80),
    Text = Color3.fromRGB(200, 200, 200),
    -- reszta domyślna
})

local Window = Rayfield:CreateWindow({
    Name = "Lemon Fucks",
    LoadingTitle = "MVP Mafia Presents",
    LoadingSubtitle = "By MVP Mafia",
    ConfigurationSaving = {
        Enabled = false,
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)
local FlyTab = Window:CreateTab("Fly", 4483362458)

--// Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// Find Tycoon
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
    Rayfield:Notify({
        Title = "Error",
        Content = "Tycoon not found!",
        Duration = 5,
    })
    return
end

--// Variables for tycoon
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

--// Tycoon functions (original - nie zmieniamy)
local function getButtons()
    local Buttons = {}
    for _, obj in ipairs(userTycoon.Purchases:GetDescendants()) do
        if obj:IsA("Model") then
            local shown = obj:GetAttribute("Shown")
            local purchased = obj:GetAttribute("Purchased")
            if shown == true and purchased ~= true then
                local buttonPart = obj:FindFirstChild("Button")
                if buttonPart and buttonPart:IsA("BasePart") then
                    table.insert(Buttons, {
                        Name = obj.Name,
                        Button = buttonPart,
                    })
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
    if not character then Buying = false; return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then Buying = false; return end
    local buttonPart = buttonData.Button
    pcall(function()
        firetouchinterest(hrp, buttonPart, 0)
        firetouchinterest(hrp, buttonPart, 1)
    end)
    Buying = false
end

task.spawn(function()
    while true do
        task.wait(0.0000001)
        if AutoBuy then
            local Buttons = getButtons()
            for _, button in ipairs(Buttons) do
                pcall(function() buyButton(button) end)
            end
        end
    end
end)

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

task.spawn(function()
    while true do
        task.wait(0.00001)
        if AutoUpgrade then
            pcall(function() upgradeMachines() end)
        end
    end
end)

local Trees = {}
local function addTree(obj)
    if obj:IsA("Model") and obj.Name == "LemonTree" then
        if not table.find(Trees, obj) then
            table.insert(Trees, obj)
        end
    end
end
local function removeTree(obj)
    local index = table.find(Trees, obj)
    if index then table.remove(Trees, index) end
end

for _, v in ipairs(workspace:GetDescendants()) do addTree(v) end
workspace.DescendantAdded:Connect(addTree)
workspace.DescendantRemoving:Connect(removeTree)

local function noCollisionTree(tree)
    for _, obj in ipairs(tree:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CanCollide = false
        end
    end
end

local function teleportToTree(tree)
    local character = LocalPlayer.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local cf = tree:GetPivot()
    hrp.CFrame = cf + Vector3.new(0, 5, 0)
    return true
end

local function collectFruit(tree)
    noCollisionTree(tree)
    local success = teleportToTree(tree)
    if not success then return end
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
                if tree and tree.Parent then
                    pcall(function() collectFruit(tree) end)
                end
            end
        end
    end
end)

--// FLY FUNCTIONS (poprawiona orientacja W/S)
local function stopFly()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if flyMoveConnection then flyMoveConnection:Disconnect() flyMoveConnection = nil end
    if flyInputEndedConnection then flyInputEndedConnection:Disconnect() flyInputEndedConnection = nil end
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
    bodyVelocity.Velocity = Vector3.new(0,0,0)
    bodyVelocity.Parent = hrp

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    local moveVector = Vector3.new(0,0,0)
    local camera = workspace.CurrentCamera

    local keys = { W = false, A = false, S = false, D = false, Space = false, Ctrl = false }
    local function updateMoveVector()
        -- POPRAWA: W -> przód (dodatni Z), S -> tył (ujemny Z)
        moveVector = Vector3.new(
            (keys.D and 1 or 0) - (keys.A and 1 or 0),                     -- X (prawy-lewy)
            (keys.Space and 1 or 0) - (keys.Ctrl and 1 or 0),               -- Y (góra-dół)
            (keys.W and 1 or 0) - (keys.S and 1 or 0)                       -- Z (przód-tył) – teraz W daje +1, S daje -1
        )
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit
        end
    end

    local function onInputBegan(input, gameProcessed)
        if gameProcessed then return end
        local key = input.KeyCode
        if key == Enum.KeyCode.W then keys.W = true updateMoveVector()
        elseif key == Enum.KeyCode.A then keys.A = true updateMoveVector()
        elseif key == Enum.KeyCode.S then keys.S = true updateMoveVector()
        elseif key == Enum.KeyCode.D then keys.D = true updateMoveVector()
        elseif key == Enum.KeyCode.Space then keys.Space = true updateMoveVector()
        elseif key == Enum.KeyCode.LeftControl then keys.Ctrl = true updateMoveVector()
        end
    end

    local function onInputEnded(input, gameProcessed)
        local key = input.KeyCode
        if key == Enum.KeyCode.W then keys.W = false updateMoveVector()
        elseif key == Enum.KeyCode.A then keys.A = false updateMoveVector()
        elseif key == Enum.KeyCode.S then keys.S = false updateMoveVector()
        elseif key == Enum.KeyCode.D then keys.D = false updateMoveVector()
        elseif key == Enum.KeyCode.Space then keys.Space = false updateMoveVector()
        elseif key == Enum.KeyCode.LeftControl then keys.Ctrl = false updateMoveVector()
        end
    end

    flyMoveConnection = UserInputService.InputBegan:Connect(onInputBegan)
    flyInputEndedConnection = UserInputService.InputEnded:Connect(onInputEnded)

    flyConnection = RunService.RenderStepped:Connect(function(dt)
        if not flying then return end
        local newChar = LocalPlayer.Character
        if not newChar or newChar ~= character then
            flying = false
            stopFly()
            return
        end
        local newHrp = newChar:FindFirstChild("HumanoidRootPart")
        local newHumanoid = newChar:FindFirstChildOfClass("Humanoid")
        if not newHrp or not newHumanoid then return end

        local cameraCF = camera.CFrame
        local lookVector = cameraCF.LookVector
        local forward = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
        local right = cameraCF.RightVector
        local up = Vector3.new(0,1,0)

        local direction = (forward * moveVector.Z + right * moveVector.X + up * moveVector.Y)
        if direction.Magnitude > 0 then
            direction = direction.Unit
        end
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

-- Keybind
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

--// UI Elements (Main tab - oryginalne)
MainTab:CreateToggle({
    Name = "Auto Buy",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(Value)
        AutoBuy = Value
        Rayfield:Notify({ Title = "Auto Buy", Content = Value and "Enabled" or "Disabled", Duration = 3 })
    end,
})

MainTab:CreateToggle({
    Name = "Auto Upgrade",
    CurrentValue = false,
    Flag = "AutoUpgrade",
    Callback = function(Value)
        AutoUpgrade = Value
        Rayfield:Notify({ Title = "Auto Upgrade", Content = Value and "Enabled" or "Disabled", Duration = 3 })
    end,
})

MainTab:CreateToggle({
    Name = "Auto Fruit",
    CurrentValue = false,
    Flag = "AutoFruit",
    Callback = function(Value)
        AutoFruit = Value
        Rayfield:Notify({ Title = "Auto Fruit", Content = Value and "Enabled" or "Disabled", Duration = 3 })
    end,
})

MainTab:CreateButton({
    Name = "Destroy GUI",
    Callback = function()
        Rayfield:Destroy()
    end,
})

--// Fly Tab z wyświetlaniem bieżącego klawisza
-- Utworzenie etykiety pokazującej aktualny klawisz
local keybindLabel = FlyTab:CreateParagraph({
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
    Callback = function(Value)
        flySpeed = Value
    end,
})

-- Przycisk do zmiany klawisza – po ustawieniu aktualizuje etykietę
FlyTab:CreateButton({
    Name = "Change Fly Keybind",
    Callback = function()
        Rayfield:Notify({
            Title = "Fly Keybind",
            Content = "Press any key within 5 seconds...",
            Duration = 5,
        })
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            flyKey = input.KeyCode
            -- Aktualizacja etykiety
            keybindLabel:Set({
                Title = "Current Fly Key",
                Content = tostring(flyKey):gsub("Enum.KeyCode.", ""),
            })
            Rayfield:Notify({
                Title = "Fly Keybind",
                Content = "Set to " .. tostring(flyKey),
                Duration = 3,
            })
            conn:Disconnect()
        end)
        task.delay(5, function()
            if conn then conn:Disconnect() end
        end)
    end,
})

Rayfield:Notify({
    Title = "Loaded",
    Content = "Tycoon Autofarm + Fly Loaded Successfully (W/S poprawione)",
    Duration = 5,
})

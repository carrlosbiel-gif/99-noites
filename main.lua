--// 99 Nights in the Forest - XENO OPTIMIZED (RADIO & TIRE UPDATE) //--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Window Setup
local Window = Rayfield:CreateWindow({
    Name = "99 Nights - Premium",
    LoadingTitle = "Carregando Itens...",
    LoadingSubtitle = "by Raygull & Gemini",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- Variables
local teleportTargets = {
    "Alien Chest", "Stronghold Diamond Chest", "Item Chest", "Item Chest2", "Item Chest3", 
    "Item Chest4", "Item Chest6", "Chest", "Seed Box", "Raygun", "Revolver", "Rifle", 
    "Laser Sword", "Riot Shield", "Spear", "Good Axe", "UFO Component", "UFO Junk", 
    "Laser Fence Blueprint", "Cultist Gem", "Medkit", "Fuel Canister", "Old Car Engine", 
    "Washing Machine", "Coal", "Log", "Broken Fan", "Alien", "Alpha Wolf", "Wolf",
    "Radio", "Tire", "Old Tire"
}
local espEnabled = false
local AutoTreeFarmEnabled = false

-- Click simulation
local VirtualInputManager = game:GetService("VirtualInputManager")
function mouse1click()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- MAGNET V2 ATUALIZADO (Radio, Pneu, Log, etc)
local function teleportItemsToMe()
    -- Lista de nomes exatos que o script vai procurar para puxar
    local itemsToGrab = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire"}
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local count = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle then
                -- Traz para a sua posição
                if obj:IsA("Model") then 
                    obj:PivotTo(hrp.CFrame + Vector3.new(0, 2, 0)) 
                else 
                    obj.CFrame = hrp.CFrame + Vector3.new(0, 2, 0)
                end
                
                -- Simula o toque para habilitar o botão de usar (Engana o Servidor)
                if firetouchinterest then
                    firetouchinterest(hrp, handle, 0)
                    task.wait(0.05)
                    firetouchinterest(hrp, handle, 1)
                end
                count = count + 1
            end
        end
    end
    
    Rayfield:Notify({
        Title = "Magnet v2",
        Content = count .. " itens trazidos (Radio, Pneu, Log, etc).",
        Duration = 3
    })
end

-- ESP Function
local function createESP(item)
    local adorneePart = item:IsA("Model") and item:FindFirstChildWhichIsA("BasePart") or (item:IsA("BasePart") and item)
    if not adorneePart or item:FindFirstChildWhichIsA("Humanoid") then return end

    if not item:FindFirstChild("ESP_Billboard") then
        local billboard = Instance.new("BillboardGui", item)
        billboard.Name = "ESP_Billboard"
        billboard.Adornee = adorneePart
        billboard.Size = UDim2.new(0, 50, 0, 20)
        billboard.AlwaysOnTop = true
        billboard.StudsOffset = Vector3.new(0, 2, 0)

        local label = Instance.new("TextLabel", billboard)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Text = item.Name
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(0, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextScaled = true
    end

    if not item:FindFirstChild("ESP_Highlight") then
        local highlight = Instance.new("Highlight", item)
        highlight.Name = "ESP_Highlight"
        highlight.FillColor = Color3.fromRGB(0, 255, 255)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.4
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end
end

local function toggleESP(state)
    espEnabled = state
    if not state then
        for _, item in pairs(workspace:GetDescendants()) do
            if item:FindFirstChild("ESP_Billboard") then item.ESP_Billboard:Destroy() end
            if item:FindFirstChild("ESP_Highlight") then item.ESP_Highlight:Destroy() end
        end
    else
        for _, item in pairs(workspace:GetDescendants()) do
            if table.find(teleportTargets, item.Name) then createESP(item) end
        end
    end
end

-- GUI TABS
local HomeTab = Window:CreateTab("🏠 Principal")

HomeTab:CreateButton({
    Name = "🧲 PUXAR TUDO (Radio, Pneu, Log, Fan, Coal)",
    Callback = teleportItemsToMe
})

HomeTab:CreateToggle({
    Name = "Item ESP (Ciano)",
    CurrentValue = false,
    Callback = toggleESP
})

HomeTab:CreateToggle({
    Name = "Auto Tree Farm",
    CurrentValue = false,
    Callback = function(v) AutoTreeFarmEnabled = v end
})

HomeTab:CreateToggle({
    Name = "Fly (Voo)",
    CurrentValue = false,
    Callback = function(v)
        local flying = v
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if flying then
            local bv = Instance.new("BodyVelocity", hrp)
            bv.Velocity = Vector3.new(0,0,0)
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bv.Name = "FlyVelocity"
            task.spawn(function()
                while flying do
                    bv.Velocity = camera.CFrame.LookVector * 60
                    task.wait()
                    if not flying then if bv then bv:Destroy() end break end
                end
            end)
        else
            if hrp:FindFirstChild("FlyVelocity") then hrp.FlyVelocity:Destroy() end
        end
    end
})

local TeleTab = Window:CreateTab("🧲 Teleports")
for _, itemName in ipairs(teleportTargets) do
    TeleTab:CreateButton({
        Name = "Ir até: " .. itemName,
        Callback = function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj.Name == itemName and (obj:IsA("Model") or obj:IsA("BasePart")) then
                    LocalPlayer.Character:PivotTo(obj:GetPivot() + Vector3.new(0, 5, 0))
                    break
                end
            end
        end
    })
end

Rayfield:Notify({Title = "Sucesso", Content = "Script Atualizado para Xeno!"})

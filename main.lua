--// 99 Nights in the Forest - XENO OPTIMIZED (MEGA MAGNET 5KM) //--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Window Setup
local Window = Rayfield:CreateWindow({
    Name = "99 Nights - Mega Magnet",
    LoadingTitle = "Carregando Configurações...",
    LoadingSubtitle = "by Raygull & Gemini",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- Itens para o ESP e Teleporte Individual
local teleportTargets = {
    "Alien Chest", "Stronghold Diamond Chest", "Item Chest", "Item Chest2", "Item Chest3", 
    "Item Chest4", "Item Chest6", "Chest", "Seed Box", "Raygun", "Revolver", "Rifle", 
    "Laser Sword", "Riot Shield", "Spear", "Good Axe", "UFO Component", "UFO Junk", 
    "Laser Fence Blueprint", "Cultist Gem", "Medkit", "Fuel Canister", "Old Car Engine", 
    "Washing Machine", "Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire"
}

-- MAGNET V2 - RAIO DE 5KM
local function megaMagnet()
    -- Itens que serão puxados automaticamente
    local itemsToGrab = {
        "Coal", "Log", "Broken Fan", "Radio", "Tire", 
        "Old Tire", "Washing Machine", "Old Car Engine"
    }
    
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local count = 0
    local maxDistance = 5000 -- Raio de 5km (em studs)

    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            
            if handle then
                -- Verifica se o item está dentro do raio de 5km
                local distance = (hrp.Position - handle.Position).Magnitude
                
                if distance <= maxDistance then
                    -- Traz o item para cima de você
                    if obj:IsA("Model") then 
                        obj:PivotTo(hrp.CFrame + Vector3.new(0, 3, 0)) 
                    else 
                        obj.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
                    end
                    
                    -- Força o servidor a liberar o botão de interagir
                    if firetouchinterest then
                        firetouchinterest(hrp, handle, 0)
                        task.wait(0.02)
                        firetouchinterest(hrp, handle, 1)
                    end
                    count = count + 1
                end
            end
        end
    end
    
    Rayfield:Notify({
        Title = "Mega Magnet 5km",
        Content = "Foram encontrados e trazidos " .. tostring(count) .. " itens!",
        Duration = 4
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
        billboard.Size = UDim2.new(0, 60, 0, 25)
        billboard.AlwaysOnTop = true
        billboard.StudsOffset = Vector3.new(0, 3, 0)

        local label = Instance.new("TextLabel", billboard)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Text = item.Name
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(0, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextScaled = true
    end
end

-- GUI TABS
local HomeTab = Window:CreateTab("🏠 Principal")

HomeTab:CreateButton({
    Name = "🧲 MEGA MAGNET (5KM RAIO)",
    Callback = megaMagnet
})

HomeTab:CreateToggle({
    Name = "Item ESP (Ciano)",
    CurrentValue = false,
    Callback = function(state)
        if not state then
            for _, item in pairs(workspace:GetDescendants()) do
                if item:FindFirstChild("ESP_Billboard") then item.ESP_Billboard:Destroy() end
            end
        else
            for _, item in pairs(workspace:GetDescendants()) do
                if table.find(teleportTargets, item.Name) then createESP(item) end
            end
        end
    end
})

HomeTab:CreateToggle({
    Name = "Voo (Fly)",
    CurrentValue = false,
    Callback = function(v)
        local flying = v
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if flying then
            local bv = Instance.new("BodyVelocity", hrp)
            bv.Name = "FlyVelocity"
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            task.spawn(function()
                while flying do
                    bv.Velocity = camera.CFrame.LookVector * 70
                    task.wait()
                    if not flying then bv:Destroy() break end
                end
            end)
        else
            if hrp:FindFirstChild("FlyVelocity") then hrp.FlyVelocity:Destroy() end
        end
    end
})

local TeleTab = Window:CreateTab("📍 Teleportes")
for _, itemName in ipairs(teleportTargets) do
    TeleTab:CreateButton({
        Name = "Ir até: " .. itemName,
        Callback = function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj.Name == itemName then
                    LocalPlayer.Character:PivotTo(obj:GetPivot() + Vector3.new(0, 5, 0))
                    break
                end
            end
        end
    })
end

Rayfield:Notify({Title = "Pronto!", Content = "Script carregado. Use o Mega Magnet com cuidado!"})

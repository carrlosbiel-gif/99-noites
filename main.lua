--// 99 Nights in the Forest - ULTRA PREMIUM (STAMINA & LASER) //--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Window Setup
local Window = Rayfield:CreateWindow({
    Name = "99 Nights - Ultra Premium",
    LoadingTitle = "Injetando Cheats...",
    LoadingSubtitle = "by Raygull & Gemini",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- Itens para Magnet e ESP
local teleportTargets = {
    "Alien Chest", "Stronghold Diamond Chest", "Item Chest", "Item Chest2", "Item Chest3", 
    "Item Chest4", "Item Chest6", "Chest", "Seed Box", "Raygun", "Revolver", "Rifle", 
    "Laser Sword", "Riot Shield", "Spear", "Good Axe", "UFO Component", "UFO Junk", 
    "Laser Fence Blueprint", "Cultist Gem", "Medkit", "Fuel Canister", "Old Car Engine", 
    "Washing Machine", "Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire"
}

-- FUNÇÃO: INFINITE STAMINA & LASER (Loop)
local InfiniteStamina = false
local InfiniteLaser = false

task.spawn(function()
    while task.wait(0.5) do
        -- Stamina Infinita
        if InfiniteStamina then
            local stats = LocalPlayer:FindFirstChild("leaderstats") or LocalPlayer:FindFirstChild("Stats")
            if stats and stats:FindFirstChild("Stamina") then
                stats.Stamina.Value = 100
            end
            -- Tentativa via Script Local (comum em jogos de sobrevivência)
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Stamina") then
                LocalPlayer.Character.Stamina.Value = 100
            end
        end
        
        -- Munição/Laser Infinito
        if InfiniteLaser then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
            if tool and (tool.Name:find("Laser") or tool.Name:find("Gun") or tool.Name:find("Raygun")) then
                -- Tenta resetar a munição na Tool
                if tool:FindFirstChild("Ammo") then tool.Ammo.Value = 999 end
                if tool:FindFirstChild("Energy") then tool.Energy.Value = 100 end
            end
        end
    end
end)

-- MEGA MAGNET (5KM)
local function megaMagnet()
    local itemsToGrab = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local count = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle and (hrp.Position - handle.Position).Magnitude <= 5000 then
                if obj:IsA("Model") then obj:PivotTo(hrp.CFrame + Vector3.new(0, 3, 0)) else obj.CFrame = hrp.CFrame + Vector3.new(0, 3, 0) end
                if firetouchinterest then
                    firetouchinterest(hrp, handle, 0)
                    task.wait(0.01)
                    firetouchinterest(hrp, handle, 1)
                end
                count = count + 1
            end
        end
    end
    Rayfield:Notify({Title = "Magnet", Content = count .. " itens trazidos!", Duration = 3})
end

-- TABS DA GUI
local MainTab = Window:CreateTab("🏠 Modificadores")

MainTab:CreateToggle({
    Name = "⚡ Stamina Infinita",
    CurrentValue = false,
    Callback = function(v) InfiniteStamina = v end
})

MainTab:CreateToggle({
    Name = "🔫 Laser/Munição Infinita",
    CurrentValue = false,
    Callback = function(v) InfiniteLaser = v end
})

MainTab:CreateButton({
    Name = "🧲 Puxar Itens (5KM)",
    Callback = megaMagnet
})

local VisualTab = Window:CreateTab("👁️ Visual/ESP")

VisualTab:CreateToggle({
    Name = "Item ESP (Nomes)",
    CurrentValue = false,
    Callback = function(state)
        if not state then
            for _, item in pairs(workspace:GetDescendants()) do
                if item:FindFirstChild("ESP_Billboard") then item.ESP_Billboard:Destroy() end
            end
        else
            for _, item in pairs(workspace:GetDescendants()) do
                if table.find(teleportTargets, item.Name) then
                    local b = Instance.new("BillboardGui", item)
                    b.Name = "ESP_Billboard"; b.AlwaysOnTop = true; b.Size = UDim2.new(0,50,0,20); b.StudsOffset = Vector3.new(0,3,0)
                    local l = Instance.new("TextLabel", b)
                    l.Size = UDim2.new(1,0,1,0); l.Text = item.Name; l.TextColor3 = Color3.fromRGB(0,255,255); l.BackgroundTransparency = 1; l.TextScaled = true
                end
            end
        end
    end
end)

local MiscTab = Window:CreateTab("🚀 Outros")

MiscTab:CreateToggle({
    Name = "Voo (Fly)",
    CurrentValue = false,
    Callback = function(v)
        local flying = v
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if flying then
            local bv = Instance.new("BodyVelocity", hrp)
            bv.Name = "FlyVel"; bv.MaxForce = Vector3.new(9e9,9e9,9e9)
            task.spawn(function()
                while flying do
                    bv.Velocity = camera.CFrame.LookVector * 80
                    task.wait()
                    if not flying then bv:Destroy() break end
                end
            end)
        else
            if hrp:FindFirstChild("FlyVel") then hrp.FlyVel:Destroy() end
        end
    end
})

Rayfield:Notify({Title = "Sucesso", Content = "Stamina e Laser Infinito ativados!"})

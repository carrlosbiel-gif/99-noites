--// 99 Nights in the Forest - XENO STABLE EDITION //--
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shanhai0w0/script/main/Orion')))()

-- Serviços
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Janela Principal
local Window = OrionLib:MakeWindow({Name = "99 Nights - Ultra Premium", HidePremium = false, SaveConfig = false, IntroEnabled = false})

-- Variáveis de Estado
_G.InfiniteStamina = false
_G.InfiniteLaser = false

-- Itens para Magnet e ESP
local targets = {
    "Alien Chest", "Stronghold Diamond Chest", "Item Chest", "Item Chest2", "Item Chest3", 
    "Item Chest4", "Item Chest6", "Chest", "Seed Box", "Raygun", "Revolver", "Rifle", 
    "Laser Sword", "Riot Shield", "Spear", "Good Axe", "UFO Component", "UFO Junk", 
    "Laser Fence Blueprint", "Cultist Gem", "Medkit", "Fuel Canister", "Old Car Engine", 
    "Washing Machine", "Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire"
}

-- Loops de Cheats (Stamina e Laser)
task.spawn(function()
    while task.wait(0.5) do
        if _G.InfiniteStamina then
            local char = LocalPlayer.Character
            if char then
                -- Tenta várias formas comuns de stamina no Roblox
                if char:FindFirstChild("Stamina") then char.Stamina.Value = 100 end
                if LocalPlayer:FindFirstChild("Stamina") then LocalPlayer.Stamina.Value = 100 end
            end
        end
        
        if _G.InfiniteLaser then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
            if tool then
                if tool:FindFirstChild("Ammo") then tool.Ammo.Value = 999 end
                if tool:FindFirstChild("Energy") then tool.Energy.Value = 100 end
            end
        end
    end
end)

-- Aba Principal
local MainTab = Window:MakeTab({Name = "Principal", Icon = "rbxassetid://4483345998", PremiumOnly = false})

MainTab:AddToggle({
    Name = "⚡ Stamina Infinita",
    Default = false,
    Callback = function(Value) _G.InfiniteStamina = Value end
})

MainTab:AddToggle({
    Name = "🔫 Laser/Munição Infinita",
    Default = false,
    Callback = function(Value) _G.InfiniteLaser = Value end
})

MainTab:AddButton({
    Name = "🧲 MEGA MAGNET (5KM RAIO)",
    Callback = function()
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
        OrionLib:MakeNotification({Name = "Magnet", Content = count .. " itens puxados!", Time = 3})
    end
})

-- Aba Visual
local VisualTab = Window:MakeTab({Name = "Visual", Icon = "rbxassetid://4483345998", PremiumOnly = false})

VisualTab:AddToggle({
    Name = "Item ESP",
    Default = false,
    Callback = function(state)
        _G.ESP = state
        if not state then
            for _, item in pairs(workspace:GetDescendants()) do
                if item:FindFirstChild("ESP_Tag") then item.ESP_Tag:Destroy() end
            end
        else
            for _, item in pairs(workspace:GetDescendants()) do
                if table.find(targets, item.Name) then
                    local b = Instance.new("BillboardGui", item)
                    b.Name = "ESP_Tag"; b.AlwaysOnTop = true; b.Size = UDim2.new(0,50,0,20); b.StudsOffset = Vector3.new(0,3,0)
                    local l = Instance.new("TextLabel", b)
                    l.Size = UDim2.new(1,0,1,0); l.Text = item.Name; l.TextColor3 = Color3.fromRGB(0,255,255); l.BackgroundTransparency = 1; l.TextScaled = true
                end
            end
        end
    end
})

-- Aba Movimento
local MoveTab = Window:MakeTab({Name = "Movimento", Icon = "rbxassetid://4483345998", PremiumOnly = false})

MoveTab:AddSlider({
    Name = "Velocidade (Speed)",
    Min = 16,
    Max = 200,
    Default = 16,
    Color = Color3.fromRGB(255,255,255),
    Increment = 1,
    ValueName = "Speed",
    Callback = function(Value)
        LocalPlayer.Character.Humanoid.WalkSpeed = Value
    end
})

OrionLib:Init()

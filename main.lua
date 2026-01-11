--// 99 Nights - LASER EXTREME, ESP & GLOBAL MAGNET //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- 1. LASER AUTOMÁTICO E INFINITO (FORÇADO)
task.spawn(function()
    while task.wait(0.05) do -- Loop ultra rápido para não deixar descarregar
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        
        if tool and (tool.Name:find("Laser") or tool.Name:find("Raygun") or tool.Name:find("Canhão")) then
            -- Tenta forçar o disparo se você estiver segurando o botão
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or UserInputService:IsGamepadButtonDown(Enum.GamepadKeyCode.ButtonR2) then
                tool:Activate() -- Spamma a ativação para tiros seguidos
            end
            
            -- Bypass de Recarga e Energia
            for _, v in pairs(tool:GetDescendants()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("StringValue") then
                    local n = v.Name:lower()
                    if n:find("energy") or n:find("charge") or n:find("ammo") or n:find("heat") then
                        v.Value = 100 -- Mantém carregado
                    elseif n:find("cooldown") or n:find("delay") or n:find("reload") then
                        v.Value = 0 -- Remove o tempo entre tiros
                    end
                end
            end
        end
    end
end)

-- 2. ESP DE ITENS (TODO O MAPA)
local targets = {
    "Alien Chest", "Stronghold Diamond Chest", "Item Chest", "Item Chest2", "Item Chest3", 
    "Item Chest4", "Item Chest6", "Chest", "Seed Box", "Raygun", "Revolver", "Rifle", 
    "Laser Sword", "Riot Shield", "Spear", "Good Axe", "UFO Component", "UFO Junk", 
    "Laser Fence Blueprint", "Cultist Gem", "Medkit", "Fuel Canister", "Old Car Engine", 
    "Washing Machine", "Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire"
}

local function applyESP(obj)
    if table.find(targets, obj.Name) and not obj:FindFirstChild("ESP_Tag") then
        local b = Instance.new("BillboardGui", obj)
        b.Name = "ESP_Tag"; b.AlwaysOnTop = true; b.Size = UDim2.new(0, 100, 0, 30); b.StudsOffset = Vector3.new(0, 3, 0)
        local l = Instance.new("TextLabel", b)
        l.Size = UDim2.new(1, 0, 1, 0); l.Text = obj.Name; l.TextColor3 = Color3.fromRGB(0, 255, 255); l.BackgroundTransparency = 1; l.TextScaled = true
    end
end

task.spawn(function()
    while task.wait(2) do
        for _, obj in pairs(workspace:GetDescendants()) do
            applyESP(obj)
        end
    end
end)

-- 3. MEGA MAGNET GLOBAL (SETABAIXO)
local function runGlobalMagnet()
    local itemsToGrab = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle then
                if obj:IsA("Model") then obj:PivotTo(hrp.CFrame * CFrame.new(0, 5, -3)) else obj.CFrame = hrp.CFrame * CFrame.new(0, 5, -3) end
                if firetouchinterest then
                    firetouchinterest(hrp, handle, 0)
                    firetouchinterest(hrp, handle, 1)
                end
            end
        end
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.ButtonDpadDown then
        runGlobalMagnet()
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "LASER OVERDRIVE",
    Text = "Segure para disparar sem parar!",
    Duration = 5
})

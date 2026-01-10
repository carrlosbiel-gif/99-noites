--// 99 Nights - LASER BUFF, ESP & GLOBAL MAGNET //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- 1. CANHÃO LASER INFINITO E RÁPIDO
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        
        if tool then
            -- Tenta encontrar qualquer valor de carga/energia na arma
            for _, v in pairs(tool:GetDescendants()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") then
                    -- Trava energia e munição no máximo
                    if v.Name:find("Energy") or v.Name:find("Charge") or v.Name:find("Ammo") then
                        v.Value = 100
                    end
                    -- Zera o tempo de espera (Cooldown) para atirar várias vezes
                    if v.Name:find("Cooldown") or v.Name:find("Delay") or v.Name:find("Rate") then
                        v.Value = 0
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
        b.Name = "ESP_Tag"
        b.AlwaysOnTop = true
        b.Size = UDim2.new(0, 100, 0, 30)
        b.StudsOffset = Vector3.new(0, 3, 0)
        
        local l = Instance.new("TextLabel", b)
        l.Size = UDim2.new(1, 0, 1, 0)
        l.Text = obj.Name
        l.TextColor3 = Color3.fromRGB(0, 255, 255) -- Ciano
        l.BackgroundTransparency = 1
        l.TextScaled = true
        l.Font = Enum.Font.SourceSansBold
    end
end

-- Scan inicial e contínuo para ESP
task.spawn(function()
    while task.wait(2) do
        for _, obj in pairs(workspace:GetDescendants()) do
            applyESP(obj)
        end
    end
end)

-- 3. MEGA MAGNET GLOBAL (PUXAR TUDO DO MAPA)
local function runGlobalMagnet()
    local itemsToGrab = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle then
                -- Teleporta para o jogador (independente da distância)
                if obj:IsA("Model") then 
                    obj:PivotTo(hrp.CFrame * CFrame.new(0, 5, -3)) 
                else 
                    obj.CFrame = hrp.CFrame * CFrame.new(0, 5, -3)
                end
                
                -- Simula toque para coletar
                if firetouchinterest then
                    firetouchinterest(hrp, handle, 0)
                    firetouchinterest(hrp, handle, 1)
                end
            end
        end
    end
end

-- Ativar Magnet com a Seta para Baixo (Teclado/Controle)
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
    if input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.ButtonDpadDown then
        runGlobalMagnet()
    end
end)

-- Notificação
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "ADMIN SYSTEM ON",
    Text = "Laser Buffado | ESP Global | Seta Baixo = Magnet",
    Duration = 5
})

--// 99 Nights in the Forest - XENO HITBOX EDITION //--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Window Setup
local Window = Rayfield:CreateWindow({
    Name = "99 Nights - Hitbox & Magnet",
    LoadingTitle = "Configurando Hitbox...",
    LoadingSubtitle = "by Gemini",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- Variáveis Globais
_G.HitboxSize = 5
_G.HitboxEnabled = false

-- Itens para o ESP e Teleporte
local teleportTargets = {
    "Alien Chest", "Stronghold Diamond Chest", "Item Chest", "Item Chest2", "Item Chest3", 
    "Item Chest4", "Item Chest6", "Chest", "Seed Box", "Raygun", "Revolver", "Rifle", 
    "Laser Sword", "Riot Shield", "Spear", "Good Axe", "UFO Component", "UFO Junk", 
    "Laser Fence Blueprint", "Cultist Gem", "Medkit", "Fuel Canister", "Old Car Engine", 
    "Washing Machine", "Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire"
}

-- FUNÇÃO HITBOX (Acima da Cabeça)
task.spawn(function()
    while task.wait(0.5) do
        if _G.HitboxEnabled then
            pcall(function()
                local char = LocalPlayer.Character
                local head = char and char:FindFirstChild("Head")
                if head then
                    local hb = char:FindFirstChild("HitboxPart") or Instance.new("Part", char)
                    hb.Name = "HitboxPart"
                    hb.Transparency = 0.7 -- Deixei um pouco visível para você ver onde está (mude para 1 para invisível)
                    hb.Color = Color3.fromRGB(255, 0, 0)
                    hb.CanCollide = false
                    hb.Size = Vector3.new(_G.HitboxSize, _G.HitboxSize, _G.HitboxSize)
                    hb.CFrame = head.CFrame * CFrame.new(0, _G.HitboxSize/2 + 2, 0) -- Posiciona ACIMA da cabeça
                    hb.Massless = true
                end
            end)
        else
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HitboxPart") then
                LocalPlayer.Character.HitboxPart:Destroy()
            end
        end
    end
end)

-- MAGNET V2 - RAIO DE 5KM
local function megaMagnet()
    local itemsToGrab = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local count = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle then
                if (hrp.Position - handle.Position).Magnitude <= 5000 then
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
    end
    Rayfield:Notify({Title = "Magnet", Content = count .. " itens trazidos!", Duration = 3})
end

-- GUI TABS
local HomeTab = Window

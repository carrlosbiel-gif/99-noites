--// 99 NIGHTS - SURVIVAL MENU (CURA E COMIDA - SEM OP) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Variáveis de Controle
_G.Noclip = false
_G.MagnetOP = false
_G.AutoFarm = false

-- Interface do Menu
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 300)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 2
MainFrame.Visible = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "99 NIGHTS SURVIVAL"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local function CreateBtn(text, pos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0, 200, 0, 45)
    btn.Position = pos
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- BOTOES
CreateBtn("ILUMINAÇÃO (DIA)", UDim2.new(0, 10, 0, 45), function()
    Lighting.ClockTime = 14
    Lighting.Brightness = 2
end)

local nBtn = CreateBtn("NOCLIP: OFF", UDim2.new(0, 10, 0, 95), function()
    _G.Noclip = not _G.Noclip
end)

local mBtn = CreateBtn("MAGNET CURA/FOOD: OFF", UDim2.new(0, 10, 0, 145), function()
    _G.MagnetOP = not _G.MagnetOP
end)

local fBtn = CreateBtn("AUTO FARM: OFF", UDim2.new(0, 10, 0, 195), function()
    _G.AutoFarm = not _G.AutoFarm
end)

CreateBtn("FECHAR (L1+R1)", UDim2.new(0, 10, 0, 245), function()
    MainFrame.Visible = false
end)

-- LOOP NOCLIP
RunService.Stepped:Connect(function()
    nBtn.Text = "NOCLIP: " .. (_G.Noclip and "ON" or "OFF")
    mBtn.Text = "MAGNET CURA/FOOD: " .. (_G.MagnetOP and "ON" or "OFF")
    fBtn.Text = "AUTO FARM: " .. (_G.AutoFarm and "ON" or "OFF")
    
    if _G.Noclip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- MAGNET SELETIVO (APENAS CURA E COMIDA - SEM UVA / SEM OP)
task.spawn(function()
    -- Lista filtrada apenas para o básico e necessário
    local listaSurvival = {
        "Medkit", "Bandagem", "Kit", "Armor", "Shield", -- Cura e Defesa
        "Meat", "Carne", "Apple", "Maca", "Berry", "Baga", "Bread", "Pao", "Food" -- Comida
    }
    
    while task.wait(3) do
        if _G.MagnetOP then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in pairs(workspace:GetDescendants()) do
                    local nome = obj.Name:lower()
                    
                    -- Filtro de exclusão: Ignora Uvas e Itens OP conhecidos
                    local isBlacklisted = nome:find("uva") or nome:find("grape") or nome:find("raygun") or nome:find("shotgun") or nome:find("alien")
                    
                    if not isBlacklisted then
                        for _, k in pairs(listaSurvival) do
                            if nome:find(k:lower()) and not obj:IsDescendantOf(game.Players) then
                                local h = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                                if h then 
                                    h.CFrame = hrp.CFrame 
                                    if firetouchinterest then firetouchinterest(hrp, h, 0); firetouchinterest(hrp, h,

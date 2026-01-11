--// 99 NIGHTS - UTILITY MENU (MAGNET DE COMIDA & ITENS) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Variáveis de Controle
_G.Noclip = false
_G.MagnetOP = false
_G.AutoFarm = false

-- Interface do Menu (Otimizada para Xeno)
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 300)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 2
MainFrame.Visible = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "99 NIGHTS UTILS"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

local function CreateBtn(text, pos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0, 200, 0, 45)
    btn.Position = pos
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- BOTOES
CreateBtn("ILUMINAÇÃO (DIA)", UDim2.new(0, 10, 0, 45), function()
    Lighting.ClockTime = 14
    Lighting.Brightness = 2
    Lighting.FogEnd = 100000
end)

local nBtn = CreateBtn("NOCLIP: OFF", UDim2.new(0, 10, 0, 95), function()
    _G.Noclip = not _G.Noclip
end)

local mBtn = CreateBtn("MAGNET TUDO: OFF", UDim2.new(0, 10, 0, 145), function()
    _G.MagnetOP = not _G.MagnetOP
end)

local fBtn = CreateBtn("AUTO FARM: OFF", UDim2.new(0, 10, 0, 195), function()
    _G.AutoFarm = not _G.AutoFarm
end)

CreateBtn("FECHAR (L1+R1)", UDim2.new(0, 10, 0, 245), function()
    MainFrame.Visible = false
end)

-- LOOP NOCLIP (R2+R3 ou Menu)
RunService.Stepped:Connect(function()
    nBtn.Text = "NOCLIP: " .. (_G.Noclip and "ON" or "OFF")
    mBtn.Text = "MAGNET TUDO: " .. (_G.MagnetOP and "ON" or "OFF")
    fBtn.Text = "AUTO FARM: " .. (_G.AutoFarm and "ON" or "OFF")
    
    if _G.Noclip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- MAGNET DE COMIDAS, ARMAS E PROTEÇÕES
task.spawn(function()
    -- Lista de busca ampliada para incluir COMIDAS
    local lista = {
        "Shotgun", "Raygun", "Canhao", "Maco", "Infernal", "Lanterna", "Medkit", "Bandagem", "Armor", 
        "Meat", "Carne", "Apple", "Maca", "Berry", "Baga", "Bread", "Pao", "Food", "Comida", "Cooked"
    }
    
    while task.wait(3) do
        if _G.MagnetOP then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in pairs(workspace:GetDescendants()) do
                    local nome = obj.Name:lower()
                    for _, k in pairs(lista) do
                        if nome:find(k:lower()) and not obj:IsDescendantOf(game.Players) then
                            local h = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                            if h then 
                                h.CFrame = hrp.CFrame 
                                -- Tenta coletar automaticamente
                                if firetouchinterest then firetouchinterest(hrp, h, 0); firetouchinterest(hrp, h, 1) end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- AUTO FARM (MADEIRA/ANIMAIS)
task.spawn(function()
    while task.wait(0.5) do
        if _G.AutoFarm then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildWhichIsA("Tool")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if tool and hrp then
                for _, v in pairs(workspace:GetChildren()) do
                    if v:IsA("Model") and v.Name ~= LocalPlayer.Name then
                        local t = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChildWhichIsA("BasePart")
                        if t and (hrp.Position - t.Position).Magnitude < 20 then
                            tool:Activate()
                        end
                    end
                end
            end
        end
    end
end)

-- CONTROLES DE ATIVAÇÃO
UserInputService.InputBegan:Connect(function(input)
    -- L1 + R1 abre menu
    if input.KeyCode == Enum.KeyCode.ButtonR1 and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL1) then
        MainFrame.Visible = not MainFrame.Visible
    end
    -- R2 + R3 noclip rápido
    if input.KeyCode == Enum.KeyCode.ButtonR3 and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2) then
        _G.Noclip = not _G.Noclip
    end
end)

print("Menu 99 Nights com Magnet de Comida Carregado!")

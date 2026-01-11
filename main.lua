--// 99 NIGHTS - SUPREME OP MOD MENU (ANTI-LAG) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Criando a Interface do Menu
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 280)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 2
MainFrame.Visible = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "99 NIGHTS SUPREME"
Title.TextColor3 = Color3.fromRGB(255, 215, 0) -- Dourado
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

-- Variáveis
_G.Noclip = false
_G.MagnetOP = false

-- Função para Criar Botões
local function CreateButton(name, pos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0, 200, 0, 45)
    btn.Position = pos
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 16
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- 1. BOTÃO FULL BRIGHT
CreateButton("ILUMINAÇÃO MÁXIMA", UDim2.new(0, 10, 0, 45), function()
    game:GetService("Lighting").ClockTime = 14
    game:GetService("Lighting").Brightness = 3
    game:GetService("Lighting").GlobalShadows = false
end)

-- 2. BOTÃO NOCLIP
local noclipBtn = CreateButton("NOCLIP: OFF", UDim2.new(0, 10, 0, 100), function()
    _G.Noclip = not _G.Noclip
end)

-- 3. BOTÃO MAGNET OP (ARMAS E ARMADURAS)
local magBtn = CreateButton("MAGNET OP: OFF", UDim2.new(0, 10, 0, 155), function()
    _G.MagnetOP = not _G.MagnetOP
    magBtn.Text = "MAGNET OP: " .. (_G.MagnetOP and "ON" or "OFF")
    magBtn.BackgroundColor3 = _G.MagnetOP and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(60, 60, 60)
end)

-- 4. FECHAR
CreateButton("FECHAR MENU (L1+R1)", UDim2.new(0, 10, 0, 210), function()
    MainFrame.Visible = false
end)

-- LOOP DO NOCLIP (R2+R3 ou Botão)
RunService.Stepped:Connect(function()
    noclipBtn.Text = "NOCLIP: " .. (_G.Noclip and "ON" or "OFF")
    if _G.Noclip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- SISTEMA DE MAGNET OP (BUSCA POR ITENS RAROS)
task.spawn(function()
    -- Lista de palavras-chave para itens OP
    local itensRaros = {"Laser", "Raygun", "Golden", "Diamond", "Heavy", "Armor", "Shield", "Axe", "Sword", "Hammer", "Gun", "Medkit"}
    
    while task.wait(3) do
        if _G.MagnetOP then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in pairs(workspace:GetDescendants()) do
                    local isOP = false
                    for _, keyword in pairs(itensRaros) do
                        if obj.Name:find(keyword) then
                            isOP = true
                            break
                        end
                    end
                    
                    if isOP and not obj:IsDescendantOf(game.Players) then
                        local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                        if handle then
                            handle.CFrame = hrp.CFrame
                            -- Auto-Coleta (Simula toque)
                            if firetouchinterest then
                                firetouchinterest(hrp, handle, 0)
                                firetouchinterest(hrp, handle, 1)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- CONTROLES DE ATIVAÇÃO
UserInputService.InputBegan:Connect(function(input)
    -- L1 + R1 = Menu
    if input.KeyCode == Enum.KeyCode.ButtonR1 and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL1) then
        MainFrame.Visible = not MainFrame.Visible
    end
    -- R2 + R3 = Noclip
    if input.KeyCode == Enum.KeyCode.ButtonR3 and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2) then
        _G.Noclip = not _G.Noclip
    end
end)

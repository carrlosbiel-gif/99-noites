--// 99 NIGHTS - SUPREME OP MOD MENU (ULTRA MAGNET) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Criando a Interface do Menu
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 280)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 2
MainFrame.Visible = true

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "99 NIGHTS SUPREME"
Title.TextColor3 = Color3.fromRGB(0, 255, 255) -- Ciano
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

-- Variáveis
_G.Noclip = false
_G.MagnetOP = false

-- Função para Criar Botões
local function CreateButton(name, pos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0, 200, 0, 45)
    btn.Position = pos
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
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

-- 3. BOTÃO MAGNET OP (BUSCA ITENS ESPECÍFICOS)
local magBtn = CreateButton("MAGNET OP: OFF", UDim2.new(0, 10, 0, 155), function()
    _G.MagnetOP = not _G.MagnetOP
    magBtn.Text = "MAGNET OP: " .. (_G.MagnetOP and "ON" or "OFF")
    magBtn.BackgroundColor3 = _G.MagnetOP and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(50, 50, 50)
end)

-- 4. FECHAR
CreateButton("FECHAR MENU (L1+R1)", UDim2.new(0, 10, 0, 210), function()
    MainFrame.Visible = false
end)

-- LOOP DO NOCLIP
RunService.Stepped:Connect(function()
    noclipBtn.Text = "NOCLIP: " .. (_G.Noclip and "ON" or "OFF")
    if _G.Noclip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- SISTEMA DE MAGNET ATUALIZADO (ITENS DA LISTA)
task.spawn(function()
    -- Lista de itens que você pediu
    local listaOP = {
        "Shotgun", "Espingarda", "Raygun", "Alien", "Canhão", "Canhao", 
        "Maço", "Maco", "Rei", "Saco Infernal", "Infernal", 
        "Lanterna", "Medkit", "Bandagem", "Kit", "Armor", "Diamond"
    }
    
    while task.wait(3) do
        if _G.MagnetOP then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in pairs(workspace:GetDescendants()) do
                    local encontrou = false
                    local nome = obj.Name:lower()
                    
                    for _, keyword in pairs(listaOP) do
                        if nome:find(keyword:lower()) then
                            encontrou = true
                            break
                        end
                    end
                    
                    if encontrou and not obj:IsDescendantOf(game.Players) then
                        local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                        if handle then
                            handle.CFrame = hrp.CFrame
                            -- Tenta coletar automaticamente
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
    if input.KeyCode == Enum.KeyCode.ButtonR1 and UserInputService:IsGamepadButtonDown(Enum.GamepadKeyCode.ButtonL1) then
        MainFrame.Visible = not MainFrame.Visible
    end
    if input.KeyCode == Enum.KeyCode.ButtonR3 and UserInputService:IsGamepadButtonDown(Enum.GamepadKeyCode.ButtonR2) then
        _G.Noclip = not _G.Noclip
    end
end)

--// 99 Nights - Xeno Optimized Version //--
-- Interface nativa para evitar crashes no Xeno

local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local FarmBtn = Instance.new("TextButton")
local ESPBtn = Instance.new("TextButton")
local AimBtn = Instance.new("TextButton")

-- Setup GUI (Minimalista)
ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.Name = "XenoSafeMenu"

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
MainFrame.Size = UDim2.new(0, 180, 0, 220)
MainFrame.Active = true
MainFrame.Draggable = true -- Você pode arrastar o menu

Title.Parent = MainFrame
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Text = "99 NIGHTS (XENO)"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

-- Estilo dos Botões
local function styleBtn(btn, text, pos)
    btn.Parent = MainFrame
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Position = UDim2.new(0.05, 0, 0, pos)
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSansBold
end

styleBtn(FarmBtn, "Auto Farm: OFF", 50)
styleBtn(ESPBtn, "ESP: OFF", 100)
styleBtn(AimBtn, "Aimbot: OFF", 150)

-- Variáveis de Controle
local Config = {Farm = false, ESP = false, Aim = false}
local LP = game:GetService("Players").LocalPlayer
local VIM = game:GetService("VirtualInputManager")

-- Lógica de Automação
FarmBtn.MouseButton1Click:Connect(function()
    Config.Farm = not Config.Farm
    FarmBtn.Text = Config.Farm and "Auto Farm: ON" or "Auto Farm: OFF"
    FarmBtn.BackgroundColor3 = Config.Farm and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
end)

ESPBtn.MouseButton1Click:Connect(function()
    Config.ESP = not Config.ESP
    ESPBtn.Text = Config.ESP and "ESP: ON" or "ESP: OFF"
    ESPBtn.BackgroundColor3 = Config.ESP and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
end)

AimBtn.MouseButton1Click:Connect(function()
    Config.Aim = not Config.Aim
    AimBtn.Text = Config.Aim and "Aimbot: ON" or "Aimbot: OFF"
    AimBtn.BackgroundColor3 = Config.Aim and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(60, 60, 60)
end)

-- Loop Principal (Otimizado para não travar o Xeno)
task.spawn(function()
    while task.wait(0.5) do
        if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then continue end
        local root = LP.Character.HumanoidRootPart

        -- Farm
        if Config.Farm then
            for _, v in ipairs(workspace:GetChildren()) do
                if v.Name == "Small Tree" and v:FindFirstChild("Trunk") then
                    if (v.Trunk.Position - root.Position).Magnitude < 15 then
                        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                        task.wait(0.1)
                        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
                    end
                end
            end
        end

        -- ESP (Highlight nativo do Roblox)
        if Config.ESP then
            for _, npc in ipairs(workspace:GetChildren()) do
                if (npc.Name == "Wolf" or npc.Name == "Alien") and not npc:FindFirstChild("Highlight") then
                    Instance.new("Highlight", npc).OutlineColor = Color3.new(1, 0, 0)
                end
            end
        end
    end
end)

-- Aimbot Suave (Segurar Botão Direito)
game:GetService("RunService").RenderStepped:Connect(function()
    if Config.Aim and game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local cam = workspace.CurrentCamera
        for _, npc in ipairs(workspace:GetChildren()) do
            if (npc.Name == "Wolf" or npc.Name == "Alien") and npc:FindFirstChild("Head") then
                local _, vis = cam:WorldToViewportPoint(npc.Head.Position)
                if vis then
                    cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, npc.Head.Position), 0.15)
                    break
                end
            end
        end
    end
end)

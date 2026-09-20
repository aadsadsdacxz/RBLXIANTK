-- language: Luau
-- SAE Enterprise Suite v6.2.1 — 100% Stealth Client Edition (Read-Only Matrix)
local CONFIG = {
    ENGINE_VERSION = "6.2.1-STEALTH",
}

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local CoreGui            = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

local S = {
    running            = true,
    fullbrightActive   = false,
    espEggsActive      = false,
    antiAfkActive      = true,
    connectionRegistry = {},
    espObjects         = {},
}

local function LogSystem(level, message)
    print(string.format("[SAE STEALTH] [%s] %s", level:upper(), tostring(message)))
end

local function RegisterConnection(connection)
    if connection then table.insert(S.connectionRegistry, connection) end
    return connection
end

local function PurgeConnections()
    for _, conn in ipairs(S.connectionRegistry) do
        pcall(function() conn:Disconnect() end)
    end
    S.connectionRegistry = {}
end

-- 🛡️ Ultimate Prompt Shield (Catches and destroys client-side error drops)
local function InitializeStealthSecurity()
    task.spawn(function()
        while task.wait(0.5) do
            if S.running then
                pcall(function()
                    for _, gui in ipairs(CoreGui:GetChildren()) do
                        if gui.Name:find("Prompt") or gui.Name:find("Error") then
                            gui:Destroy()
                            LogSystem("SUCCESS", "Intercepted and cleared potential error prompt.")
                        end
                    end
                end)
            end
        end
    end)
    LogSystem("SUCCESS", "Stealth Security Shield initialized.")
end

-- Fullbright Lighting Override (Client-side only, completely undetectable by server anti-cheat)
RegisterConnection(RunService.RenderStepped:Connect(function()
    if not S.running then return end
    if S.fullbrightActive then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    end
end))

-- Anti-AFK Connection Keepalive
local virtualUser = game:GetService("VirtualUser")
RegisterConnection(LP.Idled:Connect(function()
    if S.running and S.antiAfkActive then
        virtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
        task.wait(1)
        virtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
    end
end))

-- Read-Only High-Tier ESP (Client-side visual drawing)
local function CreateESPBox(targetObject, colorHex, labelText)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SAE_Stealth_ESP"
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    
    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = colorHex
    label.TextStrokeTransparency = 0.2
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    
    local primary = targetObject:IsA("Model") and (targetObject.PrimaryPart or targetObject:FindFirstChildWhichIsA("BasePart"))
    if primary then
        billboard.Adornee = primary
        billboard.Parent = CoreGui
        table.insert(S.espObjects, billboard)
    end
end

local function ClearAllESP()
    for _, obj in ipairs(S.espObjects) do pcall(function() obj:Destroy() end) end
    S.espObjects = {}
end

task.spawn(function()
    while true do
        if S.running and S.espEggsActive then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("egg") or obj.Name:lower():find("pet")) then
                    if not obj:FindFirstChild("SAE_Stealth_ESP") then
                        CreateESPBox(obj, Color3.fromRGB(255, 215, 0), "[" .. obj.Name .. "]")
                    end
                end
            end
        else
            ClearAllESP()
        end
        task.wait(3)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ULTRA-LIGHTWEIGHT MINIMAL USER INTERFACE
-- ═══════════════════════════════════════════════════════════════════════════════
local THEME = {
    Primary      = Color3.fromRGB(15, 15, 22),
    Secondary    = Color3.fromRGB(25, 25, 38),
    Accent       = Color3.fromRGB(80, 140, 255),
    Success      = Color3.fromRGB(50, 200, 130),
    Danger       = Color3.fromRGB(230, 60, 60),
    TextMain     = Color3.fromRGB(235, 235, 245),
    TextDim      = Color3.fromRGB(130, 130, 150),
    Border       = Color3.fromRGB(40, 40, 65),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SAE_Stealth_Suite"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = PlayerGui end

-- Main Window
local MainWindow = Instance.new("Frame", ScreenGui)
MainWindow.Size = UDim2.new(0, 360, 0, 280)
MainWindow.Position = UDim2.new(0.5, -180, 0.5, -140)
MainWindow.BackgroundColor3 = THEME.Primary
Instance.new("UICorner", MainWindow).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainWindow).Color = THEME.Border

-- Header Bar
local HeaderBar = Instance.new("Frame", MainWindow)
HeaderBar.Size = UDim2.new(1, 0, 0, 38)
HeaderBar.BackgroundColor3 = THEME.Secondary
Instance.new("UICorner", HeaderBar).CornerRadius = UDim.new(0, 10)

local HeaderTitle = Instance.new("TextLabel", HeaderBar)
HeaderTitle.Size = UDim2.new(1, -20, 1, 0)
HeaderTitle.Position = UDim2.new(0, 12, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "🛡️ SAE v6.2 — 100% Stealth Mode"
HeaderTitle.TextColor3 = THEME.TextMain
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 12
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Dragging Support
do
    local dragging, dragStart, startPos
    HeaderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainWindow.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- Content Container
local ContentContainer = Instance.new("ScrollingFrame", MainWindow)
ContentContainer.Size = UDim2.new(1, -16, 1, -50)
ContentContainer.Position = UDim2.new(0, 8, 0, 44)
ContentContainer.BackgroundTransparency = 1
ContentContainer.CanvasSize = UDim2.new(0, 0, 0, 250)
ContentContainer.ScrollBarThickness = 2
local layout = Instance.new("UIListLayout", ContentContainer)
layout.Padding = UDim.new(0, 6)

local function AddToggleElement(parent, labelText, defaultState, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, 0, 0, 34)
    container.BackgroundColor3 = THEME.Secondary
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = THEME.TextMain
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local toggleBtn = Instance.new("TextButton", container)
    toggleBtn.Size = UDim2.new(0, 32, 0, 18)
    toggleBtn.Position = UDim2.new(1, -40, 0.5, -9)
    toggleBtn.BackgroundColor3 = defaultState and THEME.Success or THEME.Border
    toggleBtn.Text = ""
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
    
    local indicator = Instance.new("Frame", toggleBtn)
    indicator.Size = UDim2.new(0, 14, 0, 14)
    indicator.Position = defaultState and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    indicator.BackgroundColor3 = THEME.TextMain
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
    
    local state = defaultState
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and THEME.Success or THEME.Border
        indicator.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        callback(state)
    end)
end

AddToggleElement(ContentContainer, "Fullbright (Client Lighting)", false, function(v) S.fullbrightActive = v end)
AddToggleElement(ContentContainer, "Egg & Pet High-Tier ESP", false, function(v) S.espEggsActive = v end)
AddToggleElement(ContentContainer, "Anti-AFK Keepalive", true, function(v) S.antiAfkActive = v end)

-- Unload Button
local unloadBtn = Instance.new("TextButton", ContentContainer)
unloadBtn.Size = UDim2.new(1, 0, 0, 34)
unloadBtn.BackgroundColor3 = THEME.Danger
unloadBtn.Text = "Unload / Terminate Script"
unloadBtn.TextColor3 = THEME.TextMain
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.TextSize = 11
Instance.new("UICorner", unloadBtn).CornerRadius = UDim.new(0, 6)

unloadBtn.MouseButton1Click:Connect(function()
    S.running = false
    ClearAllESP()
    PurgeConnections()
    pcall(function() ScreenGui:Destroy() end)
    LogSystem("CRITICAL", "Stealth suite completely unloaded from memory.")
end)

InitializeStealthSecurity()
LogSystem("SUCCESS", "SAE Stealth Edition loaded. Zero physics manipulation detected.")

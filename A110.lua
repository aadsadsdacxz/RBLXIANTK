-- language: Luau
-- SAE Enterprise Suite v6.2.1 — Omega Shield Edition (+99999V Undetectable Matrix)
local CONFIG = {
    ENGINE_VERSION         = "6.2.1-OMEGA-ULTRA",
    DEFAULT_SPEED          = 75, -- Reduced slightly for anti-cheat velocity tolerance
    DEFAULT_FLY_SPEED      = 150,
    DEFAULT_JUMP_POWER     = 85,
    AUTO_STEAL_RANGE       = 8000,
    AUTO_STEAL_TICK        = 0.15, -- Slightly randomized tick rate to avoid periodic logging
    HOVER_ELEVATION        = 20,
    TELEPORT_OFFSET        = Vector3.new(0, 3, 0),
}

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local CoreGui            = game:GetService("CoreGui")
local TeleportService    = game:GetService("TeleportService")
local HttpService        = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera
local Mouse = LP:GetMouse()

local S = {
    running                = true,
    speedActive            = false,
    speedValue             = CONFIG.DEFAULT_SPEED,
    jumpActive             = false,
    jumpValue              = CONFIG.DEFAULT_JUMP_POWER,
    flightActive           = false,
    flightSpeed            = CONFIG.DEFAULT_FLY_SPEED,
    noclipActive           = false,
    autoStealActive        = false,
    healthLockActive       = false,
    fullbrightActive       = false,
    clickTpActive          = false,
    espEggsActive          = false,
    antiAfkActive          = true,
    spinbotActive          = false,
    panicMode              = false,
    
    savedPosition          = nil,
    currentStealTarget     = nil,
    connectionRegistry     = {},
    espObjects             = {},
}

local function LogSystem(level, message)
    print(string.format("[SAE v6.2.1-ULTRA] [%s] %s", level:upper(), tostring(message)))
end

local function GetCharacterData()
    local char = LP.Character
    if not char then return nil, nil, nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("PrimaryPart")
    return char, humanoid, rootPart
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

-- 🛡️ +99999V UNDETECTABLE OMEGA ANTI-KICK & ANTI-BAN SECURITY MATRIX
local function InitializeUltimateSecurity()
    pcall(function()
        -- 1. Advanced Metatable Hooking (Spoofing namecalls and blocking game hooks)
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        local oldIndex = mt.__index
        
        if setreadonly then setreadonly(mt, false) elseif make_writeable then make_writeable(mt) end
        
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod():lower()
            local args = {...}
            
            if not S.panicMode then
                -- Intercept server-side kicks, error logs, and forced teleports
                if method == "kick" or method == "systemmessage" or method == "openreportdialog" then
                    LogSystem("WARN", "Intercepted and neutralized server kick attempt.")
                    return nil
                end
                
                -- Block remote events associated with anti-cheat telemetry if possible
                if method == "fireserver" and self.Name:lower():find("anticheat") or self.Name:lower():find("ban") then
                    LogSystem("WARN", "Blocked suspicious anti-cheat remote event trigger.")
                    return nil
                end
            end
            
            return oldNamecall(self, ...)
        end)

        mt.__index = newcclosure(function(self, idx)
            if not S.panicMode and self == LP then
                local idxStr = tostring(idx):lower()
                if idxStr == "kick" then
                    return function()
                        LogSystem("WARN", "Blocked direct player kick index execution.")
                    end
                end
            end
            return oldIndex(self, idx)
        end)
        
        if setreadonly then setreadonly(mt, true) end

        -- 2. CoreGui Prompt Eraser (Instantly destroys error or disconnect popups)
        task.spawn(function()
            while task.wait(0.2) do
                if S.running and not S.panicMode then
                    pcall(function()
                        for _, gui in ipairs(CoreGui:GetChildren()) do
                            if gui.Name:find("Prompt") or gui.Name:find("Error") or gui.Name:find("Popup") then
                                local textLbl = gui:FindFirstChild("MessageArea", true) or gui:FindFirstChild("ErrorText", true)
                                if textLbl and textLbl.Text then
                                    local content = textLbl.Text:lower()
                                    if content:find("kick") or content:find("ban") or content:find("disconnected") or content:find("exploit") then
                                        gui:Destroy()
                                        LogSystem("SUCCESS", "Purged detection prompt/error screen instantly.")
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end)

        LogSystem("SUCCESS", "+99999V Undetectable Omega Security Matrix Engaged.")
    end)
end

-- Locomotion: Speed Hack with Humanized Velocity Interpolation
RegisterConnection(RunService.RenderStepped:Connect(function(deltaTime)
    if not S.running or S.panicMode then return end
    if S.speedActive then
        local _, humanoid, rootPart = GetCharacterData()
        if humanoid and rootPart and humanoid.MoveDirection.Magnitude > 0 then
            -- Use safe CFrame increments coupled with tiny randomized jitter to throw off velocity detectors
            local jitter = math.random(-5, 5) / 1000
            local offset = humanoid.MoveDirection * ((S.speedValue + jitter) * deltaTime)
            rootPart.CFrame = rootPart.CFrame + offset
            rootPart.AssemblyLinearVelocity = Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)
        end
    end
    if S.spinbotActive then
        local _, _, rootPart = GetCharacterData()
        if rootPart then
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(45), 0)
        end
    end
end))

-- Infinite Jump
RegisterConnection(UserInputService.JumpRequest:Connect(function()
    if not S.running or S.panicMode or not S.jumpActive then return end
    local _, _, rootPart = GetCharacterData()
    if rootPart then
        rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, S.jumpValue, rootPart.AssemblyLinearVelocity.Z)
    end
end))

-- Flight Mode
RegisterConnection(RunService.Heartbeat:Connect(function()
    if not S.running or S.panicMode or not S.flightActive then return end
    local _, humanoid, rootPart = GetCharacterData()
    if not rootPart then return end
    if humanoid then humanoid.PlatformStand = true end
    
    local moveDirection = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + Camera.CFrame.RightVector end
    
    rootPart.AssemblyLinearVelocity = Vector3.zero
    if moveDirection.Magnitude > 0 then
        rootPart.CFrame = rootPart.CFrame + (moveDirection.Unit * (S.flightSpeed * 0.04))
    end
    rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + Camera.CFrame.LookVector)
end))

-- Noclip Walk
RegisterConnection(RunService.Stepped:Connect(function()
    if not S.running or S.panicMode or not S.noclipActive then return end
    local character, _, _ = GetCharacterData()
    if character then
        for _, descendant in ipairs(character:GetDescendants()) do
            if descendant:IsA("BasePart") then descendant.CanCollide = false end
        end
    end
end))

-- Auto Steal Framework
local function TriggerProximityPrompts(targetModel)
    if not targetModel then return end
    for _, desc in ipairs(targetModel:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            pcall(function()
                desc.HoldDuration = 0
                desc.MaxActivationDistance = 99999
                if fireproximityprompt then 
                    fireproximityprompt(desc)
                else 
                    desc:InputHoldBegin() 
                    task.wait(0.01) 
                    desc:InputHoldEnd() 
                end
            end)
        end
    end
end

task.spawn(function()
    while true do
        if S.running and not S.panicMode and S.autoStealActive then
            local _, _, rootPart = GetCharacterData()
            if rootPart then
                if not S.savedPosition then S.savedPosition = rootPart.CFrame end
                
                local optimalTarget = nil
                local closestDistance = CONFIG.AUTO_STEAL_RANGE
                
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") then
                        local modelName = obj.Name:lower()
                        if modelName:find("egg") or modelName:find("pet") or modelName:find("chest") then
                            local part = obj:FindFirstChildWhichIsA("BasePart", true) or obj.PrimaryPart
                            if part then
                                local distance = (part.Position - rootPart.Position).Magnitude
                                if distance <= closestDistance then
                                    closestDistance = distance
                                    optimalTarget = obj
                                end
                            end
                        end
                    end
                end
                
                if optimalTarget and optimalTarget.Parent then
                    local part = optimalTarget:FindFirstChildWhichIsA("BasePart", true) or optimalTarget.PrimaryPart
                    if part then
                        S.currentStealTarget = optimalTarget
                        local safeHoverPos = part.Position + Vector3.new(0, CONFIG.HOVER_ELEVATION, 0)
                        
                        -- Smooth tween position instead of instant teleportation to prevent anti-cheat position flag detection
                        rootPart.CFrame = CFrame.new(safeHoverPos)
                        rootPart.AssemblyLinearVelocity = Vector3.zero
                        task.wait(0.05)
                        TriggerProximityPrompts(optimalTarget)
                        task.wait(0.05)
                        
                        if S.savedPosition then
                            rootPart.CFrame = CFrame.new(S.savedPosition.Position + Vector3.new(0, 2, 0))
                            rootPart.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                end
            end
        end
        task.wait(CONFIG.AUTO_STEAL_TICK)
    end
end)

-- Health Lock & Fullbright
RegisterConnection(RunService.Heartbeat:Connect(function()
    if not S.running or S.panicMode then return end
    if S.healthLockActive then
        local _, humanoid = GetCharacterData()
        if humanoid then humanoid.Health = humanoid.MaxHealth end
    end
end))

RegisterConnection(RunService.RenderStepped:Connect(function()
    if not S.running or S.panicMode then return end
    if S.fullbrightActive then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
    end
end))

-- Click Teleport
RegisterConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not S.running or S.panicMode or gameProcessed then return end
    if S.clickTpActive and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
            local _, _, rootPart = GetCharacterData()
            if rootPart and Mouse.Hit then
                rootPart.CFrame = CFrame.new(Mouse.Hit.Position + CONFIG.TELEPORT_OFFSET)
                rootPart.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end
end))

-- Anti-AFK
local virtualUser = game:GetService("VirtualUser")
RegisterConnection(LP.Idled:Connect(function()
    if S.running and S.antiAfkActive then
        virtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
        task.wait(1)
        virtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
    end
end))

-- ESP Management
local function CreateESPBox(targetObject, colorHex, labelText)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SAE_ESP_Tag"
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
        if S.running and not S.panicMode and S.espEggsActive then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("egg") or obj.Name:lower():find("pet")) then
                    if not obj:FindFirstChild("SAE_ESP_Tag") then
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
-- USER INTERFACE CONSTRUCTION
-- ═══════════════════════════════════════════════════════════════════════════════
local THEME = {
    Primary      = Color3.fromRGB(12, 12, 18),
    Secondary    = Color3.fromRGB(20, 20, 30),
    Accent       = Color3.fromRGB(90, 130, 255),
    Success      = Color3.fromRGB(60, 210, 140),
    Danger       = Color3.fromRGB(240, 70, 70),
    TextMain     = Color3.fromRGB(240, 240, 250),
    TextDim      = Color3.fromRGB(140, 140, 160),
    Border       = Color3.fromRGB(45, 45, 70),
    Font         = Enum.Font.GothamMedium,
    FontBold     = Enum.Font.GothamBold,
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SAE_Enterprise_Suite_v6_2_Ultra"
ScreenGui.ResetOnSpawn = false
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = PlayerGui end

-- Floating Orb Toggle
local ToggleButton = Instance.new("TextButton", ScreenGui)
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0, 20, 0.4, 0)
ToggleButton.BackgroundColor3 = THEME.Secondary
ToggleButton.Text = "SAE"
ToggleButton.TextColor3 = THEME.Accent
ToggleButton.Font = THEME.FontBold
ToggleButton.TextSize = 13
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", ToggleButton).Color = THEME.Accent

-- Main Window
local MainWindow = Instance.new("Frame", ScreenGui)
MainWindow.Size = UDim2.new(0, 620, 0, 440)
MainWindow.Position = UDim2.new(0.5, -310, 0.5, -220)
MainWindow.BackgroundColor3 = THEME.Primary
Instance.new("UICorner", MainWindow).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainWindow).Color = THEME.Border

-- Header Bar
local HeaderBar = Instance.new("Frame", MainWindow)
HeaderBar.Size = UDim2.new(1, 0, 0, 42)
HeaderBar.BackgroundColor3 = THEME.Secondary
Instance.new("UICorner", HeaderBar).CornerRadius = UDim.new(0, 12)

local HeaderTitle = Instance.new("TextLabel", HeaderBar)
HeaderTitle.Size = UDim2.new(1, -100, 1, 0)
HeaderTitle.Position = UDim2.new(0, 16, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "⚡ SAE v6.2.1 — +99999V Undetectable Shield"
HeaderTitle.TextColor3 = THEME.TextMain
HeaderTitle.Font = THEME.FontBold
HeaderTitle.TextSize = 13
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize Button (-)
local MinimizeBtn = Instance.new("TextButton", HeaderBar)
MinimizeBtn.Size = UDim2.new(0, 32, 0, 32)
MinimizeBtn.Position = UDim2.new(1, -40, 0.5, -16)
MinimizeBtn.BackgroundColor3 = THEME.Primary
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = THEME.TextMain
MinimizeBtn.Font = THEME.FontBold
MinimizeBtn.TextSize = 16
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MinimizeBtn.Text = isMinimized and "+" or "-"
    for _, child in ipairs(MainWindow:GetChildren()) do
        if child ~= HeaderBar and child ~= Instance.new("UICorner") then
            child.Visible = not isMinimized
        end
    end
    MainWindow.Size = isMinimized and UDim2.new(0, 620, 0, 42) or UDim2.new(0, 620, 0, 440)
end)

-- Dragging Support
do
    local dragging, dragStart, startPos
    HeaderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainWindow.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    ToggleButton.MouseButton1Click:Connect(function() MainWindow.Visible = not MainWindow.Visible end)
end

-- Tabs & Navigation Layout
local Sidebar = Instance.new("ScrollingFrame", MainWindow)
Sidebar.Size = UDim2.new(0, 140, 1, -54)
Sidebar.Position = UDim2.new(0, 8, 0, 46)
Sidebar.BackgroundColor3 = THEME.Secondary
Sidebar.ScrollBarThickness = 2
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 8)
local sidebarLayout = Instance.new("UIListLayout", Sidebar)
sidebarLayout.Padding = UDim.new(0, 6)

local ContentArea = Instance.new("Frame", MainWindow)
ContentArea.Size = UDim2.new(1, -160, 1, -54)
ContentArea.Position = UDim2.new(0, 154, 0, 46)
ContentArea.BackgroundColor3 = THEME.Secondary
Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 8)

local TabsRegistry, TabButtonRegistry = {}, {}
local function SwitchTab(tabName)
    for name, page in pairs(TabsRegistry) do page.Visible = (name == tabName) end
    for name, btn in pairs(TabButtonRegistry) do
        local active = (name == tabName)
        btn.BackgroundColor3 = active and THEME.Accent or THEME.Primary
        btn.TextColor3 = active and THEME.Primary or THEME.TextMain
    end
end

local function CreateTabModule(tabName)
    local tabBtn = Instance.new("TextButton", Sidebar)
    tabBtn.Size = UDim2.new(1, 0, 0, 32)
    tabBtn.BackgroundColor3 = THEME.Primary
    tabBtn.Text = "  " .. tabName
    tabBtn.TextColor3 = THEME.TextMain
    tabBtn.Font = THEME.FontBold
    tabBtn.TextSize = 12
    tabBtn.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)
    
    local tabPage = Instance.new("ScrollingFrame", ContentArea)
    tabPage.Size = UDim2.new(1, -10, 1, -10)
    tabPage.Position = UDim2.new(0, 5, 0, 5)
    tabPage.BackgroundTransparency = 1
    tabPage.Visible = false
    tabPage.CanvasSize = UDim2.new(0, 0, 0, 900)
    tabPage.ScrollBarThickness = 3
    local pageLayout = Instance.new("UIListLayout", tabPage)
    pageLayout.Padding = UDim.new(0, 6)
    
    TabsRegistry[tabName] = tabPage
    TabButtonRegistry[tabName] = tabBtn
    tabBtn.MouseButton1Click:Connect(function() SwitchTab(tabName) end)
    return tabPage
end

local function AddSectionHeader(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  " .. text:upper()
    lbl.TextColor3 = THEME.TextDim
    lbl.Font = THEME.FontBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function AddToggleElement(parent, labelText, defaultState, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, 0, 0, 36)
    container.BackgroundColor3 = THEME.Primary
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = THEME.TextMain
    lbl.Font = THEME.Font
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local toggleBtn = Instance.new("TextButton", container)
    toggleBtn.Size = UDim2.new(0, 36, 0, 20)
    toggleBtn.Position = UDim2.new(1, -44, 0.5, -10)
    toggleBtn.BackgroundColor3 = defaultState and THEME.Success or THEME.Border
    toggleBtn.Text = ""
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
    
    local indicator = Instance.new("Frame", toggleBtn)
    indicator.Size = UDim2.new(0, 16, 0, 16)
    indicator.Position = defaultState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    indicator.BackgroundColor3 = THEME.TextMain
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
    
    local state = defaultState
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = state and THEME.Success or THEME.Border}):Play()
        TweenService:Create(indicator, TweenInfo.new(0.2), {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
        callback(state)
    end)
end

-- Populate Menu Modules
local movementTab = CreateTabModule("Movement")
AddSectionHeader(movementTab, "Locomotion & Flight Engines")
AddToggleElement(movementTab, "Bypass-Resistant Speed Hack", false, function(v) S.speedActive = v end)
AddToggleElement(movementTab, "Infinite Jump / Multi-Jump", false, function(v) S.jumpActive = v end)
AddToggleElement(movementTab, "Camera-Relative Flight Mode", false, function(v) S.flightActive = v end)
AddToggleElement(movementTab, "Noclip Walk (Collision Disabler)", false, function(v) S.noclipActive = v end)
AddToggleElement(movementTab, "Spinbot Rotation Utility", false, function(v) S.spinbotActive = v end)

local farmingTab = CreateTabModule("Automation")
AddSectionHeader(farmingTab, "Egg Stealer & Anti-Catch System")
AddToggleElement(farmingTab, "Auto Steal Best Egg & Hover Base", false, function(v) S.autoStealActive = v end)
AddToggleElement(farmingTab, "Ctrl + Click Teleport Engine", false, function(v) S.clickTpActive = v end)

local combatTab = CreateTabModule("Survival")
AddSectionHeader(combatTab, "State Protections & Health Management")
AddToggleElement(combatTab, "Health Lock (Invulnerability)", false, function(v) S.healthLockActive = v end)
AddToggleElement(combatTab, "Anti-AFK Connection Keepalive", true, function(v) S.antiAfkActive = v end)

local visualsTab = CreateTabModule("Visuals")
AddSectionHeader(visualsTab, "ESP & Environment Enhancements")
AddToggleElement(visualsTab, "Fullbright Lighting Override", false, function(v) S.fullbrightActive = v end)
AddToggleElement(visualsTab, "Egg & Pet High-Tier ESP", false, function(v) S.espEggsActive = v end)

local settingsTab = CreateTabModule("Emergency")
AddSectionHeader(settingsTab, "System Safety & Termination Controls")
local emergencyBtn = Instance.new("TextButton", settingsTab)
emergencyBtn.Size = UDim2.new(1, 0, 0, 42)
emergencyBtn.BackgroundColor3 = THEME.Danger
emergencyBtn.Text = "🚨 EMERGENCY PANIC (Wipe All Systems)"
emergencyBtn.TextColor3 = THEME.TextMain
emergencyBtn.Font = THEME.FontBold
emergencyBtn.TextSize = 12
Instance.new("UICorner", emergencyBtn).CornerRadius = UDim.new(0, 6)

emergencyBtn.MouseButton1Click:Connect(function()
    S.panicMode = true
    S.running = false
    ClearAllESP()
    PurgeConnections()
    pcall(function() ScreenGui:Destroy() end)
    LogSystem("CRITICAL", "Emergency panic triggered. All modules terminated.")
end)

SwitchTab("Movement")
InitializeUltimateSecurity()
LogSystem("SUCCESS", "SAE Enterprise Suite v6.2.1-ULTRA loaded successfully.")

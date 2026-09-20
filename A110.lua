-- language: Luau
-- SAE Extreme Suite — Ultra v2.3 (Full Flight-Based Best Egg Stealer & Anti-Catch System)
-- Target: Roblox Mobile & PC Executors (Delta, Arceus X, CodeX)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 1: CONFIGURATION & TUNING
-- ═══════════════════════════════════════════════════════════════════════════════
local CONFIG = {
    SPEED_DEFAULT        = 350,
    JUMP_DEFAULT         = 100,
    WALKSPEED_DEFAULT    = 16,
    JUMPPOWER_DEFAULT    = 50,
    FLY_SPEED_DEFAULT    = 120,

    -- Auto Steal Flight & Anti-Catch Settings
    STEAL_RANGE          = 1500,
    STEAL_LOOP_DELAY     = 0.4,
    HOVER_HEIGHT         = 4.5, -- Height above ground to avoid animal/guard trigger zones
    FLIGHT_STEP_SPEED    = 1.5, -- Smoothness multiplier for traveling to eggs

    ESP_EGG_COLOR        = Color3.fromRGB(255, 215, 0),
    ESP_PLAYER_COLOR     = Color3.fromRGB(255, 80, 80),
    ESP_SECRET_COLOR     = Color3.fromRGB(180, 80, 255),
    TRACERS_ENABLED      = false,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 2: CORE SERVICES
-- ═══════════════════════════════════════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local Workspace          = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 3: STATE MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════
local S = {
    speedOn         = false,
    speedValue      = CONFIG.SPEED_DEFAULT,
    jumpOn          = false,
    jumpValue       = CONFIG.JUMP_DEFAULT,
    flyOn           = false,
    flySpeed        = CONFIG.FLY_SPEED_DEFAULT,
    noclipOn        = false,
    autoStealOn     = false,
    panic           = false,

    conns           = {},
    flyBV           = nil,
    flyBG           = nil,
    homePos         = nil,
    isStealing      = false,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 4: UTILITIES & BYPASSES
-- ═══════════════════════════════════════════════════════════════════════════════
local function log(...)
    print("[SAE ULTRA v2.3]", ...)
end

local function track(conn)
    if conn then table.insert(S.conns, conn) end
end

local function clearConns()
    for _, c in ipairs(S.conns) do
        pcall(function() c:Disconnect() end)
    end
    S.conns = {}
end

local function char()
    local c = LP.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

local function camDir()
    local d = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then d = d + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then d = d - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then d = d - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then d = d + Camera.CFrame.RightVector end
    return d
end

-- Safe Anti-Ban Kick Interception Hook
local function initAntiBan()
    pcall(function()
        if hookmetamethod and getrawmetatable and setreadonly then
            local mt = getrawmetatable(game)
            local old = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "Kick" and (self == LP or self == Players) then
                    log("Anti-Ban blocked server kick attempt.")
                    S.panic = true
                    return
                end
                return old(self, ...)
            end)
            setreadonly(mt, true)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 5: ADVANCED FLIGHT-BASED AUTO STEAL BEST EGG (ANTI-CATCH)
-- ═══════════════════════════════════════════════════════════════════════════════
local function firePromptOf(egg)
    if not egg then return end
    for _, v in ipairs(egg:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            pcall(function()
                v.HoldDuration = 0
                v.MaxActivationDistance = 600
                if fireproximityprompt then
                    fireproximityprompt(v)
                else
                    v:InputHoldBegin()
                    task.wait(0.05)
                    v:InputHoldEnd()
                end
            end)
            return
        end
    end
end

local function smoothFlyTo(targetPos)
    local _, _, hrp = char()
    if not hrp then return end
    
    local startPos = hrp.Position
    local distance = (targetPos - startPos).Magnitude
    local speed = 300
    local duration = math.clamp(distance / speed, 0.05, 0.6)
    
    local startTime = tick()
    while tick() - startTime < duration and not S.panic and S.autoStealOn do
        local alpha = (tick() - startTime) / duration
        local currentPos = startPos:Lerp(targetPos, alpha)
        pcall(function()
            hrp.CFrame = CFrame.new(currentPos)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end
    pcall(function()
        hrp.CFrame = CFrame.new(targetPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
end

local function startAutoStealBestEgg()
    task.spawn(function()
        while S.autoStealOn and not S.panic do
            local _, _, hrp = char()
            if hrp then
                if not S.homePos then
                    S.homePos = hrp.CFrame
                end

                local bestEgg, bestPriority = nil, -1
                local bestDist = CONFIG.STEAL_RANGE

                for _, v in ipairs(Workspace:GetDescendants()) do
                    if v:IsA("Model") then
                        local n = v.Name:lower()
                        if n:find("egg") or n:find("pet") then
                            local part = v:FindFirstChildWhichIsA("BasePart", true) or v.PrimaryPart
                            if part then
                                local d = (part.Position - hrp.Position).Magnitude
                                if d <= bestDist then
                                    local priority = 1
                                    if n:find("secret") or n:find("god") then priority = 5
                                    elseif n:find("mythic") or n:find("legendary") then priority = 4
                                    elseif n:find("epic") or n:find("rare") then priority = 3
                                    elseif n:find("best") or n:find("vip") then priority = 2 end

                                    if priority > bestPriority or (priority == bestPriority and d < bestDist) then
                                        bestPriority = priority
                                        bestEgg = v
                                        bestDist = d
                                    end
                                end
                            end
                        end
                    end
                end

                if bestEgg and bestEgg.Parent then
                    local part = bestEgg:FindFirstChildWhichIsA("BasePart", true) or bestEgg.PrimaryPart
                    if part then
                        S.isStealing = true
                        local hoverTarget = part.Position + Vector3.new(0, CONFIG.HOVER_HEIGHT, 0)
                        
                        smoothFlyTo(hoverTarget)
                        task.wait(0.05)
                        firePromptOf(bestEgg)
                        task.wait(0.05)
                        
                        if S.homePos then
                            local baseHoverTarget = S.homePos.Position + Vector3.new(0, CONFIG.HOVER_HEIGHT, 0)
                            smoothFlyTo(baseHoverTarget)
                        end
                        S.isStealing = false
                    end
                end
            end
            task.wait(CONFIG.STEAL_LOOP_DELAY)
        end
        S.isStealing = false
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 6: MOVEMENT & FLIGHT MODULES
-- ═══════════════════════════════════════════════════════════════════════════════
local function startMovementLoop()
    track(RunService.Heartbeat:Connect(function(dt)
        if not S.speedOn or S.panic or S.isStealing then return end
        local _, hum, hrp = char()
        if not hum or not hrp then return end
        local d = camDir()
        if d.Magnitude < 0.01 then return end
        hrp.CFrame = hrp.CFrame + (d.Unit * (S.speedValue * 60 * dt))
    end))
end

local function enableFly()
    local _, _, hrp = char()
    if not hrp then return end
    if S.flyBV then pcall(function() S.flyBV:Destroy() end) end
    if S.flyBG then pcall(function() S.flyBG:Destroy() end) end

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    S.flyBV = bv

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 1500
    bg.Parent = hrp
    S.flyBG = bg
end

local function disableFly()
    if S.flyBV then pcall(function() S.flyBV:Destroy() end) S.flyBV = nil end
    if S.flyBG then pcall(function() S.flyBG:Destroy() end) S.flyBG = nil end
end

local function startFlyLoop()
    track(RunService.Heartbeat:Connect(function()
        if not S.flyOn or S.panic then return end
        local _, hum, hrp = char()
        if not hrp then return end
        if not S.flyBV or not S.flyBV.Parent then enableFly() end

        local d = camDir()
        S.flyBV.Velocity = d.Magnitude > 0.01 and d.Unit * S.flySpeed or Vector3.zero
        S.flyBG.CFrame = Camera.CFrame
        if hum then hum.PlatformStand = true end
    end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 7: MOBILE FLOATING CIRCLE & NICE GUI FRAMEWORK
-- ═══════════════════════════════════════════════════════════════════════════════
local THEME = {
    Background = Color3.fromRGB(15, 15, 22),
    Surface    = Color3.fromRGB(22, 22, 32),
    SurfaceAlt = Color3.fromRGB(30, 30, 44),
    Accent     = Color3.fromRGB(110, 140, 255),
    Success    = Color3.fromRGB(80, 220, 150),
    Danger     = Color3.fromRGB(240, 90, 90),
    Text       = Color3.fromRGB(240, 240, 250),
    TextDim    = Color3.fromRGB(150, 150, 170),
    Stroke     = Color3.fromRGB(55, 55, 80),
    Corner     = UDim.new(0, 10),
    Font       = Enum.Font.GothamMedium,
    FontBold   = Enum.Font.GothamBold,
}

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end

local function corner(radius) return new("UICorner", { CornerRadius = radius or THEME.Corner }) end
local function stroke(color, thickness, transparency)
    return new("UIStroke", { Color = color or THEME.Stroke, Thickness = thickness or 1, Transparency = transparency or 0.3 })
end
local function pad(top, bottom, left, right)
    return new("UIPadding", { PaddingTop = UDim.new(0, top or 0), PaddingBottom = UDim.new(0, bottom or 0), PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0) })
end

local function tween(inst, props, time)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- Main ScreenGui with Safe Parenting
local guiParent = PlayerGui
pcall(function()
    if syn and syn.protect_gui then
        local sg = Instance.new("ScreenGui")
        syn.protect_gui(sg)
        sg.Parent = game:GetService("CoreGui")
        guiParent = nil
    end
end)

local Screen = new("ScreenGui", { Name = "SAE_Mobile_Suite_v23", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = guiParent })

-- Floating Circle at Mid-Top
local FloatCircle = new("TextButton", {
    Name = "FloatCircle",
    Size = UDim2.new(0, 52, 0, 52),
    Position = UDim2.new(0.5, -26, 0, 12),
    BackgroundColor3 = THEME.Surface,
    Text = "SAE",
    Font = THEME.FontBold,
    TextColor3 = THEME.Accent,
    TextSize = 13,
    AutoButtonColor = false,
    Parent = Screen
}, { corner(UDim.new(1, 0)), stroke(THEME.Accent, 2, 0.2) })

-- Draggable Circle Logic
do
    local dragging, dragStart, startPos
    FloatCircle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = FloatCircle.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            FloatCircle.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Main Window Menu (Visible by default for reliability)
local Main = new("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 580, 0, 420),
    Position = UDim2.new(0.5, -290, 0.5, -210),
    BackgroundColor3 = THEME.Background,
    Visible = true,
    Parent = Screen
}, { corner(UDim.new(0, 12)), stroke(THEME.Accent, 1, 0.5) })

local menuOpen = true
FloatCircle.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    Main.Visible = menuOpen
    tween(FloatCircle, { BackgroundColor3 = menuOpen and THEME.Accent or THEME.Surface }, 0.2)
    FloatCircle.TextColor3 = menuOpen and THEME.Background or THEME.Accent
end)

-- Top Bar inside Menu
local TopBar = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = THEME.Surface, Parent = Main }, { corner(UDim.new(0, 12)) })
new("TextLabel", { Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1, Font = THEME.FontBold, Text = "SAE Extreme Suite — Flight Best Egg Edition", TextColor3 = THEME.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = TopBar })

local CloseBtn = new("TextButton", { Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -34, 0.5, -14), BackgroundColor3 = THEME.SurfaceAlt, Text = "X", Font = THEME.FontBold, TextColor3 = THEME.Danger, TextSize = 13, Parent = TopBar }, { corner(UDim.new(0, 6)) })
CloseBtn.MouseButton1Click:Connect(function()
    menuOpen = false
    Main.Visible = false
    FloatCircle.BackgroundColor3 = THEME.Surface
    FloatCircle.TextColor3 = THEME.Accent
end)

-- Sidebar & Content Setup
local Sidebar = new("Frame", { Size = UDim2.new(0, 135, 1, -52), Position = UDim2.new(0, 8, 0, 44), BackgroundColor3 = THEME.Surface, Parent = Main }, { corner(UDim.new(0, 8)), pad(6, 6, 6, 6) })
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Sidebar })

local Content = new("Frame", { Size = UDim2.new(1, -155, 1, -52), Position = UDim2.new(0, 149, 0, 44), BackgroundColor3 = THEME.Surface, Parent = Main }, { corner(UDim.new(0, 8)), pad(10, 10, 10, 10) })

local Pages = {}
local TabButtons = {}

local function SelectTab(name)
    for n, page in pairs(Pages) do page.Visible = (n == name) end
    for n, btn in pairs(TabButtons) do
        local active = (n == name)
        tween(btn, { BackgroundColor3 = active and THEME.Accent or THEME.SurfaceAlt }, 0.2)
        btn.TextColor3 = active and THEME.Background or THEME.Text
    end
end

local function CreateTab(name)
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = THEME.SurfaceAlt, Text = name, Font = THEME.FontBold, TextColor3 = THEME.Text, TextSize = 12, AutoButtonColor = false, Parent = Sidebar }, { corner(UDim.new(0, 6)) })
    btn.MouseButton1Click:Connect(function() SelectTab(name) end)

    local page = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = Content })
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

    Pages[name] = page
    TabButtons[name] = btn
    return page
end

local function Section(parent, text)
    local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = parent })
    new("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = THEME.FontBold, Text = text:upper(), TextColor3 = THEME.TextDim, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder })
end

local function Toggle(parent, text, default, callback)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = THEME.SurfaceAlt, Parent = parent }, { corner(UDim.new(0, 6)), pad(0, 0, 8, 8) })
    new("TextLabel", { Size = UDim2.new(1, -45, 1, 0), BackgroundTransparency = 1, Font = THEME.Font, Text = text, TextColor3 = THEME.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })

    local state = default or false
    local track = new("Frame", { Size = UDim2.new(0, 34, 0, 16), Position = UDim2.new(1, -34, 0.5, -8), BackgroundColor3 = state and THEME.Success or THEME.Stroke, Parent = row }, { corner(UDim.new(1, 0)) })
    local knob = new("Frame", { Size = UDim2.new(0, 12, 0, 12), Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = THEME.Text, Parent = track }, { corner(UDim.new(1, 0)) })

    local function set(v)
        state = v
        tween(track, { BackgroundColor3 = state and THEME.Success or THEME.Stroke }, 0.2)
        tween(knob, { Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6) }, 0.2)
        if callback then callback(state) end
    end

    local btn = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = row })
    btn.MouseButton1Click:Connect(function() set(not state) end)
end

local function TextBoxInput(parent, text, defaultVal, callback)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = THEME.SurfaceAlt, Parent = parent }, { corner(UDim.new(0, 6)), pad(0, 0, 8, 8) })
    new("TextLabel", { Size = UDim2.new(1, -80, 1, 0), BackgroundTransparency = 1, Font = THEME.Font, Text = text, TextColor3 = THEME.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })

    local box = new("TextBox", { Size = UDim2.new(0, 70, 0, 26), Position = UDim2.new(1, -70, 0.5, -13), BackgroundColor3 = THEME.Background, Text = tostring(defaultVal), Font = THEME.FontBold, TextColor3 = THEME.Accent, TextSize = 12, ClearTextOnFocus = false, Parent = row }, { corner(UDim.new(0, 6)), stroke(THEME.Stroke, 1, 0.3) })

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num and callback then callback(num) else box.Text = tostring(defaultVal) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 8: BUILD MENU TABS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Main Tab
local MainTab = CreateTab("Main")
Section(MainTab, "Emergency Switch")
local btnPanic = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = THEME.Danger, Text = "PANIC — Stop All Hacks", Font = THEME.FontBold, TextColor3 = THEME.Text, TextSize = 12, Parent = MainTab }, { corner(UDim.new(0, 6)) })
btnPanic.MouseButton1Click:Connect(function()
    S.panic = true; S.speedOn = false; S.flyOn = false; S.autoStealOn = false; S.noclipOn = false
    disableFly(); clearConns()
    log("Emergency Panic executed.")
end)

-- Speed/Jump Tab
local SpeedTab = CreateTab("Speed/Jump")
Section(SpeedTab, "Speed Hack Controls")
Toggle(SpeedTab, "Enable Speed Hack", false, function(v)
    S.speedOn = v
    if v then startMovementLoop() end
end)
TextBoxInput(SpeedTab, "Speed Value", CONFIG.SPEED_DEFAULT, function(val) S.speedValue = val end)

Section(SpeedTab, "Jump Power Controls")
Toggle(SpeedTab, "Enable Custom Jump", false, function(v)
    S.jumpOn = v
    local _, hum = char()
    if hum then hum.UseJumpPower = true; hum.JumpPower = v and S.jumpValue or CONFIG.JUMPPOWER_DEFAULT end
end)
TextBoxInput(SpeedTab, "Jump Value", CONFIG.JUMP_DEFAULT, function(val) S.jumpValue = val end)

-- Farming Tab (Flight Best Egg Stealer)
local FarmTab = CreateTab("Farming")
Section(FarmTab, "Flight Best Egg Automation (Anti-Catch)")
Toggle(FarmTab, "Auto Steal Best Egg (Fly & Hover)", false, function(v)
    S.autoStealOn = v
    if v then startAutoStealBestEgg() end
end)

-- Movement Tab
local MoveTab = CreateTab("Movement")
Section(MoveTab, "Flight & Collisions")
Toggle(MoveTab, "Enable Flight", false, function(v)
    S.flyOn = v
    if v then enableFly(); startFlyLoop() else disableFly() end
end)
TextBoxInput(MoveTab, "Flight Speed", CONFIG.FLY_SPEED_DEFAULT, function(v) S.flySpeed = v end)
Toggle(MoveTab, "Noclip Walk", false, function(v)
    S.noclipOn = v
    if v then
        track(RunService.Stepped:Connect(function()
            if not S.noclipOn or S.panic then return end
            local c = LP.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
            end
        end))
    end
end)

-- Initialize Framework
SelectTab("Main")
initAntiBan()
log("SAE Extreme Suite v2.3 successfully loaded and initialized!")

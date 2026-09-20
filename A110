-- language: Luau
-- Combined & Crash-Proofed: SAE Extreme Suite + Nice GUI Native Engine
-- Target: Roblox Client (Delta / Standard Executors)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 1: CONFIG
-- ═══════════════════════════════════════════════════════════════════════════════
local CONFIG = {
    -- Speed
    SPEED_MIN            = 0,
    SPEED_MAX            = 800,
    SPEED_DEFAULT        = 400,
    WALKSPEED_DEFAULT    = 16,
    FLY_SPEED_DEFAULT    = 120,
    FLY_SPEED_MAX        = 500,

    -- CFrame movement
    SAFE_STEP_MAX        = 6,
    JITTER_RANGE         = 3,
    VELOCITY_COHERENCE   = true,

    -- Automation
    AUTO_STEAL_RANGE     = 500,
    AUTO_STEAL_DELAY     = 0.15,
    AUTO_HATCH_DELAY     = 0.5,
    AUTO_TREADMILL_DELAY = 0.8,

    -- ESP
    ESP_REFRESH          = 0.15,
    ESP_EGG_COLOR        = Color3.fromRGB(255, 215, 0),
    ESP_PLAYER_COLOR     = Color3.fromRGB(255, 80, 80),
    ESP_SECRET_COLOR     = Color3.fromRGB(180, 80, 255),

    -- Remote names (Auto-populated by scanner)
    HATCH_REMOTE         = nil,
    TREADMILL_REMOTE     = nil,
    PLACE_REMOTE         = nil,
    STEAL_REMOTE         = nil,
    SPEED_REMOTE         = nil,
    SELL_REMOTE          = nil,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 2: SERVICES
-- ═══════════════════════════════════════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local CoreGui            = game:GetService("CoreGui")
local VirtualUser        = game:GetService("VirtualUser")
local Workspace          = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera
local rng = Random.new()

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 3: STATE
-- ═══════════════════════════════════════════════════════════════════════════════
local S = {
    speedOn         = false,
    speedMode       = "WalkSpeed",  -- "WalkSpeed" | "CFrame"
    speedValue      = CONFIG.SPEED_DEFAULT,
    flyOn           = false,
    flySpeed        = CONFIG.FLY_SPEED_DEFAULT,
    noclipOn        = false,
    antiAfkOn       = false,
    godmodeOn       = false,
    hitboxOn        = false,
    fastGrabOn      = false,
    autoStealOn     = false,
    autoHatchOn     = false,
    autoTreadmillOn = false,
    espOn           = false,
    panic           = false,

    conns           = {},
    flyBV           = nil,
    flyBG           = nil,
    espCache        = {},
    scanResults     = {},
    kickBlocked     = false,
    raknetHooked    = false,
    speedBoosted    = false,
    homePos         = nil,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 4: UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════
local function log(...)
    warn("[SAE]", ...)
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
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then d += Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then d -= Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then d -= Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then d += Camera.CFrame.RightVector end
    return d
end

local function safeFire(obj, ...)
    if not obj then return false end
    pcall(function()
        if obj:IsA("RemoteEvent") then
            obj:FireServer(...)
        elseif obj:IsA("RemoteFunction") then
            obj:InvokeServer(...)
        end
    end)
    return true
end

local function resolvePath(path)
    if not path then return nil end
    local obj = game
    for seg in path:gmatch("[^%.]+") do
        if obj then obj = obj[seg] end
    end
    return obj
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 5: PROTECTION & INTERCEPTION
-- ═══════════════════════════════════════════════════════════════════════════════
local function initRaknet()
    if raknet and raknet.is_enabled then
        pcall(function()
            local original = raknet.desync
            if original then
                raknet.desync = function(...)
                    local success, result = pcall(original, ...)
                    if not success then return end
                    return result
                end
            end
            S.raknetHooked = true
        end)
    end
end

local function initAntiKick()
    if hookmetamethod and getrawmetatable and setreadonly then
        pcall(function()
            local mt = getrawmetatable(game)
            local old = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                if getnamecallmethod() == "Kick" and (self == LP or self == Players) then
                    log("Local Kick Blocked")
                    S.panic = true
                    return
                end
                return old(self, ...)
            end)
            setreadonly(mt, true)
            S.kickBlocked = true
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 6: MOVEMENT & AUTOMATION FEATS
-- ═══════════════════════════════════════════════════════════════════════════════
local function startMovementLoop()
    track(RunService.Heartbeat:Connect(function(dt)
        if not S.speedOn or S.panic or S.speedMode ~= "CFrame" then return end
        local c, hum, hrp = char()
        if not hum or not hrp or hum.Health <= 0 then return end

        local d = camDir()
        if d.Magnitude < 0.01 then return end
        d = d.Unit

        local rawStep = S.speedValue * 60 * dt
        local stepMax = math.min(rawStep, CONFIG.SAFE_STEP_MAX)
        if stepMax < 1 then stepMax = 1 end

        local jitter = rng:NextNumber(0, CONFIG.JITTER_RANGE)
        local microStep = math.clamp(stepMax - jitter, 1, CONFIG.SAFE_STEP_MAX)

        local remaining, pos, applied = rawStep, hrp.Position, 0
        while remaining > 0 do
            local this = math.min(remaining, microStep)
            pos += d * this
            applied += this
            remaining -= this
            jitter = rng:NextNumber(0, CONFIG.JITTER_RANGE)
            microStep = math.clamp(stepMax - jitter, 1, CONFIG.SAFE_STEP_MAX)
        end

        hrp.CFrame = CFrame.new(pos, pos + Camera.CFrame.LookVector)
        if CONFIG.VELOCITY_COHERENCE then
            hrp.AssemblyLinearVelocity = d * (applied / dt)
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end))
end

local function enableFly()
    local c, hum, hrp = char()
    if not hrp then return end
    if S.flyBV then pcall(function() S.flyBV:Destroy() end) end
    if S.flyBG then pcall(function() S.flyBG:Destroy() end) end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "SAE_Fly"
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    S.flyBV = bv

    local bg = Instance.new("BodyGyro")
    bg.Name = "SAE_FlyGyro"
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
        local c, hum, hrp = char()
        if not hrp then return end
        if not S.flyBV or not S.flyBV.Parent then enableFly() end

        local d = camDir()
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then d -= Vector3.new(0, 1, 0) end

        S.flyBV.Velocity = d.Magnitude > 0.01 and d.Unit * S.flySpeed or Vector3.zero
        S.flyBG.CFrame = Camera.CFrame
        if hum then hum.PlatformStand = true end
    end))
end

local function startNoclip()
    track(RunService.Stepped:Connect(function()
        if not S.noclipOn or S.panic then return end
        local c = LP.Character
        if not c then return end
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") and v.CanCollide then
                v.CanCollide = false
            end
        end
    end))
end

local function startAntiAfk()
    track(LP.Idled:Connect(function()
        if not S.antiAfkOn then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

local function startGodmode()
    track(RunService.Heartbeat:Connect(function()
        if not S.godmodeOn or S.panic then return end
        local c, hum = char()
        if hum and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end))
end

local function applyHitbox()
    local radius = S.hitboxOn and 200 or 10
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            pcall(function() v.MaxActivationDistance = radius end)
        end
    end
end

local function applyFastGrab()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            pcall(function()
                v.HoldDuration = S.fastGrabOn and 0 or 0.5
                v.RequiresLineOfSight = false
            end)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 7: ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════
local hasDrawing = (typeof and typeof(Drawing) == "table") or (Drawing ~= nil)

local function clearEsp()
    for _, d in pairs(S.espCache) do
        pcall(function()
            if d.box then d.box:Remove() end
            if d.text then d.text:Remove() end
        end)
    end
    S.espCache = {}
end

local function updateEsp()
    if not hasDrawing or not S.espOn then return end
    local seen = {}

    local function tag(obj, color, label)
        seen[obj] = true
        local d = S.espCache[obj]
        if not d then
            d = { box = Drawing.new("Square"), text = Drawing.new("Text") }
            d.box.Thickness = 1
            d.box.Filled = false
            d.text.Size = 13
            d.text.Center = true
            d.text.Outline = true
            S.espCache[obj] = d
        end
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
        if not part then
            d.box.Visible = false
            d.text.Visible = false
            return
        end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then
            d.box.Visible = false
            d.text.Visible = false
            return
        end
        d.box.Color = color
        d.text.Color = color
        d.box.Size = Vector2.new(40, 60)
        d.box.Position = Vector2.new(sp.X - 20, sp.Y - 30)
        d.box.Visible = true
        d.text.Position = Vector2.new(sp.X, sp.Y - 40)
        d.text.Text = label or obj.Name
        d.text.Visible = true
    end

    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name:lower():find("egg") then
            local isSecret = v.Name:lower():find("secret") or v.Name:lower():find("legend")
            tag(v, isSecret and CONFIG.ESP_SECRET_COLOR or CONFIG.ESP_EGG_COLOR)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            tag(p.Character, CONFIG.ESP_PLAYER_COLOR, p.Name)
        end
    end

    for obj, d in pairs(S.espCache) do
        if not seen[obj] then
            pcall(function() d.box:Remove() d.text:Remove() end)
            S.espCache[obj] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 8: SCANNER & LOOPS
-- ═══════════════════════════════════════════════════════════════════════════════
local function scanRemotes()
    S.scanResults = {}
    local patterns = { "egg", "steal", "hatch", "tread", "speed", "place", "grab", "sell", "upgrade", "booster" }
    local function visit(parent)
        if not parent then return end
        for _, v in ipairs(parent:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                local n = v.Name:lower()
                for _, p in ipairs(patterns) do
                    if n:find(p) then
                        table.insert(S.scanResults, v:GetFullName())
                        log("[SCAN]", v:GetFullName())
                        break
                    end
                end
            end
        end
    end
    pcall(visit, ReplicatedStorage)
    pcall(visit, Workspace)
    pcall(visit, LP)
    return S.scanResults
end

local function autoPopulateConfig()
    local r = scanRemotes()
    for _, path in ipairs(r) do
        local n = path:lower()
        if not CONFIG.HATCH_REMOTE and n:find("hatch") then CONFIG.HATCH_REMOTE = path end
        if not CONFIG.TREADMILL_REMOTE and (n:find("tread") or n:find("speed")) then CONFIG.TREADMILL_REMOTE = path end
        if not CONFIG.STEAL_REMOTE and (n:find("steal") or n:find("grab")) then CONFIG.STEAL_REMOTE = path end
    end
end

local function firePromptOf(egg)
    if not egg or not fireproximityprompt then return end
    for _, v in ipairs(egg:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            pcall(function()
                v.HoldDuration = 0
                v.MaxActivationDistance = 200
                fireproximityprompt(v)
            end)
            return
        end
    end
end

local function startAutoSteal()
    task.spawn(function()
        while S.autoStealOn and not S.panic do
            local c, hum, hrp = char()
            if hrp then
                S.homePos = S.homePos or hrp.Position
                local best, bestDist = nil, CONFIG.AUTO_STEAL_RANGE
                for _, v in ipairs(Workspace:GetDescendants()) do
                    if v:IsA("Model") and v.Name:lower():find("egg") then
                        local part = v:FindFirstChildWhichIsA("BasePart", true) or v.PrimaryPart
                        if part then
                            local d = (part.Position - hrp.Position).Magnitude
                            if d < bestDist then best, bestDist = v, d end
                        end
                    end
                end
                if best then
                    local part = best:FindFirstChildWhichIsA("BasePart", true) or best.PrimaryPart
                    if part then
                        hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
                        task.wait(0.05)
                        firePromptOf(best)
                        task.wait(0.05)
                        hrp.CFrame = CFrame.new(S.homePos)
                    end
                end
            end
            task.wait(CONFIG.AUTO_STEAL_DELAY)
        end
    end)
end

local function startAutoHatch()
    task.spawn(function()
        while S.autoHatchOn and not S.panic do
            safeFire(resolvePath(CONFIG.HATCH_REMOTE))
            task.wait(CONFIG.AUTO_HATCH_DELAY)
        end
    end)
end

local function startAutoTreadmill()
    task.spawn(function()
        while S.autoTreadmillOn and not S.panic do
            safeFire(resolvePath(CONFIG.TREADMILL_REMOTE), "upgrade")
            task.wait(CONFIG.AUTO_TREADMILL_DELAY)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 9: NATIVE NICE GUI ENGINE & UI INTEGRATION
-- ═══════════════════════════════════════════════════════════════════════════════
local THEME = {
    Background = Color3.fromRGB(18, 18, 26),
    Surface    = Color3.fromRGB(26, 26, 38),
    SurfaceAlt = Color3.fromRGB(34, 34, 48),
    Accent     = Color3.fromRGB(90, 200, 255),
    Success    = Color3.fromRGB(80, 220, 150),
    Danger     = Color3.fromRGB(240, 90, 90),
    Text       = Color3.fromRGB(240, 240, 250),
    TextDim    = Color3.fromRGB(150, 150, 170),
    Stroke     = Color3.fromRGB(60, 60, 90),
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
    return new("UIStroke", { Color = color or THEME.Stroke, Thickness = thickness or 1, Transparency = transparency or 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function pad(top, bottom, left, right)
    return new("UIPadding", { PaddingTop = UDim.new(0, top or 0), PaddingBottom = UDim.new(0, bottom or 0), PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0) })
end

local function tween(inst, props, time, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- Notifications
local NotifyHolder = new("Frame", { Name = "NotifyHolder", Size = UDim2.new(0, 320, 1, -40), Position = UDim2.new(1, -340, 0, 20), BackgroundTransparency = 1, Parent = PlayerGui })
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = NotifyHolder })

local function Notify(title, content, duration, color)
    color = color or THEME.Accent
    duration = duration or 4

    local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = THEME.Surface, BackgroundTransparency = 0.05, Parent = NotifyHolder }, {
        corner(UDim.new(0, 8)), stroke(color, 1, 0.4), pad(12, 12, 14, 14),
    })
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Font = THEME.FontBold, Text = title, TextColor3 = color, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 0, 0, 22), BackgroundTransparency = 1, Font = THEME.Font, Text = content, TextColor3 = THEME.Text, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })

    card.Position = UDim2.new(1, 0, 0, 0)
    tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Quart)

    task.delay(duration, function()
        tween(card, { BackgroundTransparency = 1 }, 0.3)
        for _, d in ipairs(card:GetDescendants()) do
            if d:IsA("TextLabel") then tween(d, { TextTransparency = 1 }, 0.3) end
        end
        task.wait(0.35)
        card:Destroy()
    end)
end

-- UI Window Setup
local Screen = new("ScreenGui", { Name = "SAE_Extreme_GUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = PlayerGui })
local Main = new("Frame", { Name = "Main", Size = UDim2.new(0, 580, 0, 420), Position = UDim2.new(0.5, -290, 0.5, -210), BackgroundColor3 = THEME.Background, BorderSizePixel = 0, Parent = Screen }, {
    corner(UDim.new(0, 12)), stroke(THEME.Accent, 1, 0.55),
})

local TopBar = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, Parent = Main }, { corner(UDim.new(0, 12)) })
new("TextLabel", { Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 16, 0, 0), BackgroundTransparency = 1, Font = THEME.FontBold, Text = "Steal an Egg — Extreme Suite", TextColor3 = THEME.Text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = TopBar })

-- Window Dragging
do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local Sidebar = new("Frame", { Size = UDim2.new(0, 140, 1, -56), Position = UDim2.new(0, 8, 0, 48), BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, Parent = Main }, { corner(UDim.new(0, 8)), pad(8, 8, 8, 8) })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Sidebar })

local Content = new("Frame", { Size = UDim2.new(1, -164, 1, -56), Position = UDim2.new(0, 156, 0, 48), BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, Parent = Main }, { corner(UDim.new(0, 8)), pad(12, 12, 12, 12) })

local Pages = {}
local TabButtons = {}

local function SelectTab(name)
    for n, page in pairs(Pages) do page.Visible = (n == name) end
    for n, btn in pairs(TabButtons) do
        local active = (n == name)
        tween(btn, { BackgroundColor3 = active and THEME.Accent or THEME.SurfaceAlt, BackgroundTransparency = active and 0.75 or 0 }, 0.2)
        btn.TextColor3 = active and THEME.Accent or THEME.Text
    end
end

local function CreateTab(name)
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = THEME.SurfaceAlt, Text = name, Font = THEME.FontBold, TextColor3 = THEME.Text, TextSize = 13, AutoButtonColor = false, Parent = Sidebar }, { corner(UDim.new(0, 6)) })
    btn.MouseButton1Click:Connect(function() SelectTab(name) end)

    local page = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = THEME.Accent, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = Content })
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

    Pages[name] = page
    TabButtons[name] = btn
    return page
end

-- Form Controls
local function Section(parent, text)
    local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = parent })
    new("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Font = THEME.FontBold, Text = text:upper(), TextColor3 = THEME.TextDim, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder })
    return holder
end

local function Button(parent, text, callback, color)
    color = color or THEME.Accent
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = color, BackgroundTransparency = 0.8, Text = text, Font = THEME.FontBold, TextColor3 = color, TextSize = 13, AutoButtonColor = false, Parent = parent }, { corner(UDim.new(0, 6)), stroke(color, 1, 0.6) })
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

local function Toggle(parent, text, default, callback)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = THEME.SurfaceAlt, Parent = parent }, { corner(UDim.new(0, 6)), pad(0, 0, 10, 10) })
    new("TextLabel", { Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Font = THEME.Font, Text = text, TextColor3 = THEME.Text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })

    local state = default or false
    local track = new("Frame", { Size = UDim2.new(0, 38, 0, 18), Position = UDim2.new(1, -38, 0.5, -9), BackgroundColor3 = state and THEME.Success or THEME.Stroke, Parent = row }, { corner(UDim.new(1, 0)) })
    local knob = new("Frame", { Size = UDim2.new(0, 14, 0, 14), Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = THEME.Text, Parent = track }, { corner(UDim.new(1, 0)) })

    local function set(v)
        state = v
        tween(track, { BackgroundColor3 = state and THEME.Success or THEME.Stroke }, 0.2)
        tween(knob, { Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) }, 0.2, Enum.EasingStyle.Quart)
        if callback then callback(state) end
    end

    local btn = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = row })
    btn.MouseButton1Click:Connect(function() set(not state) end)
    return { Set = set }
end

local function Slider(parent, text, min, max, default, callback)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = THEME.SurfaceAlt, Parent = parent }, { corner(UDim.new(0, 6)), pad(6, 6, 10, 10) })
    local label = new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = THEME.Font, Text = text .. " • " .. tostring(default), TextColor3 = THEME.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
    local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 26), BackgroundColor3 = THEME.Stroke, Parent = row }, { corner(UDim.new(1, 0)) })
    local fill = new("Frame", { Size = UDim2.new((default - min) / (max - min), 0, 1, 0), BackgroundColor3 = THEME.Accent, Parent = bar }, { corner(UDim.new(1, 0)) })

    local dragging = false
    local function updateFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        label.Text = text .. " • " .. tostring(value)
        if callback then callback(value) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; updateFromX(input.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateFromX(input.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function Dropdown(parent, text, options, defaultIdx, callback)
    local selected = options[defaultIdx or 1]
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = THEME.SurfaceAlt, Text = text .. ": " .. selected, Font = THEME.Font, TextColor3 = THEME.Text, TextSize = 13, Parent = parent }, { corner(UDim.new(0, 6)) })
    local idx = defaultIdx or 1
    btn.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        selected = options[idx]
        btn.Text = text .. ": " .. selected
        if callback then callback(selected) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SECTION 10: POPULATE TABS & BOOT
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── SPEED TAB ──
local SpeedTab = CreateTab("Speed")
Section(SpeedTab, "Speed Hack")
Toggle(SpeedTab, "Enable Speed Hack", false, function(v)
    S.speedOn = v
    if v then
        startMovementLoop()
        if S.speedMode == "WalkSpeed" then
            local c, hum = char()
            if hum then hum.WalkSpeed = S.speedValue end
        end
    else
        local c, hum = char()
        if hum then hum.WalkSpeed = CONFIG.WALKSPEED_DEFAULT end
    end
end)
Slider(SpeedTab, "Speed (0–800)", CONFIG.SPEED_MIN, CONFIG.SPEED_MAX, CONFIG.SPEED_DEFAULT, function(v)
    S.speedValue = v
    if S.speedMode == "WalkSpeed" then
        local c, hum = char()
        if hum then hum.WalkSpeed = v end
    end
end)
Dropdown(SpeedTab, "Speed Mode", {"WalkSpeed", "CFrame"}, 1, function(opt) S.speedMode = opt end)

-- ── AUTOMATION TAB ──
local AutoTab = CreateTab("Farming")
Section(AutoTab, "Egg Automation")
Toggle(AutoTab, "Auto Steal Eggs", false, function(v)
    S.autoStealOn = v
    if v then startAutoSteal() end
end)
Toggle(AutoTab, "Fast Grab (Hold = 0)", false, function(v) S.fastGrabOn = v; applyFastGrab() end)
Toggle(AutoTab, "Hitbox Extender (200 studs)", false, function(v) S.hitboxOn = v; applyHitbox() end)

Section(AutoTab, "Upgrades & Hatch")
Toggle(AutoTab, "Auto Upgrade Treadmill", false, function(v)
    S.autoTreadmillOn = v
    if v then startAutoTreadmill() end
end)
Toggle(AutoTab, "Auto Hatch", false, function(v)
    S.autoHatchOn = v
    if v then startAutoHatch() end
end)

-- ── MOVEMENT TAB ──
local MoveTab = CreateTab("Movement")
Section(MoveTab, "Flight Controls")
Toggle(MoveTab, "Fly", false, function(v)
    S.flyOn = v
    if v then enableFly(); startFlyLoop() else disableFly() end
end)
Slider(MoveTab, "Fly Speed", 16, CONFIG.FLY_SPEED_MAX, CONFIG.FLY_SPEED_DEFAULT, function(v) S.flySpeed = v end)
Section(MoveTab, "Collision")
Toggle(MoveTab, "Noclip", false, function(v)
    S.noclipOn = v
    if v then startNoclip() end
end)

-- ── PROTECTION & ESP TAB ──
local ProtTab = CreateTab("Protection")
Section(ProtTab, "Safety Features")
Toggle(ProtTab, "Anti-AFK", false, function(v) S.antiAfkOn = v; if v then startAntiAfk() end end)
Toggle(ProtTab, "Godmode / Refill", false, function(v) S.godmodeOn = v; if v then startGodmode() end end)
Toggle(ProtTab, "Egg + Player ESP", false, function(v)
    S.espOn = v
    if v then
        track(RunService.RenderStepped:Connect(function() if S.espOn then updateEsp() end end))
    else clearEsp() end
end)

-- ── SCANNER TAB ──
local ScanTab = CreateTab("Scanner")
Section(ScanTab, "Remote Discovery")
Button(ScanTab, "Scan Remotes", function()
    local r = scanRemotes()
    Notify("Scan Complete", #r .. " remotes logged to F9 console", 4, THEME.Success)
end)

-- ── MAIN TAB ──
local MainTab = CreateTab("Main")
Section(MainTab, "Panic Controls")
Button(MainTab, "PANIC — Stop All", function()
    S.panic = true
    S.speedOn = false; S.flyOn = false; S.noclipOn = false
    S.autoStealOn = false; S.autoHatchOn = false; S.autoTreadmillOn = false; S.espOn = false
    disableFly(); clearEsp(); clearConns()
    Notify("PANIC", "All background loops stopped", 3, THEME.Danger)
end, THEME.Danger)
Button(MainTab, "Reset Panic State", function()
    S.panic = false
    Notify("Reset", "Automation features re-enabled", 3, THEME.Success)
end)

-- Initialize Framework
SelectTab("Main")
initRaknet()
initAntiKick()
task.spawn(function()
    task.wait(1.5)
    autoPopulateConfig()
end)

Notify("Extreme Suite Loaded", "Native crash-proof UI active. Scanner ran automatically.", 5, THEME.Success)

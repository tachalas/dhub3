-- KyriLib
local kyri = loadstring(game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua"))()

getgenv().AirHub = getgenv().AirHub or {}

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function Camera()
    return workspace.CurrentCamera
end

--==================================================
-- AIM
--==================================================
if not getgenv().AirHub.Aimbot then
    local Typing, Holding, Conns = false, false, {}
    local Locked = nil

    getgenv().AirHub.Aimbot = {
        Settings = {
            Enabled = false,
            TeamCheck = true,
            WallCheck = true,
            AimHead = true,
            Predict = true,
            PredictMult = 1,
            Smooth = 0.99,
            TriggerKey = "MouseButton2",
            Toggle = false,
            Mode = "crosshair",
        },
        FOVSettings = {
            Enabled = true,
            Visible = true,
            Amount = 160,
            Color = Color3.fromRGB(255, 255, 255),
            LockedColor = Color3.fromRGB(255, 70, 70),
            Transparency = 0.5,
            Sides = 64,
            Thickness = 1,
            Filled = false,
        },
        FOVCircle = Drawing.new("Circle"),
    }

    local Env = getgenv().AirHub.Aimbot

    local function OwnChar()
        return LocalPlayer.Character
    end
    local function OwnHead()
        local c = OwnChar()
        return c and c:FindFirstChild("Head")
    end
    local function OwnHRP()
        local c = OwnChar()
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function AimPart(char)
        if not char then return nil end
        if Env.Settings.AimHead then
            return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        end
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
    end
    local function IsAlive(p)
        local char = p.Character
        if not (char and char.Parent) then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local ok, state = pcall(function() return hum:GetState() end)
        if ok and state == Enum.HumanoidStateType.Dead then return false end
        return char:FindFirstChild("HumanoidRootPart") ~= nil
    end
    local function SameTeam(p)
        return LocalPlayer.Team and p.Team and p.Team == LocalPlayer.Team
    end
    local function Eligible(p)
        if p == LocalPlayer or not IsAlive(p) then return false end
        if Env.Settings.TeamCheck and SameTeam(p) then return false end
        return true
    end
    local function HasLOS(part)
        if not Env.Settings.WallCheck then return true end
        local head = OwnHead()
        if not head or not part then return false end
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local excl = { OwnChar() }
        if part.Parent then table.insert(excl, part.Parent) end
        rp.FilterDescendantsInstances = excl
        rp.IgnoreWater = true
        return workspace:Raycast(head.Position, part.Position - head.Position, rp) == nil
    end
    local function FOVRadius()
        return Env.FOVSettings.Enabled and Env.FOVSettings.Amount or math.huge
    end
    local function ScreenDist(part)
        local sp, on = Camera():WorldToViewportPoint(part.Position)
        if not on or sp.Z <= 0 then return nil end
        local vp = Camera().ViewportSize
        local dx, dy = sp.X - vp.X / 2, sp.Y - vp.Y / 2
        return math.sqrt(dx * dx + dy * dy)
    end
    local function IsValidPart(part)
        if not (part and part.Parent) then return false end
        local p = Players:GetPlayerFromCharacter(part.Parent)
        if not (p and Eligible(p)) then return false end
        local d = ScreenDist(part)
        if not d or d > FOVRadius() then return false end
        return HasLOS(part)
    end
    local function ClosestNearest()
        local hrp = OwnHRP()
        if not hrp then return nil end
        local pick, best = nil, math.huge
        for _, p in Players:GetPlayers() do
            if Eligible(p) then
                local part = AimPart(p.Character)
                if part and IsValidPart(part) then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < best then best, pick = d, part end
                end
            end
        end
        return pick
    end
    local function ClosestCrosshair()
        local pick, best = nil, math.huge
        for _, p in Players:GetPlayers() do
            if Eligible(p) then
                local part = AimPart(p.Character)
                if part and IsValidPart(part) then
                    local d = ScreenDist(part)
                    if d and d < best then best, pick = d, part end
                end
            end
        end
        return pick
    end
    local function GetTarget()
        if Env.Settings.Mode == "nearest" then
            return ClosestNearest()
        end
        if Locked and IsValidPart(Locked) then
            local want = AimPart(Locked.Parent)
            if want and want ~= Locked and IsValidPart(want) then Locked = want end
            return Locked
        end
        Locked = ClosestCrosshair()
        return Locked
    end
    local function PredictPos(part)
        if not part then return nil end
        if not Env.Settings.Predict then return part.Position end
        local vel = Vector3.zero
        pcall(function() vel = part.AssemblyLinearVelocity end)
        if vel.Magnitude < 0.05 then
            local char = part.Parent
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if hum then vel = hum.MoveDirection * (hum.WalkSpeed or 16) end
            if root then
                pcall(function()
                    local rv = root.AssemblyLinearVelocity
                    if rv.Magnitude > vel.Magnitude then vel = rv end
                end)
            end
        end
        if vel.Magnitude > 80 then
            vel = vel.Unit * 80
        elseif vel.Magnitude < 0.05 then
            return part.Position
        end
        local ping = 0
        pcall(function() ping = LocalPlayer:GetNetworkPing() end)
        local lead = math.clamp(ping * 1.5 + (1 / 60), 0, 0.28)
        lead = lead * math.clamp(tonumber(Env.Settings.PredictMult) or 1, 0, 2)
        return part.Position + vel * lead
    end
    local function IsTrigger(input)
        local key = Env.Settings.TriggerKey
        if not key or key == "" or key == "None" then
            return input.UserInputType == Enum.UserInputType.MouseButton2
        end
        if key:find("MouseButton") then
            return input.UserInputType == Enum.UserInputType[key]
        end
        if key:find("Button") then
            return input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode[key]
        end
        local ok, kc = pcall(function() return Enum.KeyCode[key] end)
        if ok and kc then
            return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == kc
        end
        return false
    end

    local function Load()
        Conns.Render = RunService.RenderStepped:Connect(function()
            local cam = Camera()
            if Env.FOVSettings.Enabled and Env.Settings.Enabled then
                local vp = cam.ViewportSize
                Env.FOVCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
                Env.FOVCircle.Radius = Env.FOVSettings.Amount
                Env.FOVCircle.Thickness = Env.FOVSettings.Thickness
                Env.FOVCircle.Filled = Env.FOVSettings.Filled
                Env.FOVCircle.NumSides = Env.FOVSettings.Sides
                Env.FOVCircle.Transparency = Env.FOVSettings.Transparency
                Env.FOVCircle.Visible = Env.FOVSettings.Visible
                Env.FOVCircle.Color = Locked and Env.FOVSettings.LockedColor or Env.FOVSettings.Color
            else
                Env.FOVCircle.Visible = false
            end
            if not (Holding and Env.Settings.Enabled) then return end
            local target = GetTarget()
            if not target then return end
            local aimPos = PredictPos(target) or target.Position
            local goal = CFrame.new(cam.CFrame.Position, aimPos)
            local s = Env.Settings.Smooth or 0.99
            cam.CFrame = (s >= 0.99) and goal or cam.CFrame:Lerp(goal, s)
        end)
        Conns.Began = UserInputService.InputBegan:Connect(function(input, gp)
            if gp or Typing or not Env.Settings.Enabled then return end
            if IsTrigger(input) then
                if Env.Settings.Toggle then
                    Holding = not Holding
                    if not Holding then Locked = nil end
                else
                    Holding = true
                end
            end
        end)
        Conns.Ended = UserInputService.InputEnded:Connect(function(input)
            if not Env.Settings.Toggle and IsTrigger(input) then
                Holding = false
                Locked = nil
            end
        end)
        Conns.TS = UserInputService.TextBoxFocused:Connect(function() Typing = true end)
        Conns.TE = UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)
    end

    Env.Functions = {}
    function Env.Functions:Exit()
        for _, c in next, Conns do c:Disconnect() end
        if Env.FOVCircle then Env.FOVCircle:Remove() end
        getgenv().AirHub.Aimbot = nil
    end
    function Env.Functions:Restart()
        for _, c in next, Conns do c:Disconnect() end
        Locked, Holding = nil, false
        Load()
    end
    function Env.Functions:ResetSettings()
        Env.Settings = {
            Enabled = false, TeamCheck = true, WallCheck = true, AimHead = true,
            Predict = true, PredictMult = 1, Smooth = 0.99,
            TriggerKey = "MouseButton2", Toggle = false, Mode = "crosshair",
        }
        Env.FOVSettings = {
            Enabled = true, Visible = true, Amount = 160,
            Color = Color3.fromRGB(255, 255, 255),
            LockedColor = Color3.fromRGB(255, 70, 70),
            Transparency = 0.5, Sides = 64, Thickness = 1, Filled = false,
        }
        Locked = nil
    end
    Load()
end

--==================================================
-- ESP
--==================================================
if not getgenv().AirHub.ESP then
    local Drawings, Highlights, Conn = {}, {}, nil
    local Bones = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
        {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
        {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
    }

    getgenv().AirHub.ESP = {
        Enabled = false,
        Chams = false,
        Box = true,
        Tracer = true,
        Skeleton = true,
        Name = true,
        Health = true,
        TeamCheck = true,
        TeamColor = false,
        MaxDist = 2000,
        Color = Color3.fromRGB(255, 70, 120),
    }
    local S = getgenv().AirHub.ESP

    local function newLine()
        local l = Drawing.new("Line")
        l.Thickness = 1
        l.Visible = false
        return l
    end
    local function newText()
        local t = Drawing.new("Text")
        t.Size = 13
        t.Center = true
        t.Outline = true
        t.Visible = false
        t.Font = 2
        return t
    end
    local function pack()
        local box = {}
        for i = 1, 4 do box[i] = newLine() end
        local skel = {}
        for i = 1, #Bones do skel[i] = newLine() end
        return {
            box = box,
            tracer = newLine(),
            skel = skel,
            name = newText(),
            hpBg = newLine(),
            hp = newLine(),
        }
    end
    local function hide(d)
        for _, l in d.box do l.Visible = false end
        d.tracer.Visible = false
        for _, l in d.skel do l.Visible = false end
        d.name.Visible = false
        d.hpBg.Visible = false
        d.hp.Visible = false
    end
    local function clearAll()
        for p, d in pairs(Drawings) do
            hide(d)
            for _, l in d.box do l:Remove() end
            d.tracer:Remove()
            for _, l in d.skel do l:Remove() end
            d.name:Remove()
            d.hpBg:Remove()
            d.hp:Remove()
            Drawings[p] = nil
        end
        for p, h in pairs(Highlights) do
            if h then h:Destroy() end
            Highlights[p] = nil
        end
    end

    local function colorFor(p)
        if S.TeamColor and p.Team then
            return p.TeamColor.Color
        end
        return S.Color
    end

    local function step()
        if not S.Enabled and not S.Chams then
            clearAll()
            return
        end
        local cam = Camera()
        local seen = {}
        local origin = cam.CFrame.Position
        for _, p in Players:GetPlayers() do
            if p == LocalPlayer then continue end
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local same = LocalPlayer.Team and p.Team and p.Team == LocalPlayer.Team
            local skip = (not char) or (not hum) or hum.Health <= 0 or (not hrp) or (S.TeamCheck and same)
            local dist = hrp and (hrp.Position - origin).Magnitude or math.huge
            if skip or dist > S.MaxDist then
                if Drawings[p] then hide(Drawings[p]) end
                if Highlights[p] then Highlights[p].Enabled = false end
                continue
            end
            seen[p] = true
            local col = colorFor(p)

            if S.Chams then
                local h = Highlights[p]
                if not h or not h.Parent then
                    h = Instance.new("Highlight")
                    h.Name = "TestCham"
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency = 0.55
                    h.OutlineTransparency = 0
                    h.Parent = char
                    Highlights[p] = h
                end
                h.Adornee = char
                h.FillColor = col
                h.OutlineColor = col
                h.Enabled = true
            elseif Highlights[p] then
                Highlights[p].Enabled = false
            end

            if not S.Enabled then
                if Drawings[p] then hide(Drawings[p]) end
                continue
            end

            local d = Drawings[p]
            if not d then
                d = pack()
                Drawings[p] = d
            end

            local cf, size = char:GetBoundingBox()
            local corners = {}
            local half = size * 0.5
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            local okBox = true
            for _, sx in { -1, 1 } do
                for _, sy in { -1, 1 } do
                    for _, sz in { -1, 1 } do
                        local w = (cf * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position
                        local sp, on = cam:WorldToViewportPoint(w)
                        if sp.Z <= 0 then okBox = false end
                        minX, maxX = math.min(minX, sp.X), math.max(maxX, sp.X)
                        minY, maxY = math.min(minY, sp.Y), math.max(maxY, sp.Y)
                    end
                end
            end

            if S.Box and okBox then
                local pts = {
                    Vector2.new(minX, minY), Vector2.new(maxX, minY),
                    Vector2.new(maxX, maxY), Vector2.new(minX, maxY),
                }
                for i = 1, 4 do
                    local a, b = pts[i], pts[i % 4 + 1]
                    d.box[i].From, d.box[i].To = a, b
                    d.box[i].Color = col
                    d.box[i].Visible = true
                end
            else
                for i = 1, 4 do d.box[i].Visible = false end
            end

            local headPos = head and head.Position or (hrp.Position + Vector3.new(0, 2, 0))
            local spH, onH = cam:WorldToViewportPoint(headPos)
            if S.Tracer and onH and spH.Z > 0 then
                local vp = cam.ViewportSize
                d.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                d.tracer.To = Vector2.new(spH.X, spH.Y)
                d.tracer.Color = col
                d.tracer.Visible = true
            else
                d.tracer.Visible = false
            end

            if S.Name and okBox then
                d.name.Text = p.DisplayName ~= "" and p.DisplayName or p.Name
                d.name.Position = Vector2.new((minX + maxX) / 2, minY - 16)
                d.name.Color = Color3.new(1, 1, 1)
                d.name.Visible = true
            else
                d.name.Visible = false
            end

            if S.Health and okBox then
                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                local x = minX - 5
                d.hpBg.From = Vector2.new(x, minY)
                d.hpBg.To = Vector2.new(x, maxY)
                d.hpBg.Color = Color3.fromRGB(20, 20, 20)
                d.hpBg.Thickness = 3
                d.hpBg.Visible = true
                local y = maxY - (maxY - minY) * ratio
                d.hp.From = Vector2.new(x, y)
                d.hp.To = Vector2.new(x, maxY)
                d.hp.Color = Color3.fromRGB(255 * (1 - ratio), 220 * ratio, 40)
                d.hp.Thickness = 2
                d.hp.Visible = true
            else
                d.hpBg.Visible = false
                d.hp.Visible = false
            end

            if S.Skeleton then
                for i, pair in Bones do
                    local a = char:FindFirstChild(pair[1])
                    local b = char:FindFirstChild(pair[2])
                    local line = d.skel[i]
                    if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                        local sa, oa = cam:WorldToViewportPoint(a.Position)
                        local sb, ob = cam:WorldToViewportPoint(b.Position)
                        if oa and ob and sa.Z > 0 and sb.Z > 0 then
                            line.From = Vector2.new(sa.X, sa.Y)
                            line.To = Vector2.new(sb.X, sb.Y)
                            line.Color = col
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    else
                        line.Visible = false
                    end
                end
            else
                for _, l in d.skel do l.Visible = false end
            end
        end
        for p, d in pairs(Drawings) do
            if not seen[p] then hide(d) end
        end
    end

    Conn = RunService.RenderStepped:Connect(step)

    S.Functions = {}
    function S.Functions:Exit()
        if Conn then Conn:Disconnect() end
        clearAll()
        getgenv().AirHub.ESP = nil
    end
end

--==================================================
-- FLING
--==================================================
if not getgenv().AirHub.Fling then
    local F = {
        Enabled = false,
        NoClip = false,
        _fling = nil,
        _coll = nil,
        _was = setmetatable({}, { __mode = "k" }),
    }
    function F:SetFling(on)
        self.Enabled = on
        if self._fling then self._fling:Disconnect() self._fling = nil end
        if not on then return end
        self._fling = RunService.Heartbeat:Connect(function()
            if not F.Enabled then return end
            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then return end
            local vel = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = vel * 500000 + Vector3.new(0, 500000, 0)
            RunService.RenderStepped:Wait()
            if root.Parent then root.AssemblyLinearVelocity = vel end
        end)
    end
    function F:SetNoClip(on)
        self.NoClip = on
        if self._coll then self._coll:Disconnect() self._coll = nil end
        if not on then
            for part in self._was do
                if part.Parent then pcall(function() part.CanCollide = true end) end
            end
            table.clear(self._was)
            return
        end
        self._coll = RunService.Stepped:Connect(function()
            if not F.NoClip then return end
            for _, plr in Players:GetPlayers() do
                if plr ~= LocalPlayer and plr.Character then
                    for _, part in plr.Character:GetChildren() do
                        if part:IsA("BasePart") and part.CanCollide then
                            F._was[part] = true
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    end
    function F:Exit()
        self:SetFling(false)
        self:SetNoClip(false)
        getgenv().AirHub.Fling = nil
    end
    getgenv().AirHub.Fling = F
end

--==================================================
-- GUI
--==================================================
local Aim = getgenv().AirHub.Aimbot
local ESP = getgenv().AirHub.ESP
local Fling = getgenv().AirHub.Fling

local w = kyri.new("Test", { GameName = "Test", AutoLoad = "default" })

local aim = w:tab("Aim", "crosshair")
local esp = w:tab("ESP", "eye")
local fling = w:tab("Fling", "zap")
local act = w:tab("Actions", "settings-2")

-- AIM
aim:section("Main")
aim:toggle("Enabled", Aim.Settings.Enabled, function(v)
    Aim.Settings.Enabled = v
    w:notify("Test", v and "On" or "Off", 2)
end, "aim_en")
aim:toggle("Team Check", Aim.Settings.TeamCheck, function(v) Aim.Settings.TeamCheck = v end, "aim_team")
aim:toggle("Wall Check", Aim.Settings.WallCheck, function(v) Aim.Settings.WallCheck = v end, "aim_wall")
aim:toggle("Aim Head", Aim.Settings.AimHead, function(v) Aim.Settings.AimHead = v end, "aim_head")
aim:toggle("Toggle Mode", Aim.Settings.Toggle, function(v) Aim.Settings.Toggle = v end, "aim_tog")
aim:dropdown("Mode", { "crosshair", "nearest" }, Aim.Settings.Mode, function(v)
    Aim.Settings.Mode = v
end, "aim_mode")

aim:space()
aim:section("Feel")
aim:toggle("Prediction", Aim.Settings.Predict, function(v) Aim.Settings.Predict = v end, "aim_pred")
aim:slider("Predict", 0, 2, Aim.Settings.PredictMult, function(v) Aim.Settings.PredictMult = v end, "aim_predm", 0.1)
aim:slider("Smooth", 0.05, 0.99, Aim.Settings.Smooth, function(v) Aim.Settings.Smooth = v end, "aim_smooth", 0.01)

aim:space()
aim:section("FOV")
aim:toggle("FOV", Aim.FOVSettings.Enabled, function(v) Aim.FOVSettings.Enabled = v end, "fov_en")
aim:toggle("Visible", Aim.FOVSettings.Visible, function(v) Aim.FOVSettings.Visible = v end, "fov_vis")
aim:toggle("Filled", Aim.FOVSettings.Filled, function(v) Aim.FOVSettings.Filled = v end, "fov_fill")
aim:slider("Size", 40, 500, Aim.FOVSettings.Amount, function(v) Aim.FOVSettings.Amount = v end, "fov_size")
aim:slider("Thickness", 1, 5, Aim.FOVSettings.Thickness, function(v) Aim.FOVSettings.Thickness = v end, "fov_th")
aim:colorpicker("Color", Aim.FOVSettings.Color, function(c) Aim.FOVSettings.Color = c end, "fov_c1")
aim:colorpicker("Lock Color", Aim.FOVSettings.LockedColor, function(c) Aim.FOVSettings.LockedColor = c end, "fov_c2")

aim:space()
aim:section("Key")
local keyLabel = aim:label("Current: " .. tostring(Aim.Settings.TriggerKey))
local detecting, detectConn = false, nil
aim:button("Detect Key", function()
    if detecting then return end
    detecting = true
    keyLabel:set("Current: press...")
    w:notify("Test", "Press key / mouse / pad", 3)
    detectConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local name
        local t = input.UserInputType
        if t == Enum.UserInputType.Keyboard then
            name = input.KeyCode.Name
        elseif t == Enum.UserInputType.MouseButton1 then
            name = "MouseButton1"
        elseif t == Enum.UserInputType.MouseButton2 then
            name = "MouseButton2"
        elseif t == Enum.UserInputType.MouseButton3 then
            name = "MouseButton3"
        elseif t == Enum.UserInputType.Gamepad1 then
            name = input.KeyCode.Name
        end
        if name then
            Aim.Settings.TriggerKey = name
            keyLabel:set("Current: " .. name)
            w:notify("Test", "Key: " .. name, 2)
            detecting = false
            detectConn:Disconnect()
            detectConn = nil
        end
    end)
end)

-- ESP
esp:section("Mode")
esp:toggle("ESP", ESP.Enabled, function(v)
    ESP.Enabled = v
    if v then ESP.Chams = false end
    w:notify("Test", v and "ESP on" or "ESP off", 2)
end, "esp_en")
esp:toggle("Chams", ESP.Chams, function(v)
    ESP.Chams = v
    if v then ESP.Enabled = false end
    w:notify("Test", v and "Chams on" or "Chams off", 2)
end, "esp_chams")

esp:space()
esp:section("Draw")
esp:toggle("Box", ESP.Box, function(v) ESP.Box = v end, "esp_box")
esp:toggle("Tracer", ESP.Tracer, function(v) ESP.Tracer = v end, "esp_tr")
esp:toggle("Skeleton", ESP.Skeleton, function(v) ESP.Skeleton = v end, "esp_sk")
esp:toggle("Name", ESP.Name, function(v) ESP.Name = v end, "esp_nm")
esp:toggle("Health", ESP.Health, function(v) ESP.Health = v end, "esp_hp")

esp:space()
esp:section("Filter")
esp:toggle("Team Check", ESP.TeamCheck, function(v) ESP.TeamCheck = v end, "esp_team")
esp:toggle("Team Colors", ESP.TeamColor, function(v) ESP.TeamColor = v end, "esp_tc")
esp:slider("Max Dist", 100, 5000, ESP.MaxDist, function(v) ESP.MaxDist = v end, "esp_dist")
esp:colorpicker("Color", ESP.Color, function(c) ESP.Color = c end, "esp_col")

-- FLING
fling:section("Touch")
fling:toggle("Fling", Fling.Enabled, function(v)
    Fling:SetFling(v)
    w:notify("Test", v and "Fling on" or "Fling off", 2)
end, "fling_en")
fling:toggle("No-Clip", Fling.NoClip, function(v)
    Fling:SetNoClip(v)
    w:notify("Test", v and "No-Clip on" or "No-Clip off", 2)
end, "fling_nc")
fling:label("Fling: anfassen reicht. No-Clip: durch andere Spieler.")

-- ACTIONS
act:section("Script")
act:button("Reset Aim", function()
    Aim.Functions:ResetSettings()
    keyLabel:set("Current: " .. tostring(Aim.Settings.TriggerKey))
    w:notify("Test", "Aim reset", 2)
end)
act:button("Restart Aim", function()
    Aim.Functions:Restart()
    w:notify("Test", "Aim restarted", 2)
end)
act:button("Unload", function()
    pcall(function() Aim.Functions:Exit() end)
    pcall(function() ESP.Functions:Exit() end)
    pcall(function() Fling:Exit() end)
    w:notify("Test", "Unloaded", 2)
end)
act:button("Destroy GUI", function()
    if detectConn then detectConn:Disconnect() end
    pcall(function() Aim.Functions:Exit() end)
    pcall(function() ESP.Functions:Exit() end)
    pcall(function() Fling:Exit() end)
    w:destroy()
end)

w:notify("Test", "Loaded", 3)

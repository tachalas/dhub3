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

local function down(key)
    return UserInputService:IsKeyDown(key)
end

local function svc(name)
    if cloneref then return cloneref(game:GetService(name)) end
    return game:GetService(name)
end

--==================================================
-- AIM
--==================================================
if not getgenv().AirHub.Aimbot then
    local Typing, Holding, Conns = false, false, {}
    local Locked = nil

    getgenv().AirHub.Aimbot = {
        Settings = {
            Enabled = false, TeamCheck = true, WallCheck = true, AimHead = true,
            Predict = true, PredictMult = 1, Smooth = 0.99,
            TriggerKey = "MouseButton2", Toggle = false, Mode = "crosshair",
        },
        FOVSettings = {
            Enabled = true, Visible = true, Amount = 160,
            Color = Color3.fromRGB(255, 255, 255),
            LockedColor = Color3.fromRGB(255, 70, 70),
            Transparency = 0.5, Sides = 64, Thickness = 1, Filled = false,
        },
        FOVCircle = Drawing.new("Circle"),
    }
    local Env = getgenv().AirHub.Aimbot

    local function OwnChar() return LocalPlayer.Character end
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
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
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
        return (Vector2.new(sp.X, sp.Y) - Vector2.new(vp.X / 2, vp.Y / 2)).Magnitude
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
        if Env.Settings.Mode == "nearest" then return ClosestNearest() end
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
        if vel.Magnitude > 80 then vel = vel.Unit * 80
        elseif vel.Magnitude < 0.05 then return part.Position end
        local ping = 0
        pcall(function() ping = LocalPlayer:GetNetworkPing() end)
        local lead = math.clamp(ping * 1.5 + (1 / 60), 0, 0.28) * math.clamp(Env.Settings.PredictMult or 1, 0, 2)
        return part.Position + vel * lead
    end
    local function IsTrigger(input)
        local key = Env.Settings.TriggerKey
        if not key or key == "" or key == "None" then
            return input.UserInputType == Enum.UserInputType.MouseButton2
        end
        if key:find("MouseButton") then return input.UserInputType == Enum.UserInputType[key] end
        if key:find("Button") then
            return input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode[key]
        end
        local ok, kc = pcall(function() return Enum.KeyCode[key] end)
        return ok and kc and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == kc
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
            if not Env.Settings.Toggle and IsTrigger(input) then Holding, Locked = false, nil end
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
            Color = Color3.fromRGB(255, 255, 255), LockedColor = Color3.fromRGB(255, 70, 70),
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
        {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
    }
    getgenv().AirHub.ESP = {
        Enabled = false, Chams = false, Box = true, Tracer = true, Skeleton = true,
        Name = true, Health = true, TeamCheck = true, TeamColor = false,
        MaxDist = 2000, Color = Color3.fromRGB(255, 70, 120),
    }
    local S = getgenv().AirHub.ESP
    local function newLine()
        local l = Drawing.new("Line")
        l.Thickness, l.Visible = 1, false
        return l
    end
    local function newText(size)
        local t = Drawing.new("Text")
        t.Size, t.Center, t.Outline, t.Visible, t.Font = size or 13, true, true, false, 2
        return t
    end
    local function pack()
        local box, skel = {}, {}
        for i = 1, 4 do box[i] = newLine() end
        for i = 1, #Bones do skel[i] = newLine() end
        return { box = box, tracer = newLine(), skel = skel, name = newText(13), team = newText(12), hpBg = newLine(), hp = newLine() }
    end
    local function hide(d)
        for _, l in d.box do l.Visible = false end
        d.tracer.Visible, d.name.Visible, d.team.Visible, d.hpBg.Visible, d.hp.Visible = false, false, false, false, false
        for _, l in d.skel do l.Visible = false end
    end
    local function clearAll()
        for _, d in pairs(Drawings) do
            hide(d)
            for _, l in d.box do l:Remove() end
            d.tracer:Remove()
            for _, l in d.skel do l:Remove() end
            d.name:Remove(); d.team:Remove(); d.hpBg:Remove(); d.hp:Remove()
        end
        table.clear(Drawings)
        for _, h in pairs(Highlights) do if h then h:Destroy() end end
        table.clear(Highlights)
    end
    local function colorFor(p)
        if S.TeamColor and p.Team then return p.TeamColor.Color end
        return S.Color
    end
    Conn = RunService.RenderStepped:Connect(function()
        if not S.Enabled and not S.Chams then clearAll() return end
        local cam = Camera()
        local seen, origin = {}, cam.CFrame.Position
        for _, p in Players:GetPlayers() do
            if p == LocalPlayer then continue end
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local same = LocalPlayer.Team and p.Team and p.Team == LocalPlayer.Team
            local dist = hrp and (hrp.Position - origin).Magnitude or math.huge
            if not char or not hum or hum.Health <= 0 or not hrp or (S.TeamCheck and same) or dist > S.MaxDist then
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
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency, h.OutlineTransparency = 0.55, 0
                    h.Parent = char
                    Highlights[p] = h
                end
                h.Adornee, h.FillColor, h.OutlineColor, h.Enabled = char, col, col, true
            elseif Highlights[p] then
                Highlights[p].Enabled = false
            end
            if not S.Enabled then
                if Drawings[p] then hide(Drawings[p]) end
                continue
            end
            local d = Drawings[p]
            if not d then d = pack() Drawings[p] = d end
            local cf, size = char:GetBoundingBox()
            local half = size * 0.5
            local minX, minY, maxX, maxY, okBox = math.huge, math.huge, -math.huge, -math.huge, true
            for _, sx in {-1, 1} do
                for _, sy in {-1, 1} do
                    for _, sz in {-1, 1} do
                        local sp = cam:WorldToViewportPoint((cf * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position)
                        if sp.Z <= 0 then okBox = false end
                        minX, maxX = math.min(minX, sp.X), math.max(maxX, sp.X)
                        minY, maxY = math.min(minY, sp.Y), math.max(maxY, sp.Y)
                    end
                end
            end
            if S.Box and okBox then
                local pts = { Vector2.new(minX, minY), Vector2.new(maxX, minY), Vector2.new(maxX, maxY), Vector2.new(minX, maxY) }
                for i = 1, 4 do
                    d.box[i].From, d.box[i].To, d.box[i].Color, d.box[i].Visible = pts[i], pts[i % 4 + 1], col, true
                end
            else
                for i = 1, 4 do d.box[i].Visible = false end
            end
            local headWorld = (head and head.Position or hrp.Position) + Vector3.new(0, ((head and head.Size.Y) or 1) * 0.7 + 0.35, 0)
            local spH, onH = cam:WorldToViewportPoint(headWorld)
            if S.Name and onH and spH.Z > 0 then
                d.name.Text = (p.DisplayName ~= "" and p.DisplayName) or p.Name
                d.name.Position = Vector2.new(spH.X, spH.Y - 14)
                d.name.Color, d.name.Visible = Color3.new(1, 1, 1), true
                d.team.Text = "[" .. ((p.Team and p.Team.Name) or "No Team") .. "]"
                d.team.Position = Vector2.new(spH.X, spH.Y)
                d.team.Color = p.Team and p.TeamColor.Color or Color3.fromRGB(180, 180, 180)
                d.team.Visible = true
            else
                d.name.Visible, d.team.Visible = false, false
            end
            local spBody = cam:WorldToViewportPoint(hrp.Position)
            if S.Tracer and spBody.Z > 0 then
                local vp = cam.ViewportSize
                d.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                d.tracer.To = Vector2.new(spBody.X, spBody.Y)
                d.tracer.Color, d.tracer.Visible = col, true
            else
                d.tracer.Visible = false
            end
            if S.Health and okBox then
                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                d.hpBg.From, d.hpBg.To = Vector2.new(minX - 5, minY), Vector2.new(minX - 5, maxY)
                d.hpBg.Color, d.hpBg.Thickness, d.hpBg.Visible = Color3.fromRGB(20, 20, 20), 3, true
                d.hp.From = Vector2.new(minX - 5, maxY - (maxY - minY) * ratio)
                d.hp.To = Vector2.new(minX - 5, maxY)
                d.hp.Color = Color3.fromRGB(255 * (1 - ratio), 220 * ratio, 40)
                d.hp.Thickness, d.hp.Visible = 2, true
            else
                d.hpBg.Visible, d.hp.Visible = false, false
            end
            if S.Skeleton then
                for i, pair in Bones do
                    local a, b, line = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2]), d.skel[i]
                    if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                        local sa, oa = cam:WorldToViewportPoint(a.Position)
                        local sb, ob = cam:WorldToViewportPoint(b.Position)
                        if oa and ob and sa.Z > 0 and sb.Z > 0 then
                            line.From, line.To, line.Color, line.Visible = Vector2.new(sa.X, sa.Y), Vector2.new(sb.X, sb.Y), col, true
                        else line.Visible = false end
                    else line.Visible = false end
                end
            else
                for _, l in d.skel do l.Visible = false end
            end
        end
        for p, d in pairs(Drawings) do if not seen[p] then hide(d) end end
    end)
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
local function installSafeFling(F)
    function F:SetSafeFling(on)
        self.Safe = on
        if self._safe then self._safe:Disconnect() self._safe = nil end
        if not on then return end

        local bursts = 0
        local active = false

        self._safe = RunService.Heartbeat:Connect(function()
            if not F.Safe then return end
            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then return end

            if not active then
                for _, plr in Players:GetPlayers() do
                    if plr ~= LocalPlayer and plr.Character then
                        local other = plr.Character:FindFirstChild("HumanoidRootPart")
                            or plr.Character:FindFirstChild("Head")
                        if other and (other.Position - root.Position).Magnitude <= 8 then
                            active = true
                            break
                        end
                    end
                end
                if not active then return end
            end

            bursts += 1
            local vel = root.Velocity
            root.Velocity = vel * 500000 + Vector3.new(0, 500000, 0)
            RunService.RenderStepped:Wait()

            if bursts >= 8 then
                if root.Parent then
                    root.Velocity = Vector3.zero
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end
                F.Safe = false
                if F._safe then F._safe:Disconnect() F._safe = nil end
            elseif root.Parent then
                root.Velocity = vel
            end
        end)
    end
end

if not getgenv().AirHub.Fling then
    local F = {
        Enabled = false, Safe = false, NoClip = false,
        _fling = nil, _safe = nil, _coll = nil,
        _was = setmetatable({}, { __mode = "k" }),
    }

    function F:SetFling(on)
        self.Enabled = on
        if self._fling then self._fling:Disconnect() self._fling = nil end
        if not on then return end
        self._fling = RunService.Heartbeat:Connect(function()
            if not F.Enabled then return end
            local char = LocalPlayer.Character
            if not char or not char.Parent then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not root or not root.Parent or not hum or hum.Health <= 0 then return end
            local vel = root.Velocity
            root.Velocity = vel * 500000 + Vector3.new(0, 500000, 0)
            RunService.RenderStepped:Wait()
            if root and root.Parent then
                root.Velocity = vel
            end
        end)
    end

    installSafeFling(F)

    function F:SetNoClip(on)
        self.NoClip = on
        if self._coll then self._coll:Disconnect() self._coll = nil end
        if not on then
            for part in self._was do if part.Parent then pcall(function() part.CanCollide = true end) end end
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
        self:SetSafeFling(false)
        self:SetNoClip(false)
        getgenv().AirHub.Fling = nil
    end
    getgenv().AirHub.Fling = F
end

installSafeFling(getgenv().AirHub.Fling)

--==================================================
-- FLY
--==================================================
if not getgenv().AirHub.Fly then
    local Fly = { Enabled = false, Speed = 80, _conn = nil }
    function Fly:Start()
        if self._conn then return end
        self.Enabled = true
        self._conn = RunService.RenderStepped:Connect(function()
            if not Fly.Enabled then return end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end
            local cam = Camera().CFrame
            local v = Vector3.zero
            local look, right = cam.LookVector, cam.RightVector
            if down(Enum.KeyCode.W) then v += look end
            if down(Enum.KeyCode.S) then v -= look end
            if down(Enum.KeyCode.A) then v -= right end
            if down(Enum.KeyCode.D) then v += right end
            if down(Enum.KeyCode.Space) or down(Enum.KeyCode.E) then v += Vector3.yAxis end
            if down(Enum.KeyCode.LeftControl) or down(Enum.KeyCode.Q) then v -= Vector3.yAxis end
            pcall(function()
                local st = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
                for _, inp in st do
                    if inp.KeyCode == Enum.KeyCode.Thumbstick1 then
                        v += look * -inp.Position.Y + right * inp.Position.X
                    end
                end
            end)
            hum.PlatformStand = true
            if v.Magnitude > 0.05 then
                hrp.AssemblyLinearVelocity = v.Unit * Fly.Speed
            else
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    function Fly:Stop()
        self.Enabled = false
        if self._conn then self._conn:Disconnect() self._conn = nil end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
    end
    function Fly:Exit()
        self:Stop()
        getgenv().AirHub.Fly = nil
    end
    getgenv().AirHub.Fly = Fly
end

--==================================================
-- VC
--==================================================
if not getgenv().AirHub.VC then
    local VC = { Version = 1, Executed = false, Muted = false, Mode = nil }

    local function waitMicUnmuted()
        local mutedImg = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png"
        local tba = game:GetService("CoreGui"):FindFirstChild("TopBarApp")
        tba = tba and tba:FindFirstChild("TopBarApp")
        local lf = tba and tba:FindFirstChild("UnibarLeftFrame")
        local um = lf and lf:FindFirstChild("UnibarMenu")
        local n2 = um and um:FindFirstChild("2")
        local n3 = n2 and n2:FindFirstChild("3")
        local tmi = n3 and n3:FindFirstChild("toggle_mic_mute", true)
        if not tmi then return end
        local icon = tmi:FindFirstChild("IntegrationIconFrame", true)
        icon = icon and icon:FindFirstChild("IntegrationIcon", true)
        icon = icon and icon:FindFirstChild("1")
        if not icon then return end
        local t0 = os.clock()
        repeat task.wait(0.5) until icon.Image ~= mutedImg or os.clock() - t0 > 25
    end

    function VC:RunV1(notify)
        if self.Mode then
            notify(self.Mode == "v1" and "Already on" or "Rejoin to switch")
            return
        end
        self.Mode = "v1"
        task.spawn(function()
            local ok, err = pcall(function()
                local v = svc("VoiceChatService")
                local vi = svc("VoiceChatInternal")
                notify("Unmute, dann warten")
                pcall(waitMicUnmuted)
                v:leaveVoice()
                task.wait(3)
                if getconnections then
                    local h = getconnections(vi.StateChanged)
                    for i = 7, #h do
                        pcall(function() h[i]:Disable() end)
                    end
                end
                task.wait(3)
                v:joinVoice()
                vi:PublishPause(VC.Muted)
            end)
            if ok then
                VC.Executed = true
                notify("V1 active")
            else
                VC.Mode = nil
                notify("V1 failed: " .. tostring(err))
            end
        end)
    end

    function VC:RunV2(notify)
        if self.Mode then
            notify(self.Mode == "v2" and "Already on" or "Rejoin to switch")
            return
        end
        self.Mode = "v2"
        task.spawn(function()
            local ok, err = pcall(function()
                local g = svc("VoiceChatService")
                local h = svc("VoiceChatInternal")
                local j = svc("CoreGui")
                local mutedImg = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png"
                local talkImg = "rbxasset://textures/ui/VoiceChat/MicLight/Talking0.png"
                local btn, iconImg, redDot

                local function find()
                    btn, iconImg, redDot = nil, nil, nil
                    for _, v in j:GetDescendants() do
                        if v.Name == "toggle_mic_mute" then btn = v
                        elseif v.Name == "RedVoiceDot" and v:IsA("GuiObject") then redDot = v end
                    end
                    if btn then
                        local holder = btn:FindFirstChild("IntegrationIconFrame", true)
                        if holder then iconImg = holder:FindFirstChild("IntegrationIcon", true) end
                    end
                end

                find()
                if not btn then
                    task.spawn(function() g:joinVoice() end)
                    task.wait(1.5)
                    find()
                end
                notify("Unmute to continue")

                local function img()
                    if iconImg and iconImg:FindFirstChild("1") then return iconImg["1"].Image end
                end
                local t0 = os.clock()
                while true do
                    local x = img()
                    if x and x ~= mutedImg and x ~= "" then talkImg = x break end
                    if os.clock() - t0 > 30 then error("mic timeout") end
                    task.wait(0.5)
                end

                task.wait(1)
                task.spawn(function() g:leaveVoice() end)
                task.wait(2)
                if getconnections then
                    local cons = getconnections(h.StateChanged)
                    for i, c in cons do
                        if i >= 7 and c then pcall(function() c:Disable() end) end
                    end
                end
                task.wait(2)
                task.spawn(function() g:joinVoice() end)
                task.wait(1)
                find()

                if btn then
                    for _, d in btn:GetDescendants() do
                        if d:IsA("ImageLabel") or d:IsA("ImageButton") then d.ImageTransparency = 1
                        elseif d:IsA("TextLabel") or d:IsA("TextButton") then d.TextTransparency = 1 end
                    end
                end

                local parent = (gethui and gethui()) or j
                local old = parent:FindFirstChild("CustomVoiceController")
                if old then old:Destroy() end
                local gui = Instance.new("ScreenGui")
                gui.Name = "CustomVoiceController"
                gui.ResetOnSpawn = false
                gui.IgnoreGuiInset = true
                gui.DisplayOrder = 999999
                gui.Parent = parent
                local hit = Instance.new("TextButton")
                hit.Size = UDim2.fromOffset(35, 35)
                hit.Position = UDim2.fromOffset(164, 17)
                hit.BackgroundTransparency = 1
                hit.Text = ""
                hit.ZIndex = 10000
                hit.Parent = gui
                local mic = Instance.new("ImageLabel")
                mic.Size = UDim2.fromScale(1, 1)
                mic.BackgroundTransparency = 1
                mic.Image = mutedImg
                mic.ScaleType = Enum.ScaleType.Fit
                mic.ZIndex = 10001
                mic.Parent = hit

                local function apply(muted)
                    mic.Image = muted and mutedImg or talkImg
                    if redDot and redDot.Parent then redDot.Visible = not muted end
                    task.spawn(function() h:PublishPause(muted) end)
                end
                hit.MouseButton1Click:Connect(function()
                    VC.Muted = not VC.Muted
                    apply(VC.Muted)
                end)
                VC._setV2 = function(muted)
                    VC.Muted = muted
                    apply(muted)
                end
                apply(true)
                VC.Muted = true
                if iconImg and iconImg.AbsolutePosition.X > 50 then
                    local p = iconImg.AbsolutePosition
                    hit.Position = UDim2.fromOffset(p.X + 14, p.Y + 13)
                end
            end)
            if ok then
                VC.Executed = true
                notify("V2 active")
            else
                VC.Mode = nil
                notify("V2 failed: " .. tostring(err))
            end
        end)
    end

    function VC:ToggleMic(notify)
        if not self.Executed then notify("Execute first") return end
        self.Muted = not self.Muted
        if self.Mode == "v2" and self._setV2 then
            pcall(self._setV2, self.Muted)
        else
            pcall(function() svc("VoiceChatInternal"):PublishPause(self.Muted) end)
        end
        notify(self.Muted and "Muted" or "Unmuted")
    end

    function VC:Exit()
        local parent = (gethui and gethui()) or game:GetService("CoreGui")
        local g = parent:FindFirstChild("CustomVoiceController")
        if g then g:Destroy() end
        getgenv().AirHub.VC = nil
    end
    getgenv().AirHub.VC = VC
end

--==================================================
-- GUI
--==================================================
local Aim = getgenv().AirHub.Aimbot
local ESP = getgenv().AirHub.ESP
local Fling = getgenv().AirHub.Fling
local FakeLag = getgenv().AirHub.FakeLag
local Fly = getgenv().AirHub.Fly
local VC = getgenv().AirHub.VC

local w = kyri.new("Test", { GameName = "Test", AutoLoad = "default" })
local aim = w:tab("Aim", "crosshair")
local esp = w:tab("ESP", "eye")
local fly = w:tab("Fly", "wind")
local fling = w:tab("Fling", "zap")
local lag = w:tab("Fake Lag", "wifi-off")
local vc = w:tab("VC", "mic")
local act = w:tab("Actions", "settings-2")

aim:section("Main")
aim:toggle("Enabled", Aim.Settings.Enabled, function(v) Aim.Settings.Enabled = v end, "aim_en")
aim:toggle("Team Check", Aim.Settings.TeamCheck, function(v) Aim.Settings.TeamCheck = v end, "aim_team")
aim:toggle("Wall Check", Aim.Settings.WallCheck, function(v) Aim.Settings.WallCheck = v end, "aim_wall")
aim:toggle("Aim Head", Aim.Settings.AimHead, function(v) Aim.Settings.AimHead = v end, "aim_head")
aim:toggle("Toggle Mode", Aim.Settings.Toggle, function(v) Aim.Settings.Toggle = v end, "aim_tog")
aim:dropdown("Mode", { "crosshair", "nearest" }, Aim.Settings.Mode, function(v) Aim.Settings.Mode = v end, "aim_mode")
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
    detectConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local name
        local t = input.UserInputType
        if t == Enum.UserInputType.Keyboard then name = input.KeyCode.Name
        elseif t == Enum.UserInputType.MouseButton1 then name = "MouseButton1"
        elseif t == Enum.UserInputType.MouseButton2 then name = "MouseButton2"
        elseif t == Enum.UserInputType.MouseButton3 then name = "MouseButton3"
        elseif t == Enum.UserInputType.Gamepad1 then name = input.KeyCode.Name end
        if name then
            Aim.Settings.TriggerKey = name
            keyLabel:set("Current: " .. name)
            detecting = false
            detectConn:Disconnect()
            detectConn = nil
        end
    end)
end)

esp:section("Mode")
esp:toggle("ESP", ESP.Enabled, function(v)
    ESP.Enabled = v
    if v then ESP.Chams = false end
end, "esp_en")
esp:toggle("Chams", ESP.Chams, function(v)
    ESP.Chams = v
    if v then ESP.Enabled = false end
end, "esp_chams")
esp:space()
esp:section("Draw")
esp:toggle("Box", ESP.Box, function(v) ESP.Box = v end, "esp_box")
esp:toggle("Tracer", ESP.Tracer, function(v) ESP.Tracer = v end, "esp_tr")
esp:toggle("Skeleton", ESP.Skeleton, function(v) ESP.Skeleton = v end, "esp_sk")
esp:toggle("Name + Team", ESP.Name, function(v) ESP.Name = v end, "esp_nm")
esp:toggle("Health", ESP.Health, function(v) ESP.Health = v end, "esp_hp")
esp:space()
esp:section("Filter")
esp:toggle("Team Check", ESP.TeamCheck, function(v) ESP.TeamCheck = v end, "esp_team")
esp:toggle("Team Colors", ESP.TeamColor, function(v) ESP.TeamColor = v end, "esp_tc")
esp:slider("Max Dist", 100, 5000, ESP.MaxDist, function(v) ESP.MaxDist = v end, "esp_dist")
esp:colorpicker("Color", ESP.Color, function(c) ESP.Color = c end, "esp_col")

fly:section("Move")
fly:toggle("Fly", Fly.Enabled, function(v)
    if v then Fly:Start() else Fly:Stop() end
    w:notify("Test", v and "Fly on" or "Fly off", 2)
end, "fly_en")
fly:slider("Speed", 16, 300, Fly.Speed, function(v) Fly.Speed = v end, "fly_spd")
fly:label("WASD, Space/E hoch, Ctrl/Q runter.")

fling:section("Touch")
fling:toggle("Fling", false, function(v) Fling:SetFling(v) end, "fling_en")
fling:toggle("Fling Safe", false, function(v)
    Fling:SetSafeFling(v)
    w:notify("Test", v and "Safe on, 1 hit" or "Safe off", 2)
end, "fling_safe")
fling:toggle("No-Clip", false, function(v) Fling:SetNoClip(v) end, "fling_nc")
fling:label("Safe stoppt nach einem Treffer und setzt Velocity auf 0.")

lag:section("Stutter")
lag:toggle("Fake Lag", FakeLag.Enabled, function(v)
    if v then FakeLag:Start() else FakeLag:Stop() end
end, "lag_en")
lag:slider("Delay", 50, 500, FakeLag.Delay, function(v) FakeLag.Delay = v end, "lag_ms")

vc:section("Bypass")
vc:dropdown("Version", { "V1", "V2" }, "V1", function(val)
    if VC.Mode then
        w:notify("Test", "Rejoin to switch", 3)
        return
    end
    VC.Version = val == "V2" and 2 or 1
end, "vc_ver")
vc:button("Execute", function()
    local function note(t) w:notify("Test", t, 3) end
    if VC.Version == 2 then VC:RunV2(note) else VC:RunV1(note) end
end)
vc:button("Mic", function()
    VC:ToggleMic(function(t) w:notify("Test", t, 2) end)
end)
vc:label("Erst unmute, kurz reden, dann Execute.")

act:section("Script")
act:button("Reset Aim", function()
    Aim.Functions:ResetSettings()
    keyLabel:set("Current: " .. tostring(Aim.Settings.TriggerKey))
end)
act:button("Restart Aim", function() Aim.Functions:Restart() end)
act:button("Unload", function()
    if detectConn then detectConn:Disconnect() end
    pcall(function() Aim.Functions:Exit() end)
    pcall(function() ESP.Functions:Exit() end)
    pcall(function() Fling:Exit() end)
    pcall(function() FakeLag:Exit() end)
    pcall(function() Fly:Exit() end)
    pcall(function() VC:Exit() end)
end)
act:button("Destroy GUI", function()
    if detectConn then detectConn:Disconnect() end
    pcall(function() Aim.Functions:Exit() end)
    pcall(function() ESP.Functions:Exit() end)
    pcall(function() Fling:Exit() end)
    pcall(function() FakeLag:Exit() end)
    pcall(function() Fly:Exit() end)
    pcall(function() VC:Exit() end)
    w:destroy()
end)

w:notify("Test", "Loaded", 3)

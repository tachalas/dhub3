-- KyriLib laden
local kyri = loadstring(game:HttpGet("https://raw.githubusercontent.com/Justanewplayer19/KyriLib/refs/heads/main/source.lua"))()

-- Environment
getgenv().AirHub = getgenv().AirHub or {}

--======= MODULE =======--
local pcall, getgenv, next, setmetatable, Vector2new, CFramenew, Color3fromRGB, Drawingnew, TweenInfonew, stringupper, mousemoverel = pcall, getgenv, next, setmetatable, Vector2.new, CFrame.new, Color3.fromRGB, Drawing.new, TweenInfo.new, string.upper, mousemoverel or (Input and Input.MouseMove)

if not getgenv().AirHub.Aimbot then
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera

    local RequiredDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, false, false, {}

    getgenv().AirHub.Aimbot = {
        Settings = {
            Enabled = false,
            TeamCheck = false,
            AliveCheck = true,
            WallCheck = false,
            Sensitivity = 0,
            ThirdPerson = false,
            ThirdPersonSensitivity = 3,
            TriggerKey = "MouseButton2",
            Toggle = false,
            LockPart = "Head"
        },
        FOVSettings = {
            Enabled = true,
            Visible = true,
            Amount = 90,
            Color = Color3fromRGB(255, 255, 255),
            LockedColor = Color3fromRGB(255, 70, 70),
            Transparency = 0.5,
            Sides = 60,
            Thickness = 1,
            Filled = false
        },
        FOVCircle = Drawingnew("Circle")
    }

    local Environment = getgenv().AirHub.Aimbot

    local function ConvertVector(Vector)
        return Vector2new(Vector.X, Vector.Y)
    end

    local function CancelLock()
        Environment.Locked = nil
        Environment.FOVCircle.Color = Environment.FOVSettings.Color
        UserInputService.MouseDeltaSensitivity = OriginalSensitivity
        if Animation then
            Animation:Cancel()
        end
    end

    local function GetClosestPlayer()
        if not Environment.Locked then
            RequiredDistance = (Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000)

            for _, v in next, Players:GetPlayers() do
                if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild(Environment.Settings.LockPart) and v.Character:FindFirstChildOfClass("Humanoid") then
                    if Environment.Settings.TeamCheck and v.TeamColor == LocalPlayer.TeamColor then continue end
                    if Environment.Settings.AliveCheck and v.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
                    if Environment.Settings.WallCheck and #(Camera:GetPartsObscuringTarget({v.Character[Environment.Settings.LockPart].Position}, v.Character:GetDescendants())) > 0 then continue end

                    local Vector, OnScreen = Camera:WorldToViewportPoint(v.Character[Environment.Settings.LockPart].Position)
                    Vector = ConvertVector(Vector)
                    local Distance = (UserInputService:GetMouseLocation() - Vector).Magnitude

                    if Distance < RequiredDistance and OnScreen then
                        RequiredDistance = Distance
                        Environment.Locked = v
                    end
                end
            end
        elseif (UserInputService:GetMouseLocation() - ConvertVector(Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position))).Magnitude > RequiredDistance then
            CancelLock()
        end
    end

    -- Verbesserte Key-Prüfung (Keyboard + Mouse + Gamepad)
    local function IsTrigger(Input)
        local key = Environment.Settings.TriggerKey
        if not key or key == "" then return false end

        -- Mouse Buttons
        if key:find("MouseButton") then
            return Input.UserInputType == Enum.UserInputType[key]
        end

        -- Gamepad Buttons (ButtonL2, ButtonR2, ButtonA usw.)
        if key:find("Button") then
            return Input.UserInputType == Enum.UserInputType.Gamepad1
                and Input.KeyCode == Enum.KeyCode[key]
        end

        -- Keyboard
        local success, keycode = pcall(function()
            return Enum.KeyCode[key]
        end)
        if success and keycode then
            return Input.UserInputType == Enum.UserInputType.Keyboard
                and Input.KeyCode == keycode
        end

        return false
    end

    local function Load()
        OriginalSensitivity = UserInputService.MouseDeltaSensitivity

        ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
            if Environment.FOVSettings.Enabled and Environment.Settings.Enabled then
                Environment.FOVCircle.Radius = Environment.FOVSettings.Amount
                Environment.FOVCircle.Thickness = Environment.FOVSettings.Thickness
                Environment.FOVCircle.Filled = Environment.FOVSettings.Filled
                Environment.FOVCircle.NumSides = Environment.FOVSettings.Sides
                Environment.FOVCircle.Color = Environment.FOVSettings.Color
                Environment.FOVCircle.Transparency = Environment.FOVSettings.Transparency
                Environment.FOVCircle.Visible = Environment.FOVSettings.Visible
                Environment.FOVCircle.Position = Vector2new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
            else
                Environment.FOVCircle.Visible = false
            end

            if Running and Environment.Settings.Enabled then
                GetClosestPlayer()

                if Environment.Locked then
                    if Environment.Settings.ThirdPerson then
                        local Vector = Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position)
                        mousemoverel((Vector.X - UserInputService:GetMouseLocation().X) * Environment.Settings.ThirdPersonSensitivity, (Vector.Y - UserInputService:GetMouseLocation().Y) * Environment.Settings.ThirdPersonSensitivity)
                    else
                        if Environment.Settings.Sensitivity > 0 then
                            Animation = TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)})
                            Animation:Play()
                        else
                            Camera.CFrame = CFramenew(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)
                        end
                        UserInputService.MouseDeltaSensitivity = 0
                    end
                    Environment.FOVCircle.Color = Environment.FOVSettings.LockedColor
                end
            end
        end)

        ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
            if not Typing then
                if IsTrigger(Input) then
                    if Environment.Settings.Toggle then
                        Running = not Running
                        if not Running then CancelLock() end
                    else
                        Running = true
                    end
                end
            end
        end)

        ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
            if not Typing and not Environment.Settings.Toggle then
                if IsTrigger(Input) then
                    Running = false
                    CancelLock()
                end
            end
        end)
    end

    ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function()
        Typing = true
    end)

    ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function()
        Typing = false
    end)

    Environment.Functions = {}

    function Environment.Functions:Exit()
        for _, v in next, ServiceConnections do
            v:Disconnect()
        end
        Environment.FOVCircle:Remove()
        getgenv().AirHub.Aimbot.Functions = nil
        getgenv().AirHub.Aimbot = nil
    end

    function Environment.Functions:Restart()
        for _, v in next, ServiceConnections do
            v:Disconnect()
        end
        Load()
    end

    function Environment.Functions:ResetSettings()
        Environment.Settings = {
            Enabled = false,
            TeamCheck = false,
            AliveCheck = true,
            WallCheck = false,
            Sensitivity = 0,
            ThirdPerson = false,
            ThirdPersonSensitivity = 3,
            TriggerKey = "MouseButton2",
            Toggle = false,
            LockPart = "Head"
        }
        Environment.FOVSettings = {
            Enabled = true,
            Visible = true,
            Amount = 90,
            Color = Color3fromRGB(255, 255, 255),
            LockedColor = Color3fromRGB(255, 70, 70),
            Transparency = 0.5,
            Sides = 60,
            Thickness = 1,
            Filled = false
        }
    end

    setmetatable(Environment.Functions, { __newindex = warn })
    Load()
end

--======= GUI =======--
local Module = getgenv().AirHub.Aimbot
local UserInputService = game:GetService("UserInputService")

local w = kyri.new("Test", {
    GameName = "Test",
    AutoLoad = "default"
})

local tab1 = w:tab("Test", "sliders")
local tab2 = w:tab("Test 2", "circle")
local tab3 = w:tab("Test 3", "settings-2")

----------------------------------------
-- TAB 1
----------------------------------------
tab1:section("Main")

tab1:toggle("Enabled", Module.Settings.Enabled, function(state)
    Module.Settings.Enabled = state
    w:notify("Test", state and "On" or "Off", 2)
end, "test_enabled")

tab1:toggle("Check 1", Module.Settings.TeamCheck, function(state)
    Module.Settings.TeamCheck = state
end, "test_check1")

tab1:toggle("Check 2", Module.Settings.AliveCheck, function(state)
    Module.Settings.AliveCheck = state
end, "test_check2")

tab1:toggle("Check 3", Module.Settings.WallCheck, function(state)
    Module.Settings.WallCheck = state
end, "test_check3")

tab1:toggle("Mode", Module.Settings.Toggle, function(state)
    Module.Settings.Toggle = state
end, "test_mode")

tab1:toggle("Mode 2", Module.Settings.ThirdPerson, function(state)
    Module.Settings.ThirdPerson = state
end, "test_mode2")

tab1:space()
tab1:section("Options")

tab1:dropdown("Part", {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso"}, Module.Settings.LockPart, function(val)
    Module.Settings.LockPart = val
end, "test_part")

tab1:slider("Value 1", 0, 1, Module.Settings.Sensitivity, function(val)
    Module.Settings.Sensitivity = val
end, "test_val1", 0.01)

tab1:slider("Value 2", 1, 10, Module.Settings.ThirdPersonSensitivity, function(val)
    Module.Settings.ThirdPersonSensitivity = val
end, "test_val2", 0.1)

----------------------------------------
-- TAB 2
----------------------------------------
tab2:section("Circle")

tab2:toggle("Enabled", Module.FOVSettings.Enabled, function(state)
    Module.FOVSettings.Enabled = state
end, "test_circle_enabled")

tab2:toggle("Visible", Module.FOVSettings.Visible, function(state)
    Module.FOVSettings.Visible = state
end, "test_circle_visible")

tab2:toggle("Filled", Module.FOVSettings.Filled, function(state)
    Module.FOVSettings.Filled = state
end, "test_circle_filled")

tab2:slider("Size", 10, 500, Module.FOVSettings.Amount, function(val)
    Module.FOVSettings.Amount = val
end, "test_circle_size")

tab2:slider("Thickness", 1, 5, Module.FOVSettings.Thickness, function(val)
    Module.FOVSettings.Thickness = val
end, "test_circle_thickness")

tab2:slider("Sides", 12, 100, Module.FOVSettings.Sides, function(val)
    Module.FOVSettings.Sides = val
end, "test_circle_sides")

tab2:slider("Transparency", 0, 1, Module.FOVSettings.Transparency, function(val)
    Module.FOVSettings.Transparency = val
end, "test_circle_trans", 0.05)

tab2:space()
tab2:section("Colors")

tab2:colorpicker("Color 1", Module.FOVSettings.Color, function(color)
    Module.FOVSettings.Color = color
end, "test_color1")

tab2:colorpicker("Color 2", Module.FOVSettings.LockedColor, function(color)
    Module.FOVSettings.LockedColor = color
end, "test_color2")

----------------------------------------
-- TAB 3
----------------------------------------
tab3:section("Key")

-- Anzeige der aktuellen Taste
local keyLabel = tab3:label("Current: " .. tostring(Module.Settings.TriggerKey))

local detecting = false
local detectConn = nil

tab3:button("Detect Key", function()
    if detecting then return end
    detecting = true
    keyLabel:set("Current: Press any key...")
    w:notify("Test", "Press any key / button now", 3)

    detectConn = UserInputService.InputBegan:Connect(function(Input, gp)
        if gp then return end

        local keyName = nil

        if Input.UserInputType == Enum.UserInputType.Keyboard then
            keyName = Input.KeyCode.Name
        elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
            keyName = "MouseButton1"
        elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
            keyName = "MouseButton2"
        elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then
            keyName = "MouseButton3"
        elseif Input.UserInputType == Enum.UserInputType.Gamepad1 then
            keyName = Input.KeyCode.Name  -- z.B. ButtonL2, ButtonR2, ButtonA
        end

        if keyName then
            Module.Settings.TriggerKey = keyName
            keyLabel:set("Current: " .. keyName)
            w:notify("Test", "Key set to: " .. keyName, 2)
            detecting = false
            if detectConn then
                detectConn:Disconnect()
                detectConn = nil
            end
        end
    end)
end)

tab3:space()
tab3:section("Actions")

tab3:button("Reset", function()
    Module.Functions:ResetSettings()
    keyLabel:set("Current: " .. tostring(Module.Settings.TriggerKey))
    w:notify("Test", "Reset done", 3)
end)

tab3:button("Restart", function()
    Module.Functions:Restart()
    w:notify("Test", "Restarted", 2)
end)

tab3:button("Unload", function()
    Module.Functions:Exit()
    w:notify("Test", "Unloaded", 2)
end)

tab3:button("Destroy GUI", function()
    if detectConn then
        detectConn:Disconnect()
    end
    pcall(function()
        Module.Functions:Exit()
    end)
    w:destroy()
end)

w:notify("Test", "Loaded", 3)

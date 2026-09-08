-- ui
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local UIManager = {
    Initialized = false,
    Library = nil,
    Window = nil,
    Connections = {}
}

function UIManager.init(Config, Library, SilentAim, Movement, unloadCallback)
    if type(Movement) == "function" and unloadCallback == nil then
        unloadCallback = Movement
        Movement = nil
    end
    if UIManager.Initialized then return end
    UIManager.Initialized = true
    UIManager.Library = Library

    if Config.UI_THEME then
        for prop, val in pairs(Config.UI_THEME) do
            if Library[prop] ~= nil then Library[prop] = val end
        end
    end

    local saveDebounce = nil
    local function queueAutoSave()
        if saveDebounce then task.cancel(saveDebounce) end
        saveDebounce = task.delay(0.35, function()
            Config.save()
            saveDebounce = nil
        end)
    end

    local function updateSetting(key, newVal)
        if Config[key] ~= newVal then
            Config[key] = newVal
            queueAutoSave()
        end
    end

    local windowTitle = "Seeto.SolutionZ / Frontlines / " .. (Config.VERSION or "v1.0")

    local Window = Library:CreateWindow({
        Title = windowTitle,
        Center = true,
        AutoShow = (Config.MENU_OPEN ~= false),
        TabPadding = 6,
        MenuFadeTime = 0.2,
        Size = UDim2.fromOffset(Config.WINDOW_SIZE_X or 380, Config.WINDOW_SIZE_Y or 210),
        ResizeCallback = function(w, h)
            if Config.WINDOW_SIZE_X ~= w or Config.WINDOW_SIZE_Y ~= h then
                Config.WINDOW_SIZE_X = w
                Config.WINDOW_SIZE_Y = h
                queueAutoSave()
            end
        end
    })
    UIManager.Window = Window

    local Tabs = {
        Aim = Window:AddTab("Aim"),
        Visuals = Window:AddTab("Visuals"),
        Movement = Window:AddTab("Movement"),
        Settings = Window:AddTab("Settings")
    }

    local AimMain = Tabs.Aim:AddLeftGroupbox("Silent aim")
    local AimFov = Tabs.Aim:AddRightGroupbox("FOV settings")

    AimMain:AddToggle("SilentAim", {
        Text = "Silent aim",
        Default = (Config.SILENT_AIM_ENABLED ~= false),
        Tooltip = "redirects bullets to target",
        Callback = function(Value) updateSetting("SILENT_AIM_ENABLED", Value) end
    })

    AimMain:AddToggle("ZeroSpread", {
        Text = "Zero spread",
        Default = (Config.ZERO_SPREAD_ENABLED ~= false),
        Tooltip = "no spread",
        Callback = function(Value)
            updateSetting("ZERO_SPREAD_ENABLED", Value)
            if SilentAim and SilentAim.setZeroSpread then
                SilentAim.setZeroSpread(Value)
            end
        end
    })

    AimMain:AddToggle("NoRecoil", {
        Text = "No recoil",
        Default = (Config.NO_RECOIL_ENABLED ~= false),
        Tooltip = "no gun kick",
        Callback = function(Value)
            updateSetting("NO_RECOIL_ENABLED", Value)
            if SilentAim and SilentAim.setNoRecoil then
                SilentAim.setNoRecoil(Value)
            end
        end
    })

    AimMain:AddDropdown("TargetPriority", {
        Values = { "Auto", "Head", "Torso", "Random" },
        Default = Config.TARGET_PRIORITY or "Auto",
        Multi = false,
        Text = "Target priority",
        Tooltip = "where to aim",
        Callback = function(Value) updateSetting("TARGET_PRIORITY", Value) end
    })

    AimFov:AddToggle("ShowFov", {
        Text = "Show FOV circle",
        Default = (Config.FOV_CIRCLE_ENABLED ~= false),
        Tooltip = "draws fov circle",
        Callback = function(Value) updateSetting("FOV_CIRCLE_ENABLED", Value) end
    })

    AimFov:AddSlider("FovRadius", {
        Text = "FOV radius",
        Default = Config.FOV_RADIUS or 400,
        Min = 50,
        Max = 800,
        Rounding = 0,
        Compact = false,
        Suffix = "px",
        Callback = function(Value) updateSetting("FOV_RADIUS", Value) end
    })

    AimFov:AddSlider("FovOpacity", {
        Text = "FOV opacity",
        Default = math.floor((Config.FOV_CIRCLE_TRANSPARENCY or 0.4) * 100),
        Min = 5,
        Max = 100,
        Rounding = 0,
        Compact = false,
        Suffix = "%",
        Callback = function(Value) updateSetting("FOV_CIRCLE_TRANSPARENCY", Value / 100) end
    })

    -- Visuals Tab
    local EspMain = Tabs.Visuals:AddLeftGroupbox("ESP")
    local TracerGroup = Tabs.Visuals:AddRightGroupbox("Tracers")

    EspMain:AddToggle("EspMaster", {
        Text = "Enable ESP",
        Default = (Config.ESP_ENABLED ~= false),
        Tooltip = "master toggle",
        Callback = function(Value) updateSetting("ESP_ENABLED", Value) end
    })

    EspMain:AddToggle("BoxEsp", {
        Text = "Box ESP",
        Default = (Config.BOX_ESP_ENABLED ~= false),
        Tooltip = "draws boxes",
        Callback = function(Value) updateSetting("BOX_ESP_ENABLED", Value) end
    })

    EspMain:AddDropdown("BoxType", {
        Values = { "2D Box", "3D Box" },
        Default = Config.BOX_TYPE or "2D Box",
        Multi = false,
        Text = "Box type",
        Tooltip = "2d or 3d boxes",
        Callback = function(Value) updateSetting("BOX_TYPE", Value) end
    })

    EspMain:AddToggle("SkeletonEsp", {
        Text = "Skeleton ESP",
        Default = (Config.SKELETON_ENABLED ~= false),
        Tooltip = "draws bones",
        Callback = function(Value) updateSetting("SKELETON_ENABLED", Value) end
    })

    EspMain:AddToggle("ShowNames", {
        Text = "Player names",
        Default = (Config.SHOW_NAMES_BELOW == true),
        Tooltip = "shows usernames",
        Callback = function(Value) updateSetting("SHOW_NAMES_BELOW", Value) end
    })

    EspMain:AddToggle("HealthBar", {
        Text = "Health bar",
        Default = (Config.HEALTH_BAR_ENABLED ~= false),
        Tooltip = "shows hp",
        Callback = function(Value) updateSetting("HEALTH_BAR_ENABLED", Value) end
    })

    EspMain:AddToggle("ViewAngle", {
        Text = "View angle",
        Default = (Config.VIEWANGLE_ENABLED ~= false),
        Tooltip = "look direction",
        Callback = function(Value) updateSetting("VIEWANGLE_ENABLED", Value) end
    })

    EspMain:AddToggle("TargetSnapline", {
        Text = "Target snapline",
        Default = (Config.TARGET_SNAPLINE_ENABLED == true),
        Tooltip = "line to target",
        Callback = function(Value) updateSetting("TARGET_SNAPLINE_ENABLED", Value) end
    })

    EspMain:AddToggle("KnifeEsp", {
        Text = "Knife indicator",
        Default = (Config.KNIFE_ESP_ENABLED ~= false),
        Tooltip = "yellow diamond on knives",
        Callback = function(Value) updateSetting("KNIFE_ESP_ENABLED", Value) end
    })

    EspMain:AddToggle("DisableTeammates", {
        Text = "Filter teammates",
        Default = (Config.DISABLE_TEAMMATES ~= false),
        Tooltip = "hide team",
        Callback = function(Value) updateSetting("DISABLE_TEAMMATES", Value) end
    })

    -- Tracers Groupbox
    TracerGroup:AddToggle("TracerBeams", {
        Text = "Bullet tracers",
        Default = (Config.TRACER_BEAMS_ENABLED ~= false),
        Tooltip = "draws bullet lines",
        Callback = function(Value) updateSetting("TRACER_BEAMS_ENABLED", Value) end
    })

    -- Movement Tab
    local MoveMain = Tabs.Movement:AddLeftGroupbox("Speed boost")

    MoveMain:AddToggle("SpeedBoost", {
        Text = "Enable speed boost",
        Default = (Config.SPEED_BOOST_ENABLED == true),
        Tooltip = "increases walk and sprint speed",
        Callback = function(Value)
            updateSetting("SPEED_BOOST_ENABLED", Value)
            if Movement and Movement.setSpeed then
                Movement.setSpeed(Value, Config.SPEED_BOOST_PERCENT or 100)
            end
        end
    })

    MoveMain:AddSlider("SpeedPercent", {
        Text = "Speed boost multiplier",
        Default = Config.SPEED_BOOST_PERCENT or 100,
        Min = 1,
        Max = 500,
        Rounding = 0,
        Compact = false,
        Suffix = "%",
        Callback = function(Value)
            updateSetting("SPEED_BOOST_PERCENT", Value)
            if Movement and Movement.setSpeed then
                Movement.setSpeed(Config.SPEED_BOOST_ENABLED == true, Value)
            end
        end
    })

    local MovementMisc = Tabs.Movement:AddRightGroupbox("Flight & Noclip")

    MovementMisc:AddToggle("FlyToggle", {
        Text = "Enable fly",
        Default = (Config.FLY_ENABLED == true),
        Tooltip = "fly with WASD & camera direction",
        Callback = function(Value)
            updateSetting("FLY_ENABLED", Value)
            if Movement and Movement.setFly then
                Movement.setFly(Value, Config.FLY_SPEED or 50)
            end
        end
    })

    local FlyWarningLabel

    MovementMisc:AddSlider("FlySpeed", {
        Text = "Fly speed",
        Default = Config.FLY_SPEED or 50,
        Min = 10,
        Max = 300,
        Rounding = 0,
        Compact = false,
        Suffix = " studs/s",
        Callback = function(Value)
            updateSetting("FLY_SPEED", Value)
            if FlyWarningLabel then
                if Value >= 250 then
                    FlyWarningLabel:SetText("[!] (BEWARE OF KICK)")
                    if FlyWarningLabel.TextLabel then
                        FlyWarningLabel.TextLabel.TextColor3 = Library.RiskColor or Color3.fromRGB(255, 60, 60)
                    end
                else
                    FlyWarningLabel:SetText("")
                end
            end
            if Movement and Movement.setFly then
                Movement.setFly(Config.FLY_ENABLED == true, Value)
            end
        end
    })

    local initWarn = ((Config.FLY_SPEED or 50) >= 250) and "[!] (BEWARE OF KICK)" or ""
    FlyWarningLabel = MovementMisc:AddLabel(initWarn)
    if FlyWarningLabel and FlyWarningLabel.TextLabel then
        FlyWarningLabel.TextLabel.TextColor3 = Library.RiskColor or Color3.fromRGB(255, 60, 60)
    end

    MovementMisc:AddToggle("NoclipToggle", {
        Text = "Enable noclip",
        Default = (Config.NOCLIP_ENABLED == true),
        Tooltip = "pass through walls, floors & obstacles",
        Callback = function(Value)
            updateSetting("NOCLIP_ENABLED", Value)
            if Movement and Movement.setNoclip then
                Movement.setNoclip(Value)
            end
        end
    })

    -- Settings Tab
    local MenuGroup = Tabs.Settings:AddLeftGroupbox("Keybinds")
    local ActionsGroup = Tabs.Settings:AddRightGroupbox("Actions")

    local defaultMenuKey = (Config.TOGGLE_UI_KEY and Config.TOGGLE_UI_KEY.Name) or "Insert"
    MenuGroup:AddLabel("Menu toggle"):AddKeyPicker("MenuKeybind", {
        Default = defaultMenuKey,
        NoUI = true,
        Text = "Menu Key",
        ChangedCallback = function(NewKey)
            local key = (NewKey ~= "None") and Enum.KeyCode[NewKey] or nil
            updateSetting("TOGGLE_UI_KEY", key)
        end
    })

    local defaultAimKey = (type(Config.TOGGLE_AIM_KEY) == "string" and Config.TOGGLE_AIM_KEY) or (Config.TOGGLE_AIM_KEY and Config.TOGGLE_AIM_KEY.Name) or "None"
    MenuGroup:AddLabel("Silent aim bind"):AddKeyPicker("AimKeybind", {
        Default = defaultAimKey,
        Mode = Config.AIM_BIND_MODE or "Toggle",
        NoUI = true,
        Text = "Silent aim bind",
        ChangedCallback = function(NewKey)
            local key = (NewKey and NewKey ~= "None") and NewKey or "None"
            updateSetting("TOGGLE_AIM_KEY", key)
        end
    })

    MenuGroup:AddDropdown("AimBindMode", {
        Values = { "Toggle", "Hold" },
        Default = Config.AIM_BIND_MODE or "Toggle",
        Multi = false,
        Text = "Aim bind mode",
        Tooltip = "hold or toggle",
        Callback = function(Value)
            updateSetting("AIM_BIND_MODE", Value)
            if Options and Options.AimKeybind then
                Options.AimKeybind.Mode = Value
                Options.AimKeybind.Toggled = false
                if Options.AimKeybind.Update then
                    Options.AimKeybind:Update()
                end
            end
        end
    })

    local defaultEspKey = (Config.TOGGLE_ESP_KEY and Config.TOGGLE_ESP_KEY.Name) or "None"
    MenuGroup:AddLabel("Master ESP bind"):AddKeyPicker("EspKeybind", {
        Default = defaultEspKey,
        NoUI = true,
        Text = "Master ESP bind",
        ChangedCallback = function(NewKey)
            local key = (NewKey ~= "None") and Enum.KeyCode[NewKey] or nil
            updateSetting("TOGGLE_ESP_KEY", key)
        end
    })

    local defaultFlyKey = (type(Config.TOGGLE_FLY_KEY) == "string" and Config.TOGGLE_FLY_KEY) or (Config.TOGGLE_FLY_KEY and Config.TOGGLE_FLY_KEY.Name) or "None"
    MenuGroup:AddLabel("Fly toggle"):AddKeyPicker("FlyKeybind", {
        Default = defaultFlyKey,
        NoUI = true,
        Text = "Fly toggle",
        ChangedCallback = function(NewKey)
            local key = (NewKey and NewKey ~= "None") and NewKey or "None"
            updateSetting("TOGGLE_FLY_KEY", key)
        end
    })

    local defaultNoclipKey = (type(Config.TOGGLE_NOCLIP_KEY) == "string" and Config.TOGGLE_NOCLIP_KEY) or (Config.TOGGLE_NOCLIP_KEY and Config.TOGGLE_NOCLIP_KEY.Name) or "None"
    MenuGroup:AddLabel("Noclip toggle"):AddKeyPicker("NoclipKeybind", {
        Default = defaultNoclipKey,
        NoUI = true,
        Text = "Noclip toggle",
        ChangedCallback = function(NewKey)
            local key = (NewKey and NewKey ~= "None") and NewKey or "None"
            updateSetting("TOGGLE_NOCLIP_KEY", key)
        end
    })

    local defaultUnloadKey = (Config.UNLOAD_KEY and Config.UNLOAD_KEY.Name) or "K"
    MenuGroup:AddLabel("Unload script"):AddKeyPicker("UnloadKeybind", {
        Default = defaultUnloadKey,
        NoUI = true,
        Text = "Kill script",
        ChangedCallback = function(NewKey)
            local key = (NewKey ~= "None") and Enum.KeyCode[NewKey] or nil
            updateSetting("UNLOAD_KEY", key)
        end
    })

    Library.ToggleKeybind = Options.MenuKeybind

    ActionsGroup:AddButton({
        Text = "Reset defaults",
        Func = function()
            Config.reset()

            if Toggles.SilentAim then Toggles.SilentAim:SetValue(Config.SILENT_AIM_ENABLED) end
            if Toggles.ZeroSpread then Toggles.ZeroSpread:SetValue(Config.ZERO_SPREAD_ENABLED) end
            if SilentAim and SilentAim.setZeroSpread then SilentAim.setZeroSpread(Config.ZERO_SPREAD_ENABLED ~= false) end
            if Options.TargetPriority then Options.TargetPriority:SetValue(Config.TARGET_PRIORITY or "Auto") end

            if Toggles.ShowFov then Toggles.ShowFov:SetValue(Config.FOV_CIRCLE_ENABLED) end
            if Options.FovRadius then Options.FovRadius:SetValue(Config.FOV_RADIUS or 400) end
            if Options.FovOpacity then Options.FovOpacity:SetValue(math.floor((Config.FOV_CIRCLE_TRANSPARENCY or 0.4) * 100)) end

            if Toggles.EspMaster then Toggles.EspMaster:SetValue(Config.ESP_ENABLED) end
            if Toggles.BoxEsp then Toggles.BoxEsp:SetValue(Config.BOX_ESP_ENABLED ~= false) end
            if Options.BoxType then Options.BoxType:SetValue(Config.BOX_TYPE or "2D Box") end
            if Toggles.SkeletonEsp then Toggles.SkeletonEsp:SetValue(Config.SKELETON_ENABLED ~= false) end
            if Toggles.ShowNames then Toggles.ShowNames:SetValue(Config.SHOW_NAMES_BELOW == true) end
            if Toggles.HealthBar then Toggles.HealthBar:SetValue(Config.HEALTH_BAR_ENABLED) end
            if Toggles.ViewAngle then Toggles.ViewAngle:SetValue(Config.VIEWANGLE_ENABLED) end
            if Toggles.TargetSnapline then Toggles.TargetSnapline:SetValue(Config.TARGET_SNAPLINE_ENABLED == true) end
            if Toggles.KnifeEsp then Toggles.KnifeEsp:SetValue(Config.KNIFE_ESP_ENABLED ~= false) end
            if Toggles.DisableTeammates then Toggles.DisableTeammates:SetValue(Config.DISABLE_TEAMMATES) end
            if Toggles.TracerBeams then Toggles.TracerBeams:SetValue(Config.TRACER_BEAMS_ENABLED) end
            if Toggles.SpeedBoost then Toggles.SpeedBoost:SetValue(Config.SPEED_BOOST_ENABLED == true) end
            if Options.SpeedPercent then Options.SpeedPercent:SetValue(Config.SPEED_BOOST_PERCENT or 100) end
            if Toggles.FlyToggle then Toggles.FlyToggle:SetValue(Config.FLY_ENABLED == true) end
            if Options.FlySpeed then Options.FlySpeed:SetValue(Config.FLY_SPEED or 50) end
            if Toggles.NoclipToggle then Toggles.NoclipToggle:SetValue(Config.NOCLIP_ENABLED == true) end

            if Options.MenuKeybind then Options.MenuKeybind:SetValue("Insert") end
            if Options.AimKeybind then Options.AimKeybind:SetValue("None") end
            if Options.AimBindMode then Options.AimBindMode:SetValue("Hold") end
            if Options.EspKeybind then Options.EspKeybind:SetValue("None") end
            if Options.FlyKeybind then Options.FlyKeybind:SetValue("None") end
            if Options.NoclipKeybind then Options.NoclipKeybind:SetValue("None") end
            if Options.UnloadKeybind then Options.UnloadKeybind:SetValue("P") end

            Config.WINDOW_SIZE_X = 380
            Config.WINDOW_SIZE_Y = 319
            if Window and Window.Outer then
                Window.Outer.Size = UDim2.fromOffset(380, 319)
            end

            queueAutoSave()
            Library:Notify("Settings reset to defaults", 2)
        end,
        DoubleClick = false,
        Tooltip = "resets all settings"
    })

    ActionsGroup:AddButton({
        Text = "Unload",
        Func = function()
            if type(unloadCallback) == "function" then
                unloadCallback()
            elseif _G.__frontlinesJanitor then
                _G.__frontlinesJanitor()
            end
        end,
        DoubleClick = true,
        Tooltip = "double click to quit"
    })

    local function matchesKey(input, keyVal, optionObj)
        local key = keyVal
        if not key or key == "None" or key == "" then
            if optionObj and optionObj.Value and optionObj.Value ~= "None" then
                key = optionObj.Value
            else
                return false
            end
        end

        if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
            return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key
        end

        if type(key) == "string" then
            if key == "MB1" then
                return input.UserInputType == Enum.UserInputType.MouseButton1
            elseif key == "MB2" then
                return input.UserInputType == Enum.UserInputType.MouseButton2
            elseif key == "MB3" then
                return input.UserInputType == Enum.UserInputType.MouseButton3
            elseif Enum.KeyCode[key] then
                return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode[key]
            end
        end

        return false
    end

    local bindInputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if Library and Library.IsPickingKey then return end
        if UserInputService:GetFocusedTextBox() then return end

        if matchesKey(input, Config.TOGGLE_AIM_KEY, Options and Options.AimKeybind) then
            if Config.AIM_BIND_MODE == "Toggle" then
                local nextState = not Config.SILENT_AIM_ENABLED
                updateSetting("SILENT_AIM_ENABLED", nextState)
                if Toggles.SilentAim and Toggles.SilentAim.Value ~= nextState then
                    Toggles.SilentAim:SetValue(nextState)
                end
            end
        elseif matchesKey(input, Config.TOGGLE_FLY_KEY, Options and Options.FlyKeybind) then
            local nextState = not Config.FLY_ENABLED
            updateSetting("FLY_ENABLED", nextState)
            if Toggles.FlyToggle and Toggles.FlyToggle.Value ~= nextState then
                Toggles.FlyToggle:SetValue(nextState)
            end
            if Movement and Movement.setFly then
                Movement.setFly(nextState, Config.FLY_SPEED or 50)
            end
        elseif matchesKey(input, Config.TOGGLE_NOCLIP_KEY, Options and Options.NoclipKeybind) then
            local nextState = not Config.NOCLIP_ENABLED
            updateSetting("NOCLIP_ENABLED", nextState)
            if Toggles.NoclipToggle and Toggles.NoclipToggle.Value ~= nextState then
                Toggles.NoclipToggle:SetValue(nextState)
            end
            if Movement and Movement.setNoclip then
                Movement.setNoclip(nextState)
            end
        elseif Config.TOGGLE_ESP_KEY and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.TOGGLE_ESP_KEY then
            local nextState = not Config.ESP_ENABLED
            updateSetting("ESP_ENABLED", nextState)
            if Toggles.EspMaster and Toggles.EspMaster.Value ~= nextState then
                Toggles.EspMaster:SetValue(nextState)
            end
        elseif Config.TOGGLE_UI_KEY_ALT and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.TOGGLE_UI_KEY_ALT then
            if Window and Window.Holder then
                Window.Holder.Visible = not Window.Holder.Visible
            end
        end
    end)
    table.insert(UIManager.Connections, bindInputBegan)

    -- Input isolation (sinks game actions & discharges while clicking/typing in UI)
    local isInteractingWithUI = false

    local function isMouseOverUI()
        if not Library then return false end
        if Library.OpenedFrames then
            for frame, _ in pairs(Library.OpenedFrames) do
                if frame and frame.Visible and Library.IsMouseOverFrame and Library:IsMouseOverFrame(frame) then
                    return true
                end
            end
        end
        local holder = Window and Window.Holder
        if holder and holder.Visible and Library.IsMouseOverFrame and Library:IsMouseOverFrame(holder) then
            return true
        end

        local mPos = UserInputService:GetMouseLocation()
        if holder and holder.Visible then
            local pos, size = holder.AbsolutePosition, holder.AbsoluteSize
            if mPos.X >= pos.X and mPos.X <= (pos.X + size.X) and mPos.Y >= pos.Y and mPos.Y <= (pos.Y + size.Y) then
                return true
            end
        end

        return false
    end

    -- Setup actor control proxy
    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if fca and type(run_on_actor) == "function" then
        pcall(run_on_actor, fca, [[
            local RunService = game:GetService("RunService")
            local act = game.Players.LocalPlayer.PlayerScripts:FindFirstChild("frontlines_client_actor")
            local main = act and act:FindFirstChild("frontlines_main")
            local env = main and getsenv(main)
            local G = env and env._G or _G
            local globals = G.globals
            local cs = globals and globals.ctrl_states
            local ts = globals and globals.ctrl_ts
            if not cs then return end

            if not rawget(cs, "__is_proxy") then
                local raw = {}
                for k, v in pairs(cs) do
                    raw[k] = v
                    cs[k] = nil
                end
                rawset(cs, "__is_proxy", true)
                rawset(cs, "__raw", raw)

                local mt = {
                    __index = function(t, k)
                        local sink = (act and act:GetAttribute("UISinkActive") == true) or _G.__ui_sink_active == true
                        local keySink = (act and act:GetAttribute("UIKeySinkActive") == true) or _G.__ui_key_sink_active == true
                        if sink then
                            if k == "fire" or k == "trigger" or k == "hold_ads" or k == "hold_ads_aux"
                               or k == "hold_melee_attack" or k == "hold_melee_throw" or k == "gamepad_trigger" then
                                return false
                            end
                        end
                        if keySink then
                            if k == "hold_jump" or k == "hold_crouch" or k == "hold_reload"
                               or k == "mv_fw" or k == "mv_bw" or k == "mv_lt" or k == "mv_rt" or k == "hold_accel" then
                                return false
                            end
                        end
                        return raw[k]
                    end,
                    __newindex = function(t, k, v)
                        local sink = (act and act:GetAttribute("UISinkActive") == true) or _G.__ui_sink_active == true
                        local keySink = (act and act:GetAttribute("UIKeySinkActive") == true) or _G.__ui_key_sink_active == true
                        if sink then
                            if k == "fire" or k == "trigger" or k == "hold_ads" or k == "hold_ads_aux"
                               or k == "hold_melee_attack" or k == "hold_melee_throw" or k == "gamepad_trigger" then
                                raw[k] = false
                                return
                            end
                        end
                        if keySink then
                            if k == "hold_jump" or k == "hold_crouch" or k == "hold_reload"
                               or k == "mv_fw" or k == "mv_bw" or k == "mv_lt" or k == "mv_rt" or k == "hold_accel" then
                                raw[k] = false
                                return
                            end
                        end
                        raw[k] = v
                    end
                }
                setmetatable(cs, mt)
            end

            if not _G.__solutionzSinkCleaner then
                _G.__solutionzSinkCleaner = RunService.RenderStepped:Connect(function()
                    local sink = (act and act:GetAttribute("UISinkActive") == true) or _G.__ui_sink_active == true
                    if sink and ts then
                        ts.trigger = 0
                    end
                end)
            end
        ]])
    end

    local sinkSyncConn = RunService.RenderStepped:Connect(function()
        local isMenuOpen = (Window and Window.Holder and Window.Holder.Visible == true)
        local mouseOver = isMenuOpen and (isMouseOverUI() or isInteractingWithUI)
        local keyPicking = (Library and Library.IsPickingKey == true) or (UserInputService:GetFocusedTextBox() ~= nil)
        local sinkActive = mouseOver or keyPicking

        if fca then
            fca:SetAttribute("UISinkActive", sinkActive)
            fca:SetAttribute("UIKeySinkActive", keyPicking)
        end
    end)
    table.insert(UIManager.Connections, sinkSyncConn)

    local SINK_ACTION_NAME = "SolutionZ_Frontlines_InputSink"
    pcall(function() ContextActionService:UnbindAction(SINK_ACTION_NAME) end)

    ContextActionService:BindActionAtPriority(
        SINK_ACTION_NAME,
        function(actionName, inputState, inputObject)
            if Library and Library.IsPickingKey then
                return Enum.ContextActionResult.Sink
            end
            if UserInputService:GetFocusedTextBox() then
                if inputObject.UserInputType == Enum.UserInputType.Keyboard then
                    return Enum.ContextActionResult.Sink
                end
            end

            local it = inputObject.UserInputType
            if it == Enum.UserInputType.MouseButton1
                or it == Enum.UserInputType.MouseButton2
                or it == Enum.UserInputType.MouseButton3
                or it == Enum.UserInputType.MouseWheel then

                if inputState == Enum.UserInputState.Begin then
                    if isMouseOverUI() then
                        isInteractingWithUI = true
                        return Enum.ContextActionResult.Sink
                    end
                elseif inputState == Enum.UserInputState.Change then
                    if isInteractingWithUI or isMouseOverUI() then
                        return Enum.ContextActionResult.Sink
                    end
                elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
                    if isInteractingWithUI or isMouseOverUI() then
                        isInteractingWithUI = false
                        return Enum.ContextActionResult.Sink
                    end
                end
            end

            return Enum.ContextActionResult.Pass
        end,
        false,
        2000000,
        Enum.UserInputType.MouseButton1,
        Enum.UserInputType.MouseButton2,
        Enum.UserInputType.MouseButton3,
        Enum.UserInputType.MouseWheel,
        Enum.UserInputType.Keyboard
    )

    Library:Notify(windowTitle .. " Loaded!", 3)
end

function UIManager.cleanup()
    pcall(function()
        ContextActionService:UnbindAction("SolutionZ_Frontlines_InputSink")
    end)

    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if fca then
        pcall(function()
            fca:SetAttribute("UISinkActive", false)
            fca:SetAttribute("UIKeySinkActive", false)
        end)
    end

    for _, c in ipairs(UIManager.Connections) do
        pcall(function() c:Disconnect() end)
    end
    UIManager.Connections = {}

    local Library = UIManager.Library
    if Library and Library.Unload then
        pcall(function() Library:Unload() end)
    end

    UIManager.Library = nil
    UIManager.Window = nil
    UIManager.Initialized = false
end

return UIManager

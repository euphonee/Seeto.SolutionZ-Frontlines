-- ui
local UserInputService = game:GetService("UserInputService")

local UIManager = {
    Initialized = false,
    Library = nil,
    Window = nil,
    Connections = {}
}

function UIManager.init(Config, Library, SilentAim, unloadCallback)
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
        TabPadding = 8,
        MenuFadeTime = 0.2
    })
    UIManager.Window = Window

    local Tabs = {
        Aim = Window:AddTab("Aim"),
        Visuals = Window:AddTab("Visuals"),
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

    TracerGroup:AddSlider("TracerFadeout", {
        Text = "Fade duration",
        Default = Config.TRACER_FADEOUT_TIME or 3.4,
        Min = 0.5,
        Max = 5.0,
        Rounding = 1,
        Compact = false,
        Suffix = "s",
        Callback = function(Value) updateSetting("TRACER_FADEOUT_TIME", Value) end
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
            if Toggles.DisableTeammates then Toggles.DisableTeammates:SetValue(Config.DISABLE_TEAMMATES) end
            if Toggles.TracerBeams then Toggles.TracerBeams:SetValue(Config.TRACER_BEAMS_ENABLED) end
            if Options.TracerFadeout then Options.TracerFadeout:SetValue(Config.TRACER_FADEOUT_TIME or 3.4) end

            if Options.MenuKeybind then Options.MenuKeybind:SetValue("Insert") end
            if Options.AimKeybind then Options.AimKeybind:SetValue("None") end
            if Options.AimBindMode then Options.AimBindMode:SetValue("Toggle") end
            if Options.EspKeybind then Options.EspKeybind:SetValue("None") end
            if Options.UnloadKeybind then Options.UnloadKeybind:SetValue("K") end

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

    local function matchesAimKey(input)
        local key = Config.TOGGLE_AIM_KEY
        if not key or key == "None" or key == "" then
            if Options and Options.AimKeybind and Options.AimKeybind.Value and Options.AimKeybind.Value ~= "None" then
                key = Options.AimKeybind.Value
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

        if matchesAimKey(input) then
            if Config.AIM_BIND_MODE == "Toggle" then
                local nextState = not Config.SILENT_AIM_ENABLED
                updateSetting("SILENT_AIM_ENABLED", nextState)
                if Toggles.SilentAim and Toggles.SilentAim.Value ~= nextState then
                    Toggles.SilentAim:SetValue(nextState)
                end
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

    Library:Notify(windowTitle .. " Loaded!", 3)
end

function UIManager.cleanup()
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

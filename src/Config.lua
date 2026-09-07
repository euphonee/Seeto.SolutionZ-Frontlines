-- config
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local CONFIG_FOLDER = "SolutionZ_Frontlines"
local CONFIG_FILE = "SolutionZ_Frontlines/config.json"

local function ensureDirectory()
    if type(makefolder) == "function" then
        if type(isfolder) == "function" then
            if not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end
        else
            pcall(makefolder, CONFIG_FOLDER)
        end
    end
end

local Config = {
    VERSION = "v1.1",

    -- Aim
    SILENT_AIM_ENABLED = true,
    ZERO_SPREAD_ENABLED = true,
    NO_RECOIL_ENABLED = true,
    TARGET_PRIORITY = "Auto",
    FOV_RADIUS = 237,
    FOV_CIRCLE_ENABLED = true,
    FOV_CIRCLE_TRANSPARENCY = 0.18,
    FOV_CIRCLE_COLOR = Color3.fromRGB(255, 255, 255),

    -- Visuals
    ESP_ENABLED = true,
    BOX_ESP_ENABLED = true,
    BOX_TYPE = "2D Box",
    SKELETON_ENABLED = true,
    SHOW_NAMES_BELOW = false,
    HEALTH_BAR_ENABLED = true,
    VIEWANGLE_ENABLED = true,
    LOOK_LINE_LENGTH = 4.5,
    TARGET_SNAPLINE_ENABLED = false,
    DISABLE_TEAMMATES = true,

    -- Tracers
    TRACER_BEAMS_ENABLED = false,
    TRACER_FADEOUT_TIME = 3.4,
    TRACER_BEAM_WIDTH = 2,
    TRACER_BEAM_COLOR = Color3.fromRGB(0, 160, 255),

    -- Colors
    ENEMY_COLOR = Color3.fromRGB(255, 50, 50),
    TARGET_COLOR = Color3.fromRGB(0, 255, 120),
    SNAPLINE_COLOR = Color3.fromRGB(0, 255, 120),
    LOOK_LINE_COLOR = Color3.fromRGB(255, 255, 255),
    FRIENDLY_COLOR = Color3.fromRGB(60, 140, 255),

    -- Keybinds
    TOGGLE_UI_KEY = Enum.KeyCode.Insert,
    TOGGLE_UI_KEY_ALT = Enum.KeyCode.RightShift,
    TOGGLE_AIM_KEY = "None",
    AIM_BIND_MODE = "Hold",
    TOGGLE_ESP_KEY = nil,
    UNLOAD_KEY = Enum.KeyCode.K,

    MENU_OPEN = true,

    -- Theme
    UI_THEME = {
        FontColor       = Color3.fromRGB(245, 248, 255),
        MainColor       = Color3.fromRGB(22, 24, 30),
        BackgroundColor = Color3.fromRGB(15, 17, 22),
        AccentColor     = Color3.fromRGB(0, 160, 255),
        OutlineColor    = Color3.fromRGB(45, 52, 68),
        RiskColor       = Color3.fromRGB(255, 60, 60)
    },

    -- Runtime target state
    CurrentTargetActor = nil,
    CurrentTargetModel = nil,
    CurrentTargetHeadPos = nil,
    CurrentTargetPartName = "Head_M"
}

local DEFAULT_VALUES = {
    SILENT_AIM_ENABLED = true,
    ZERO_SPREAD_ENABLED = true,
    NO_RECOIL_ENABLED = true,
    TARGET_PRIORITY = "Auto",
    FOV_RADIUS = 237,
    FOV_CIRCLE_ENABLED = true,
    FOV_CIRCLE_TRANSPARENCY = 0.18,
    ESP_ENABLED = true,
    BOX_ESP_ENABLED = true,
    BOX_TYPE = "2D Box",
    SKELETON_ENABLED = true,
    SHOW_NAMES_BELOW = false,
    HEALTH_BAR_ENABLED = true,
    VIEWANGLE_ENABLED = true,
    TARGET_SNAPLINE_ENABLED = false,
    DISABLE_TEAMMATES = true,
    TRACER_BEAMS_ENABLED = false,
    TRACER_FADEOUT_TIME = 3.4,
    TRACER_BEAM_WIDTH = 2,
    TOGGLE_UI_KEY = "Insert",
    TOGGLE_UI_KEY_ALT = "RightShift",
    TOGGLE_AIM_KEY = "None",
    AIM_BIND_MODE = "Hold",
    TOGGLE_ESP_KEY = "None",
    UNLOAD_KEY = "K"
}

-- Global persistent input table
if not getgenv()._frontlinesKeysDown then
    getgenv()._frontlinesKeysDown = {}
    UserInputService.InputBegan:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            getgenv()._frontlinesKeysDown[input.KeyCode] = true
            getgenv()._frontlinesKeysDown[input.KeyCode.Name] = true
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            getgenv()._frontlinesKeysDown["MB1"] = true
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            getgenv()._frontlinesKeysDown["MB2"] = true
        elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
            getgenv()._frontlinesKeysDown["MB3"] = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            getgenv()._frontlinesKeysDown[input.KeyCode] = false
            getgenv()._frontlinesKeysDown[input.KeyCode.Name] = false
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            getgenv()._frontlinesKeysDown["MB1"] = false
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            getgenv()._frontlinesKeysDown["MB2"] = false
        elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
            getgenv()._frontlinesKeysDown["MB3"] = false
        end
    end)
end

function Config.isAimKeyHeld()
    local kb = (Options and Options.AimKeybind) or (getgenv and getgenv().Options and getgenv().Options.AimKeybind)
    if kb and kb.Value and kb.Value ~= "None" and kb.Value ~= "" then
        if kb.Mode == "Hold" and kb:GetState() == true then
            return true
        end
    end

    local key = (kb and kb.Value and kb.Value ~= "None" and kb.Value ~= "") and kb.Value or Config.TOGGLE_AIM_KEY
    if not key or key == "None" or key == "" then
        return true
    end

    local keysDown = getgenv()._frontlinesKeysDown or {}

    -- Mouse buttons
    if key == "MB1" or key == Enum.UserInputType.MouseButton1 then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or (keysDown["MB1"] == true)
    elseif key == "MB2" or key == Enum.UserInputType.MouseButton2 then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or (keysDown["MB2"] == true)
    elseif key == "MB3" or key == Enum.UserInputType.MouseButton3 then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) or (keysDown["MB3"] == true)
    end

    -- EnumItem KeyCode
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        return UserInputService:IsKeyDown(key) or (keysDown[key] == true) or (keysDown[key.Name] == true)
    end

    -- String key name
    if type(key) == "string" then
        local ok, kc = pcall(function() return Enum.KeyCode[key] end)
        if ok and kc and UserInputService:IsKeyDown(kc) then return true end
        if (keysDown[key] == true) or (ok and kc and keysDown[kc] == true) then return true end
    end

    return false
end

function Config.isSilentAimActive()
    if UserInputService:GetFocusedTextBox() then return false end
    if Config.SILENT_AIM_ENABLED == false then return false end

    local kb = (Options and Options.AimKeybind) or (getgenv and getgenv().Options and getgenv().Options.AimKeybind)
    local key = (kb and kb.Value and kb.Value ~= "None" and kb.Value ~= "") and kb.Value or Config.TOGGLE_AIM_KEY
    local hasKey = key and key ~= "None" and key ~= ""

    -- If no aim key is bound ([None]/backspace), aim is active when toggled on
    if not hasKey then
        return true
    end

    local mode = (kb and kb.Mode) or Config.AIM_BIND_MODE or "Toggle"
    if mode == "Hold" then
        return Config.isAimKeyHeld()
    end

    return true
end

function Config.save()
    if type(writefile) ~= "function" then return end
    ensureDirectory()

    local data = {}
    for key, val in pairs(DEFAULT_VALUES) do
        local current = Config[key]
        if typeof(current) == "EnumItem" then
            data[key] = current.Name
        elseif current == nil then
            data[key] = "None"
        else
            data[key] = current
        end
    end

    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

function Config.load()
    if type(readfile) ~= "function" then return end
    ensureDirectory()

    local paths = { CONFIG_FILE, "Frontlines/config.json" }
    local content = nil
    for _, p in ipairs(paths) do
        local success, c = pcall(readfile, p)
        if success and c and #c > 0 then
            content = c
            break
        end
    end

    if not content then return end

    local ok, parsed = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok or type(parsed) ~= "table" then return end

    for key, val in pairs(parsed) do
        if key == "TOGGLE_UI_KEY" or key == "TOGGLE_UI_KEY_ALT" or key == "TOGGLE_ESP_KEY" or key == "UNLOAD_KEY" then
            if val and val ~= "None" and Enum.KeyCode[val] then
                Config[key] = Enum.KeyCode[val]
            elseif val == "None" then
                Config[key] = nil
            end
        elseif key == "TOGGLE_AIM_KEY" then
            if val and val ~= "None" then
                Config[key] = val
            else
                Config[key] = "None"
            end
        elseif Config[key] ~= nil then
            Config[key] = val
        end
    end
end

function Config.reset()
    for key, val in pairs(DEFAULT_VALUES) do
        if key == "TOGGLE_UI_KEY" or key == "TOGGLE_UI_KEY_ALT" or key == "TOGGLE_ESP_KEY" or key == "UNLOAD_KEY" then
            if val and val ~= "None" and Enum.KeyCode[val] then
                Config[key] = Enum.KeyCode[val]
            else
                Config[key] = nil
            end
        elseif key == "TOGGLE_AIM_KEY" then
            Config[key] = "None"
        else
            Config[key] = val
        end
    end
end

return Config

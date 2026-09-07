-- frontlines suite

if _G.__frontlinesJanitor then pcall(_G.__frontlinesJanitor) _G.__frontlinesJanitor = nil end
if _G.__agScriptJanitor then pcall(_G.__agScriptJanitor) _G.__agScriptJanitor = nil end
if _G.combined_conn then pcall(function() _G.combined_conn:Disconnect() end) _G.combined_conn = nil end
if _G.combined_kill_conn then pcall(function() _G.combined_kill_conn:Disconnect() end) _G.combined_kill_conn = nil end
if _G.redirect_hb_conn then pcall(function() _G.redirect_hb_conn:Disconnect() end) _G.redirect_hb_conn = nil end
if _G.redirect_st_conn then pcall(function() _G.redirect_st_conn:Disconnect() end) _G.redirect_st_conn = nil end
if _G.skeleton_conn then pcall(function() _G.skeleton_conn:Disconnect() end) _G.skeleton_conn = nil end
if _G.skeleton_kill_conn then pcall(function() _G.skeleton_kill_conn:Disconnect() end) _G.skeleton_kill_conn = nil end

if _G.combined_drawings then
    for _, obj in pairs(_G.combined_drawings) do pcall(function() obj:Remove() end) end
    _G.combined_drawings = nil
end

if _G.skeleton_drawings then
    for _, obj in pairs(_G.skeleton_drawings) do pcall(function() obj:Remove() end) end
    _G.skeleton_drawings = nil
end

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera

local modules = {}
local function import(moduleName)
    if modules[moduleName] then return modules[moduleName] end

    if type(readfile) == "function" then
        local paths = {
            "SolutionZ_Frontlines/src/" .. moduleName .. ".lua",
            "Frontlines/src/" .. moduleName .. ".lua",
            "src/" .. moduleName .. ".lua",
            moduleName .. ".lua"
        }
        for _, path in ipairs(paths) do
            local ok, content = pcall(readfile, path)
            if ok and content and #content > 0 then
                local fn, loadErr = loadstring(content)
                if fn then
                    local res = fn()
                    modules[moduleName] = res
                    return res
                else
                    warn("[Frontlines] Error in " .. path .. ": " .. tostring(loadErr))
                end
            end
        end
    end

    if _G.__FrontlinesModules and _G.__FrontlinesModules[moduleName] then
        local res = _G.__FrontlinesModules[moduleName]()
        modules[moduleName] = res
        return res
    end

    local okHttp, remoteContent = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/euphonee/Seeto.SolutionZ-Frontlines/main/src/" .. moduleName .. ".lua")
    end)
    if okHttp and remoteContent and #remoteContent > 0 then
        local fn, loadErr = loadstring(remoteContent)
        if fn then
            local res = fn()
            modules[moduleName] = res
            return res
        end
    end

    error("[Frontlines] Failed to import: " .. tostring(moduleName))
end

local Config           = import("Config")
local Utils            = import("Utils")
local SkeletonRenderer = import("SkeletonRenderer")
local TargetEngine     = import("TargetEngine")
local ESPManager       = import("ESPManager")
local SilentAim        = import("SilentAim")
local BulletTracers    = import("BulletTracers")
local LinoriaLib       = import("LinoriaLib")
local UIManager        = import("UIManager")

Config.load()

TargetEngine.init(Config)
ESPManager.init(Config, Utils, SkeletonRenderer)
SilentAim.init(Config, Utils)
BulletTracers.init(Config, Utils)

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.NumSides = 64
fovCircle.Radius = Config.FOV_RADIUS or 400
fovCircle.Filled = false
fovCircle.Transparency = Config.FOV_CIRCLE_TRANSPARENCY or 0.4
fovCircle.Color = Config.FOV_CIRCLE_COLOR or Color3.fromRGB(255, 255, 255)
fovCircle.ZIndex = 1
fovCircle.Visible = Config.FOV_CIRCLE_ENABLED

local renderConn = nil
local keyConn = nil

local function cleanup()
    if renderConn then pcall(function() renderConn:Disconnect() end) end
    if keyConn then pcall(function() keyConn:Disconnect() end) end

    UIManager.cleanup()
    BulletTracers.cleanup()
    SilentAim.cleanup()
    ESPManager.cleanup(SkeletonRenderer)
    TargetEngine.cleanup()

    pcall(function() fovCircle:Remove() end)
    _G.__frontlinesJanitor = nil
    print("[Frontlines] unloaded")
end

_G.__frontlinesJanitor = cleanup

UIManager.init(Config, LinoriaLib, SilentAim, cleanup)

renderConn = RunService.RenderStepped:Connect(function(dt)
    local vpCenter = Camera.ViewportSize * 0.5
    fovCircle.Position = Vector2.new(vpCenter.X, vpCenter.Y)
    fovCircle.Radius = Config.FOV_RADIUS or 400
    fovCircle.Color = Config.FOV_CIRCLE_COLOR or Color3.fromRGB(255, 255, 255)
    fovCircle.Transparency = Config.FOV_CIRCLE_TRANSPARENCY or 0.4
    fovCircle.Visible = (Config.FOV_CIRCLE_ENABLED ~= false) and (Config.ESP_ENABLED ~= false)

    TargetEngine.update(Config, Utils)
    SilentAim.updateAttachments(Config, Utils)
    ESPManager.update(Config, Utils, SkeletonRenderer)
end)

keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if UserInputService:GetFocusedTextBox() then return end
    if LinoriaLib and LinoriaLib.IsPickingKey then return end
    if Config.UNLOAD_KEY and input.KeyCode == Config.UNLOAD_KEY then
        cleanup()
    end
end)

local banner = "Seeto.SolutionZ / Frontlines / " .. (Config.VERSION or "v1.0")
print(banner)
return banner

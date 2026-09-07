-- silent aim
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera

local SilentAim = {
    Initialized = false,
    CachedFireAttachments = {},
    OriginalCFrames = {},
    Connections = {}
}

function SilentAim.setZeroSpread(enabled)
    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if not fca or type(run_on_actor) ~= "function" then return end

    pcall(run_on_actor, fca, string.format([[
        _G.__zero_spread_enabled = %s

        for _, obj in ipairs(getgc(true)) do
            if type(obj) == 'table' and (rawget(obj, 'spread') ~= nil or rawget(obj, '__is_spread_proxy')) then
                if not rawget(obj, '__is_spread_proxy') then
                    rawset(obj, '__is_spread_proxy', true)
                    local proxyStore = { spread = rawget(obj, 'spread') or 0 }
                    rawset(obj, 'spread', nil)
                    local mt = {
                        __index = function(t, k)
                            if k == 'spread' then
                                if _G.__zero_spread_enabled ~= false then
                                    return 0
                                else
                                    return rawget(proxyStore, 'spread') or 0
                                end
                            end
                            return rawget(proxyStore, k)
                        end,
                        __newindex = function(t, k, v)
                            if k == 'spread' then
                                rawset(proxyStore, 'spread', v)
                            else
                                rawset(proxyStore, k, v)
                            end
                        end
                    }
                    setmetatable(obj, mt)
                end
            end
        end
    ]], tostring(enabled ~= false)))
end

function SilentAim.setNoRecoil(enabled)
    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if not fca or type(run_on_actor) ~= "function" then return end

    pcall(run_on_actor, fca, string.format([[
        _G.__no_recoil_enabled = %s

        -- Restore any previously zeroed recoil_params tables
        if _G.__recoil_params_tracked then
            for _, entry in ipairs(_G.__recoil_params_tracked) do
                entry.tbl.attitude_impulse_1 = entry.attitude_impulse_1
                entry.tbl.attitude_impulse_2 = entry.attitude_impulse_2
                entry.tbl.cam_impulse_1 = entry.cam_impulse_1
                entry.tbl.cam_impulse_2 = entry.cam_impulse_2
                entry.tbl.cam_angular_impulse_1 = entry.cam_angular_impulse_1
                entry.tbl.cam_angular_impulse_2 = entry.cam_angular_impulse_2
            end
        end
        if _G.__sway_params_tracked then
            for _, entry in ipairs(_G.__sway_params_tracked) do
                entry.tbl.max_rot_x = entry.max_rot_x
                entry.tbl.max_rot_y = entry.max_rot_y
            end
        end

        local function attachRecoilProxy(obj)
            if type(obj) == 'table' and not rawget(obj, '__is_recoil_proxy') then
                rawset(obj, '__is_recoil_proxy', true)
                local proxyStore = { attitude_delta = rawget(obj, 'attitude_delta') or Vector3.new() }
                rawset(obj, 'attitude_delta', nil)
                local mt = {
                    __index = function(t, k)
                        if k == 'attitude_delta' then
                            if _G.__no_recoil_enabled ~= false then
                                return Vector3.new(0, 0, 0)
                            else
                                return rawget(proxyStore, 'attitude_delta') or Vector3.new(0, 0, 0)
                            end
                        end
                        return rawget(proxyStore, k)
                    end,
                    __newindex = function(t, k, v)
                        if k == 'attitude_delta' then
                            rawset(proxyStore, 'attitude_delta', v)
                        else
                            rawset(proxyStore, k, v)
                        end
                    end
                }
                setmetatable(obj, mt)
            end
        end

        for _, obj in ipairs(getgc(true)) do
            if type(obj) == 'table' and (rawget(obj, 'attitude_delta') ~= nil or rawget(obj, '__is_recoil_proxy')) then
                attachRecoilProxy(obj)
            elseif type(obj) == 'function' then
                local info = debug.getinfo(obj)
                if info and info.source and (info.source:find('soldier_movement') or info.source:find('recoil_anim')) then
                    local upvals = debug.getupvalues(obj)
                    for _, v in pairs(upvals) do
                        if type(v) == 'table' and (rawget(v, 'attitude_delta') ~= nil or rawget(v, '__is_recoil_proxy')) then
                            attachRecoilProxy(v)
                        end
                    end
                end
            end
        end
    ]], tostring(enabled ~= false)))
end

function SilentAim.refreshCachedAttachments(Utils)
    local atts = {}
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if Utils.isLocalFireAttachment(inst) then
            table.insert(atts, inst)
        end
    end
    SilentAim.CachedFireAttachments = atts
end

function SilentAim.restoreAttachments()
    for inst, origCf in pairs(SilentAim.OriginalCFrames) do
        if inst and inst.Parent then
            pcall(function() inst.CFrame = origCf end)
        end
    end
    SilentAim.OriginalCFrames = {}
end

function SilentAim.init(Config, Utils)
    if SilentAim.Initialized then return end
    SilentAim.Initialized = true

    SilentAim.refreshCachedAttachments(Utils)

    local descConn = Workspace.DescendantAdded:Connect(function(inst)
        if Utils.isLocalFireAttachment(inst) then
            table.insert(SilentAim.CachedFireAttachments, inst)
        end
    end)
    table.insert(SilentAim.Connections, descConn)

    SilentAim.setZeroSpread(Config.ZERO_SPREAD_ENABLED ~= false)
    SilentAim.setNoRecoil(Config.NO_RECOIL_ENABLED ~= false)
end

function SilentAim.updateAttachments(Config, Utils)
    local isAimActive = false
    if type(Config.isSilentAimActive) == "function" then
        isAimActive = (Config.isSilentAimActive() == true)
    else
        isAimActive = (Config.SILENT_AIM_ENABLED ~= false)
    end

    if not isAimActive then
        if next(SilentAim.OriginalCFrames) ~= nil then
            SilentAim.restoreAttachments()
        end
        return
    end

    local camPos = Camera.CFrame.Position
    local camLook = Camera.CFrame.LookVector
    local targetHeadPos = Config.CurrentTargetHeadPos
    local atts = SilentAim.CachedFireAttachments

    for i = #atts, 1, -1 do
        local inst = atts[i]
        if not inst or not inst.Parent then
            table.remove(atts, i)
            SilentAim.OriginalCFrames[inst] = nil
        else
            local parent = inst.Parent
            if parent:IsA("BasePart") then
                local distFromCam = (parent.Position - camPos).Magnitude
                if distFromCam < 8 then
                    if not SilentAim.OriginalCFrames[inst] then
                        SilentAim.OriginalCFrames[inst] = inst.CFrame
                    end

                    if targetHeadPos then
                        local naturalWorldPos = inst.WorldPosition
                        local targetWorld = Utils.getLookMatrix(naturalWorldPos, targetHeadPos)
                        inst.CFrame = parent.CFrame:ToObjectSpace(targetWorld)
                    elseif Config.ZERO_SPREAD_ENABLED ~= false then
                        local naturalWorldPos = inst.WorldPosition
                        local aimTarget = naturalWorldPos + camLook * 1000
                        local targetWorld = Utils.getLookMatrix(naturalWorldPos, aimTarget)
                        inst.CFrame = parent.CFrame:ToObjectSpace(targetWorld)
                    else
                        local origCf = SilentAim.OriginalCFrames[inst]
                        if origCf then
                            inst.CFrame = origCf
                        end
                    end
                end
            end
        end
    end
end

function SilentAim.cleanup()
    SilentAim.restoreAttachments()
    SilentAim.setZeroSpread(false)
    SilentAim.setNoRecoil(false)
    for _, c in ipairs(SilentAim.Connections) do
        pcall(function() c:Disconnect() end)
    end
    SilentAim.Connections = {}
    SilentAim.CachedFireAttachments = {}
    SilentAim.OriginalCFrames = {}
    SilentAim.Initialized = false
end

return SilentAim

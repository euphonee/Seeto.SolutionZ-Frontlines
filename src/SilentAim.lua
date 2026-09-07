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
            if type(obj) == 'table' and rawget(obj, 'spread') ~= nil and not rawget(obj, '__is_spread_proxy') then
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
    ]], tostring(enabled ~= false)))
end

function SilentAim.setNoRecoil(enabled)
    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if not fca or type(run_on_actor) ~= "function" then return end

    pcall(run_on_actor, fca, string.format([[
        _G.__no_recoil_enabled = %s

        if not _G.__recoil_proxy_installed then
            local target = nil
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == 'table' and (rawget(obj, 'attitude_delta') ~= nil or rawget(obj, '__is_recoil_proxy') == true) then
                    target = obj
                    break
                end
            end

            if target then
                _G.__recoil_proxy_installed = true
                rawset(target, 'attitude_delta', nil)
                rawset(target, '__is_recoil_proxy', true)
                local proxyStore = { attitude_delta = Vector3.new() }
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
                setmetatable(target, mt)
            end
        end

        if not _G.__recoil_params_tracked or #_G.__recoil_params_tracked == 0 then
            _G.__recoil_params_tracked = {}
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == 'table' and rawget(obj, 'attitude_impulse_1') ~= nil then
                    table.insert(_G.__recoil_params_tracked, {
                        tbl = obj,
                        attitude_impulse_1 = obj.attitude_impulse_1,
                        attitude_impulse_2 = obj.attitude_impulse_2,
                        cam_impulse_1 = obj.cam_impulse_1,
                        cam_impulse_2 = obj.cam_impulse_2,
                        cam_angular_impulse_1 = obj.cam_angular_impulse_1,
                        cam_angular_impulse_2 = obj.cam_angular_impulse_2,
                    })
                end
            end
        end

        if not _G.__sway_params_tracked or #_G.__sway_params_tracked == 0 then
            _G.__sway_params_tracked = {}
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == 'table' and rawget(obj, 'aim_sway_params') ~= nil then
                    local sp = obj.aim_sway_params
                    table.insert(_G.__sway_params_tracked, {
                        tbl = sp,
                        max_rot_x = sp.max_rot_x,
                        max_rot_y = sp.max_rot_y
                    })
                end
            end
        end

        if _G.__recoil_params_tracked then
            local zeroVec = Vector3.new(0, 0, 0)
            for _, entry in ipairs(_G.__recoil_params_tracked) do
                local t = entry.tbl
                if _G.__no_recoil_enabled ~= false then
                    t.attitude_impulse_1 = zeroVec
                    t.attitude_impulse_2 = zeroVec
                    t.cam_impulse_1 = zeroVec
                    t.cam_impulse_2 = zeroVec
                    t.cam_angular_impulse_1 = zeroVec
                    t.cam_angular_impulse_2 = zeroVec
                else
                    t.attitude_impulse_1 = entry.attitude_impulse_1
                    t.attitude_impulse_2 = entry.attitude_impulse_2
                    t.cam_impulse_1 = entry.cam_impulse_1
                    t.cam_impulse_2 = entry.cam_impulse_2
                    t.cam_angular_impulse_1 = entry.cam_angular_impulse_1
                    t.cam_angular_impulse_2 = entry.cam_angular_impulse_2
                end
            end
        end

        if _G.__sway_params_tracked then
            for _, entry in ipairs(_G.__sway_params_tracked) do
                if _G.__no_recoil_enabled ~= false then
                    entry.tbl.max_rot_x = 0
                    entry.tbl.max_rot_y = 0
                else
                    entry.tbl.max_rot_x = entry.max_rot_x
                    entry.tbl.max_rot_y = entry.max_rot_y
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

                    local naturalWorldPos = inst.WorldPosition
                    local aimTarget = targetHeadPos or (naturalWorldPos + camLook * 1000)
                    local targetWorld = Utils.getLookMatrix(naturalWorldPos, aimTarget)
                    inst.CFrame = parent.CFrame:ToObjectSpace(targetWorld)
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

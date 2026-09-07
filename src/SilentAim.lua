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
        local RunService = game:GetService("RunService")
        local isEnabled = %s
        _G.__no_recoil_enabled = isEnabled

        local act = game.Players.LocalPlayer.PlayerScripts:FindFirstChild("frontlines_client_actor")
        local main = act and act:FindFirstChild("frontlines_main")
        local env = main and getsenv(main)
        local G = env and env._G or _G

        -- 1. Track and zero all recoil_params tables in GC
        if not _G.__recoil_params_tracked then
            _G.__recoil_params_tracked = {}
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == 'table' and rawget(obj, 'cam_angular_impulse_1') ~= nil then
                    table.insert(_G.__recoil_params_tracked, {
                        tbl = obj,
                        attitude_impulse_1 = rawget(obj, 'attitude_impulse_1') or Vector3.new(),
                        attitude_impulse_2 = rawget(obj, 'attitude_impulse_2') or Vector3.new(),
                        cam_impulse_1 = rawget(obj, 'cam_impulse_1') or Vector3.new(),
                        cam_impulse_2 = rawget(obj, 'cam_impulse_2') or Vector3.new(),
                        cam_angular_impulse_1 = rawget(obj, 'cam_angular_impulse_1') or Vector3.new(),
                        cam_angular_impulse_2 = rawget(obj, 'cam_angular_impulse_2') or Vector3.new(),
                        attitude_cdho_constant = rawget(obj, 'attitude_cdho_constant') or 0
                    })
                end
            end
        end

        -- 2. Track and zero all sway_params tables in GC
        if not _G.__sway_params_tracked then
            _G.__sway_params_tracked = {}
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == 'table' and rawget(obj, 'max_rot_x') ~= nil and rawget(obj, 'max_rot_y') ~= nil then
                    table.insert(_G.__sway_params_tracked, {
                        tbl = obj,
                        max_rot_x = rawget(obj, 'max_rot_x') or 0,
                        max_rot_y = rawget(obj, 'max_rot_y') or 0
                    })
                end
            end
        end

        if isEnabled then
            for _, entry in ipairs(_G.__recoil_params_tracked) do
                entry.tbl.attitude_impulse_1 = Vector3.new(0, 0, 0)
                entry.tbl.attitude_impulse_2 = Vector3.new(0, 0, 0)
                entry.tbl.cam_impulse_1 = Vector3.new(0, 0, 0)
                entry.tbl.cam_impulse_2 = Vector3.new(0, 0, 0)
                entry.tbl.cam_angular_impulse_1 = Vector3.new(0, 0, 0)
                entry.tbl.cam_angular_impulse_2 = Vector3.new(0, 0, 0)
                entry.tbl.attitude_cdho_constant = 0
            end
            for _, entry in ipairs(_G.__sway_params_tracked) do
                entry.tbl.max_rot_x = 0
                entry.tbl.max_rot_y = 0
            end
        else
            for _, entry in ipairs(_G.__recoil_params_tracked) do
                entry.tbl.attitude_impulse_1 = entry.attitude_impulse_1
                entry.tbl.attitude_impulse_2 = entry.attitude_impulse_2
                entry.tbl.cam_impulse_1 = entry.cam_impulse_1
                entry.tbl.cam_impulse_2 = entry.cam_impulse_2
                entry.tbl.cam_angular_impulse_1 = entry.cam_angular_impulse_1
                entry.tbl.cam_angular_impulse_2 = entry.cam_angular_impulse_2
                entry.tbl.attitude_cdho_constant = entry.attitude_cdho_constant
            end
            for _, entry in ipairs(_G.__sway_params_tracked) do
                entry.tbl.max_rot_x = entry.max_rot_x
                entry.tbl.max_rot_y = entry.max_rot_y
            end
        end

        -- 3. Proxy attitude_delta on any recoil tables in GC
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
            end
        end

        -- 4. Lock Camera Joint in RenderStepped (zeroes any procedural rotational kick / shake)
        if not _G.__solutionzNoRecoilConn then
            _G.__solutionzNoRecoilConn = RunService.RenderStepped:Connect(function()
                if _G.__no_recoil_enabled ~= false then
                    local cam_joint = G.globals and G.globals.fpv_sol_joint_trs and G.globals.fpv_sol_joint_trs[G.fpv_sol_joint_t.CAMERA]
                    if cam_joint then
                        cam_joint[1] = Vector3.new(0, 0, 0)
                        cam_joint[2] = 1
                        cam_joint[3] = 0
                        cam_joint[4] = 0
                        cam_joint[5] = 0
                    end
                    if G.globals and G.globals.fpv_sol_recoil then
                        G.globals.fpv_sol_recoil.attitude_delta = Vector3.new(0, 0, 0)
                    end
                end
            end)
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

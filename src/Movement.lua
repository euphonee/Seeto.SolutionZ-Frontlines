-- movement
local Movement = {
    Initialized = false,
    CurrentSpeedMultiplier = 1.0,
    SpeedEnabled = false,
    FlyEnabled = false,
    FlySpeed = 50,
    NoclipEnabled = false
}

function Movement.setSpeed(enabled, percent)
    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if not fca or type(run_on_actor) ~= "function" then return end

    local p = tonumber(percent) or 100
    local targetMult = enabled and (1 + (p / 100)) or 1.0
    Movement.CurrentSpeedMultiplier = targetMult
    Movement.SpeedEnabled = enabled

    pcall(run_on_actor, fca, string.format([[
        local RunService = game:GetService("RunService")
        local targetMult = %f
        local isEnabled = %s

        _G.__speed_boost_enabled = isEnabled
        _G.__speed_boost_multiplier = targetMult

        local actor = game.Players.LocalPlayer.PlayerScripts:FindFirstChild("frontlines_client_actor")
        local mainScript = actor and actor:FindFirstChild("frontlines_main")
        local env = mainScript and getsenv and getsenv(mainScript)
        local G = env and env._G or _G

        if G.globals and G.globals.fpv_sol_multipliers then
            G.globals.fpv_sol_multipliers.movement = targetMult
        end

        if not _G.__solutionzSpeedConn then
            _G.__solutionzSpeedConn = RunService.RenderStepped:Connect(function()
                local desired = _G.__speed_boost_enabled and _G.__speed_boost_multiplier or 1.0
                if G.globals and G.globals.fpv_sol_multipliers then
                    if G.globals.fpv_sol_multipliers.movement ~= desired then
                        G.globals.fpv_sol_multipliers.movement = desired
                    end
                else
                    for _, obj in ipairs(getgc(true)) do
                        if type(obj) == 'table' and rawget(obj, 'movement') and rawget(obj, 'ads') and rawget(obj, 'reload') then
                            if obj.movement ~= desired then
                                obj.movement = desired
                            end
                            break
                        end
                    end
                end
            end)
        end
    ]], targetMult, tostring(enabled ~= false)))
end

function Movement.setFly(enabled, speed)
    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if not fca or type(run_on_actor) ~= "function" then return end

    local spd = tonumber(speed) or 50
    Movement.FlyEnabled = enabled
    Movement.FlySpeed = spd

    pcall(run_on_actor, fca, string.format([[
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")
        local Workspace = game:GetService("Workspace")

        _G.__fly_enabled = %s
        _G.__fly_speed = %f
        _G.__fly_pos = nil
        _G.__last_fly_root = nil
        _G.__last_fly_parent = nil
        _G.__spawn_grace_until = os.clock() + 0.35

        local actor = game.Players.LocalPlayer.PlayerScripts:FindFirstChild("frontlines_client_actor")
        local mainScript = actor and actor:FindFirstChild("frontlines_main")
        local env = mainScript and getsenv and getsenv(mainScript)
        local G = env and env._G or _G

        -- Hook spawn and death events to prevent stale position snaps on respawn
        if G.append_exe_set and G.exe_set_t and not _G.__solutionzFlyHooksInstalled then
            _G.__solutionzFlyHooksInstalled = true
            if G.exe_set_t.FPV_SOL_SPAWN then
                pcall(G.append_exe_set, G.exe_set_t.FPV_SOL_SPAWN, "SOLUTIONZ_FLY_SPAWN", G.DEFAULT_EXE_PRIO or 100, function()
                    _G.__fly_pos = nil
                    _G.__last_fly_root = nil
                    _G.__last_fly_parent = nil
                    _G.__spawn_grace_until = os.clock() + 0.5
                end)
            end
            if G.exe_set_t.FPV_SOL_DESPAWN then
                pcall(G.append_exe_set, G.exe_set_t.FPV_SOL_DESPAWN, "SOLUTIONZ_FLY_DESPAWN", G.DEFAULT_EXE_PRIO or 100, function()
                    _G.__fly_pos = nil
                    _G.__last_fly_root = nil
                    _G.__last_fly_parent = nil
                end)
            end
            if G.exe_set_t.FPV_SOL_DEATH then
                pcall(G.append_exe_set, G.exe_set_t.FPV_SOL_DEATH, "SOLUTIONZ_FLY_DEATH", G.DEFAULT_EXE_PRIO or 100, function()
                    _G.__fly_pos = nil
                    _G.__last_fly_root = nil
                    _G.__last_fly_parent = nil
                end)
            end
        end

        if not _G.__solutionzFlyConn then
            _G.__solutionzFlyConn = RunService.RenderStepped:Connect(function(dt)
                if not _G.__fly_enabled then
                    _G.__fly_pos = nil
                    _G.__last_fly_root = nil
                    return
                end

                local instances = G.globals and G.globals.fpv_sol_instances
                local root = instances and instances.root
                local hum = instances and instances.humanoid

                if not root or not root.Parent then
                    local sol = Workspace:FindFirstChild("soldier_model")
                    root = sol and sol:FindFirstChild("HumanoidRootPart")
                    hum = sol and sol:FindFirstChild("Humanoid")
                end
                if not root or not root.Parent then
                    _G.__fly_pos = nil
                    _G.__last_fly_root = nil
                    return
                end

                -- Verify character is alive
                if hum and hum.Health <= 0 then
                    _G.__fly_pos = nil
                    _G.__last_fly_root = nil
                    return
                end

                -- Detect new spawn / root instance change
                if root ~= _G.__last_fly_root or root.Parent ~= _G.__last_fly_parent or not _G.__fly_pos then
                    _G.__fly_pos = root.Position
                    _G.__last_fly_root = root
                    _G.__last_fly_parent = root.Parent
                    _G.__spawn_grace_until = os.clock() + 0.35
                    return
                end

                -- If position delta is unreasonably large (e.g. server teleport / respawn gap), resync smoothly
                if (root.Position - _G.__fly_pos).Magnitude > 35 then
                    _G.__fly_pos = root.Position
                    return
                end

                -- Grace period check on initial spawn
                if os.clock() < (_G.__spawn_grace_until or 0) then
                    _G.__fly_pos = root.Position
                    return
                end

                local cam = Workspace.CurrentCamera
                if not cam then return end

                local moveDir = Vector3.new()

                -- Ignore flight WASD input if typing in chat/textbox or picking a keybind
                if not UserInputService:GetFocusedTextBox() and not _G.__ui_key_sink_active then
                    -- Camera-directional WASD flight
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                        moveDir = moveDir + cam.CFrame.LookVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                        moveDir = moveDir - cam.CFrame.LookVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                        moveDir = moveDir + cam.CFrame.RightVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                        moveDir = moveDir - cam.CFrame.RightVector
                    end

                    -- Rise: LeftShift or Space
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        moveDir = moveDir + Vector3.new(0, 1, 0)
                    end

                    -- Descend: LeftControl or C
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
                        moveDir = moveDir - Vector3.new(0, 1, 0)
                    end
                end

                local flySpeed = _G.__fly_speed or 50
                if moveDir.Magnitude > 0.001 then
                    _G.__fly_pos = _G.__fly_pos + moveDir.Unit * (flySpeed * dt)
                end

                -- Absolute position lock: completely eliminates downward gravity drift while hovering
                local currentRot = root.CFrame - root.CFrame.Position
                root.CFrame = CFrame.new(_G.__fly_pos) * currentRot
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
        end
    ]], tostring(enabled ~= false), spd))
end

function Movement.setNoclip(enabled)
    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if not fca or type(run_on_actor) ~= "function" then return end

    Movement.NoclipEnabled = enabled

    pcall(run_on_actor, fca, string.format([[
        local RunService = game:GetService("RunService")
        local Workspace = game:GetService("Workspace")
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer

        _G.__noclip_enabled = %s

        local actor = LocalPlayer.PlayerScripts:FindFirstChild("frontlines_client_actor")
        local mainScript = actor and actor:FindFirstChild("frontlines_main")
        local env = mainScript and getsenv and getsenv(mainScript)
        local G = env and env._G or _G

        if not _G.__solutionzNoclipConn then
            _G.__solutionzNoclipConn = RunService.Stepped:Connect(function()
                if not _G.__noclip_enabled then return end

                -- Disable collision on soldier_model
                local root = G.globals and G.globals.fpv_sol_instances and G.globals.fpv_sol_instances.root
                local solModel = root and root.Parent or Workspace:FindFirstChild("soldier_model")
                if solModel then
                    for _, part in ipairs(solModel:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end

                -- Disable collision on LocalPlayer Character
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    ]], tostring(enabled ~= false)))
end

function Movement.init(Config)
    if Movement.Initialized then return end
    Movement.Initialized = true
    Movement.setSpeed(Config.SPEED_BOOST_ENABLED == true, Config.SPEED_BOOST_PERCENT or 100)
    Movement.setFly(Config.FLY_ENABLED == true, Config.FLY_SPEED or 50)
    Movement.setNoclip(Config.NOCLIP_ENABLED == true)
end

function Movement.cleanup()
    Movement.setSpeed(false, 0)
    Movement.setFly(false, 0)
    Movement.setNoclip(false)
    local pscripts = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if fca and type(run_on_actor) == "function" then
        pcall(run_on_actor, fca, [[
            if _G.__solutionzSpeedConn then
                pcall(function() _G.__solutionzSpeedConn:Disconnect() end)
                _G.__solutionzSpeedConn = nil
            end
            if _G.__solutionzFlyConn then
                pcall(function() _G.__solutionzFlyConn:Disconnect() end)
                _G.__solutionzFlyConn = nil
            end
            if _G.__solutionzNoclipConn then
                pcall(function() _G.__solutionzNoclipConn:Disconnect() end)
                _G.__solutionzNoclipConn = nil
            end
            _G.__speed_boost_enabled = false
            _G.__speed_boost_multiplier = 1.0
            _G.__fly_enabled = false
            _G.__fly_speed = 50
            _G.__fly_pos = nil
            _G.__noclip_enabled = false

            local actor = game.Players.LocalPlayer.PlayerScripts:FindFirstChild("frontlines_client_actor")
            local mainScript = actor and actor:FindFirstChild("frontlines_main")
            local env = mainScript and getsenv and getsenv(mainScript)
            local G = env and env._G or _G
            if G.globals and G.globals.fpv_sol_multipliers then
                G.globals.fpv_sol_multipliers.movement = 1.0
            end
        ]])
    end
    Movement.Initialized = false
end

return Movement

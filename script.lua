steam_ids = {}
peer_ids = {}
vehicleGroups = {}

gameSettings = {
	teleport_vehicle = false,
	cleanup_vehicle = false
}

function onTick() -- Keep those two settings off to 100% prevent vehicle stealing.
	for name, setting in pairs(gameSettings) do
		--server.setGameSetting(name, setting)
	end
end


function onPlayerJoin(steam_id, name, peer_id, admin, auth)
    server.announce("[Server]", name .. " joined the game")
	server.addAuth(peer_id)
    steam_ids[peer_id] = steam_id
    peer_ids[steam_id] = peer_id
end

function onPlayerLeave(steam_id, name, peer_id, admin, auth)
    server.announce("[Server]", name .. " left the game")

    -- Despawn all owned vehicle Groups
    for group_id, group in pairs(vehicleGroups) do
        if group.owner == peer_id then
            server.despawnVehicleGroup(group_id, true)
            -- Remove group_id from vehicleGroups
            vehicleGroups[group_id] = nil
        end
    end

    steam_ids[peer_id] = nil
    peer_ids[steam_id] = nil
end

function onVehicleDespawn(vehicle_id, peer_id)
	if (peer_id == -1) then return end -- Ignore vehicles spawned by the server
    -- Check if vehicle_id is in vehicleGroups, if so, remove the vehicle_id from the group
    for group_id, group in pairs(vehicleGroups) do
        for i, group_vehicle_id in ipairs(group.vehicleIds) do
            if group_vehicle_id == vehicle_id then
                table.remove(group.vehicleIds, i)
                break -- Break out of the loop once the vehicle_id is found and removed
            end
        end
    end
end

function onGroupSpawn(group_id, peer_id, x, y, z)
server.announce(group_id, x .. "," .. y .. "," .. z)
	if (peer_id == -1) then return end -- Ignore vehicles spawned by the server
    vehicleGroups[group_id] = { owner = peer_id, vehicleIds = {} }
    local vehicle_ids = server.getVehicleGroup(group_id)
    for _, vehicle_id in ipairs(vehicle_ids) do
        table.insert(vehicleGroups[group_id].vehicleIds, vehicle_id)
    end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, _, group_id)
	if (peer_id == -1) then return end -- Ignore vehicles spawned by the server
    server.setVehicleTooltip(vehicle_id,
        "Owner: " .. peer_id .. "\nGroup ID: " .. group_id ..
        "\nVehicle ID:" .. vehicle_id)
    server.setVehicleEditable(vehicle_id, false) -- Lock vehicle
end

function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, command, ...)
    args = { ... }

if (command == "?tp") then
		server.setPlayerPos(user_peer_id, matrix.translation(args[1], args[2], args[3]))
	end
    if (command == "?c") then
        -- Check if a specific peer ID is specified in args[1]
        local target_peer_id = tonumber(args[1])

        if target_peer_id and is_admin then
			-- Announce despawned vehicles
            local vehicleCount = 0
            local groupCount = 0
            for group_id, group in pairs(vehicleGroups) do
                groupCount = groupCount + 1
                vehicleCount = vehicleCount + #group.vehicleIds
            end
            -- Admin can despawn the vehicles of the specified user
            for group_id, group in pairs(vehicleGroups) do
                if group.owner == target_peer_id then
                    server.despawnVehicleGroup(group_id, true)
                    vehicleGroups[group_id] = nil
                end
            end

            server.announce("[VM]",
                "Despawned " .. vehicleCount .. " vehicles in " ..
                groupCount .. " groups owned by " ..
                target_peer_id, user_peer_id)
        else
            -- Announce despawned vehicles
            local vehicleCount = 0
            local groupCount = 0
            for group_id, group in pairs(vehicleGroups) do
                groupCount = groupCount + 1
                vehicleCount = vehicleCount + #group.vehicleIds
            end
			-- Normal user can only despawn their own vehicles
            for group_id, group in pairs(vehicleGroups) do
                if group.owner == user_peer_id then
                    server.despawnVehicleGroup(group_id, true)
                    vehicleGroups[group_id] = nil
                end
            end
            server.announce("[VM]", "Despawned " .. vehicleCount ..
                " vehicles in " .. groupCount .. " groups",
                user_peer_id)
        end
    elseif (command == "?dg") then
        -- Check if the user is an admin and can bypass ownership checks
        if not is_admin then
            if tonumber(args[1]) ~= nil and vehicleGroups[tonumber(args[1])] ~=
                nil and vehicleGroups[tonumber(args[1])].owner == user_peer_id then
                vehicleCount = #vehicleGroups[tonumber(args[1])].vehicleIds
                server.despawnVehicleGroup(tonumber(args[1]), true)
                vehicleGroups[tonumber(args[1])] = nil
                server.announce("[VM]", "Despawned " .. vehicleCount ..
                    " vehicles in group " .. args[1],
                    user_peer_id)
            end
        else
            -- Admin can despawn any group
            if tonumber(args[1]) ~= nil and vehicleGroups[tonumber(args[1])] ~=
                nil then
                vehicleCount = #vehicleGroups[tonumber(args[1])].vehicleIds
                server.despawnVehicleGroup(tonumber(args[1]), true)
                vehicleGroups[tonumber(args[1])] = nil
                server.announce("[VM]", "Despawned " .. vehicleCount ..
                    " vehicles in group " .. args[1],
                    user_peer_id)
            end
        end
    elseif (command == "?dv") then
        -- Check if the user is an admin and can bypass ownership checks
        if not is_admin then
            -- Check if args[1] is a number, and if they own that vehicle
            local target_vehicle_id = tonumber(args[1])
            if target_vehicle_id then
                for group_id, group in pairs(vehicleGroups) do
                    for i, vehicle_id in ipairs(group.vehicleIds) do
                        if vehicle_id == target_vehicle_id and group.owner ==
                            user_peer_id then
                            server.despawnVehicle(vehicle_id, true)
                            server.announce("[VM]",
                                "Despawned vehicle " .. args[1],
                                user_peer_id)
                            return -- Exit the function after despawning the vehicle
                        end
                    end
                end
            end

            -- If the function hasn't returned, the user does not own the specified vehicle
            server.announce("[VM]", "You do not own the specified vehicle.",
                user_peer_id)
        else
            -- Admin can despawn any vehicle
            if tonumber(args[1]) ~= nil then
                for group_id, group in pairs(vehicleGroups) do
                    for i, vehicle_id in ipairs(group.vehicleIds) do
                        if vehicle_id == tonumber(args[1]) then
                            server.despawnVehicle(vehicle_id, true)
                            server.announce("[VM]",
                                "Despawned vehicle " .. args[1],
                                user_peer_id)
                            return -- Exit the function after despawning the vehicle
                        end
                    end
                end
            end

            -- If the function hasn't returned, the specified vehicle does not exist
            server.announce("[VM]", "Specified vehicle not found.", user_peer_id)
        end
    end
end

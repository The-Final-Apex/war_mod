-- Define the crate node
minetest.register_node("war_mod:supply_crate", {
    description = "Supply Crate",
    tiles = {"crate_top.png", "crate_bottom.png", "crate_side.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 1},
    sounds = default.node_sound_wood_defaults(),
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        -- Give the player some items when they open the crate
        local inv = player:get_inventory()
        inv:add_item("main", "default:sword_steel")
        inv:add_item("main", "guns4d:ammo")
        inv:add_item("main", "default:apple 10") -- Some basic supplies too

        -- Remove the crate after it's opened
        minetest.remove_node(pos)
        minetest.chat_send_player(player:get_player_name(), "You've opened the supply crate!")
    end,
})

-- Function to spawn the crate in the sky and make it fall
local function drop_supply_crate(pos)
    -- Define a position high in the sky (200 units above the player's position)
    local sky_pos = {x = pos.x, y = pos.y + 100, z = pos.z}

    -- Create the crate entity at the sky position
    local crate_entity = minetest.add_entity(sky_pos, "war_mod:supply_crate_entity")
    if crate_entity then
        crate_entity:set_velocity({x = 0, y = -15, z = 0}) -- Increased falling speed
        crate_entity:set_acceleration({x = 0, y = -40, z = 0}) -- Increased acceleration downwards
        crate_entity:get_luaentity().falling_timer = 5 -- Set a countdown for falling
    end
end

-- Crate falling entity definition
minetest.register_entity("war_mod:supply_crate_entity", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        visual = "wielditem",
        visual_size = {x = 0.67, y = 0.67},
        textures = {"war_mod:supply_crate"},
        light_source = 14, -- Set light level (0 to 14)
    },
    on_step = function(self, dtime)
        -- Initialize the falling_timer if it doesn't exist
        if not self.falling_timer then
            self.falling_timer = 5 -- Initialize timer
        end
        
        local pos = self.object:get_pos()
        local below_pos = {x = pos.x, y = pos.y - 1, z = pos.z}
        local below_node = minetest.get_node(below_pos)

        -- Countdown timer for falling
        self.falling_timer = self.falling_timer - dtime
        if self.falling_timer > 0 then
            -- Emit light while falling
        elseif below_node.name ~= "air" then
            -- Create heavy smoke effect with varied directions
            for i = 1, 100 do -- Increase the amount of smoke
                minetest.add_particlespawner({
                    amount = 20,
                    time = 0.5,
                    minpos = {x = pos.x - 1, y = pos.y, z = pos.z - 1},
                    maxpos = {x = pos.x + 1, y = pos.y + 1, z = pos.z + 1},
                    minvel = {x = -2, y = 5, z = -2},
                    maxvel = {x = 2, y = 8, z = 2},
                    minacc = {x = -3, y = -1, z = -3}, -- Spread smoke in different directions
                    maxacc = {x = 3, y = -2, z = 3},
                    minexptime = 1,
                    maxexptime = 2,
                    minsize = 5,
                    maxsize = 10,
                    texture = "tnt_smoke.png", -- Ensure this texture exists
                })
            end

            -- Create landing particles effect
            minetest.add_particlespawner({
                amount = 50,
                time = 0.5, -- Duration of the particles
                minpos = {x = pos.x - 1, y = pos.y, z = pos.z - 1},
                maxpos = {x = pos.x + 1, y = pos.y + 1, z = pos.z + 1},
                minvel = {x = -2, y = 5, z = -2},
                maxvel = {x = 2, y = 8, z = 2},
                minacc = {x = -1, y = -2, z = -1},
                maxacc = {x = 1, y = -5, z = 1},
                minexptime = 0.5,
                maxexptime = 1,
                minsize = 1,
                maxsize = 3,
                texture = "landing_particle.png", -- Make sure this texture exists
            })

            -- Check for players below and kill them if the crate lands on them
            local players = minetest.get_connected_players()
            for _, player in ipairs(players) do
                local player_pos = player:get_pos()
                if player_pos.y < pos.y and player_pos.y > pos.y - 1 and
                   player_pos.x >= pos.x - 0.5 and player_pos.x <= pos.x + 0.5 and
                   player_pos.z >= pos.z - 0.5 and player_pos.z <= pos.z + 0.5 then
                    player:set_hp(0) -- Kill the player
                    minetest.chat_send_player(player:get_player_name(), "You were crushed by a supply crate!")
                end
            end

            -- Set the crate node and destroy the block below
            minetest.set_node(below_pos, {name = "war_mod:supply_crate"})
            self.object:remove() -- Remove the entity after landing
        end
    end,
})

-- Command to drop the crate
minetest.register_chatcommand("supply_drop", {
    description = "Call in a supply crate drop",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            local pos = player:get_pos()
            drop_supply_crate(pos)
            minetest.chat_send_player(name, "Supply crate inbound!")
        end
    end,
})


-- Define the drone pad node
minetest.register_node("war_mod:drone_pad", {
    description = "Drone Pad",
    tiles = {"drone_pad_top.png", "drone_pad_bottom.png", "drone_pad_side.png"},
    groups = {cracky = 2},
    sounds = default.node_sound_stone_defaults(),
})

-- Define the supply drone entity
minetest.register_entity("war_mod:supply_drone", {
    initial_properties = {
        physical = true,
        collide_with_objects = false,
        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        visual = "wielditem",
        visual_size = {x = 0.5, y = 0.5},
        textures = {"war_mod:drone_texture.png"}, -- Ensure you have this texture
    },
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1}) -- Make the drone immortal
        self.follow_time = 5 -- Time to follow the player
        self.start_time = minetest.get_gametime() -- Record the start time
        self.returning = false -- State to check if returning to pad
        self.pad_pos = nil -- Position of the drone pad
    end,
    on_step = function(self, dtime)
        -- Check if the drone should return to the pad
        if self.returning then
            if self.pad_pos then
                local drone_pos = self.object:get_pos()
                local dx = self.pad_pos.x - drone_pos.x
                local dz = self.pad_pos.z - drone_pos.z
                local distance = math.sqrt(dx^2 + dz^2)

                -- Move the drone towards the pad position
                if distance > 1 then
                    local speed = 2 -- Speed of the drone
                    self.object:set_velocity({
                        x = dx / distance * speed,
                        y = 1, -- Hover above ground
                        z = dz / distance * speed
                    })
                else
                    self.object:remove() -- Remove the drone after reaching the pad
                end
            end
            return
        end

        -- Check if the drone should still follow the player
        if minetest.get_gametime() - self.start_time > self.follow_time then
            self:drop_supplies()
            self.returning = true -- Start returning to the pad
            return
        end

        -- Find the player and move towards them
        local players = minetest.get_connected_players()
        if #players > 0 then
            local player = players[1] -- Get the first player (or implement logic to choose a player)
            local player_pos = player:get_pos()
            local drone_pos = self.object:get_pos()

            -- Move the drone towards the player position
            local dx = player_pos.x - drone_pos.x
            local dz = player_pos.z - drone_pos.z
            local distance = math.sqrt(dx^2 + dz^2)

            -- Move only if within a certain distance
            if distance > 1 then
                local speed = 2 -- Speed of the drone
                self.object:set_velocity({
                    x = dx / distance * speed,
                    y = 1, -- Hover above ground
                    z = dz / distance * speed
                })
            end
        end
    end,
    drop_supplies = function(self)
        local pos = self.object:get_pos()
        -- Add the items to the world (you can customize the items as needed)
        local inv_items = {
            "default:sword_steel",
            "guns4d:ammo",
            "default:apple 10"
        }
        for _, item in ipairs(inv_items) do
            minetest.add_item(pos, item) -- Drop items at the drone's location
        end

        -- Set the drone pad position for returning
        local players = minetest.get_connected_players()
        if #players > 0 then
            local player = players[1] -- Get the first player (or implement logic to choose a player)
            self.pad_pos = minetest.get_node(player:get_pos()).name == "war_mod:drone_pad" and player:get_pos() or nil
        end
    end,
})

-- Function to spawn the drone
local function spawn_supply_drone(player_name)
    local player = minetest.get_player_by_name(player_name)
    local player_pos = player:get_pos()
    
    -- Find the nearest drone pad
    local nearest_pad_pos
    local min_distance = math.huge

    for _, object in ipairs(minetest.get_objects_inside_radius(player_pos, 50)) do
        if object:get_luaentity() and object:get_luaentity().name == "war_mod:drone_pad" then
            local pad_pos = object:get_pos()
            local distance = vector.distance(player_pos, pad_pos)
            if distance < min_distance then
                min_distance = distance
                nearest_pad_pos = pad_pos
            end
        end
    end

    if nearest_pad_pos then
        -- Spawn the drone above the pad
        local drone = minetest.add_entity({x = nearest_pad_pos.x, y = nearest_pad_pos.y + 5, z = nearest_pad_pos.z}, "war_mod:supply_drone")
        minetest.chat_send_player(player_name, "Supply drone inbound!")
    else
        minetest.chat_send_player(player_name, "No nearby drone pad found!")
    end
end

-- Command to spawn the supply drone
minetest.register_chatcommand("supply_drone", {
    description = "Spawn a supply drone from the nearest drone pad",
    func = spawn_supply_drone,
})

-- Custom explosion function (kept the same)
local function create_explosion(pos, radius)
    -- Destroy nodes within the radius
    for dx = -radius, radius do
        for dy = -radius, radius do
            for dz = -radius, radius do
                local node_pos = {x = pos.x + dx, y = pos.y + dy, z = pos.z + dz}
                local node = minetest.get_node(node_pos)
                if node.name ~= "air" then
                    minetest.remove_node(node_pos)
                end
            end
        end
    end

    -- Add particle effects for explosion
    minetest.add_particlespawner({
        amount = 100,
        time = 0.1,
        minpos = {x = pos.x - radius, y = pos.y - radius, z = pos.z - radius},
        maxpos = {x = pos.x + radius, y = pos.y + radius, z = pos.z + radius},
        minvel = {x = -5, y = -5, z = -5},
        maxvel = {x = 5, y = 5, z = 5},
        minacc = {x = 0, y = 0, z = 0},
        maxacc = {x = 0, y = 0, z = 0},
        minexptime = 0.5,
        maxexptime = 1.5,
        minsize = 5,
        maxsize = 10,
        texture = "tnt_smoke.png",
    })
end

-- Bomb entity definition (kept the same)
minetest.register_entity("war_mod:airstrike_bomb", {
    initial_properties = {
        physical = true,
        collide_with_objects = false,
        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        visual = "wielditem",
        visual_size = {x = 0.5, y = 0.5},
        textures = {"default_tnt.png"},
    },
    falling_timer = 0,
    on_activate = function(self, staticdata)
        self.object:set_armor_groups({immortal = 1})
        self.falling_timer = 0
    end,
    on_step = function(self, dtime)
        self.falling_timer = self.falling_timer + dtime
        local velocity = self.object:get_velocity()
        self.object:set_velocity({x = velocity.x, y = velocity.y - 0.5, z = velocity.z})

        -- Check for ground collision
        local pos = self.object:get_pos()
        if minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name ~= "air" or self.falling_timer > 10 then
            create_explosion(pos, 5) -- Explosion radius

            -- Damage nearby players
            local objs = minetest.get_objects_inside_radius(pos, 1)
            for _, obj in ipairs(objs) do
                if obj:is_player() then
                    obj:set_hp(0) -- Kill the player
                end
            end

            -- Remove the bomb entity
            self.object:remove()
        end
    end,
})

-- Function to spawn airstrike bombs
local function spawn_airstrike_bombs(center_pos)
    for i = 1, 30 do
        -- Randomize bomb positions within a 10-block radius
        local offset_x = math.random(-5, 5)
        local offset_z = math.random(-5, 5)
        local bomb_pos = {
            x = center_pos.x + offset_x,
            y = center_pos.y + 100,
            z = center_pos.z + offset_z
        }

        -- Spawn the bomb entity
        local bomb_entity = minetest.add_entity(bomb_pos, "war_mod:airstrike_bomb")
        if bomb_entity then
            bomb_entity:set_velocity({x = 0, y = -80, z = 0}) -- Fast fall speed
        end
    end
end


-- Command with countdown and airstrike message
minetest.register_chatcommand("airstrike", {
    description = "Call an airstrike at your position",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then
            return
        end
        local pos = player:get_pos()

        -- Display the countdown and airstrike message
        local countdown = 10
        minetest.chat_send_player(name, "Command Center: Request affirmative. Airstrike inbound in 10 seconds...")

        -- Countdown function
        local function start_countdown(countdown, name)
            minetest.after(1, function()
                countdown = countdown - 1
                if countdown > 0 then
                    minetest.chat_send_player(name, "Command Center: Airstrike inbound in " .. countdown .. " seconds...")
                    start_countdown(countdown, name) -- Call the countdown function again
                else
                    -- Trigger the airstrike here once the countdown reaches 0
                    minetest.chat_send_player(name, "Command Center: Airstrike deployed!")
                    
                    -- Spawn the airstrike bombs
                    spawn_airstrike_bombs(pos) -- Calls the bomb spawning function
                end
            end)
        end

        -- Start the countdown from 10 seconds
        start_countdown(countdown, name)
    end,
})


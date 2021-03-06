
-- define global
hopper = {version = "20220123"}


-- Intllib
local S

if minetest.get_translator then
	S = minetest.get_translator("hopper")
elseif minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	S = function(s, a, ...) a = {a, ...}
		return s:gsub("@(%d+)", function(n)
			return a[tonumber(n)]
		end)
	end

end

-- creative check
local creative_mode_cache = minetest.settings:get_bool("creative_mode")
function check_creative(name)
	return creative_mode_cache or minetest.check_player_privs(name, {creative = true})
end


-- default containers
local containers = {

	{"top", "hopper:hopper", "main"},
	{"bottom", "hopper:hopper", "main"},
	{"side", "hopper:hopper", "main"},
	{"side", "hopper:hopper_side", "main"},

	{"top", "default:chest", "main"},
	{"bottom", "default:chest", "main"},
	{"side", "default:chest", "main"},

	{"top", "default:furnace", "dst"},
	{"bottom", "default:furnace", "src"},
	{"side", "default:furnace", "fuel"},

	{"top", "default:furnace_active", "dst"},
	{"bottom", "default:furnace_active", "src"},
	{"side", "default:furnace_active", "fuel"},

	{"top", "default:chest_locked", "main"}, -- checks owner before taking items
	{"bottom", "default:chest_locked", "main"},
	{"side", "default:chest_locked", "main"},

	{"top", "default:chest_open", "main"}, --  new animated chests
	{"bottom", "default:chest_open", "main"},
	{"side", "default:chest_open", "main"},

	{"top", "default:chest_locked_open", "main"}, -- checks owner before taking items
	{"bottom", "default:chest_locked_open", "main"},
	{"side", "default:chest_locked_open", "main"},

	{"void", "hopper:hopper", "main"},
	{"void", "hopper:hopper_side", "main"},
	{"void", "hopper:hopper_void", "main"},
	{"void", "default:chest", "main"},
	{"void", "default:chest_open", "main"},
	{"void", "default:furnace", "src"},
	{"void", "default:furnace_active", "src"}
}

-- global function to add new containers
function hopper:add_container(list)

	for n = 1, #list do
		table.insert(containers, list[n])
	end
end


-- protector redo mod support
if minetest.get_modpath("protector") then

	hopper:add_container({
		{"top", "protector:chest", "main"},
		{"bottom", "protector:chest", "main"},
		{"side", "protector:chest", "main"},
		{"void", "protector:chest", "main"}
	})
end


-- wine mod support
if minetest.get_modpath("wine") then

	hopper:add_container({
		{"top", "wine:wine_barrel", "dst"},
		{"bottom", "wine:wine_barrel", "src"},
		{"side", "wine:wine_barrel", "src"},
		{"void", "wine:wine_barrel", "src"}
	})
end


-- formspec
local function get_hopper_formspec(pos)

	local spos = pos.x .. "," .. pos.y .. "," ..pos.z
	local formspec =
		"size[8,9]"
		.. default.gui_bg
		.. default.gui_bg_img
		.. default.gui_slots
		.. "list[nodemeta:" .. spos .. ";main;0,0.3;8,4;]"
		.. "list[current_player;main;0,4.85;8,1;]"
		.. "list[current_player;main;0,6.08;8,3;8]"
		.. "listring[nodemeta:" .. spos .. ";main]"
		.. "listring[current_player;main]"

	return formspec
end


-- check where pointing and set normal or side-hopper
local hopper_place = function(itemstack, placer, pointed_thing)

	local pos = pointed_thing.above
	local x = pointed_thing.under.x - pos.x
	local z = pointed_thing.under.z - pos.z
	local name = placer:get_player_name() or ""

	if minetest.is_protected(pos, name) then
		minetest.record_protection_violation(pos, name)
		return itemstack
	end

	-- make sure we aren't replacing something we shouldnt
	local node = minetest.get_node_or_nil(pos)
	local def = node and minetest.registered_nodes[node.name]
	if def and not def.buildable_to then
		return itemstack
	end

	if x == -1 then
		minetest.set_node(pos, {name = "hopper:hopper_side", param2 = 0})

	elseif x == 1 then
		minetest.set_node(pos, {name = "hopper:hopper_side", param2 = 2})

	elseif z == -1 then
		minetest.set_node(pos, {name = "hopper:hopper_side", param2 = 3})

	elseif z == 1 then
		minetest.set_node(pos, {name = "hopper:hopper_side", param2 = 1})

	else
		minetest.set_node(pos, {name = "hopper:hopper"})
	end

	if not check_creative(placer:get_player_name()) then
		itemstack:take_item()
	end

	-- set metadata
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()

	inv:set_size("main", 4*4)

	meta:set_string("owner", name)

	return itemstack
end


-- hopper
minetest.register_node("hopper:hopper", {
	description = S("Hopper (Place onto sides for side-hopper)"),
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	use_texture_alpha = "clip",
	tiles = {"hopper_top.png", "hopper_top.png", "hopper_front.png"},
	inventory_image = "hopper_inv.png",
	node_box = {
		type = "fixed",
		fixed = {
			--funnel walls
			{-0.5, 0.0, 0.4, 0.5, 0.5, 0.5},
			{0.4, 0.0, -0.5, 0.5, 0.5, 0.5},
			{-0.5, 0.0, -0.5, -0.4, 0.5, 0.5},
			{-0.5, 0.0, -0.5, 0.5, 0.5, -0.4},
			--funnel base
			{-0.5, 0.0, -0.5, 0.5, 0.1, 0.5},
			--spout
			{-0.3, -0.3, -0.3, 0.3, 0.0, 0.3},
			{-0.15, -0.3, -0.15, 0.15, -0.5, 0.15}
		}
	},

	on_place = hopper_place,

	can_dig = function(pos, player)

		local inv = minetest.get_meta(pos):get_inventory()

		return inv:is_empty("main")
	end,

	on_rightclick = function(pos, node, clicker, itemstack)

		if not minetest.get_meta(pos)
		or minetest.is_protected(pos, clicker:get_player_name()) then
			return itemstack
		end

		minetest.show_formspec(clicker:get_player_name(),
			"hopper:hopper", get_hopper_formspec(pos))
	end,

	on_metadata_inventory_move = function(
			pos, from_list, from_index, to_list, to_index, count, player)

		minetest.log("action", player:get_player_name()
			.. " moves stuff in hopper at " .. minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)

		minetest.log("action", player:get_player_name()
			.. " moves stuff to hopper at " .. minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_take = function(pos, listname, index, stack, player)

		minetest.log("action", player:get_player_name()
			.. " moves stuff from hopper at " .. minetest.pos_to_string(pos))
	end,

	on_rotate = screwdriver.disallow,
	on_blast = function() end
})


-- side hopper
minetest.register_node("hopper:hopper_side", {
	description = S("Side Hopper (Place into crafting to return normal Hopper)"),
	groups = {cracky = 3, not_in_creative_inventory = 1},
	drawtype = "nodebox",
	paramtype = "light",
	use_texture_alpha = "clip",
	paramtype2 = "facedir",
	tiles = {
		"hopper_top.png", "hopper_top.png", "hopper_back.png",
		"hopper_side.png", "hopper_back.png", "hopper_back.png"
	},
	inventory_image = "hopper_side_inv.png",
	drop = "hopper:hopper",
	node_box = {
		type = "fixed",
		fixed = {
			--funnel walls
			{-0.5, 0.0, 0.4, 0.5, 0.5, 0.5},
			{0.4, 0.0, -0.5, 0.5, 0.5, 0.5},
			{-0.5, 0.0, -0.5, -0.4, 0.5, 0.5},
			{-0.5, 0.0, -0.5, 0.5, 0.5, -0.4},
			--funnel base
			{-0.5, 0.0, -0.5, 0.5, 0.1, 0.5},
			--spout
			{-0.3, -0.3, -0.3, 0.3, 0.0, 0.3},
			{-0.7, -0.3, -0.15, 0.15, 0.0, 0.15}
		}
	},

	on_place = hopper_place,

	can_dig = function(pos, player)

		local inv = minetest.get_meta(pos):get_inventory()

		return inv:is_empty("main")
	end,

	on_rightclick = function(pos, node, clicker, itemstack)

		if not minetest.get_meta(pos)
		or minetest.is_protected(pos, clicker:get_player_name()) then
			return itemstack
		end

		minetest.show_formspec(clicker:get_player_name(),
			"hopper:hopper_side", get_hopper_formspec(pos))
	end,

	on_metadata_inventory_move = function(
			pos, from_list, from_index, to_list, to_index, count, player)

		minetest.log("action", player:get_player_name()
			.. " moves stuff in side hopper at " .. minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)

		minetest.log("action", player:get_player_name()
			.. " moves stuff to side hopper at " .. minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_take = function(pos, listname, index, stack, player)

		minetest.log("action", player:get_player_name()
			.. " moves stuff from side hopper at " .. minetest.pos_to_string(pos))
	end,

	on_rotate = screwdriver.rotate_simple,
	on_blast = function() end
})


local player_void = {}

-- void hopper
minetest.register_node("hopper:hopper_void", {
	description = S("Void Hopper (Use first to set destination container)"),
	groups = {cracky = 3},
	drawtype = "nodebox",
	paramtype = "light",
	use_texture_alpha = "clip",
	tiles = {"hopper_top.png", "hopper_top.png", "hopper_front.png"},
	inventory_image = "default_obsidian.png^hopper_inv.png",
	node_box = {
		type = "fixed",
		fixed = {
			--funnel walls
			{-0.5, 0.0, 0.4, 0.5, 0.5, 0.5},
			{0.4, 0.0, -0.5, 0.5, 0.5, 0.5},
			{-0.5, 0.0, -0.5, -0.4, 0.5, 0.5},
			{-0.5, 0.0, -0.5, 0.5, 0.5, -0.4},
			--funnel base
			{-0.5, 0.0, -0.5, 0.5, 0.1, 0.5}
		}
	},

	on_use = function(itemstack, player, pointed_thing)

		if pointed_thing.type ~= "node" then
			return
		end

		local pos = pointed_thing.under
		local name = player:get_player_name()
		local node = minetest.get_node(pos).name
		local ok

		if minetest.is_protected(pos, name) then
			minetest.record_protection_violation(pos, name)
			return itemstack
		end

		for _ = 1, #containers do
			if node == containers[_][2] then
				ok = true
			end
		end

		if ok then
			minetest.chat_send_player(name, S("Output container set"
				.. " " .. minetest.pos_to_string(pos)))
			player_void[name] = pos
		else
			minetest.chat_send_player(name, S("Not a registered container!"))
			player_void[name] = nil
		end
	end,

	on_place = function(itemstack, placer, pointed_thing)

		local pos = pointed_thing.above
		local name = placer:get_player_name() or ""

		if not player_void[name] then
			minetest.chat_send_player(name, S("No container position set!"))
			return itemstack
		end

		if minetest.is_protected(pos, name) then
			minetest.record_protection_violation(pos, name)
			return itemstack
		end

		-- make sure we aren't replacing something we shouldnt
		local node = minetest.get_node_or_nil(pos)
		local def = node and minetest.registered_nodes[node.name]
		if def and not def.buildable_to then
			return itemstack
		end

		if not check_creative(placer:get_player_name()) then
			itemstack:take_item()
		end

		minetest.set_node(pos, {name = "hopper:hopper_void", param2 = 0})

		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()

		inv:set_size("main", 4*4)

		meta:set_string("owner", name)
		meta:set_string("void", minetest.pos_to_string(player_void[name]))
		meta:set_string("infotext", "Void Hopper\nConnected to " ..
				minetest.pos_to_string(player_void[name]))

		return itemstack
	end,

	can_dig = function(pos, player)

		local inv = minetest.get_meta(pos):get_inventory()

		return inv:is_empty("main")
	end,

	on_rightclick = function(pos, node, clicker, itemstack)

		if not minetest.get_meta(pos)
		or minetest.is_protected(pos, clicker:get_player_name()) then
			return itemstack
		end

		minetest.show_formspec(clicker:get_player_name(),
			"hopper:hopper", get_hopper_formspec(pos))
	end,

	on_metadata_inventory_move = function(
			pos, from_list, from_index, to_list, to_index, count, player)

		minetest.log("action", player:get_player_name()
			.. " moves stuff in void hopper at " .. minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_put = function(pos, listname, index, stack, player)

		minetest.log("action", player:get_player_name()
			.." moves stuff into void hopper at " .. minetest.pos_to_string(pos))
	end,

	on_metadata_inventory_take = function(pos, listname, index, stack, player)

		minetest.log("action", player:get_player_name()
			.. " moves stuff from void hopper at " .. minetest.pos_to_string(pos))
	end,

	on_rotate = screwdriver.disallow,
	on_blast = function() end
})


-- transfer function
local transfer = function(src, srcpos, dst, dstpos)

	-- source inventory
	local inv = minetest.get_meta(srcpos):get_inventory()

	-- destination inventory
	local inv2 = minetest.get_meta(dstpos):get_inventory()

	-- check for empty source or no inventory
	if not inv or not inv2 or inv:is_empty(src) == true then
		return
	end

	local stack, item, max

	-- transfer item
	for i = 1, inv:get_size(src) do

		stack = inv:get_stack(src, i)
		item = stack:get_name()
		max = stack:get_stack_max()

		-- if slot not empty and room for item in destination
		if item ~= ""
		and inv2:room_for_item(dst, item) then

			-- stack max of 1 is usually for tools or items with metadata
			if max == 1 then
				inv2:add_item(dst, stack)
				inv:set_stack(src, i, nil)

			else -- everything else that can be stacked
				stack:take_item(1)
				inv2:add_item(dst, item)
				inv:set_stack(src, i, stack)
			end

			return
		end
	end
end


local lazy = minetest.settings:get_bool("lazy_container_support")

local function add_container_lazy(meta, where, node_name, inv_names)

	if not meta then return end

	local inv = meta:get_inventory()

	for _, inv_name in pairs(inv_names) do

		if inv:get_size(inv_name) > 0 then

--print("hopper: add_container_lazy ["..#containers.."] "..where.." '"..node_name.."' "..inv_name)

			hopper:add_container({{where, node_name, inv_name}})

			return
		end
	end
end


-- hopper workings
minetest.register_abm({

	label = "Hopper suction and transfer",
	nodenames = {"hopper:hopper", "hopper:hopper_side", "hopper:hopper_void"},
	interval = 1,
	chance = 1,
	catch_up = false,

	action = function(pos, node, active_object_count, active_object_count_wider)

		local inv = minetest.get_meta(pos):get_inventory()

		for _,object in pairs(minetest.get_objects_inside_radius(pos, 1)) do

			if not object:is_player()
			and object:get_luaentity()
			and object:get_luaentity().name == "__builtin:item"
			and inv
			and inv:room_for_item("main",
				ItemStack(object:get_luaentity().itemstring)) then

				if object:get_pos().y - pos.y > 0.25 then

					inv:add_item("main",
						ItemStack(object:get_luaentity().itemstring))

					object:get_luaentity().itemstring = ""
					object:remove()
				end
			end
		end

		local dst_pos

		-- if side hopper check which way spout is facing
		if node.name == "hopper:hopper_side" then

			local face = node.param2

			if face == 0 then
				dst_pos = {x = pos.x - 1, y = pos.y, z = pos.z}

			elseif face == 1 then
				dst_pos = {x = pos.x, y = pos.y, z = pos.z + 1}

			elseif face == 2 then
				dst_pos = {x = pos.x + 1, y = pos.y, z = pos.z}

			elseif face == 3 then
				dst_pos = {x = pos.x, y = pos.y, z = pos.z - 1}
			else
				return
			end

		elseif node.name == "hopper:hopper_void" then

			local meta = minetest.get_meta(pos)

			if not meta then return end

			dst_pos = minetest.string_to_pos(meta:get_string("void"))

		elseif node.name == "hopper:hopper" then
			-- otherwise normal hopper, output downwards
			dst_pos = {x = pos.x, y = pos.y - 1, z = pos.z}
		else
			return
		end

		-- get node above hopper
		local src_pos = {x = pos.x, y = pos.y + 1, z = pos.z}
		local src_name = minetest.get_node(src_pos).name

		-- get node at other end of spout
		local dst_name = minetest.get_node(dst_pos).name

		-- hopper owner
		local owner = minetest.get_meta(pos):get_string("owner")

		if minetest.check_player_privs(owner, "protection_bypass") then
			owner = ""
		end

		local to
		if node.name == "hopper:hopper" then
			to = "bottom"
		elseif node.name == "hopper:hopper_side" then
			to = "side"
		elseif node.name == "hopper:hopper_void" then
			to = "void"
		end

		local where, name, inv, def, src_inv, dst_inv

		-- do for loop here for api check
		for n = 1, #containers do

			where = containers[n][1]
			name = containers[n][2]
			inv = containers[n][3]

			if where == "top" and src_name == name then
				src_inv = inv -- from hopper into destionation container
			elseif where == to and dst_name == name then
				dst_inv = inv
			end
		end

		-- get container owner
		local c_owner = minetest.get_meta(src_pos):get_string("owner") or ""

		-- if protection_bypass or actual owner or container not owned
		if owner == "" or owner == c_owner or c_owner == "" then

			if src_inv then

				transfer(src_inv, src_pos, "main", pos)

				minetest.get_node_timer(src_pos):start(1)

			elseif src_name ~= "ignore" and lazy then

				local meta = minetest.get_meta(src_pos)

				add_container_lazy(meta, "top", src_name, {"main", "dst", "out"})
			end
		end

		c_owner = minetest.get_meta(dst_pos):get_string("owner") or ""

		if owner == "" or owner == c_owner or c_owner == "" then

			if dst_inv then

				transfer("main", pos, dst_inv, dst_pos)

				minetest.get_node_timer(dst_pos):start(1)

			elseif dst_name ~= "ignore" and lazy then

				local meta = minetest.get_meta(dst_pos)

				if to == "side" then
					add_container_lazy(meta, to, dst_name, {"fuel", "main", "src", "in"})
				else
					add_container_lazy(meta, to, dst_name, {"main", "src", "in"})
				end
			end
		end
	end
})


-- hopper recipe
minetest.register_craft({
	output = "hopper:hopper",
	recipe = {
		{"default:steel_ingot", "default:chest", "default:steel_ingot"},
		{"", "default:steel_ingot", ""}
	}
})

-- side hopper to hopper recipe
minetest.register_craft({
	output = "hopper:hopper",
	recipe = {{"hopper:hopper_side"}}
})

-- void hopper recipe
if minetest.get_modpath("teleport_potion") then
	minetest.register_craft({
		output = "hopper:hopper_void",
		recipe = {
			{"default:steel_ingot", "default:chest", "default:steel_ingot"},
			{"teleport_potion:potion", "default:steel_ingot", "teleport_potion:potion"}
		}
	})
else
	minetest.register_craft({
		output = "hopper:hopper_void",
		recipe = {
			{"default:steel_ingot", "default:chest", "default:steel_ingot"},
			{"default:diamondblock", "default:steel_ingot", "default:mese"}
		}
	})
end


-- add lucky blocks
if minetest.get_modpath("lucky_block") then

	lucky_block:add_blocks({
		{"dro", {"hopper:hopper"}, 3},
		{"nod", "default:lava_source", 1}
	})
end


print ("[MOD] Hopper loaded")

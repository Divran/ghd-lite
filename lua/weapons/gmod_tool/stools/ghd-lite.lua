TOOL.Category		= "Construction"
TOOL.Name			= "#Tool.ghdlite.name"
TOOL.Command		= nil
TOOL.ConfigName		= ""
TOOL.Tab			= "Main"

if CLIENT then
	language.Add( "Tool.ghdlite.name", "Gravity Hull Designator Lite" )
	language.Add( "Tool.ghdlite.desc", "Allows players to stand on props" )
	language.Add( "Tool.ghdlite.left", "Set GHD on entity" )
	language.Add( "Tool.ghdlite.right", "Remove GHD" )
	TOOL.Information = { "left", "right" }
end

local function inrange(vec,min,max)
	if vec.x < min.x then return false end
	if vec.y < min.y then return false end
	if vec.z < min.z then return false end

	if vec.x > max.x then return false end
	if vec.y > max.y then return false end
	if vec.z > max.z then return false end

	return true
end

local ghddata = {}
local plydata = {}

function TOOL:LeftClick(trace)
	if not IsFirstTimePredicted() then return false end
	if not IsValid(trace.Entity) then return false end
	if trace.Entity:IsWorld() then return false end

	local base = trace.Entity
	local min = base:OBBMins()
	local max = base:OBBMaxs() + Vector(0,0,50)
	ghddata[trace.Entity] = {
		base = base,
		inrange = function(ply)
			return inrange(base:WorldToLocal(ply:GetPos()),min,max)
		end
	}

	print("REGISTERED",trace.Entity)
	return true
end

function TOOL:RightClick(trace)
	if not IsFirstTimePredicted() then return false end
	if not IsValid(trace.Entity) then return false end
	if trace.Entity:IsWorld() then return false end
	ghddata[trace.Entity] = nil

	print("UNREGISTERED",trace.Entity)
end

if CLIENT then
	function TOOL.BuildCPanel(panel)
		panel:AddControl("Header", { Text = "#Tool.ghdlite.name", Description = "#Tool.ghdlite.desc" })
	end
end

hook.Remove("PlayerInitialSpawn","ghd-lite")
hook.Remove("EntityRemoved","ghd-lite")
hook.Remove("Think","ghd-lite")
hook.Remove("SetupMove","ghd-lite")
hook.Remove("Move","ghd-lite")
hook.Remove("FinishMove","ghd-lite")
hook.Remove("InputMouseApply", "ghd-lite")

hook.Add("PlayerInitialSpawn","ghd-lite",function(ply)
	if ply:IsBot() then return end
	plydata[ply] = {}
end)

timer.Simple(0.1,function()
	for k,v in pairs( player.GetHumans() ) do
		plydata[v] = {}
	end
end)

hook.Add("EntityRemoved","ghd-lite",function(ent)
	plydata[ent] = nil
	ghddata[ent] = nil
end)

local function validateMove(ply)
	if not plydata[ply] or not plydata[ply].base then return end

	local data = plydata[ply]
	local base = data.base
	if not IsValid(base) then return end

	local phys

	if SERVER then
		phys = base:GetPhysicsObject()
		if not IsValid(phys) then return end
	else
		phys = base
	end

	return data, phys
end

hook.Add("Think","ghd-lite-think",function()
	if CLIENT then
		local data, phys = validateMove(LocalPlayer())
		if data then
			LocalPlayer():SetEyeAngles(data.base:LocalToWorldAngles(data.current_ang))
		end
	end

	local check = plydata
	if CLIENT then check = {[LocalPlayer()] = plydata[LocalPlayer()]} end

	for ply, plydat in pairs( check ) do
		if ply:GetMoveType() == MOVETYPE_NOCLIP then
			-- noclip entered, abort everything
			plydata[ply].base = nil
		else
			if IsValid(plydat.base) then
				if not plydat.inrange(ply) then -- if no longer in range
					print("PLAYER",ply,"DISCONNECTED FROM",plydat.base)
					plydata[ply].disconnect = true
				end
			else
				for ent, dat in pairs( ghddata ) do -- check all ghddata if we're in range
					if dat.inrange(ply) then -- if yes, connect to it
						plydat.base = ent
						plydat.inrange = dat.inrange
						plydat.current_vel = ent:WorldToLocal(ply:GetVelocity()+ent:GetPos())
						plydat.current_pos = ent:WorldToLocal(ply:GetPos()-Vector(0,0,0.5))
						plydat.current_ang = ent:WorldToLocalAngles(ply:EyeAngles())
						plydat.current_ang.r = 0
						print("PLAYER",ply,"CONNECTED TO",ent)
						break
					end
				end
			end
		end
	end
end)

local mouse_sensitvity = GetConVar("sensitivity")
hook.Add("SetupMove","ghd-lite",function(ply,mv,cmd)
	local data, phys = validateMove(ply)
	if not data then return end

	local mousex = cmd:GetMouseX()
	local mousey = cmd:GetMouseY()

	data.wanted_ang = Angle(mousey,-mousex,0) * mouse_sensitvity:GetFloat() * FrameTime()

	local wanted_vel = Vector(cmd:GetForwardMove(),-cmd:GetSideMove(),cmd:GetUpMove())
	if wanted_vel:Length() > mv:GetMaxSpeed() then
		wanted_vel:Normalize()
		wanted_vel:Mul(mv:GetMaxSpeed())
	end

	local ang = cmd:GetViewAngles()
	ang.p = 0
	wanted_vel:Rotate(ang-phys:GetAngles())
	--wanted_vel = data.current_vel * 0.05 + wanted_vel

	data.wanted_vel = wanted_vel
	data.wanted_pos = data.current_pos + data.wanted_vel * FrameTime()
	
	cmd:SetViewAngles(data.base:LocalToWorldAngles(data.current_ang))

	--mv:SetVelocity(Vector(0,0,0))
	
	--mv:SetVelocity(phys:LocalToWorld(data.wanted_vel)-phys:GetPos())
	--mv:SetOrigin(phys:LocalToWorld(data.wanted_pos))

	--[[
	data.wanted_velocity = wanted_velocity --+ phys:GetVelocityAtPoint(ply:GetPos())
	data.local_position:Add(data.wanted_velocity) -- phys:WorldToLocal(ply:GetPos())
	--]]

	--data.wanted_velocity = mv:GetVelocity() - phys:GetVelocity()
	--print("SetupMove, current vel:",data.wanted_vel,"current pos:",data.wanted_pos,"ang:",data.current_ang)
end)

--[[
hook.Add("Move","ghd-ite",function(ply,mv)
	local data, phys = validateMove(ply)
	if not data then return end

	--mv:SetVelocity(Vector(0,0,0))
	
	--mv:SetVelocity(phys:LocalToWorld(data.wanted_vel)-phys:GetPos())
	--mv:SetOrigin(phys:LocalToWorld(data.wanted_pos))

	--mv:SetVelocity(data.wanted_velocity)
	--mv:SetOrigin(phys:LocalToWorld(data.local_position))
	--print("Move, setting player velocity to:",data.wanted_velocity)
	print("Move, current vel:",data.wanted_vel,"current pos:",data.wanted_pos)
end)
]]

hook.Add("FinishMove","ghd-lite",function(ply,mv)
	local data, phys = validateMove(ply)
	if not data then return end

	--mv:SetVelocity(phys:LocalToWorld(data.wanted_vel)-phys:GetPos())
	--mv:SetOrigin(phys:LocalToWorld(data.wanted_pos))

	--print("FinishMove, current vel:",data.current_vel,"current pos:",data.current_pos)

	if data.disconnect then -- disconnect safely
		ply:SetVelocity(Vector(0,0,0))
		ply:SetPos(phys:LocalToWorld(data.current_pos+Vector(0,0,1)))

		local ang = data.base:LocalToWorldAngles(data.current_ang)
		ang.r = 0
		ply:SetEyeAngles(ang)

		data.base = nil
		data.disconnect = nil
		print("DISCONNECT SAFELY")
	else
		ply:SetVelocity(phys:LocalToWorld(data.wanted_vel)-phys:GetPos())
		ply:SetPos(phys:LocalToWorld(data.wanted_pos))

		data.current_vel = data.wanted_vel
		data.current_pos = data.wanted_pos
		--ply:SetEyeAngles(data.base:LocalToWorldAngles(data.current_ang))
		data.current_ang = data.current_ang + data.wanted_ang
		data.current_ang.p = math.Clamp(data.current_ang.p,-89.9999,89.9999)
		data.current_ang.y = data.current_ang.y % 360
		data.current_ang.r = data.current_ang.r % 360

		return true
	end
end)

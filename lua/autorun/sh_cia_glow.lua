AddCSLuaFile()

--[[
	TODO: scoreboard tag
	TODO: marked players highlight
]]

-- local ttt_glowing_detective = CreateConVar("ttt_glowing_detective", "0", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Should the detective be seen through walls?")
-- local ttt_glowing_scoreboard_tag = CreateConVar("ttt_glowing_scoreboard_tag", "0", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Should players highlight with scoreboard tags?")
local is_reload = false
if CIA_GLOW then is_reload = true end
CIA_GLOW = CIA_GLOW or {}
-- local function IsRoleVisible(ply)
-- 	local showTeam = ply:HasRole()
-- 	local tm = ply:GetTeam() or nil
-- 	if tm then
-- 		local tmData = TEAMS[tm]
-- 		if tm == TEAM_NONE or not tmData or tmData.alone then
-- 			-- NO TEAM
-- 		else
-- 			-- TEAM
-- 		end
-- 	end

-- 	-- ply:IsActive()
-- 	-- if ply:HasRole() then
-- 		-- return
-- 			-- and (ply:IsInTeam(l_ply) or rd.isPublicRole)
-- 			-- and not rd.avoidTeamIcons
-- end

-- @TODO make all these functions hooks from the basegame to share logic

CIA_GLOW.IsSpectatorGhost = function(ply)
	return SpecDM and ply.IsGhost and ply:IsGhost()
end

CIA_GLOW.ShouldDrawOverheadIcon = function(ply)
	local client = LocalPlayer()
	local rd = ply:GetSubRoleData()
	return ply:IsActive()
		and ply:HasRole()
		and (not client:IsActive() or ply:IsInTeam(client) or rd.isPublicRole)
		and not rd.avoidTeamIcons
end

CIA_GLOW.ShouldDrawScoreboardTeam = function(ply)
	local tm = ply:GetTeam() or nil
	local has_team = false
	if tm then
		local tmData = TEAMS[tm]
		has_team = not (tm == TEAM_NONE or not tmData or tmData.alone)
	end
	return has_team
end

CIA_GLOW.ShouldDrawDisguised = function(ply)

	local client = LocalPlayer()
	return ply:GetNWBool("disguised", false)
		and not (client:IsInTeam(ply) and not client:GetSubRoleData().unknownTeam or client:IsSpec())
end

CIA_GLOW.ShouldDrawTargetIDPlayers = function(ply)
	-- show the role of a player if it is known to the client
	local rstate = GetRoundState()
	local target_role
	if rstate == ROUND_ACTIVE and ply.HasRole and ply:HasRole() then
		target_role = ply:GetSubRoleData()
	end

	return not not target_role
end

CIA_GLOW.ShouldDrawPlayerNotSolo = function(ply)
	local tm = ply:GetTeam()
	return tm and tm ~= TEAM_NONE and not TEAMS[tm].alone
end

ESC_DRAW_NONE     = 0
ESC_DRAW_TARGETID = 1
ESC_DRAW_VISIBLE  = 2
ESC_DRAW_ALWAYS   = 4

CIA_GLOW.last_peeped_entity = nil

CIA_GLOW.PreDrawHalos = function()
	local l_ply = LocalPlayer()
	local l_ply_role = l_ply:GetRole()
	local plys = player.GetAll()
	local peeped_entity = l_ply:GetEyeTrace().Entity
	local round_state = GetRoundState()

	for i = 1, #plys do
		local desired_color = COLOR_SLATEGRAY
		local esc = nil
		local ply = plys[i]
		local conditions = {}
		-- if ply == l_ply then continue end
		-- bert
		-- local detective_show = ttt_glowing_detective2:GetBool()
		-- disguised players are not shown to normal players, except: same team, unknown team or to spectators
		-- local hide_because_disguised = false
		-- 	or
		-- local target_role
		-- local out_color = ply_rd and ply:GetRoleColor() or COLOR_SLATEGRAY



		-- IS ROLE VISIBLE?
		conditions.round_over = round_state == ROUND_POST
		conditions.detective_check = (ply:IsInTeam(l_ply) and not ply:GetDetective()) or (ply:GetRole() == l_ply_role)
		-- should_draw
		-- ply:IsSpecial()
		-- ply:Alive()
		-- ply:HasRole()
		-- ply_rd.avoidTeamIcons
		-- ply_rd.isPublicRole

		conditions.should_draw_overhead_icon = CIA_GLOW.ShouldDrawOverheadIcon(ply)
		conditions.should_draw_scoreboard_team = CIA_GLOW.ShouldDrawScoreboardTeam(ply)
		conditions.should_draw_disguised = CIA_GLOW.ShouldDrawDisguised(ply)
		conditions.should_draw_target_id_players = CIA_GLOW.ShouldDrawTargetIDPlayers(ply)
		conditions.should_draw_player_not_solo = CIA_GLOW.ShouldDrawPlayerNotSolo(ply)
		local should_draw_overhead_icon_hook, _, color_hook = hook.Run("TTT2ModifyOverheadIcon", ply, conditions.should_draw_overhead_icon)
		-- conditions.overhead_resource = not (material_hook and color_hook)
		conditions.overhead_icon_hook_said_ok = should_draw_overhead_icon_hook ~= false

		-- add scoreboard tags if tag is set
		desired_color = ply.sb_tag and ply.sb_tag.color or desired_color
		desired_color = color_hook or (ply:HasRole() and ply:GetRoleColor()) or desired_color

		-- NO MORE CONDITIONS FROM NOW ON
		-- if peeped_entity ~= CIA_GLOW.last_peeped_entity and IsValid(peeped_entity) and peeped_entity:IsPlayer() then
		-- 	print("glowdebug:", ply, "peeped", peeped_entity)
		-- 	PrintTable(conditions)
		-- end
		CIA_GLOW.last_peeped_entity = peeped_entity

		-- ESC_DRAW_TARGETID
		if (
			(
				conditions.should_draw_target_id_players
				or (ply.sb_tag and ply.sb_tag.color)
			)
			and peeped_entity == ply
	 	) then
			esc = ESC_DRAW_TARGETID
		end

		-- ESC_DRAW_VISIBLE
		if (
			conditions.overhead_icon_hook_said_ok
			and conditions.should_draw_overhead_icon
	 	) then
			esc = ESC_DRAW_VISIBLE
		end

		-- ESC_DRAW_ALWAYS
		if (
			conditions.detective_check
	 	) then
			esc = ESC_DRAW_ALWAYS
		end

		-- these are conditions that just prevent any drawing, done at the end, because fuck it
		-- ESC_DRAW_NONE
		if (
			ply == l_ply
			or CIA_GLOW.IsSpectatorGhost(ply)
			or (round_state == ROUND_ACTIVE and not ply:IsTerror())
			or not ply:Alive()
		) then
			esc = ESC_DRAW_NONE
		end

		local draw_mode = NULL
		if esc == ESC_DRAW_ALWAYS then
			draw_mode = OUTLINE_MODE_BOTH
		elseif (esc == ESC_DRAW_VISIBLE or esc == ESC_DRAW_TARGETID) then
			draw_mode = OUTLINE_MODE_VISIBLE
		else
			continue
		end
		outline.Add(ply, desired_color, draw_mode )
	end
end

CIA_GLOW.PostGamemodeLoaded = function()
	if GAMEMODE_NAME ~= "terrortown" then return end
	hook.Remove("PreDrawHalos", "CIA_GLOW__PreDrawHalos")
	hook.Add("PreDrawHalos", "CIA_GLOW__PreDrawHalos", CIA_GLOW.PreDrawHalos)
end

if is_reload then
	print("reloaded: sh_role_glow_modified.lua")
	hook.Remove("PostGamemodeLoaded", "CIA_GLOW__PostGamemodeLoaded")

	CIA_GLOW.PostGamemodeLoaded()
end
hook.Add("PostGamemodeLoaded", "CIA_GLOW__PostGamemodeLoaded", CIA_GLOW.PostGamemodeLoaded)
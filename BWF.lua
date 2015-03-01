--[[
	Benefits with Friends
	A World of Warcraft AddOn by Alex Schumaker
]]--

BWF = LibStub("AceAddon-3.0"):NewAddon("Benefits with Friends", "AceConsole-3.0", "AceEvent-3.0")

local grouproster = {}
local wasingroup
local autoaccepted
local db

local _

function BWF:OnInitialize()
	local defaults = {
		global = {
			autosetloot_method = "freeforall",
			autoacceptinv_enabled = true,
			allowpasslead = true,
			allowfriendinv = true,

			realID = true,
			character = true,
			btag = true,
			queuesafe = true,
			guildFriend = true,
			BWFad = true
		}
	}

	self.db = LibStub("AceDB-3.0"):New("BWFdb", defaults, true)
	db = self.db.global

	-- Update db with new fields if they've not been set yet
	for k, v in pairs(db) do
	    if db[k] == nil then
		db[k] = v
	    end
	end

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Benefits with Friends", self.BWFOptions)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Benefits with Friends", "BenefitsWithFriends")
	
	RegisterAddonMessagePrefix("BWFmsg");

	BWF:Print("Benefits with Friends loaded!")
	BWF:RegisterEvent("GROUP_ROSTER_UPDATE")
	BWF:RegisterEvent("PLAYER_ENTERING_WORLD")
	BWF:RegisterEvent("PARTY_INVITE_REQUEST")
	BWF:RegisterEvent("FRIENDLIST_UPDATE")
	BWF:RegisterEvent("CHAT_MSG_ADDON")
	BWF:RegisterEvent("CHAT_MSG_PARTY")
	BWF:RegisterEvent("CHAT_MSG_WHISPER")
	BWF:RegisterEvent("CHAT_MSG_BN_WHISPER")

	BWF:RegisterEvent("LOOT_OPENED")
	-- BWF:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
end

BWF.BWFOptions = {
	type = "group",
	name = "Benefits with Friends",
	get = function(key) return db[key.arg] end,
	set = function(key, val) db[key.arg] = val end,
	args = {
		autosetloot_method = {
			name = "Auto Set Loot",
			desc = "Automatically changes the loot method on forming a group.",
			type = "select",
			values = {
				freeforall = "Free for All",
				roundrobin = "Round Robin",
				group = "Group Loot",
				needbeforegreed = "Need Before Greed",
				master = "Master"
			},
			style = "dropdown",
			order = 1,
			arg = "autosetloot_method"
		},
		autoacceptinv_enabled = {
			name = "Auto-Accept Invites",
			desc = "Auto-Accepts group invitations from friends.",
			type = "toggle",
			order = 2,
			arg = "autoacceptinv_enabled"
		},
		allowpasslead = {
			name = "Allow PassLead",
			desc = "Allows friends in your party take lead from you using by typing '/bwf passlead' or 'bwf passlead' into party chat.",
			type = "toggle",
			order = 3,
			arg = "allowpasslead"
		},
		allowfriendinv = {
			name = "Allow Friend Group Invites",
			desc = "Allows friends to invite themselves to your group if you or one of your friends is the leader.",
			type = "toggle",
			order = 4,
			arg = "allowfriendinv"
		},
		realID = {
			name = "Real ID",
			desc = "Automatically change the loot method when inviting RealID friends.",
			type = "toggle",
			arg = "realID"
		},
		guildFriend = {
			name = "Guild Friends",
			desc = "Automatically change the loot method when inviting guild members.",
			type = "toggle",
			arg = "guildFriend"
		},
		character = {
			name = "Character",
			desc = "Automatically change the loot method when inviting normal, non-Battle.net friends.",
			type = "toggle",
			arg = "character"
		},
		btag = {
			name = "Battle Tag",
			desc = "Automatically change the loot method when inviting BattleTag friends.",
			type = "toggle",
			arg = "btag"	
		},
		queuesafe = {
			name = "Queue Safety",
			desc = "If checked, you will not auto-accept invites while in a queue that would cancel upon group roster change.",
			type = "toggle",
			arg = "queuesafe"
		},
		BWFad = {
			name = "BWF Announcements",
			desc = "Toggles the narrating announcements promoting BWF when if performs one of its functions!",
			type = "toggle",
			arg = "BWFad"
		}
	}	
}

function BWF:BWFtestfunc()
	--local name,_,_,_,_,_,zone,_,_,_,_ = GetRaidRosterInfo(2)
	--BWF:Print(name .. " is in " .. zone)
	
	--_,_,name,_,zone = BNGetFriendInfo(1)
	--BWF:Print(name .. " is on " .. zone)
	
	--for k,v in pairs(BWFdb) do BWF:Print(tostring(k) .. ", " .. tostring(v)) end
	BWF:Print(#grouproster)
	--BWF:Print(BWF:GroupFriendMakeup("party", (GetNumGroupMembers() - 1)))
	
	--BWF:BNPrintFriends();
	
	--self.db:ResetDB("Default")

	BWF:Print("Test Complete.")
end

function BWF:PLAYER_ENTERING_WORLD()
	--Assemble the group roster list and internal friends list.

	for i = 2, GetNumGroupMembers(), 1 do
		local name = GetRaidRosterInfo(i)
		table.insert(grouproster, name)
	end
end

function BWF:FRIENDLIST_UPDATE()
	
end

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
--++++++++++++++++ Chat Message Commands +++++++++++++++++--
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

function BWF:CHAT_MSG_ADDON(self, ...)
	local prefix, msg, type, sender = ...
	if prefix == "BWFmsg" then
		sender = BWF:SplitNameAndServer(sender)[1]
		if msg == "follow_me_" .. UnitName("player") then
			if BWF:IsAFriend(sender) then
				FollowUnit(sender)
				SendChatMessage("Following " .. sender .. "!", "SAY", nil)
			end
		elseif msg == "passlead" then
			BWF:PassLead(sender)
		end
	end
end

function BWF:CHAT_MSG_PARTY(self, msg, sender)
	msg = string.lower(msg)
	if msg == "bwf passlead" then
		BWF:PassLead(sender)
	end
end

function BWF:CHAT_MSG_WHISPER(self, msg, sender)
	msg = string.lower(msg)
	if msg == "bwf inv" then
		BWF:FriendInvite(sender)
	end
end

function BWF:CHAT_MSG_BN_WHISPER(self, msg, sender)
	msg = string.lower(msg)
	if msg == "bwf inv" and not (BWF:IsQueued() and db.queuesafe) then
		local _,name,game,realm = BNGetToonInfo(BNet_GetPresenceID(sender))

		if game == "WoW" then
			BWF:FriendInvite(name .. "-" .. realm)
		end
	end
end

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

function BWF:GROUP_ROSTER_UPDATE()
	--If someone has entered or left the party, then we want to reevaluate.
	if IsInGroup() and #grouproster ~= GetNumGroupMembers() - 1 then
		BWF:UpdateInternalGroupRoster()
		if UnitIsGroupLeader("player") then
			local type, count = BWF:GetGroupTypeAndCount()
			local fulloffriends = BWF:GroupFriendMakeup(type)
			if type == "party" then
				if fulloffriends and select(1, GetLootMethod()) ~= db.autosetloot_method then
					SetLootMethod(db.autosetloot_method, "player")
				elseif not fulloffriends and select(1, GetLootMethod()) ~= "group" then
					SetLootMethod("group")
				end
				--put marks up based on preferred options
			end
		elseif not wasingroup and autoaccepted and db.BWFad then
			SendChatMessage("Benefits With Friends: Auto-Accepted Invite!", "PARTY", nil)
			autoaccepted = false
		end
	end
	
	--You left a group.
	if not IsInGroup() and wasingroup then
		BWF:Print("You have left the group.")
		BWF:UpdateInternalGroupRoster()
	end

	if IsInGroup() and not wasingroup and not UnitIsGroupLeader("player") then 
		BWF:ClosePopup() 
		
	end	

	wasingroup = IsInGroup()
end

function BWF:PARTY_INVITE_REQUEST(info, sender)
	if not (BWF:IsQueued() and db.queuesafe) and db.autoacceptinv_enabled and BWF:IsAFriend(sender) then
		AcceptGroup()
		autoaccepted = true
	end
end

function BWF:LOOT_OPENED(info, auto)
	-- if auto == 1 then
	-- 		for i = 1,GetNumLootItems() do 
	-- 		local _,item = GetLootSlotInfo(i)
	-- 		print(item)
	-- 	end
	-- end
end

function BWF:ClosePopup()
	StaticPopup_Hide("PARTY_INVITE")
end

function BWF:UpdateInternalGroupRoster() 
	grouproster = {}
	for i = 2, GetNumGroupMembers() do
		name = GetRaidRosterInfo(i)
		table.insert(grouproster, name)
	end
end

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
--++++++++++++++++++   Slash Commands   ++++++++++++++++++--
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

BWF.Command = function(msg)
	if msg == "" then
		InterfaceOptionsFrame_OpenToCategory(BWF.optionsFrame)
		InterfaceOptionsFrame_OpenToCategory(BWF.optionsFrame)
	elseif BWF.Commands[msg] then
		BWF.Commands[msg].func()
	else
		return;
	end
end

BWF.Commands = {}

BWF.Commands["follow"] = {}
BWF.Commands["f"] = {}
BWF.Commands["follow"].func = 
	function()
		if UnitName("target") then
			SendAddonMessage("BWFmsg", "follow_me_" .. UnitName("target"), "RAID")
		else
			BWF:Print("You must target the person you want to follow you!")
		end
	end

BWF.Commands["f"].func = BWF.Commands["follow"].func

BWF.Commands["passlead"] = {}
BWF.Commands["passlead"].func = 
	function()
		if IsInGroup() then
			SendAddonMessage("BWFmsg", "passlead", "RAID")
		end
	end
		

BWF:RegisterChatCommand("bwftest", "BWFtestfunc")
SlashCmdList["benefitswithfriends"] = BWF.Command
SLASH_benefitswithfriends1 = "/benefitswithfriends"
SLASH_benefitswithfriends2 = "/bwf"

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
--++++++++++++++     Support Functions     +++++++++++++++--
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

--Gets the group's type and the number of people in it.
function BWF:GetGroupTypeAndCount()
	local type
	local count = GetNumGroupMembers()
	if IsInRaid() then 
		type = "raid"
	else
		type = "party"
	end
	count = count - 1
	return type, count
end 


--Checks to see if your group is made up of your friends!
function BWF:GroupFriendMakeup(type)
	local friendsinparty = 0
	if type == "party" then
		for i = 1, #grouproster, 1 do
			local partyname = grouproster[i]
			
			--This next part should be taken out and should instead implement the dedicated method: IsAFriend(name)
			if BWF:IsAFriend(partyname) then
				friendsinparty = friendsinparty + 1
			end	
		end
	end

	--print("Friends in party: " .. friendsinparty .. "/" .. #grouproster)
	if friendsinparty == #grouproster then
		return true
	else
		return false	
	end
end

function BWF:GetNumFriends()
	local total = 0
	local _,BNonlinefriends = BNGetNumFriends()
	for i = 1, BNonlinefriends do
		if select(7, BNGetFriendInfo(i)) == "WoW" then
			total = total + 1
		end
	end

	local _,onlinefriends = GetNumFriends()
	total = total + onlinefriends

	return total
end

function BWF:IsQueued()
	local lfdqueue = GetLFGQueueStats(LE_LFG_CATEGORY_LFD)
	local rfqueue = GetLFGQueueStats(LE_LFG_CATEGORY_RF)
	return (lfdqueue or rfqueue)
end

function BWF:BNPrintFriends()
	local _,onlinefriends = BNGetNumFriends()
	j = 1
	while j <= onlinefriends do 
		local _,_,_,_,name = BNGetFriendInfo(j)
		print(j .. ":  " .. name)
		j = j + 1			
	end		
end

--Checks to see if the given person is a friend or not!
function BWF:IsAFriend(name)
	name = BWF:SplitNameAndServer(name)[1]
	local value = false
	local _,BNonlinefriends = BNGetNumFriends()
 	local _,onlinefriends = GetNumFriends()
 	local friendslist = {}

 	if db.realID or db.btag then
	 	for i = 1, BNonlinefriends do
			local _,_,_,_,friend,_,game,_,_,_,_,_,RID = BNGetFriendInfo(i)
			if game == "WoW" then
				if (RID and db.realID) or (not RID and db.btag) then
					table.insert(friendslist, friend)
				end
			end
		end	
 	end

	if db.guildFriend then
	    local numGuildMembers, numOnline, numOnlineAndMobile = GetNumGuildMembers()
	    for i = 1, numGuildMembers do
		local fullName, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, reputation = GetGuildRosterInfo(i)
		table.insert(friendslist, BWF:SplitNameAndServer(fullName)[1])
	    end
	end
	
 	if db.character then
	 	for j = 1, onlinefriends do
			local friend = BWF:SplitNameAndServer(GetFriendInfo(j))[1]
			table.insert(friendslist, friend)
		end
 	end

	for i, friend in pairs(friendslist) do
		if name == friend then
			value = true
			break
		end
	end

	
	if value == true then
		--print(name .. " is a friend: True")
		return value	
	else
		--print(name .. " is a friend: False")
		return false
	end
end

function BWF:PrintListConents(list)
	for j, item in pairs(list) do
		print(item)
	end
end

function BWF:SplitNameAndServer(str)
	local result
	local dash = string.find(str, "-")

	if dash then
		result = {str:sub(1,dash-1), str:sub(dash+1,#str)}
	else 
		result = {str, "Server"}
	end

	return result
end

function BWF:PassLead(sender)
	if db.allowpasslead and UnitIsGroupLeader("player") and BWF:IsAFriend(sender) then
		local name = Ambiguate(sender, "none")
		PromoteToLeader(name)
		if db.BWFad then
			SendChatMessage("Benefits With Friends: Passing lead to " .. name .. "!", "PARTY", nil)
		end
	end
end

function BWF:FriendInvite(name)
	if db.allowfriendinv and UnitIsGroupLeader("player") and BWF:IsAFriend(name) then
		realname = Ambiguate(name, "none")
		InviteUnit(realname)
		if db.BWFad then
			SendChatMessage("Benefits With Friends: Inviting " .. realname .. " by request!", "PARTY", nil)
		end
	end
end

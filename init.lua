
irc_users = {}

local function notify(nick, message) 
	return mt_irc:queueMsg(mt_irc.msgs.privmsg(nick, message))
end

local old_chat_send_player = minetest.chat_send_player
minetest.chat_send_player = function(name, message)
	for nick, loggedInAs in pairs(irc_users) do
		if name == loggedInAs and not minetest.get_player_by_name(name) then
			notify(nick, message)
		end
	end
	return old_chat_send_player(name, message)
end

mt_irc:register_hook("NickChange", function(user, newNick)
	for nick, player in pairs(irc_users) do
		if nick == user.nick then
			irc_users[newNick] = irc_users[user.nick]
			irc_users[user.nick] = nil
		end
	end
end)

mt_irc:register_hook("OnQuit", function(user, reason)
	irc_users[user.nick] = nil
end)

mt_irc:register_bot_command("login", {
	params = "<username> <password>",
	description = "Login as a user to run commands",
	func = function(user, args)
		if args == "" then
			notify(user.nick, "You need a username and password")
			return
		end
		local found, _, playername, password = args:find("^([^%s]+)%s([^%s]+)$")
		if not found then
			playername = args
			password = ""
		end
		if minetest.auth_table[playername] and
		   minetest.auth_table[playername].password ==
		   minetest.get_password_hash(playername, password) then
			minetest.log("action", "User "..user.nick
					.." from IRC logs in as "..playername)
			irc_users[user.nick] = playername
			notify(user.nick, "You are now logged in as "..playername)
		else
			minetest.log("action", user.nick.."@IRC attempted to log in as "
				..playername.." unsuccessfully")
			notify(user.nick, "Incorrect password or player does not exist")
		end
end})

mt_irc:register_bot_command("logout", {
	description = "Logout",
	func = function (user, args)
		if irc_users[user.nick] then
			minetest.log("action", user.nick.."@IRC logs out from "
				..irc_users[user.nick])
			irc_users[user.nick] = nil
			notify(user.nick, "You are now logged off")
		else
			notify(from, "You are not logged in")
		end
end})

mt_irc:register_bot_command("cmd", {
	params = "<command>",
	description = "Run a command on the server",
	func = function (user, args)
		if args == "" then
			notify(user.nick, "You need a command")
			return
		end
		if not irc_users[user.nick] then
			notify(user.nick, "You are not logged in")
			return
		end
		local found, _, commandname, params = args:find("^([^%s]+)%s(.+)$")
		if not found then
			commandname = args
		end
		local command = minetest.chatcommands[commandname]
		if not command then
			notify(user.nick, "Not a valid command")
			return
		end
		if minetest.check_player_privs(irc_users[user.nick], command.privs) then
			minetest.log("action", user.nick.."@IRC runs "
				..args.." as "..irc_users[user.nick])
			command.func(irc_users[user.nick], (params or ""))
		end
end})

mt_irc:register_bot_command("say", {
	params = "message",
	description = "Say something",
	func = function (user, args)
		if args == "" then
			notify(from, "You need a message")
			return
		end
		if not irc_users[user.nick] then
			notify(user.nick, "You are not logged in")
			return
		end
		if minetest.check_player_privs(irc_users[user.nick], {shout=true}) then
			minetest.log("action", user.nick.."@IRC says "
				..args.." as "..irc_users[user.nick])
			minetest.chat_send_all("<"..irc_users[user.nick].."@IRC> "..args)
			notify(user.nick, "Message sent successfuly")
		end
end})


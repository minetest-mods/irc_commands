irc_users = {}

local old_chat_send_player = minetest.chat_send_player
minetest.chat_send_player = function(name, message)
	for nick, user in pairs(irc_users) do
		if name == user then
			mt_irc.say(nick, message)
		end
	end
	return old_chat_send_player(name, message)
end

mt_irc.register_bot_command("login", {
	params = "<username> <password>",
	description = "Login as a user to run commands",
	func = function (from, args)
		if (args == "") then
			mt_irc.say(from, "You need a username and password")
			return
		end
		local found, _, username, password = args:find("^([^%s]+)%s([^%s]+)$")
		if not found then
			username = args
		end
		if minetest.auth_table[username] and
		   minetest.auth_table[username].password == minetest.get_password_hash(username, (password or "")) then
			irc_users[from] = username
			mt_irc.say(from, "You are now logged in as "..username)
		else
			mt_irc.say(from, "Incorrect password or player does not exist")
		end
end})

mt_irc.register_bot_command("logout", {
	description = "Logout",
	func = function (from, args)
		irc_users[from] = nil
		mt_irc.say(from, "You are now logged off")
end})

mt_irc.register_bot_command("cmd", {
	params = "<command>",
	description = "Run a command on the server";
	func = function (from, args)
		if args == "" then
			mt_irc.say(from, "You need a command")
			return
		end
		if not irc_users[from] then
			mt_irc.say(from, "You are not loged in")
			return
		end
		local found, _, commandname, params = args:find("^([^%s]+)%s(.+)$")
		if not found then
			commandname = args
		end
		local command = minetest.chatcommands[commandname]
		if not command then
			mt_irc.say(from, "Not a valid command")
			return
		end
		if minetest.check_player_privs(irc_users[from], command.privs) then
			command.func(irc_users[from], (params or ""))
			mt_irc.say(from, "Command run successfuly")
		end
end})

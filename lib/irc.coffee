###
IRC Class

@author		Michael Owens
@website		http://www.michaelowens.nl
@copyright	Michael Owens 2011

@author		Shaun Walker
@website     http://www.theshaun.com
@copyright	Shaun Walker 2012
###

sys = require("util")
net = require("net")
fs = require("fs")
path = require("path")
User = require("./user")

module.exports = class Server extends process.EventEmitter
  constructor: (@config) ->
    {
      @logger
    } = @config

    @channels = {}
    @users = {}
    @hooks = []
    @triggers = []
    @replies = []
    @connection = null
    @buffer = ""
    @encoding = "utf8"
    @timeout = 60 * 60 * 1000

    # channel.initialize this  if typeof channel.initialize is "function"
    _this = this
    _this.on "numeric", (msg) ->
      command = msg.command
      return  if command isnt "353"
      chan = msg.arguments[2]

      # replace + and @ prefixes for channel privs, we only want the nick
      nicks = msg.arguments[3].replace(/\+|@/g, "").split(" ")
      chans = _this.channels
      user = null
      allusers = _this.users
      nick = undefined

      # TODO: support all channel prefixes - need to find proper documentation to list these
      return  if not chan or chan.charAt(0) isnt "#"
      chan = chans[chan]
      i = 0

      while i < nicks.length
        nick = nicks[i].toLowerCase()
        user = allusers[nick]
        user = allusers[nick] = new User(_this, nicks[i])  unless user
        user.join chan.name
        i++

    @plugins = []
    i = 0
    z = config.plugins.length

    while i < z
      p = config.plugins[i]
      @loadPlugin p
      i++

  parseMsg: (text) ->
    return false  if typeof text isnt "string"
    tmp = text.split(" ")
    return false  if tmp.length < 2
    prefix = null
    command = null
    lastarg = null
    args = []
    i = 0
    j = tmp.length

    while i < j
      if i is 0 and tmp[i].indexOf(":") is 0
        prefix = tmp[0].substr(1)
      else if tmp[i] is ""
        continue
      else if not command and tmp[i].indexOf(":") isnt 0
        command = tmp[i].toUpperCase()
      else if tmp[i].indexOf(":") is 0
        tmp[i] = tmp[i].substr(1)
        tmp.splice 0, i
        args.push tmp.join(" ")
        lastarg = args.length - 1
        break
      else
        args.push tmp[i]
      i++
    prefix: prefix
    command: command
    arguments: args
    lastarg: lastarg
    orig: text

  connect: ->
    c = @connection = net.createConnection(@config.port, @config.host)
    c.setEncoding @encoding
    c.setTimeout @timeout
    @addListener "connect", @onConnect
    @addListener "data", @onReceive
    @addListener "eof", @onEOF
    @addListener "timeout", @onTimeout
    @addListener "close", @onClose

  disconnect: (reason) ->
    if @connection.readyState isnt "closed"
      @connection.close()
      @logger.info "disconnected (" + reason + ")"

  onConnect: ->
    @logger.info "connected"
    @raw "PASS " + @config.zncIdent  if @config.zncIdent
    @raw "NICK", @config.nick
    @raw "USER", @config.username, "0", "*", ":" + @config.realname
    @emit "connect"

  onReceive: (chunk) ->
    @buffer += chunk
    while @buffer
      offset = @buffer.indexOf("\r\n")
      return  if offset < 0
      msg = @buffer.slice(0, offset)
      @buffer = @buffer.slice(offset + 2)
      @logger.verbose "< " + msg
      @onMessage @parseMsg msg

  onMessage: (msg) ->
    @logger.verbose "++ command: " + msg.command
    @logger.verbose "++ arguments: " + msg.arguments
    @logger.verbose "++ prefix: " + msg.prefix
    @logger.verbose "++ lastarg: " + msg.lastarg
    target = msg.arguments[0]
    nick = (@user(msg.prefix) or "").toLowerCase()
    user = @users[nick]
    m = undefined
    command = msg.command
    users = @users
    switch true
      when (command is "PING")
        @raw "PONG", msg.arguments
      when (command is "PRIVMSG")
        user.update msg.prefix  if user
        m = msg.arguments[1]
        if m.substring(0, 1) is @config.command
          trigger = m.split(" ")[0].substring(1, m.length)
          unless typeof @triggers[trigger] is "undefined"
            trig = @triggers[trigger]
            trig.callback.apply @plugins[trig.plugin], arguments
        if user is @config.nick
          @emit "private_message", msg
        else
          @emit "message", msg
      when (command is "JOIN")
        if user
          user.update msg.prefix
          user.join target
        else
          user = @users[nick] = new User(this, nick)
        user.join target
        @emit "join", msg
      when (command is "PART")
        if user
          user.update msg.prefix
          user.part target
        @emit "part", msg
      when (command is "QUIT")
        if user
          user.update msg.prefix
          user.quit msg
        @emit "quit", msg
      when (command is "NICK")
        user.update msg.prefix  if user
        @emit "nick", msg
      when (/^\d+$/.test(command))
        @emit "numeric", msg
    @emit msg.command, msg
    @emit "data", msg

  user: (mask) ->
    return  unless mask
    match = mask.match(/([^!]+)![^@]+@.+/)
    return  unless match
    match[1]

  onEOF: ->
    @disconnect "EOF"

  onTimeout: ->
    @disconnect "timeout"

  onClose: ->
    @disconnect "close"

  raw: (cmd) ->
    return @disconnect("cannot send with readyState " + @connection.readyState)  if @connection.readyState isnt "open"
    msg = Array::slice.call(arguments, 1).join(" ") + "\r\n"
    @logger.verbose ">" + cmd + " " + msg
    @connection.write cmd + " " + msg, @encoding

  send: (target, msg) ->
    msg = Array::slice.call(arguments, 1).join(" ") + "\r\n"
    @raw "PRIVMSG", target, ":" + msg  if arguments.length > 1

  addListener: (ev, f) ->
    that = this
    @connection.addListener ev, (->
      ->
        f.apply that, arguments
    )()

  addPluginListener: (plugin, ev, f) ->
    @hooks[plugin] = []  if typeof @hooks[plugin] is "undefined"
    callback = (->
      ->
        f.apply that, arguments
    )()
    @hooks[plugin].push
      event: ev
      callback: callback

    that = @plugins[plugin]
    @on ev, callback

  loadPlugin: (name) ->
    @unloadPlugin name
    that = this
    try
      p = require("../plugins/" + name)
      @plugins[name] = new p(this, name)
      ["connect", "data", "numeric", "message", "join", "part", "quit", "nick", "privateMessage"].forEach ((event) ->
        onEvent = "on" + event.charAt(0).toUpperCase() + event.substr(1)
        callback = @plugins[name][onEvent]
        @addPluginListener name, event, callback  if typeof callback is "function"
      ), this
    catch err
      @logger.error "Cannot load Plugin " + name + ": ", err.message
      throw "Error loading plugin"

  unloadPlugin: (name) ->
    unless typeof @plugins[name] is "undefined"
      delete @plugins[name]

      unless typeof @hooks[name] is "undefined"
        for hook of @hooks[name]
          @removeListener @hooks[name][hook].event, @hooks[name][hook].callback
      unless typeof @replies[name] is "undefined"
        for reply of @replies[name]
          @removeListener @replies[name][reply].event, @replies[name][reply].callback
      for trig of @triggers
        delete @triggers[trig]  if @triggers[trig].plugin is name
      p = path.normalize(__dirname + "/../plugins/" + name)
      delete require.cache[p + ".js"]

  addTrigger: (plugin, trigger, callback) ->
    if typeof @triggers[trigger] is "undefined"
      @triggers[trigger] =
        plugin: plugin.name
        callback: callback

  onReply: (plugin, ev, f) ->
    @replies[plugin] = []  if typeof @replies[plugin] is "undefined"
    callback = (->
      ->
        f.apply that, arguments
    )()
    @replies[plugin].push
      event: ev
      callback: callback

    that = @plugins[plugin]
    @on ev, callback

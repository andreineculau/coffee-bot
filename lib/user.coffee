module.exports = class User
  constructor: (irc, mask) -> # fully qualified irc hostmask - nick!ident@host
    @irc = irc
    @logger = irc.logger
    @channels = []
    @passive = true
    @nick = ""
    @ident = ""
    @host = ""
    @update mask

  update: (mask) ->
    match = mask.match(/([^!]+)!([^@]+)@(.+)/)
    if not match and @passive is true

      # this happens when only a nick is available IE: on join's 353 numeric
      @nick = mask
      @ident = ""
      @host = ""
    else
      @passive = false
      @nick = match[1]
      @ident = match[2]
      @host = match[3]
    @nick = @nick.replace(/\+|@/, "")

  changeNick: (newnick) ->
    irc = @irc
    allusers = irc.users
    oldnick = @nick
    user = allusers[oldnick]
    userchans = user.channels
    allchans = irc.channels
    userchans.forEach (channel) ->
      chan = allchans[channel]
      idx = chan.users.indexOf(oldnick)
      chan.users[idx] = newnick  if idx isnt -1

    allusers[newnick] = user
    delete allusers[oldnick]

    @logger.info "CHANGENICK: ", allusers

  join: (channel) ->
    unless channel
      @logger.error "FAIL USER JOIN: ", @nick
      return
    channels = @channels
    chan = @irc.channels[channel]
    unless @isOn(channel)
      @channels.push channel
      chan.users.push @nick

  part: (channel) -> # string or Channel object
    channel = channel.name  if typeof channel is "object"
    unless channel
      @logger.error "FAIL USER PART: ", @nick
      return
    channels = @channels
    irc = @irc
    allchans = irc.channels
    allusers = irc.users
    chan = allchans[channel]
    if @isOn(channel)
      chan.users.splice chan.users.indexOf(@nick), 1
      channels.splice channels.indexOf(channel), 1
      delete allchans[channel]  if chan.users.length is 0
    console.log chan.users.join(" ")
    delete allusers[@nick]  if @channels.length is 0 and @nick isnt irc.nick

  quit: (msg) ->
    allchans = @irc.channels
    chan = undefined
    idx = undefined
    for chanName of allchans
      chan = allchans[chanName]
      idx = chan.users.indexOf(@nick)
      chan.users.splice idx, 1  unless idx is -1
    delete @irc.users[@nick]

  isOn: (channel) ->
    chans = @channels
    (chans.indexOf(channel) isnt -1)

  msg: (target, msg) ->
    @irc.send target, msg

  send: (msg) ->
    @irc.send @nick, msg

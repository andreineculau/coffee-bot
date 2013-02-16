module.exports = class Channel
  constructor: (irc, room, join, password) ->
    @irc = irc
    @name = room
    @inRoom = false
    @password = password
    @users = []
    @join()  if join

  join: ->
    chans = @irc.channels
    name = @name
    chans[name] = this
    @irc.raw "JOIN", name, @password
    @inRoom = true

  part: (msg) ->
    user = null
    users = [].concat(@users)
    userCount = users.length
    allusers = @irc.users
    chans = @irc.channels
    @irc.raw "PART", @name, ":" + msg
    @inRoom = false
    i = 0

    while i < userCount
      user = allusers[users[i]]

      # if user is only in 1 channel and channel is this one
      user.part this  if typeof user isnt "undefined" and user.isOn(@name)
      i++

  send: (msg) ->
    @irc.send @name, msg

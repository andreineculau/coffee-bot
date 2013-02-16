###
Global Functionalities and Boot Up

@author		Michael Owens
@website		http://www.michaelowens.nl
@copyright	Michael Owens 2011
###

Plugin = require '../lib/plugin'
Channel = require '../lib/channel'
module.exports = class PluginGlobal extends Plugin
  onNumeric: (context) ->
    # 376 is end of MOTD/modes
    return  if context.command isnt '376'
    userchans = @irc.config.channels # userchannels
    i = 0

    while i < userchans.length
      channelName = userchans[i]
      password = undefined
      if typeof (channelName) is 'object'
        password = channelName.password
        channelName = channelName.name
      chan = new Channel(@irc, channelName, true, password)
      @irc.channels[chan.name] = chan
      i++

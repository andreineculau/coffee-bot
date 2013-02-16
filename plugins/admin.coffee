###
Admin Plugin

@author      Markus M. May
@website     http://www.javafreedom.org
@copyright   Markus M. May 2013

Provides some basic functionalities like changing nick
###

Plugin = require '../lib/plugin'
Channel = require '../lib/channel'
module.exports = class PluginGlobal extends Plugin

module.exports = class PluginAdmin extends Plugin
  constructor: (ph) ->
    super
    @addTrigger 'admin', @trigAdmin

  trigAdmin: (msg) ->
    {args, answer} = @parse msg
    command = args.shift()

    switch command
      when 'nick'
        return  if typeof args[0] is 'undefined'
        @irc.raw 'NICK', args[0]
        answer 'there! better?'
      when 'join'
        return  if typeof args[0] is 'undefined'
        chan = new Channel(@irc, args[0], true, args[1])
        @irc.channels[chan.name] = chan
        answer "joined #{chan.name}"
      when 'part'
        return  if typeof args[0] is 'undefined'
        chan = @irc.channels[args[0]]
        if typeof chan isnt 'undefined'
          # could lead to errors, need to fix
          chan.part 'admin requested me to leave!'
          delete @irc.channels[args[0]]
          answer "parted #{chan.name}"

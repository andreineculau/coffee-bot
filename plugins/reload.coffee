###
Reload Plugin

@author		  Michael Owens
@website		http://www.michaelowens.nl
@copyright	Michael Owens 2011
###

Plugin = require '../lib/plugin'
module.exports = class PluginReload extends Plugin
  constructor: (@irc, @name) ->
    super
    @addTrigger 'reload', @loadPlugin
    @addTrigger 'unload', @unloadPlugin

  loadPlugin: (context) ->
    {args, answer} = @parse context
    answer "reloading #{args[0]}"
    @irc.loadPlugin args[0]

  unloadPlugin: (context) ->
    {args, answer} = @parse context
    answer "unloading #{args[0]}"
    @irc.unloadPlugin args[0]


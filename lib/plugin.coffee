module.exports = class Plugin
  constructor: (@irc, @name) ->
    @config = @irc.config.pluginConfigs[@name] or {}  if @name

  parse: (context) ->
    user = @irc.user context.prefix
    channel = context.arguments[0]
    isPrivMsg = user is channel
    channel = @irc.channels[channel]
    msg = context.arguments[1]
    args = msg.split(' ').slice 1

    answer = (msg) ->
      prefix = ''
      prefix = user + ': '  unless isPrivMsg
      channel.send prefix + msg

    result =
      user: user
      channel: channel
      args: args or []
      answer: answer

    result

  addTrigger: (trigger, callback) ->
    @irc.addTrigger @, trigger, callback

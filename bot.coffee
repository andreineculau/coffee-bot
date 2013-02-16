#!/usr/bin/env coffee

argv = require('optimist').options({
    config: {
      default: 'config'
    }
  }).argv
pkgconfig = require 'pkgconfig'
winston = require 'winston'
irc = require './lib/irc'

config = pkgconfig {
  schema: 'config/schema.json'
  config: 'config/' + argv.config + '.json'
}

config.logger = new winston.Logger
config.logger.add winston.transports[transport], options  for transport, options  of config.log

new irc(config).connect()

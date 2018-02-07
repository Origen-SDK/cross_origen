# This file is similar to environment.rb and will be loaded
# automatically at the start of each invocation of Origen.
#
# However the major difference is that it will not be loaded
# if the application is imported by a 3rd party app - in that
# case only environment.rb is loaded.
#
# Therefore this file should be used to load anything you need
# to setup a development environment for this app, normally
# this would be used to load some dummy classes to instantiate
# your objects so that they can be tested and/or interacted with
# in the console.
require "cross_origen_dev/dut"

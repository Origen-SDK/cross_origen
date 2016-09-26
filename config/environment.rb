# This file will be required by Origen before your target is loaded, you
# can use this to require all of your files, which is the easiest way
# to get started. As your experience grows you may wish to require only the
# minimum files required to allow the target to be initialized and let
# each class require its own dependencies.
#
# It is recommended that you keep all of your application logic in lib/
# The lib directory has already been added to the search path and so any files
# in there can be referenced from here with a relative path.
#
# Note that pattern files do not need to be referenced from here and these
# will be located automatically by origen.

# This says load the file "lib/pioneer.rb" the first time anyone makes a
# reference to the class name 'Pioneer'.
#autoload :Pioneer,   "pioneer"
# This is generally preferable to using require which will load the file
# regardless of whether it is needed by the current target or not:
#require "pioneer"
# Sometimes you have to use require however:-
#   1. When defining a test program interface:
#require "interfaces/j750"
#   2. If you want to extend a class defined by an imported application, in
#      this case your must use required and supply a full path (to distinguish
#      it from the one in the parent application):
#require "#{Origen.root}/c90_top_level/p2"
module CrossOrigen
  autoload :XMLDoc,       "cross_origen/xml_doc"
  autoload :Headers,      "cross_origen/headers"
  autoload :Ralf,         "cross_origen/ralf"
  autoload :IpXact,       "cross_origen/ip_xact"
  autoload :DesignSync,   "cross_origen/design_sync"
  autoload :OrigenFormat, "cross_origen/origen_format"
  autoload :CMSISSVD,     "cross_origen/cmsis_svd"
end
require "cross_origen"

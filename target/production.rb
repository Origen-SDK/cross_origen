# The target file is run before *every* Origen operation and is used to instantiate
# the runtime environment - usually this means instantiating a top-level DUT
# object and a tester.
#
# Naming is arbitrary but instances names should be prefixed with $ which indicates a 
# global variable in Ruby, and this is required in order for the objects instantiated
# here to be visible throughout your application code.

#$tester = Origen::Tester::J750.new  # Set the tester to the Origen J750 model
$dut = CrossOrigen::Test::DUT.new             # Instantiate an SoC instance

# You can also perform global configuration here, e.g. 
# $dut.do_something_before_every_job

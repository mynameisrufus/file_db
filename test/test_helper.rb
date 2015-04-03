$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__)))

require 'minitest/autorun'
require 'minitest/reporters'
require 'pry'

Minitest::Reporters.use!(Minitest::Reporters::DefaultReporter.new(color: true))

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'asha'

require 'minitest/autorun'
require 'minitest/reporters'

MiniTest::Reporters.use!

Asha.establish_connection(host: '127.0.0.1', db: 1)
Asha.database.flushdb
require "active_record"
require "pg"
require "logger"

ActiveRecord::Base.logger = Logger.new("tmp/test.log")
config = YAML::load(IO.read("config/database.yml"))
ActiveRecord::Base.establish_connection(config["development"])

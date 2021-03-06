require 'fileutils'

desc "Generates one or more files in your project. Valid options are ALL (controller, view and model), CONTROLLER, VIEW, and MODEL. Specify a target 'base' i.e. generate MODEL='src/foo' would generate src/foo_model.rb"
task 'generate'
rule(/^generate/) do |t|
  ARGV[1..-1].each do |generator_command|
    command, argument = generator_command.split("=")
    case command
    when "ALL"
      generate_tuple(argument)
    when "VIEW"
      generate_view(argument)
    when "CONTROLLER"
      generate_controller(argument)
    when "MODEL"
      generate_model(argument)
    else
      $stdout << "Unknown generate target #{argument}"
    end
  end
end

def generate_tuple(path)
  pwd = FileUtils.pwd
  generate_controller(path)
  FileUtils.cd(pwd)
  generate_model(path)
  FileUtils.cd(pwd)
  generate_view(path)
end

def generate_controller(path)
  name = setup_directory(path)
  file_name = "#{name}_controller.rb"
  name = camelize(name)
  $stdout << "Generating controller #{name}Controller in file #{file_name}\n"
  controller = File.new(file_name, "w")
  controller << <<-ENDL
class #{name}Controller < ApplicationController
  set_model '#{name}Model'
  set_view '#{name}View'
  set_close_action :exit
end
  ENDL
end

def generate_model(path)
  name = setup_directory(path)
  file_name = "#{name}_model.rb"
  name = camelize(name)
  $stdout << "Generating model #{name}Model in file #{file_name}\n"
  model = File.new(file_name, "w")
  model << <<-ENDL
class #{name}Model

end
  ENDL
end

def generate_view(path)
  name = setup_directory(path)
  file_name = "#{name}_view.rb"
  name = camelize(name)
  $stdout << "Generating view #{name}View in file #{file_name}\n"
  view = File.new(file_name, "w")
  view << <<-ENDL
class #{name}View < ApplicationView
  set_java_class ''
end
  ENDL
end

def setup_directory(path)
  FileUtils.mkdir_p path.gsub("\\", "/")
  FileUtils.cd(path)
  path.split("/").last
end

def camelize(name, first_letter_in_uppercase = true)
  name = name.to_s
  if first_letter_in_uppercase
    name.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
  else
    name[0..0] + camelize(name[1..-1])
  end
end
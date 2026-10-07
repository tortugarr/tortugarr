#!/usr/bin/env ruby
# Wires the native games module into the Runner project:
#  - adds Runner/Games/* sources to the target
#  - embeds each Frameworks/Cores/*.framework with code-sign-on-copy, WITHOUT
#    linking it (cores are dlopen'd; linking them would collide on retro_* symbols)
require 'xcodeproj'

project_dir = File.expand_path(File.join(__dir__, '..'))
project_path = File.join(project_dir, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' } or abort('Runner target not found')

# -- Runner/Games sources -------------------------------------------------
games_group = project.main_group.find_subpath('Runner/Games', true)
games_group.set_source_tree('SOURCE_ROOT')
games_group.set_path('Runner/Games')

source_exts = %w[.swift .c .m .mm]
abs_files = Dir.glob(File.join(project_dir, 'Runner/Games/*'))
  .select { |f| source_exts.include?(File.extname(f)) }.sort
basenames = abs_files.map { |f| File.basename(f) }

project.files.select { |f| basenames.include?(File.basename(f.path.to_s)) }.each do |f|
  f.referrers.grep(Xcodeproj::Project::Object::PBXBuildFile).each(&:remove_from_project)
  f.remove_from_project
end

abs_files.each do |abs|
  ref = games_group.new_reference(abs)
  target.add_file_references([ref]) unless File.extname(abs) == '.h'
  puts "added source: #{File.basename(abs)}"
end

# -- Core frameworks: embed + sign, no link -------------------------------
frameworks = Dir.glob(File.join(project_dir, 'Frameworks/Cores/*.framework')).sort
abort('no core frameworks found - run scripts/cores/wrap_frameworks.sh first') if frameworks.empty?

cores_group = project.main_group.find_subpath('Frameworks/Cores', true)
cores_group.set_source_tree('SOURCE_ROOT')
cores_group.set_path('Frameworks/Cores')

embed_name = 'Embed Libretro Cores'
embed = target.copy_files_build_phases.find { |p| p.name == embed_name }
unless embed
  embed = target.new_copy_files_build_phase(embed_name)
  embed.symbol_dst_subfolder_spec = :frameworks
end

fw_basenames = frameworks.map { |f| File.basename(f) }
project.files.select { |f| fw_basenames.include?(File.basename(f.path.to_s)) }.each do |f|
  f.referrers.grep(Xcodeproj::Project::Object::PBXBuildFile).each(&:remove_from_project)
  f.remove_from_project
end

frameworks.each do |abs|
  ref = cores_group.new_reference(abs)
  bf = embed.add_file_reference(ref)
  bf.settings = { 'ATTRIBUTES' => %w[CodeSignOnCopy RemoveHeadersOnCopy] }
  puts "embedded core: #{File.basename(abs)}"
end

project.save
puts 'saved project'

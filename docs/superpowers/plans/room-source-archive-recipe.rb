# Run from the project root:
# ruby docs/superpowers/plans/room-source-archive-recipe.rb
# Replaces only this generated Room source archive; no previous archive is touched.
require 'digest'
require 'find'
require 'open3'

target = 'dist/color-lab-room-masks-2026-10-22.zip'
roots = %w[lib assets test tool docs android ios]
root_files = %w[README.md pubspec.yaml pubspec.lock analysis_options.yaml .metadata .gitignore]
excluded_parts = %w[build .dart_tool .idea dist .git .codex .agents .aws .gradle
                    .kotlin Pods .symlinks xcuserdata ephemeral .cache DerivedData]
excluded_names = %w[local.properties Generated.xcconfig flutter_export_environment.sh
                    GeneratedPluginRegistrant.java GeneratedPluginRegistrant.h
                    GeneratedPluginRegistrant.m generated_plugin_registrant.cc
                    generated_plugin_registrant.h generated_plugins.cmake
                    .flutter-plugins .flutter-plugins-dependencies .DS_Store
                    Flutter.podspec key.properties IDEWorkspaceChecks.plist WorkspaceSettings.xcsettings]
excluded_extensions = %w[.apk .aab .zip .iml .dylib .so .dll .exe .p12 .jks .keystore]
exclude = lambda do |path|
  parts = path.split('/')
  parts.any? { |part| excluded_parts.include?(part) || part.start_with?('.env') } ||
    excluded_names.include?(parts.last) ||
    excluded_extensions.include?(File.extname(path).downcase) ||
    parts.any? { |part| part.match?(/\A(?:secrets?|credentials)(?:\.|\z)/i) }
end

files = root_files.dup
roots.each do |root|
  Find.find(root) do |path|
    raise "Unexpected symlink: #{path}" if File.symlink?(path)
    if exclude.call(path)
      Find.prune if File.directory?(path)
      next
    end
    files << path if File.file?(path)
  end
end
files.sort!
raise 'Duplicate manifest paths' unless files.uniq == files
raise 'Unsafe manifest path' if files.any? { |path| path.start_with?('/') || path.split('/').include?('..') || path.include?("\n") }
raise 'Missing source file' unless files.all? { |path| File.file?(path) }
required = %w[lib/main.dart assets/models/room_seg.tflite assets/models/room_seg_descriptor.json
              assets/licenses/room-model-LICENSE.txt assets/licenses/room-model-NOTICE.txt
              test/fixtures/room/reference_masks.bin test/fixtures/room/reference_masks.json
              test/fixtures/room/reference_room.png test/fixtures/room/reference_input.bin
              tool/deny-native-compilers.sb tool/render_previews.dart tool/run_room_model_smoke.dart
              android/gradle/wrapper/gradle-wrapper.jar android/gradlew android/gradlew.bat
              ios/Podfile ios/Runner.xcodeproj/project.pbxproj
              docs/superpowers/plans/room-task-10-report.md README.md pubspec.lock .metadata .gitignore]
raise "Required sources missing: #{required - files}" unless (required - files).empty?
parent = File.dirname(target)
# Fresh extracted deliveries intentionally exclude dist. Create only this exact
# parent, never follow a symlink or recursively create arbitrary ancestors.
Dir.mkdir(parent) unless File.exist?(parent) || File.symlink?(parent)
raise 'Refuse a symlink/non-directory output parent' unless File.directory?(parent) && !File.symlink?(parent)
if File.exist?(target) || File.symlink?(target)
  raise 'Refuse a symlink/non-file target' unless File.file?(target) && !File.symlink?(target)
  # -FS synchronizes only this authorized generated target, removing obsolete entries.
end
stdout, stderr, result = Open3.capture3('zip', '-q', '-FS', target, '-@', stdin_data: files.join("\n") + "\n")
raise "zip failed: #{stdout}#{stderr}" unless result.success?
stdout, stderr, result = Open3.capture3('unzip', '-tq', target)
raise "Integrity failure: #{stdout}#{stderr}" unless result.success?
puts stdout
entries, stderr, result = Open3.capture3('unzip', '-Z1', target)
raise stderr unless result.success?
entries = entries.lines.map(&:chomp)
raise 'Duplicate/unsafe archive entries' unless entries.uniq == entries && entries.none? { |path| path.start_with?('/') || path.split('/').include?('..') }
raise 'Archive differs from source manifest' unless entries.sort == files
raise 'Excluded file leaked' if entries.any? { |path| exclude.call(path) }
files.each do |path|
  bytes, error, status = Open3.capture3('unzip', '-p', target, path)
  raise "Archived bytes differ: #{path}: #{error}" unless status.success? && bytes.b == File.binread(path)
end
puts "PASS: #{entries.length} project-relative entries; all source bytes equal; required sources included; exclusions clean"
puts "#{Digest::SHA256.file(target).hexdigest}  #{target}"

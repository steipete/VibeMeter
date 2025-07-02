#!/bin/bash
# Setup xcconfig files in Xcode project
# This ensures version.xcconfig values are properly used

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔧 Setting up xcconfig files in Xcode project..."

# Create a temporary Ruby script to modify the Xcode project
cat > "$PROJECT_ROOT/setup_xcconfig.rb" << 'RUBY_SCRIPT'
#!/usr/bin/env ruby

require 'xcodeproj'

project_path = ARGV[0]
project = Xcodeproj::Project.open(project_path)

# Find the xcconfig files
shared_config = project.files.find { |f| f.path == "VibeMeter/Shared.xcconfig" }
debug_config = project.files.find { |f| f.path == "VibeMeter/Debug.xcconfig" }
release_config = project.files.find { |f| f.path == "VibeMeter/Release.xcconfig" }

if shared_config.nil?
  puts "❌ Could not find Shared.xcconfig in project"
  exit 1
end

# Set the configuration files for each target
project.targets.each do |target|
  next unless target.name == "VibeMeter" || target.name == "VibeMeterTests"
  
  target.build_configurations.each do |config|
    if config.name == "Debug"
      config.base_configuration_reference = debug_config || shared_config
      puts "✅ Set Debug configuration for #{target.name}"
    elsif config.name == "Release"
      config.base_configuration_reference = release_config || shared_config
      puts "✅ Set Release configuration for #{target.name}"
    end
  end
end

# Also set for the project itself
project.build_configurations.each do |config|
  if config.name == "Debug"
    config.base_configuration_reference = debug_config || shared_config
    puts "✅ Set Debug configuration for project"
  elsif config.name == "Release"
    config.base_configuration_reference = release_config || shared_config
    puts "✅ Set Release configuration for project"
  end
end

project.save
puts "✅ Project saved with xcconfig references"
RUBY_SCRIPT

# Check if xcodeproj gem is installed
if ! gem list xcodeproj -i > /dev/null 2>&1; then
    echo "📦 Installing xcodeproj gem..."
    sudo gem install xcodeproj
fi

# Run the Ruby script
ruby "$PROJECT_ROOT/setup_xcconfig.rb" "$PROJECT_ROOT/VibeMeter.xcodeproj"

# Clean up
rm -f "$PROJECT_ROOT/setup_xcconfig.rb"

echo "✅ xcconfig setup complete!"
echo ""
echo "The project now uses:"
echo "  - Debug builds: Debug.xcconfig → Shared.xcconfig → version.xcconfig"
echo "  - Release builds: Release.xcconfig → Shared.xcconfig → version.xcconfig"
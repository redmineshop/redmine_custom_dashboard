# Zeitwerk-compatible version module.
# Zeitwerk maps lib/redmine_custom_dashboard/version.rb → RedmineCustomDashboard::Version.
module RedmineCustomDashboard
  module Version
    STRING = '1.1.0'
  end

  VERSION = Version::STRING
end

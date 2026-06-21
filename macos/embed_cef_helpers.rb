# webview_cef — macOS multi-process helper installer.
#
# Call from your macOS Podfile's post_install hook to make CEF run multi-process.
# It adds an "Embed CEF Helpers" run-script build phase to your app (Runner)
# target; that phase clones the prebuilt CEF helper into the five sub-process
# .app bundles inside your app's Frameworks dir on every build. No manual Xcode
# changes are required.
#
#   post_install do |installer|
#     installer.pods_project.targets.each do |target|
#       flutter_additional_macos_build_settings(target)
#     end
#     require File.expand_path(
#       'Flutter/ephemeral/.symlinks/plugins/webview_cef/macos/embed_cef_helpers.rb', __dir__)
#     WebviewCEF.install_helper_phase(installer)
#   end
#
# Without this hook the plugin still works, but falls back to single-process.
module WebviewCEF
  PHASE_NAME = 'Embed CEF Helpers'.freeze
  SCRIPT = 'bash "${SRCROOT}/Flutter/ephemeral/.symlinks/plugins/webview_cef/macos/scripts/embed_cef_helpers.sh"'.freeze

  def self.install_helper_phase(installer)
    installer.aggregate_targets.each do |aggregate|
      project = aggregate.user_project
      next unless project

      aggregate.user_targets.each do |target|
        # Only application targets get a bundle to embed helpers into.
        next unless target.product_type == 'com.apple.product-type.application'

        # Idempotent: drop a previous phase before re-adding.
        target.build_phases.delete_if do |ph|
          ph.respond_to?(:name) && ph.name == PHASE_NAME
        end

        phase = target.new_shell_script_build_phase(PHASE_NAME)
        phase.shell_path = '/bin/bash'
        phase.shell_script = SCRIPT
        # Runs every build; cloning is cheap and keeps helpers in sync.
        phase.always_out_of_date = '1' if phase.respond_to?(:always_out_of_date=)
        puts "webview_cef: added '#{PHASE_NAME}' phase to target '#{target.name}'."
      end

      project.save
    end
  end
end

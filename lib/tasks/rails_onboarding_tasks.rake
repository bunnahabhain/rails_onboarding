namespace :rails_onboarding do
  desc "Validate that host application meets all RailsOnboarding requirements"
  task validate: :environment do
    puts "\n" + "=" * 80
    puts "RailsOnboarding Requirements Validation"
    puts "=" * 80 + "\n"

    begin
      results = RailsOnboarding::RequirementsValidator.check

      # Print info
      if results[:info].any?
        puts "\nValidation Results:"
        results[:info].each { |info| puts "  #{info}" }
      end

      # Print warnings
      if results[:warnings].any?
        puts "\n⚠️  WARNINGS (#{results[:warnings].size}):"
        results[:warnings].each { |warning| puts "  ⚠  #{warning}" }
      end

      # Print errors
      if results[:errors].any?
        puts "\n❌ ERRORS (#{results[:errors].size}):"
        results[:errors].each { |error| puts "  ✗ #{error}" }
        puts "\n" + "=" * 80
        puts "❌ Validation FAILED - Please fix the errors above"
        puts "=" * 80 + "\n"
        exit 1
      else
        puts "\n" + "=" * 80
        puts "✅ All requirements validated successfully!"
        puts "=" * 80 + "\n"
      end
    rescue => e
      puts "\n❌ Error running validation: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
      exit 1
    end
  end

  desc "Display RailsOnboarding configuration"
  task config: :environment do
    puts "\n" + "=" * 80
    puts "RailsOnboarding Configuration"
    puts "=" * 80 + "\n"

    config = RailsOnboarding.configuration

    puts "User Class: #{config.user_class_name}"
    puts "Steps: #{config.steps.size} configured"
    config.steps.each_with_index do |step, index|
      puts "  #{index + 1}. #{step[:name]} - #{step[:title]} #{'(skippable)' if step[:skippable]}"
    end

    puts "\nFeatures:"
    puts "  Tooltips: #{config.enable_tooltips ? '✓ enabled' : '✗ disabled'}"
    puts "  Milestones: #{config.enable_milestones ? '✓ enabled' : '✗ disabled'}"
    puts "  Emails: #{config.enable_emails ? '✓ enabled' : '✗ disabled'}"

    puts "\nRedirects:"
    puts "  After completion: #{config.redirect_after_completion || 'not configured'}"
    puts "  After skip: #{config.redirect_after_skip || 'not configured'}"

    puts "\nOptional Dependencies:"
    puts "  ActiveJob: #{RailsOnboarding.active_job_available? ? '✓' : '✗'}"
    puts "  ActionMailer: #{RailsOnboarding.action_mailer_available? ? '✓' : '✗'}"
    puts "  ActionMailer configured: #{RailsOnboarding.action_mailer_configured? ? '✓' : '✗'}"
    puts "  Devise: #{defined?(Devise) ? '✓' : '✗'}"
    puts "  Turbo: #{defined?(Turbo) ? '✓' : '✗'}"
    puts "  Stimulus: #{defined?(Stimulus) ? '✓' : '✗'}"

    puts "\n" + "=" * 80 + "\n"
  end

  desc "Reset onboarding for a user (provide USER_ID=123)"
  task reset_user: :environment do
    user_id = ENV["USER_ID"]

    unless user_id
      puts "❌ Error: Please provide USER_ID environment variable"
      puts "Usage: rake rails_onboarding:reset_user USER_ID=123"
      exit 1
    end

    user_class = RailsOnboarding.configuration.user_class_name.constantize
    user = user_class.find_by(id: user_id)

    unless user
      puts "❌ Error: User with ID #{user_id} not found"
      exit 1
    end

    user.reset_onboarding!
    puts "✅ Onboarding reset for user ##{user_id}"
  rescue => e
    puts "❌ Error: #{e.message}"
    exit 1
  end

  desc "Mark pre-existing users as already onboarded (BEFORE=2026-01-01 DRY_RUN=true)"
  task backfill_existing_users: :environment do
    options = {
      created_before: ENV["BEFORE"].presence,
      dry_run: ENV["DRY_RUN"].to_s.downcase.in?(%w[1 true yes]),
      batch_size: (ENV["BATCH_SIZE"].presence || RailsOnboarding::Backfill::DEFAULT_BATCH_SIZE).to_i
    }.compact

    puts "\n" + "=" * 80
    puts "RailsOnboarding Backfill"
    puts "=" * 80 + "\n"

    puts "User class: #{RailsOnboarding::Backfill.user_class.name}"
    puts "Cutoff: #{options[:created_before] || 'none (all users who never started onboarding)'}"
    puts "Batch size: #{options[:batch_size]}"
    puts "Mode: #{options[:dry_run] ? 'DRY RUN (no writes)' : 'LIVE'}"
    puts

    result = RailsOnboarding::Backfill.mark_existing_users_onboarded(**options)

    if result.dry_run?
      puts "Would mark #{result.matched} user(s) as onboarded."
      puts "Re-run without DRY_RUN=true to apply."
    else
      puts "✅ Marked #{result.updated} of #{result.matched} matched user(s) as onboarded."
      puts "   onboarding_completed_at was set from each user's created_at where available."
    end

    puts "\n" + "=" * 80 + "\n"
  rescue => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
    exit 1
  end

  desc "Show onboarding statistics"
  task stats: :environment do
    user_class = RailsOnboarding.configuration.user_class_name.constantize

    total_users = user_class.count
    completed_users = user_class.where(onboarding_completed: true).count
    skipped_users = user_class.where(onboarding_skipped: true).count
    in_progress = total_users - completed_users - skipped_users

    completion_rate = total_users > 0 ? (completed_users.to_f / total_users * 100).round(2) : 0

    puts "\n" + "=" * 80
    puts "RailsOnboarding Statistics"
    puts "=" * 80 + "\n"

    puts "Total Users: #{total_users}"
    puts "Completed Onboarding: #{completed_users} (#{completion_rate}%)"
    puts "Skipped Onboarding: #{skipped_users}"
    puts "In Progress: #{in_progress}"

    puts "\n" + "=" * 80 + "\n"
  rescue => e
    puts "❌ Error: #{e.message}"
    exit 1
  end
end

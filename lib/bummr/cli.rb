TEST_COMMAND = ENV["BUMMR_TEST"] || "bundle exec rake"
BASE_BRANCH = ENV["BASE_BRANCH"] || "master"

module Bummr
  class CLI < Thor
    include Bummr::Log

    desc "check", "Run automated checks to see if bummr can be run"
    def check(fullcheck=true)
      Bummr::Check.instance.check(fullcheck)
    end

    desc "update", "Update outdated gems, run tests, bisect if tests fail"
    method_option :all, type: :boolean, default: false
    method_option :group, type: :string
    def update
      system("bundle install")

      log("Bummr update initiated #{Time.now}")

      outdated_gems = Bummr::Outdated.instance.outdated_gems(
        all_gems: options[:all], group: options[:group]
      )

      if outdated_gems.empty?
        puts "No outdated gems to update".color(:green)
      else
        Bummr::Updater.new(outdated_gems).update_gems

        system("git rebase #{BASE_BRANCH}")
        test
      end
    end

    desc "test", "Test for a successful build and bisect if necesssary"
    def test
      check(false)

      system "bundle install"
      puts "Testing the build!".color(:green)

      if system(TEST_COMMAND) == false
        bisect
      else
        puts "Passed the build!".color(:green)
        puts "See log/bummr.log for details".color(:yellow)
      end
    end

    desc "bisect", "Find the bad commit, remove it, test again"
    def bisect
      check(false)

      Bummr::Bisecter.instance.bisect
    end

    desc "remove_commit", "Remove a commit from the history"
    def remove_commit(sha)
      Bummr::Remover.instance.remove_commit(sha)
    end
  end
end

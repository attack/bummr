module Bummr
  class Bisecter
    include Singleton

    def bisect
      puts "Bad commits found! Bisecting...".color(:red)

      system("bundle")
      system("git bisect start")
      system("git bisect bad")
      system("git bisect good #{BASE_BRANCH}")

      bad_sha = nil
      Open3.popen2e("git bisect run #{TEST_COMMAND}") do |_std_in, std_out_err|
        while line = std_out_err.gets
          puts line

          sha_regex = Regexp::new("(.*) is the first bad commit\n").match(line)
          unless sha_regex.nil?
            sha = sha_regex[1]
          end

          if line == "bisect run success\n"
            bad_sha = sha
            Bummr::Remover.instance.remove_commit(sha)
          end
        end
      end

      puts " DEBUG: before reset"
      system("git log --oneline -20")
      system("git bisect reset")

      puts " DEBUG: after reset"
      system("git log --oneline -20")

      bad_sha
    end
  end
end

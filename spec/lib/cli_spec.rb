require 'spec_helper'

describe Bummr::CLI do
  # https://github.com/wireframe/gitx/blob/171da367072b0e82d5906d1e5b3f8ff38e5774e7/spec/thegarage/gitx/cli/release_command_spec.rb#L9
  let(:args) { [] }
  let(:options) { {} }
  let(:config) { { pretend: true } }
  let(:cli) { described_class.new(args, options, config) }
  let(:git) { Bummr::Git.instance }
  let(:outdated_gems) {
    [
      { name: "myGem", installed: "0.3.2", newest: "0.3.5" },
      { name: "otherGem", installed: "1.3.2.23", newest: "1.6.5" },
      { name: "thirdGem", installed: "4.3.4", newest: "5.6.45" },
    ]
  }

  describe "#update" do
    context "when run in interactive mode" do
      context "and user rejects moving forward" do
        it "does not attempt to move forward" do
          expect(cli).to receive(:yes?).and_return(false)
          expect(cli).not_to receive(:check)

          cli.update
        end
      end

      context "and the user agrees to move forward" do
        def mock_bummr_standard_flow
          updater = double
          allow(updater).to receive(:update_gems)

          expect(cli).to receive(:ask_questions)
          expect(cli).to receive(:yes?).and_return(true)
          expect(cli).to receive(:check)
          expect(cli).to receive(:log)
          expect(cli).to receive(:system).with("bundle")
          expect(Bummr::Updater).to receive(:new).with(outdated_gems).and_return updater
          expect(cli).to receive(:test)
          expect(git).to receive(:rebase_interactive).with(BASE_BRANCH)
        end

        context "and there are no outdated gems" do
          it "informs that there are no outdated gems" do
            allow_any_instance_of(Bummr::Outdated).to receive(:outdated_gems)
              .and_return []

            expect(cli).to receive(:ask_questions)
            expect(cli).to receive(:yes?).and_return(true)
            expect(cli).to receive(:check)
            expect(cli).to receive(:log)
            expect(cli).to receive(:system).with("bundle")
            expect(cli).to receive(:puts).with("No outdated gems to update".color(:green))

            cli.update
          end
        end

        context "and there are outdated gems" do
          it "calls 'update' on the updater" do
            allow_any_instance_of(Bummr::Outdated).to receive(:outdated_gems)
              .and_return outdated_gems

            mock_bummr_standard_flow

            cli.update
          end
        end

        describe "all option" do
          it "requests all outdated gems be listed" do
            options[:all] = true

            expect_any_instance_of(Bummr::Outdated)
              .to receive(:outdated_gems).with(hash_including({ all_gems: true }))
              .and_return outdated_gems

            mock_bummr_standard_flow

            cli.update
          end
        end

        describe "group option" do
          it "requests only outdated gems from supplied be listed" do
            options[:group] = 'test'

            expect_any_instance_of(Bummr::Outdated)
              .to receive(:outdated_gems).with(hash_including({ group: 'test' }))
              .and_return outdated_gems

            mock_bummr_standard_flow

            cli.update
          end
        end
      end
    end

    context "when run in headless mode" do
      let(:options) { { headless: true } }

      it "skips interactive functionality" do
        expect(cli).not_to receive(:ask_questions)
        expect(cli).not_to receive(:yes?)
        expect(cli).not_to receive(:check)

        mock_bummr_headless_flow

        cli.update
      end

      it "logs an intitial message" do
        expect(cli).to receive(:log)

        mock_bummr_headless_flow

        cli.update
      end

      it "calls bundle" do
        expect(cli).to receive(:system).with("bundle")

        mock_bummr_headless_flow

        cli.update
      end

      context "and there are no outdated gems" do
        it "informs that there are no outdated gems" do
          expect(cli).to receive(:puts).with("No outdated gems to update".color(:green))

          outdated_instance = stub_outdated(outdated_gems: [])
          mock_bummr_headless_flow(outdated_instance: outdated_instance)

          cli.update
        end
      end

      context "and there are outdated gems" do
        it "calls 'update_gems' on the updater" do
          updater = stub_updater(outdated_gems: outdated_gems)
          expect(updater).to receive(:update_gems)

          mock_bummr_headless_flow(
            outdated_instance: stub_outdated(outdated_gems: outdated_gems),
            updater_instance: updater
          )

          cli.update
        end

        it "calls a non-interactive rebase" do
          expect(git).to receive(:rebase).with(BASE_BRANCH)

          mock_bummr_headless_flow(
            outdated_instance: stub_outdated(outdated_gems: outdated_gems),
            updater_instance: stub_updater(outdated_gems: outdated_gems)
          )

          cli.update
        end

        it "calls #test" do
          expect(cli).to receive(:test)

          mock_bummr_headless_flow(
            outdated_instance: stub_outdated(outdated_gems: outdated_gems),
            updater_instance: stub_updater(outdated_gems: outdated_gems)
          )

          cli.update
        end
      end

      describe "all option" do
        it "requests all outdated gems be listed" do
          options[:all] = true

          outdated_instance = Bummr::Outdated.instance
          expect(outdated_instance)
            .to receive(:outdated_gems).with(hash_including({ all_gems: true }))
            .and_return outdated_gems

          mock_bummr_headless_flow(
            outdated_instance: outdated_instance,
            updater_instance: stub_updater(outdated_gems: outdated_gems)
          )

          cli.update
        end
      end

      describe "group option" do
        it "requests only outdated gems from supplied be listed" do
          options[:group] = 'test'

          outdated_instance = Bummr::Outdated.instance
          expect(outdated_instance)
            .to receive(:outdated_gems).with(hash_including({ group: 'test' }))
            .and_return outdated_gems

          mock_bummr_headless_flow(
            outdated_instance: outdated_instance,
            updater_instance: stub_updater(outdated_gems: outdated_gems)
          )

          cli.update
        end
      end

      def mock_bummr_headless_flow(outdated_instance: nil, updater_instance: nil)
        outdated_instance || stub_outdated(outdated_gems: [])
        updater_instance || stub_updater(outdated_gems: [])

        allow(cli).to receive(:log)
        allow(cli).to receive(:system).with("bundle")
        allow(cli).to receive(:test)
        allow(git).to receive(:rebase).with(BASE_BRANCH)
      end

      def stub_outdated(outdated_gems: [])
        outdated = Bummr::Outdated.instance
        allow(outdated).to receive(:outdated_gems).and_return outdated_gems
        outdated
      end

      def stub_updater(outdated_gems: [])
        updater = double("Updater", update_gems: nil)
        allow(Bummr::Updater).to receive(:new).with(outdated_gems).and_return updater
        updater
      end
    end
  end

  describe "#test" do
    before do
      allow(STDOUT).to receive(:puts)
      allow(cli).to receive(:check)
      allow(cli).to receive(:system)
      allow(cli).to receive(:bisect)
    end

    context "build passes" do
      it "reports that it passed the build, does not bisect" do
        allow(cli).to receive(:system).with("bundle exec rake").and_return true

        cli.test

        expect(cli).to have_received(:check).with(false)
        expect(cli).to have_received(:system).with("bundle")
        expect(cli).to have_received(:system).with("bundle exec rake")
        expect(cli).not_to have_received(:bisect)
      end
    end

    context "build fails" do
      it "bisects" do
        allow(cli).to receive(:system).with("bundle exec rake").and_return false

        cli.test

        expect(cli).to have_received(:check).with(false)
        expect(cli).to have_received(:system).with("bundle")
        expect(cli).to have_received(:system).with("bundle exec rake")
        expect(cli).to have_received(:bisect)
      end
    end
  end

  describe "#bisect" do
    it "calls Bummr:Bisecter.instance.bisect" do
      allow(cli).to receive(:check)
      allow_any_instance_of(Bummr::Bisecter).to receive(:bisect)
      bisecter = Bummr::Bisecter.instance

      cli.bisect

      expect(bisecter).to have_received(:bisect)
    end
  end
end

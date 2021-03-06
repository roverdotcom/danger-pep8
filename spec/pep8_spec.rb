require File.expand_path('../spec_helper', __FILE__)

module Danger
  describe Danger::DangerPep8 do
    it 'should be a plugin' do
      expect(Danger::DangerPep8.new(nil)).to be_a Danger::Plugin
    end

    describe 'with Dangerfile' do
      before do
        @dangerfile = testing_dangerfile
        @pep8 = @dangerfile.pep8
      end

      context 'flake8 not installed' do
        before do
          allow(@pep8).to receive(:`).with("which flake8").and_return("")
        end
      end

      context 'flake8 installed' do
        before do
          allow(@pep8).to receive(:`).with("which flake8").and_return("/usr/bin/flake8")
        end

        describe 'lint' do
          it 'runs lint from current directory by default' do
            expect(@pep8).to receive(:`).with("flake8 .").and_return("")
            @pep8.lint
          end

          it 'runs lint from a custom directory' do
            expect(@pep8).to receive(:`).with("flake8 my/custom/directory").and_return("")

            @pep8.base_dir = "my/custom/directory"
            @pep8.lint
          end

          it 'handles a custom config file' do
            expect(@pep8).to receive(:`).with("flake8 . --config my-pep8-config").and_return("")
            @pep8.config_file = "my-pep8-config"
            @pep8.lint
          end

          it 'handles a lint with no errors' do
            allow(@pep8).to receive(:`).with("flake8 .").and_return("")
            @pep8.lint
            expect(@pep8.status_report[:markdowns].first).to be_nil
          end

          it 'comments inline properly' do
            lint_report = "./tests/test_matcher.py:90:9: E128 continuation line under-indented for visual indent\n"
            allow(@pep8).to receive(:`).with("flake8 .").and_return(lint_report)

            @pep8.lint(use_inline_comments=true)

            message = @pep8.status_report[:messages].first
            expect(message).to eq('E128 continuation line under-indented for visual indent')
          end
        end

        context 'when running on github' do
          it 'handles a lint with errors count greater than threshold' do
            lint_report = "./tests/test_matcher.py:90:9: E128 continuation line under-indented for visual indent\n"

            allow(@pep8).to receive(:`).with("flake8 .").and_return(lint_report)
            allow(@dangerfile.danger).to receive(:scm_provider).and_return("github")
            allow(@dangerfile.github).to receive(:html_link)
              .with("./tests/test_matcher.py#L90", full_path: false)
              .and_return("fake_link_to:test_matcher.py#90")

            @pep8.lint

            markdown = @pep8.status_report[:markdowns].first
            expect(markdown.message).to include("## DangerPep8 found issues")
            expect(markdown.message).to include("| fake_link_to:test_matcher.py#90 | 90 | 9 | E128 continuation line under-indented for visual indent |")
          end
        end

        context 'when running outside github' do
          it 'handles a lint with errors' do
            lint_report = "./tests/test_matcher.py:90:9: E128 continuation line under-indented for visual indent\n"

            allow(@pep8).to receive(:`).with("flake8 .").and_return(lint_report)
            allow(@dangerfile.danger).to receive(:scm_provider).and_return("fake_provider")

            @pep8.lint

            markdown = @pep8.status_report[:markdowns].first
            expect(markdown.message).to include("## DangerPep8 found issues")
            expect(markdown.message).to include("| ./tests/test_matcher.py | 90 | 9 | E128 continuation line under-indented for visual indent |")
          end

          it 'handles a lint with errors count lesser than threshold' do
            lint_report = "./tests/test_matcher.py:90:9: E128 continuation line under-indented for visual indent\n"

            allow(@pep8).to receive(:`).with("flake8 .").and_return(lint_report)

            @pep8.threshold = 5
            @pep8.lint

            expect(@pep8.status_report[:markdowns].first).to be_nil
          end
        end

        describe 'count_errors' do
          it 'handles errors showing only count' do
            allow(@pep8).to receive(:`).with("flake8 . --quiet --quiet --count").and_return("10")

            @pep8.count_errors

            warning_message = @pep8.status_report[:warnings].first
            expect(warning_message).to include("10 PEP 8 issues found")
          end

          it 'should not report for count_errors if total errors is bellow configured threshold' do
            allow(@pep8).to receive(:`).with("flake8 . --quiet --quiet --count").and_return("10")

            @pep8.threshold = 20
            @pep8.count_errors

            expect(@pep8.status_report[:warnings]).to be_empty
          end

          it 'should not report anything if there is no error' do
            allow(@pep8).to receive(:`).with("flake8 . --quiet --quiet --count").and_return("")

            @pep8.count_errors

            expect(@pep8.status_report[:warnings]).to be_empty
          end
        end

      end

    end
  end
end

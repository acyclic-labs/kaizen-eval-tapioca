# typed: strict
# frozen_string_literal: true

require "tapioca/internal"
require "minitest/autorun"
require "minitest/spec"
require "minitest/hooks/default"
require "minitest/reporters"
require "minitest/mock"
require "rails/test_unit/line_filtering"

require "tapioca/helpers/test/content"
require "tapioca/helpers/test/template"
require "tapioca/helpers/test/isolation"
require "dsl_spec_helper"
require "spec_with_project"
require "rails_spec_helper"

require "spec_reporter"

backtrace_filter = Minitest::ExtensibleBacktraceFilter.default_filter
backtrace_filter.add_filter(%r{gems/sorbet-runtime})
backtrace_filter.add_filter(%r{gems/railties})
backtrace_filter.add_filter(%r{tapioca/helpers/test/})

Minitest::Reporters.use!(SpecReporter.new(color: true), ENV, backtrace_filter)

module Minitest
  class Test
    extend Rails::LineFiltering
  end
end

# Split the suite across CI jobs with TEST_SHARD_INDEX (1-based) and TEST_SHARD_TOTAL.
# Each class's test methods are dealt round-robin, in sorted order, so every test runs in exactly one shard.
if ENV["TEST_SHARD_TOTAL"]
  require "zlib"

  # @requires_ancestor: singleton(Minitest::Test)
  module TestSharding
    #: -> Array[String]
    def runnable_methods
      total = Integer(ENV.fetch("TEST_SHARD_TOTAL"))
      index = Integer(ENV.fetch("TEST_SHARD_INDEX")) - 1
      offset = Zlib.crc32(name.to_s)
      methods = super
      selected = methods.sort.select.with_index { |_, i| (i + offset) % total == index }
      methods & selected
    end
  end

  Minitest::Test.singleton_class.prepend(TestSharding)
end

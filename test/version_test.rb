# frozen_string_literal: true

# Copyright 2025 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

require 'test/unit'
include Test::Unit::Assertions

require_relative '../lib/openapi/arrangement/version'
include OpenAPIArrangement


class MainTest < Test::Unit::TestCase
  def test_info
    assert_equal("#{NAME}: #{VERSION}", OpenAPIArrangement.info)
    assert_equal("#{NAME} version #{VERSION}", OpenAPIArrangement.info(' version '))
    assert_equal("#{NAME}#{VERSION}", OpenAPIArrangement.info(''))
  end
end

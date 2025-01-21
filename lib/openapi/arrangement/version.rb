# frozen_string_literal: true

# Copyright © 2025 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

# Name and version.
module OpenAPIArrangement
  NAME = 'openapi-arrangement'
  VERSION = '0.1.0'

  def self.info(separator = ': ')
    "#{NAME}#{separator}#{VERSION}"
  end
end

# frozen_string_literal: true

# Copyright © 2026 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

# Name and version.
module OpenAPIArrangement
  NAME = 'openapi-arrangement'
  VERSION = '0.1.1'

  def self.info(separator = ': ')
    "#{NAME}#{separator}#{VERSION}"
  end
end

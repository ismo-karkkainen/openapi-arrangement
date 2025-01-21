# frozen_string_literal: true

require_relative 'lib/openapi/arrangement/version'
require 'simpleidn'
require 'rake'

Gem::Specification.new do |s|
  s.name = OpenAPIArrangement::NAME
  s.version = OpenAPIArrangement::VERSION
  s.summary = 'Schema arrangement code for OpenAPI specifications.'
  s.description = 'Code for arranging schemas in OpenAPI format specifications.

Intended to be used in gems that are invoked from openapi-generate tool from
openapi-sourcetools gem.

Provides functionality for ordering schemas:
- Based on mutual dependencies to minimize the need for forward declarations.
- Alphabetical order.'
  s.authors = [ 'Ismo Kärkkäinen' ]
  s.email = 'ismokarkkainen@icloud.com'
  s.files = FileList[ 'lib/openapi/arrangement.rb', 'lib/openapi/arrangement/*.rb', 'LICENSE.txt' ].to_a
  s.homepage = "https://#{SimpleIDN.to_ascii('ismo-kärkkäinen.fi')}/#{OpenAPIArrangement::NAME}/index.html"
  s.license = 'UPL-1.0'
  s.required_ruby_version = '>= 3.2.5'
  s.metadata = { 'rubygems_mfa_required' => 'true' }
end

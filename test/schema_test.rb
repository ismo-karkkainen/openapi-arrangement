# frozen_string_literal: true

# Copyright 2024-2025 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

require 'test/unit'
include Test::Unit::Assertions
require 'yaml'

require_relative '../lib/openapi/arrangement/schema'
include OpenAPIArrangement

module OpenAPIArrangement
  module Schema
    public_class_method :path_candidates
    public_class_method :get_schemas
  end
end

class SchemaTest < Test::Unit::TestCase
  def test_path_candidates
    p = ''
    cs = Schema.path_candidates(p)
    assert_equal(cs.size, 1, 'one key')
    assert_equal(cs.keys.first, p, 'empty string')
    assert_equal(cs[p], [], 'empty array')
    p = 'foo'
    cs = Schema.path_candidates(p)
    assert_equal(cs.size, 1, 'one key')
    assert_equal(cs.keys.first, p, 'input key')
    assert_equal(cs[p], [ p ], 'input is only candidate piece')
    p = '#/foo/bar'
    cs = Schema.path_candidates(p)
    assert_equal(cs.size, 1, 'one key')
    assert_equal(cs.keys.first, p, 'input key')
    assert_equal(cs[p], %w[foo bar], 'two pieces')
    p = '#/foo//bar'
    cs = Schema.path_candidates(p)
    assert_equal(cs.size, 1, 'one key')
    assert_equal(cs.keys.first, p, 'input key')
    assert_equal(cs[p], %w[foo bar], 'two pieces still')
    p = '#/$defs'
    cs = Schema.path_candidates(p)
    assert_equal(cs.size, 1, 'one key')
    assert_equal(cs.keys.first, p, 'input key')
    assert_equal(cs[p], [ '$defs' ], 'one piece')
  end

  def test_get_schemas
    doc = YAML.safe_load(%(
---
components:
  schemas:
    Solo:
      foo: bar
    RefSolo:
      properties:
        foo:
          $ref: Solo
"$defs":
  Second:
    type: something
    properties:
      foo:
        $ref: Solo
))
    p = '#/components/schemas'
    schemas, path = Schema.get_schemas(doc, Schema.path_candidates(p))
    assert_false(schemas.nil?, 'schemas returned')
    assert_false(p.nil?, 'path returned')
    assert_equal(p, path, 'same path')
    assert(schemas.key?('Solo'), 'correct object')
    p = '#/$defs'
    schemas, path = Schema.get_schemas(doc, Schema.path_candidates(p))
    assert_false(schemas.nil?, 'schemas returned')
    assert_false(p.nil?, 'path returned')
    assert_equal(p, path, 'same path')
    assert(schemas.key?('Second'), 'correct object')
  end
end

class SchemaInfoTest < Test::Unit::TestCase
  def test_initialize
    spec = YAML.safe_load(%(
---
components:
  schemas:
    Solo:
      foo: bar
    RefSolo:
      properties:
        foo:
          $ref: Solo
    Second:
      type: something
      properties:
        foo:
          $ref: Solo
    LoopA:
      allOf:
      - $ref: Second
      - $ref: LoopB
    LoopB:
      anyOf:
      - $ref: LoopA
      - $ref: Solo
    LoopC:
      properties:
        foo:
          $ref: LoopD
    LoopD:
      properties:
        foo:
          $ref: LoopE
    LoopE:
      properties:
        foo:
          $ref: LoopC
    Loop1:
      properties:
        foo:
          $ref: Loop2
    Loop6:
      properties:
        foo:
          $ref: Loop1
    Loop2:
      properties:
        foo:
          $ref: Loop3
    Loop5:
      properties:
        foo:
          $ref: Loop6
    Loop3:
      properties:
        foo:
          $ref: Loop4
    Loop4:
      properties:
        foo:
          $ref: Loop5
))
    schemas = {}
    path = %w[components schemas]
    spec.dig(*path).each do |name, schema|
      si = Schema::Info.new("ref#{name}", name, schema)
      schemas[name] = si
      assert(si.ref.end_with?(name), "#{name} ends ref")
    end
    dr = schemas['Solo'].direct_refs
    assert(dr.empty?, 'Solo has no direct refs')
    dr = schemas['RefSolo'].direct_refs
    assert_equal(dr.size, 1, 'RefSolo has one direct ref')
    assert(dr.member?('Solo'), 'RefSolo refers to Solo')
    dr = schemas['Second'].direct_refs
    assert_equal(dr.size, 1, 'Second has one direct ref')
    assert(dr.member?('Solo'), 'Second refers to Solo')
    dr = schemas['LoopA'].direct_refs
    assert_equal(dr.size, 2, 'LoopA has two direct refs')
    assert(dr.member?('Second'), 'LoopA refers to Second')
    assert(dr.member?('LoopB'), 'LoopA refers to LoopB')
    dr = schemas['LoopB'].direct_refs
    assert_equal(dr.size, 2, 'LoopB has two direct refs')
    assert(dr.member?('Solo'), 'LoopB refers to Solo')
    assert(dr.member?('LoopA'), 'LoopB refers to LoopA')
    dr = schemas['LoopC'].direct_refs
    assert_equal(dr.size, 1, 'LoopC has one direct ref')
    assert(dr.member?('LoopD'), 'LoopC refers to LoopD')
    dr = schemas['LoopD'].direct_refs
    assert_equal(dr.size, 1, 'LoopD has one direct ref')
    assert(dr.member?('LoopE'), 'LoopD refers to LoopE')
  end

  def test_gather_array_refs
    items = YAML.safe_load(%(
---
- noref: value
- $ref: ref1
- noref: value
  $ref: ref2
- $ref: ref3
))
    r = {}
    Schema::Info.gather_array_refs(r, items, false)
    assert_false(r['ref1'], 'ref1 present on not required')
    assert_false(r['ref2'], 'ref2 present on not required')
    assert_false(r['ref3'], 'ref3 present on not required')
    r = { 'ref1' => true, 'ref2' => false }
    Schema::Info.gather_array_refs(r, items, false)
    assert(r['ref1'], 'ref1 present on not required, pre-filled')
    assert_false(r['ref2'], 'ref2 present on not required, pre-filled')
    assert_false(r['ref3'], 'ref3 present on not required, pre-filled')
    r = { 'ref1' => true, 'ref2' => false }
    Schema::Info.gather_array_refs(r, items, true)
    assert(r['ref1'], 'ref1 present on required, pre-filled')
    assert(r['ref2'], 'ref2 present on required, pre-filled')
    assert(r['ref3'], 'ref3 present on required, pre-filled')
    r = {}
    Schema::Info.gather_array_refs(r, items, true)
    assert(r['ref1'], 'ref1 present on required')
    assert(r['ref2'], 'ref2 present on required')
    assert(r['ref3'], 'ref3 present on required')
  end

  def test_gather_refs
    r = { 'rc' => true }
    s = YAML.safe_load(%(---
required:
- a
properties:
  a:
    $ref: ra
  b:
    $ref: rb
  c:
    $ref: rc
))
    Schema::Info.gather_refs(r, s)
    assert(r['ra'], 'ra found')
    assert_false(r['rb'], 'rb found')
    assert(r['rc'], 'rc found')
  end
end

class SchemaOrdererTest < Test::Unit::TestCase
  class Tester
    attr_reader :attribute

    def initialize
      @attribute = 'a'
    end

    def method
      'x'
    end
  end

  def test_var_or_method_value
    t = Tester.new
    assert_equal(Schema::Orderer.var_or_method_value(t, 'attribute'), t.attribute, 'attribute found')
    assert_equal(Schema::Orderer.var_or_method_value(t, '@attribute'), t.attribute, '@attribute found')
    assert_equal(Schema::Orderer.var_or_method_value(t, 'method'), t.method, 'method found')
    begin
      Schema::Orderer.var_or_method_value(t, 'missing')
      flunk('missing did not throw')
    rescue Exception => e
      assert_equal(e.class.name, 'ArgumentError', 'missing name throws ArgumentError')
    end
  end

  def test_alphabetical
    spec = YAML.safe_load(%(---
components:
  schemas:
    Solo:
      foo: bar
    RefSolo:
      properties:
        foo:
          $ref: Solo
    Second:
      type: something
      properties:
        foo:
          $ref: Solo
    LoopA:
      allOf:
      - $ref: Second
      - $ref: LoopB
    LoopB:
      anyOf:
      - $ref: LoopA
      - $ref: Solo
    LoopC:
      properties:
        foo:
          $ref: LoopD
    LoopD:
      properties:
        foo:
          $ref: LoopE
    LoopE:
      properties:
        foo:
          $ref: LoopC
    Loop1:
      properties:
        foo:
          $ref: Loop2
    Loop6:
      properties:
        foo:
          $ref: Loop1
    Loop2:
      properties:
        foo:
          $ref: Loop3
    Loop5:
      properties:
        foo:
          $ref: Loop6
    Loop3:
      properties:
        foo:
          $ref: Loop4
    Loop4:
      properties:
        foo:
          $ref: Loop5
))
    order = OpenAPIArrangement::Schema.alphabetical(spec)
    names = %w[Solo RefSolo Second LoopA LoopE LoopB LoopC LoopD Loop1 Loop2 Loop3 Loop4 Loop5 Loop6].sort
    assert_equal(order.size, names.size)
    order.size.times do |k|
      ok = order[k]
      assert_equal(ok.name, names[k])
      k.times do |pre|
        next unless ok.direct_refs.key?(names[pre])
        assert_false(ok.unseen_refs.member?(names[pre]))
      end
      ((k + 1)...order.size).each do |post|
        next unless ok.direct_refs.key?(names[post])
        assert(ok.unseen_refs.member?(names[post]))
      end
    end
  end

  def test_dependencies_first
    spec = YAML.safe_load(%(---
components:
  schemas:
    Solo:
      foo: bar
    RefSolo:
      properties:
        foo:
          $ref: rSolo
    Second:
      type: something
      properties:
        foo:
          $ref: rSolo
    LoopA:
      allOf:
      - $ref: rSecond
      - $ref: rLoopB
    LoopB:
      anyOf:
      - $ref: rLoopA
      - $ref: rSolo
    LoopC:
      properties:
        foo:
          $ref: rLoopD
    LoopD:
      properties:
        foo:
          $ref: rLoopE
    LoopE:
      properties:
        foo:
          $ref: rLoopC
    Loop1:
      properties:
        foo:
          $ref: rLoop2
    Loop6:
      properties:
        foo:
          $ref: rLoop1
    Loop2:
      properties:
        foo:
          $ref: rLoop3
    Loop5:
      properties:
        foo:
          $ref: rLoop6
    Loop3:
      properties:
        foo:
          $ref: rLoop4
    Loop4:
      properties:
        foo:
          $ref: rLoop5
))
    order = OpenAPIArrangement::Schema.dependencies_first(spec)
    names = %w[Solo Loop1 Loop2 Loop3 Loop4 Loop5 Loop6 LoopC LoopD LoopE RefSolo Second LoopB LoopA]
    assert_equal(names.size, order.size)
    order.size.times do |k|
      ok = order[k]
      assert_equal(names[k], ok.name)
      k.times do |pre|
        next unless ok.direct_refs.key?(names[pre])
        assert_false(ok.unseen_refs.member?(names[pre]))
      end
      ((k + 1)...order.size).each do |post|
        next unless ok.direct_refs.key?(names[post])
        assert(ok.unseen_refs.member?(names[post]))
      end
    end
  end
end

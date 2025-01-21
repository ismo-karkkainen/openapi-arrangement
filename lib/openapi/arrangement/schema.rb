# frozen_string_literal: true

# Copyright © 2024-2025 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

module OpenAPIArrangement
  # Schema ordering.
  module Schema
    # Convenience methods to simplify using Orderer.
    # All return a sorted array of Schema::Info instances.

    # Arranges schemas in alphabetical order.
    def self.alphabetical(doc, path = nil)
      cands = path_candidates(path)
      schemas, path = get_schemas(doc, cands)
      return nil if schemas.nil?
      ord = Orderer.new(path, schemas)
      ord.sort!('@name')
    end

    # Arranges schemas to minimize forward declarations.
    def self.dependencies_first(doc, path = nil)
      cands = path_candidates(path)
      schemas, path = get_schemas(doc, cands)
      return nil if schemas.nil?
      ord = Orderer.new(path, schemas)
      ord.sort!
    end

    def self.path_candidates(path = nil)
      if path.nil?
        return {
          '#/components/schemas/' => %w[components schemas],
          '#/$defs/' => %w[$defs] # Supposing someone wants to use JSON schema doc.
        }
      end
      pieces = path.split('/')
      pieces.reject!(&:empty?)
      pieces.shift if '#' == pieces.first
      { path => pieces }
    end
    private_class_method :path_candidates

    def self.get_schemas(doc, cands)
      cands.each do |path, pieces|
        schemas = doc.dig(*pieces)
        return [ schemas, path ] unless schemas.nil?
      end
      [ nil, nil ]
    end
    private_class_method :get_schemas

    # Schema, reference to it, name, and what it refers to.
    class Info
      attr_reader :ref, :schema, :direct_refs, :name, :unseen_refs

      def initialize(ref, name, schema)
        @ref = ref
        @name = name
        @schema = schema
        @direct_refs = {}
        self.class.gather_refs(@direct_refs, schema)
      end

      # Sets references that require forward declaration to be used.
      def mark_as_seen(seen)
        @unseen_refs = Set.new(@direct_refs.keys) - seen
      end

      def to_s
        v = @direct_refs.keys.sort.map { |k| "#{k}:#{@direct_refs[k] ? 'req' : 'opt'}" }
        "#{@ref}: #{v.join(' ')}"
      end

      # Adds all refs found in the array to refs with given required state.
      def self.gather_array_refs(refs, items, required)
        items.each do |s|
          r = s['$ref']
          next if r.nil?
          refs[r] = required || refs.fetch(r, false)
        end
      end

      # For any key '$ref' adds to refs whether referred type is required.
      # Requires that there are no in-lined schemas, openapi-addschemas has been run.
      def self.gather_refs(refs, schema)
        # This implies types mixed together according to examples. Needs mixed type.
        # AND. Also, mixing may fail. Adds a new schema, do in openapi-oftypes.
        items = schema['allOf']
        return gather_array_refs(refs, items, true) unless items.nil?
        # As long as one schema is fulfilled, it is ok. OR, first that fits.
        items = schema['anyOf'] if items.nil?
        # oneOf implies selection between different types. No multiple matches. XOR.
        # Needs to ensure that later types do not match.
        # Should check if there is enough difference to ensure single match.
        # Use separate program run after addschemas to create allOf mixed schema
        # and verify the others can be dealt with.
        items = schema['oneOf'] if items.nil?
        return gather_array_refs(refs, items, false) unless items.nil?
        # Defaults below handle it if "type" is not "object".
        reqs = schema.fetch('required', [])
        schema.fetch('properties', {}).each do |name, spec|
          r = spec['$ref']
          next if r.nil?
          refs[r] = reqs.include?(name) || refs.fetch(r, false)
        end
      end
    end

    # Orders schemas according to given orderer.
    # There is only one actual ordering method now.
    class Orderer
      attr_accessor :schemas, :order, :orderer

      def initialize(path, schema_specs)
        @schemas = {}
        schema_specs.each do |name, schema|
          r = "#{path}#{name}"
          @schemas[r] = Info.new(r, name, schema)
        end
      end

      def sort!(orderer = 'greedy_required_first')
        @orderer = orderer
        case orderer
        when 'greedy_required_first' then @order = greedy_required_first
        when '<=>' then @order = @schemas.values.sort { |a, b| a <=> b }
        else
          @order = @schemas.values.sort do |a, b|
            va = self.class.var_or_method_value(a, orderer)
            vb = self.class.var_or_method_value(b, orderer)
            va <=> vb
          end
        end
        seen = Set.new
        @order.each do |si|
          si.mark_as_seen(seen)
          seen.add(si.name)
        end
        @order
      end

      def count_comparison(optfwd, manfwd, optrem, manrem, si, best)
        # Fewer mandatory forwards is good because it leaves more room for implementation.
        return true if manfwd < best[1]
        if manfwd == best[1]
          return true if manrem < best[3]
          if manrem == best[3]
            return true if optfwd < best[0]
            if optfwd == best[0]
              return true if optrem < best[2]
              if optrem == best[2]
                best_req_si = best.last.direct_refs.fetch(si.ref, false)
                si_req_best = si.direct_refs.fetch(best.last.ref, false)
                return nil if best_req_si == si_req_best
                return !si_req_best
              end
            end
          end
        end
        false
      end

      def greedy_required_first
        chosen = []
        until chosen.size == @schemas.size
          used = Set.new(chosen.map(&:ref))
          available = @schemas.values.reject { |si| used.member?(si.ref) }
          best = nil
          available.each do |si|
            # Optional forwards from chosen.
            optfwd = chosen.count { |x| !x.direct_refs.fetch(si.ref, false) && x.direct_refs.key?(si.ref) }
            # Mandatory forwards from chosen.
            manfwd = chosen.count { |x| x.direct_refs.fetch(si.ref, false) && x.direct_refs.key?(si.ref) }
            # Optional and mandatory references from si.
            opts = Set.new(si.direct_refs.keys.reject { |n| si.direct_refs[n] })
            mans = Set.new(si.direct_refs.keys.select { |n| si.direct_refs[n] })
            # Optional forwards to be added for si.
            optrem = (opts - used).size
            # Mandatory forwards to be added for si.
            manrem = (mans - used).size
            better = false
            if best.nil?
              better = true
            else
              better = count_comparison(optfwd, manfwd, optrem, manrem, si, best)
              # Order by name if equally good otherwise.
              better = si.name < best.last.name if better.nil?
            end
            best = [ optfwd, manfwd, optrem, manrem, si ] if better
          end
          chosen.push(best.last)
        end
        chosen
      end

      def self.var_or_method_value(x, name)
        n = name.start_with?('@') ? name : "@#{name}"
        return x.instance_variable_get(n) if x.instance_variable_defined?(n)
        return x.public_send(name) if x.respond_to?(name)
        raise ArgumentError, "#{name} is not #{x.class} instance variable nor public method"
      end
    end
  end
end

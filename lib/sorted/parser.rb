require 'sorted/toggler'

module Sorted
  # Takes a sort query string and an SQL order string and parses the
  # values to produce key value pairs.
  #
  # Example:
  #  Sorted::Parser.new('phone_desc', 'name ASC').to_s #-> "phone_desc!name_asc"
  class Parser
    attr_reader :sort, :order, :sorts, :orders

    # Regex to make sure we only get valid names and not injected code.
    SORTED_QUERY_REGEX  = /([a-zA-Z0-9._]+)_(asc|desc)$/
    SQL_REGEX           = /(([a-z0-9._]+)\s([asc|desc]+)|[a-z0-9._]+)/i
    FIELD_REGEX         = /^(([a-z0-9_]+)\.([a-z0-9_]+)|[a-z0-9_]+)$/i

    def initialize(sort, order = nil, whitelist = [], customlist = {}, logger = -> (_) { })
      @sort       = sort
      @order      = order
      @sorts      = parse_sort
      @orders     = parse_order
      @logger     = logger
      @customlist = customlist
      @whitelist  = Parser::initialize_whitelist whitelist
    end

    def parse_sort
      sort.to_s.split(/!/).map do |sort_string|
        if m = sort_string.match(SORTED_QUERY_REGEX)
          [m[1], m[2].downcase]
        end
      end.compact
    end

    def parse_order
      order.to_s.split(/,/).map do |order_string|
        if m = order_string.match(SQL_REGEX)
          [m[2].nil? ? m[1] : m[2], m[3].nil? ? "asc" : m[3].downcase]
        end
      end.compact
    end

    def to_hash
      array.inject({}) { |a, (k, v)| a.merge(k => v) }
    end

    def to_sql(quoter = ->(frag) { frag })
      sentence = array.map do |field, dir|
        next @customlist["#{field} #{dir}"] if @customlist["#{field} #{dir}"]
        column = field.split('.').map(&quoter).join('.')
        "#{column} #{dir.upcase}"
      end.join(', ')
      Arel.sql(sentence)
    end

    def to_s
      array.map { |a| a.join('_') }.join('!')
    end

    def to_a
      array
    end

    def toggle
      @array = apply_whitelist Toggler.new(sorts, orders).to_a
      self
    end

    def reset
      @array = default
      self
    end

    private

    def self.initialize_whitelist(arg)
      return nil if arg.nil?
      list =
        if arg.respond_to?(:to_ary)
          arg.to_ary || [arg]
        else
          [arg]
        end.flatten

      fields =
        list.map do |item|
          case
          when item.is_a?(String)
            if m = item.match(FIELD_REGEX)
              m[3].nil? ? m[1] : m[3]
            end
          when %i(table_name column_names).all?(&item.method(:respond_to?))
            item.column_names
          end
        end.flatten.compact.group_by { |_| _ }.select { |_, v| 1 < v.length }.keys

      list.map do |item|
        case
        when item.is_a?(String)
          [item]
        when %i(table_name column_names).all?(&item.method(:respond_to?))
          item.column_names.map do |c|
            ["#{item.table_name}.#{c}", unless fields.include?(c) then c end]
          end
        end
      end.flatten.compact
    end

    def apply_whitelist(arr)
      return arr if @whitelist.nil?
      arr.select do |field, dir|
        passed = @whitelist.include?(field) && ["asc", "desc"].include?(dir)
        @logger.call("Unpermitted sort field: #{field} #{dir}") unless passed
        passed
      end
    end

    def array
      @array ||= default
    end

    def default
      sorts_new = sorts.dup
      orders.each do |o|
        sorts_new << o unless sorts_new.flatten.include?(o[0])
      end
      apply_whitelist sorts_new
    end
  end
end

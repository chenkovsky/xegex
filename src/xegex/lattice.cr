module Xegex
  class Lattice(T)
    include Enumerable(T)
    @size : Int32
    @start_arr : Array(Array(T)?)
    @end_arr : Array(Array(T)?)

    getter :size

    def initialize(@size)
      @start_arr = Array(Array(T)?).new(@size, nil)
      @end_arr = Array(Array(T)?).new(@size, nil)
    end

    def <<(span : T) : Nil
      spans = @start_arr[span.start_idx] ||= [] of T
      spans << span
      spans = @end_arr[span.end_idx] ||= [] of T
      spans << span
    end

    def start_at(idx : Int32)
      spans = @start_arr[idx]
      return if spans.nil?
      spans.each do |span|
        yield span
      end
    end

    def end_at(idx : Int32)
      spans = @end_arr[idx]
      return if spans.nil?
      spans.each do |span|
        yield span
      end
    end

    def each
      @start_arr.each do |arr|
        next if arr.nil?
        arr.each do |span|
          yield span
        end
      end
    end
  end
end

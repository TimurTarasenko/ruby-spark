require "sourcify"

# Resilient Distributed Dataset

module Spark
  class RDD

    attr_reader :jrdd, :context, :serializer

    def initialize(jrdd, context, serializer)
      @jrdd = jrdd
      @context = context
      @serializer = serializer

      @cached = false
      @checkpointed = false
    end



    # =======================================================================    
    # Variables 
    # =======================================================================   

    def default_reduce_partitions
      if @context.conf.contains("spark.default.parallelism")
        @context.default_parallelism
      else
        @jrdd.partitions.size
      end
    end

    def id
      @jrdd.id
    end

    def cached?
      @cached
    end

    def checkpointed?
      @checkpointed
    end



    # =======================================================================    
    # Compute functions    
    # =======================================================================        


    # jrdd.collect() -> ArrayList
    #     .to_a -> Arrays in Array
    def collect
      Spark::Serializer::UTF8.load(jrdd.collect.to_a)
      # Spark::Serializer::UTF8.load_from_itr(jrdd.collect.iterator)
    end




    def map(f)
      f = to_source(f)

      function = [f, "Proc.new {|_, iterator| iterator.map{|i| @__function__.call(i)} }"]
      PipelinedRDD.new(self, function)
    end

    # def flat_map(f)
    #   function = [f, Proc.new {|_, iterator| iterator.flat_map{|i| @_f.call(i)} }]
    #   map_partitions_with_index(function)
    # end

    # def reduce_by_key(f, num_partitions=nil)
    #   combine_by_key(lambda {|x| x}, f, f, num_partitions)
    # end

    # def combine_by_key(create_combiner, merge_value, merge_combiners, num_partitions=nil)
    #   num_partitions ||= default_reduce_partitions
    # end

    # def map_partitions_with_index(f)
    #   PipelinedRDD.new(self, f)
    # end



    # Aliases
    # alias_method :flatMap, :flat_map
    # alias_method :reduceByKey, :reduce_by_key
    # alias_method :combineByKey, :combine_by_key
    # alias_method :mapPartitionsWithIndex, :map_partitions_with_index

    private

      def to_source(f)
        return f if f.is_a?(String)

        begin
          f.to_source
        rescue
          raise Spark::SerializeError, "Function can not be serialized. Instead, use the String."
        end
      end

  end


  class PipelinedRDD < RDD

    attr_reader :prev_jrdd, :serializer, :function

    def initialize(prev, function)

      # if !prev.is_a?(PipelinedRDD) || !prev.pipelinable?
      if prev.is_a?(PipelinedRDD) && prev.pipelinable?
        # Second, ... stages
        @function = prev.function
        @function << function
        @prev_jrdd = prev.prev_jrdd
      else
        # First stage
        @function = [function]
        @prev_jrdd = prev.jrdd
      end

      @cached = false
      @checkpointed = false

      @context = prev.context
      @serializer = prev.serializer
    end

    def pipelinable?
      !(cached? || checkpointed?)
    end

    def jrdd
      return @jrdd_values if @jrdd_values

      command = Marshal.dump([@function, @serializer.to_s]).bytes.to_a
      env = @context.environment
      class_tag = @prev_jrdd.classTag

      ruby_rdd = RubyRDD.new(@prev_jrdd.rdd, command, env, Spark.worker_dir, class_tag)
      @jrdd_values = ruby_rdd.asJavaRDD
      @jrdd_values
    end

  end
end

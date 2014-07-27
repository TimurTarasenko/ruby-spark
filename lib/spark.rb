require "spark/version"
require "spark/error"

module Spark
  autoload :Context,    "spark/context"
  autoload :RDD,        "spark/rdd"
  autoload :CLI,        "spark/cli"
  autoload :Build,      "spark/build"
  autoload :Serializer, "spark/serializer"
  autoload :Command,    "spark/command"
  autoload :Helper,     "spark/helper"

  extend Helper::Platform

  # Load dependent libraries, can be use once
  # Cannot load before CLI::install
  #
  #   spark_home: path to directory where are located sparks .jar files
  #
  # TODO: check if spark_home is file or directory
  #
  def self.load_lib(spark_home=nil)
    return if @loaded_lib

    spark_home ||= Spark.target_dir

    if jruby?
      jruby_load_lib(spark_home)
    else
      other_load_lib(spark_home)
    end

    @loaded_lib = true
  end

  def self.print_logo(message=nil)
    puts <<-STRING

    Welcome to
       ___       ____              __
      | _ \\     / __/__  ___ _____/ /__
      | __/    _\\ \\/ _ \\/ _ `/ __/  '_/
      | \\\\    /__ / .__/\\_,_/_/ /_/\\_\\   version #{Spark::VERSION}
      |  \\\\      /_/

    #{message}

    STRING
  end

  # Root of the gem
  def self.root
    @root ||= File.expand_path("..", File.dirname(__FILE__))
  end

  # Default directory for java extensions
  def self.target_dir
    @target_dir ||= File.join(root, 'target')
  end

  # Directory where is worker.rb
  def self.worker_dir
    @worker_dir ||= File.join(root, 'lib', 'spark', 'worker')
  end

  # Full path of ruby spark extension
  # used for build and load
  def self.ruby_spark_jar
    @ruby_spark_jar ||= File.join(target_dir, 'ruby-spark.jar')
  end

  def self.jruby_load_lib(spark_home)
    require "java"
    
    Dir.glob(File.join(spark_home, "*.jar")){|file| 
      require file
    }
    require Spark.ruby_spark_jar

    java_import org.apache.spark.SparkConf
    java_import org.apache.spark.api.java.JavaSparkContext
    java_import org.apache.spark.api.ruby.RubyRDD
    java_import org.apache.spark.api.python.PairwiseRDD
    java_import org.apache.spark.api.python.PythonPartitioner
  end

  def self.other_load_lib(spark_home)
    require "rjb"

    jars = []
    jars << Dir.glob(File.join(spark_home, "*.jar"))
    jars << Spark.ruby_spark_jar
    Rjb::load(jars.flatten.join(":"))
    Rjb::primitive_conversion = true

    Object.const_set(:SparkConf,         Rjb::import("org.apache.spark.SparkConf"))
    Object.const_set(:JavaSparkContext,  Rjb::import("org.apache.spark.api.java.JavaSparkContext"))
    Object.const_set(:RubyRDD,           Rjb::import("org.apache.spark.api.ruby.RubyRDD"))
    Object.const_set(:PairwiseRDD,       Rjb::import("org.apache.spark.api.python.PairwiseRDD"))
    Object.const_set(:PythonPartitioner, Rjb::import("org.apache.spark.api.python.PythonPartitioner"))
  end

end

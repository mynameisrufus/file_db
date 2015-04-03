require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'rake/testtask'
require 'benchmark'

RuboCop::RakeTask.new

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/**/test_*.rb']
  t.verbose = false
end

task default: [:test, :rubocop]

namespace :benchmark do
  task :write do
    FileDB.init('tmp/db_benchmark')

    FileDB.flush

    n = 2_000

    Benchmark.bm do |x|
      x.report(:write_synchronous) do
        for i in 1..n
          FileDB.set(key: "foo_#{i}", value: "bar_#{i}", wait: true)
        end
      end
    end

    FileDB.flush

    Benchmark.bm do |x|
      x.report(:write_asynchronous) do
        for i in 1..n
          FileDB.set(key: "foo_#{i}", value: "bar_#{i}")
        end
      end
    end

    actual = nil
    expected = n

    Benchmark.bm do |x|
      x.report(:read_synchronous) do
        for i in 1..n
          actual = FileDB.get(wait: true).count
        end
      end
    end

    if actual != expected
      fail "FAILURE: #{actual} nodes returned, should be #{expected}"
    else
      puts "SUCCESS: #{expected} nodes persisted"
    end
  end

  task :read do
    FileDB.init('tmp/db_benchmark')

    FileDB.flush

    n = 2_000

    puts "writing #{n} nodes for benchmark"
    for i in 1..n
      FileDB.set(key: "foo_#{i}", value: "bar_#{i}", wait: true)
    end

    Benchmark.bm do |x|
      x.report(:read_synchronous) do
        for i in 1..n
          FileDB.get(key: "foo_#{i}", wait: true)
        end
      end
    end

    Benchmark.bm do |x|
      x.report(:read_asynchronous) do
        for i in 1..n
          FileDB.get(key: "foo_#{i}")
        end
      end
    end
  end

  task :complex do
    FileDB.init('tmp/db_benchmark')

    FileDB.flush

    n = 500

    threads = []
    labels = %w(a b c d)

    labels.each do |label|
      t = Thread.new do
        for i in 1..n
          FileDB.set(key: "foo_#{label}_#{i}", value: "bar_#{i}")
        end
      end
      threads << t
    end

    labels.each do |label|
      t = Thread.new do
        for i in 1..n
          FileDB.set(key: "foo_#{label}_#{i}", value: "bar_#{i}")
        end
      end
      threads << t
    end

    threads.each(&:join)

    t = Thread.new do
      for i in 1..n
        FileDB.del(key: "foo_#{labels.first}_#{i}")
      end
    end

    t.join

    actual = nil
    expected = n * (labels.count - 1)

    Benchmark.bm do |x|
      x.report(:read_synchronous) do
        actual = FileDB.get(wait: true).count
      end
    end

    if actual != expected
      fail "FAILURE: #{actual} nodes returned, should be #{expected}"
    else
      puts "SUCCESS: #{expected} nodes persisted"
    end
  end
end

require 'json'

module FileDB
  VERSION = '0.0.1'
  NS_KEY = '_namespaces'

  class NotFound < StandardError; end
  class InvalidKey < StandardError; end
  class CompareAndSwap < StandardError; end
  class CompareAndDelete < StandardError; end

  Node = Struct.new(:version, :key, :value)
  State = Struct.new(:action, :node, :prev_node)

  class << self
    def marshal(d)
      JSON.generate(d)
    end

    def unmarshal(d)
      JSON.parse(d)
    end

    def ensure_db
      rw do |f|
        c = f.read
        if c.empty?
          c = { NS_KEY => {} }
          f.write(marshal(c))
          c
        else
          unmarshal(c)
        end
      end
    end

    def init(path)
      @path = path
      @db = ensure_db
      @mutex =  Mutex.new
      @queue = Queue.new
      @reader = spawn_reader
      @writer = spawn_writer
    end

    def spawn_reader
      t = Thread.new do
        loop do
          sleep(0.1)
          @mutex.synchronize { @db = read }
        end
      end
      t.abort_on_exception = true
      t
    end
    private :spawn_reader

    def spawn_writer
      t = Thread.new do
        while operation = @queue.pop
          begin
            operation.call
          rescue NotFound, CompareAndSwap, CompareAndDelete
            # silent fail
          end
        end
      end
      t.abort_on_exception = true
      t
    end
    private :spawn_writer

    def read
      d = nil
      File.open(full_path, File::RDONLY) do |f|
        f.flock(File::LOCK_EX)
        c = f.read
        d = unmarshal(c)
      end
      d
    end
    private :read

    def db
      @mutex.synchronize { @db }
    end
    private :db

    def flush
      File.open(full_path, File::WRONLY | File::TRUNC | File::CREAT, 0644) do |f|
        f.flock(File::LOCK_EX)
        d = { NS_KEY => {} }
        f.write(marshal(d))
      end
    end

    def full_path
      File.expand_path(@path)
    end

    def get(key: nil, namespace: nil, wait: false)
      if wait
        until @queue.empty?
          sleep(0.1)
        end
        d = read
      else
        d = db
      end
      return one(d, key: key, namespace: namespace) if key
      all(d, namespace: namespace)
    end

    def new_state(a, k, n, p)
      State.new(a).tap do |state|
        state.node = Node.new(n['i'], k, n['v']).freeze if n
        state.prev_node = Node.new(p['i'], k, p['v']).freeze if p
        state.freeze
      end
    end

    def one(d, key:, namespace:)
      p = namespace ? (d[NS_KEY][namespace] ||= {})[key] : d[key]
      fail NotFound, "#{key} not found" unless p
      new_state('get', key, p, nil)
    end
    private :one

    def all(d, namespace:)
      s = namespace ? (d[NS_KEY][namespace] ||= {}) : d
      s.each_with_object([]) do |node, states|
        k, p = *node
        next if k == NS_KEY
        states << new_state('get', k, p, nil)
      end
    end
    private :all

    def rw
      File.open(full_path, File::RDWR | File::CREAT, 0644) do |f|
        f.flock(File::LOCK_EX)
        yield f
      end
    end
    private :rw

    def rw_unmarshal
      rw do |f|
        c = f.read
        d = unmarshal(c)
        yield d
        f.rewind
        f.write(marshal(d))
        f.flush
        f.truncate(f.pos)
      end
    end
    private :rw_unmarshal

    def wait_or_queue(wait, operation)
      if wait
        operation.call
      else
        @queue << operation
        true
      end
    end
    private :wait_or_queue

    def compare_check(prev_node, p, e)
      return unless prev_node && prev_node.version != p['i']
      fail e, "version #{prev_node.version} != #{p['i']}"
    end
    private :compare_check

    def key_check(key)
      fail InvalidKey, "#{key} is invalid" if key == NS_KEY
    end
    private :key_check

    def set(key:, value:, prev_node: nil, namespace: nil, wait: false)
      return compare_and_swap(key: key,
                              value: value,
                              prev_node: prev_node,
                              namespace: namespace,
                              wait: wait) if prev_node
      key_check(key)
      operation = lambda do
        n = nil
        p = nil
        rw_unmarshal do |d|
          p = namespace ? (d[NS_KEY][namespace] ||= {})[key] : d[key]
          i = p ? p['i'] + 1 : 1
          n = { 'v' => value, 'i' => i }
          namespace ? d[NS_KEY][namespace][key] = n : d[key] = n
        end
        new_state('set', key, n, p)
      end
      wait_or_queue(wait, operation)
    end

    def compare_and_swap(key:, value:, prev_node:, namespace:, wait: false)
      key_check(key)
      operation = lambda do
        n = nil
        p = nil
        rw_unmarshal do |d|
          p = namespace ? (d[NS_KEY][namespace] ||= {})[key] : d[key]
          compare_check(prev_node, p, CompareAndSwap)
          i = p ? p['i'] + 1 : 1
          n = { 'v' => value, 'i' => i }
          namespace ? d[NS_KEY][namespace][key] = n : d[key] = n
        end
        new_state('compare_and_swap', key, n, p)
      end
      wait_or_queue(wait, operation)
    end

    def del(key:, prev_node: nil, namespace: nil, wait: false)
      return compare_and_delete(key: key,
                                prev_node: prev_node,
                                namespace: namespace,
                                wait: wait) if prev_node
      key_check(key)
      operation = lambda do
        p = nil
        n = nil
        rw_unmarshal do |d|
          p = namespace ? (d[NS_KEY][namespace] ||= {})[key] : d[key]
          fail NotFound, "#{key} not found" unless p
          if namespace
            d[NS_KEY][namespace].delete(key)
            d[NS_KEY].delete(namespace) if namespace.empty?
          else
            d.delete(key)
          end
        end
        new_state('delete', key, nil, p)
      end
      wait_or_queue(wait, operation)
    end

    def compare_and_delete(key:, prev_node:, namespace: nil, wait: false)
      key_check(key)
      operation = lambda do
        p = nil
        n = nil
        rw_unmarshal do |d|
          p = namespace ? (d[NS_KEY][namespace] ||= {})[key] : d[key]
          fail NotFound, "#{key} not found" unless p
          compare_check(prev_node, p, CompareAndDelete) if prev_node
          if namespace
            d[NS_KEY][namespace].delete(key)
            d[NS_KEY].delete(namespace) if namespace.empty?
          else
            d.delete(key)
          end
        end
        new_state('compare_and_delete', key, nil, p)
      end
      wait_or_queue(wait, operation)
    end
  end
end

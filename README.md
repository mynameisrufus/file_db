# FileDb

FileDB is a filesystem DB that supports synchronous and asynchronous operations,
API inspired by https://github.com/coreos/etcd and not recommended for
production.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'file_db'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install file_db

## Usage

By default all operations are asynchronous, for synchronous operations use the
option `wait: true`, only three operations are supported `get` `set` and `del`.

### Reads and writes

Asynchronous write, synchronous read:

```ruby
FileDB.set(key: 'foo1', value: 'bar')
FileDb.get(key: 'foo1', wait: true)
```

This will raise `FileDB::NotFound` error because of the 100ms update lag:

```ruby
FileDB.set(key: 'foo1', value: 'bar')
FileDb.get(key: 'foo1')
```

### Namespaces

You will need to provide the `namespace` argument to subsequent calls to `get`,
`set` and `del` for this node:

```ruby
FileDB.set(key: 'foo1', value: 'bar', namespace: 'fubar')
```

### Compare and swap

This following will raise a `FileDB::CompareAndSwap` error:

```ruby
state = FileDB.set(key: 'foo1', value: 'bar', wait: true)
FileDB.set(key: 'foo1', value: 'bar', wait: true)
FileDB.set(key: 'foo1', value: 'bar', wait: true, prev_node: state.node)
```

### Compare and delete

This following will raise a `FileDB::CompareAndDelete` error:

```ruby
state = FileDB.set(key: 'foo1', value: 'bar', wait: true)
FileDB.set(key: 'foo1', value: 'bar', wait: true)
FileDB.del(key: 'foo1', wait: true, prev_node: state.node)
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/file_db/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

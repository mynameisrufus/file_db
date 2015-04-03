require 'test_helper'

describe FileDB do
  before do
    FileDB.init('tmp/db_test')
    FileDB.flush
  end

  it 'should remove everything from DB' do
    assert(FileDB.flush)
  end

  it 'should set a key value in namespace' do
    FileDB.set(key: 'foo', value: 'bar', namespace: 'fubar', wait: true)
    assert_raises(FileDB::NotFound) { FileDB.get(key: 'foo', wait: true) }
    state = FileDB.get(key: 'foo', namespace: 'fubar', wait: true)
    assert(state.node)
  end

  it 'should get all values' do
    FileDB.set(key: 'foo1', value: 'bar', wait: true)
    FileDB.set(key: 'foo2', value: 'bar', wait: true)
    assert_equal(2, FileDB.get(wait: true).count)
  end

  it 'should get all values' do
    FileDB.set(key: 'foo1', value: 'bar', wait: true)
    FileDB.set(key: 'foo1', value: 'bar', wait: true, namespace: 'fubar')
    FileDB.set(key: 'foo2', value: 'bar', wait: true, namespace: 'fubar')
    assert_equal(2, FileDB.get(namespace: 'fubar', wait: true).count)
  end

  it 'should have previous version' do
    FileDB.set(key: 'foo', value: 'bar', wait: true)
    state = FileDB.set(key: 'foo', value: 'bar', wait: true)
    assert_equal(1, state.prev_node.version)
  end

  it 'should increment the node version' do
    FileDB.set(key: 'foo', value: 'bar', wait: true)
    FileDB.set(key: 'foo', value: 'bar', wait: true)
    state = FileDB.get(key: 'foo', wait: true)
    assert_equal(2, state.node.version)
  end

  it 'should raise invalid key error' do
    assert_raises(FileDB::InvalidKey) { FileDB.set(key: '_namespaces', value: 'bar', wait: true) }
    assert_raises(FileDB::InvalidKey) { FileDB.del(key: '_namespaces', wait: true) }
  end

  it 'should raise version error' do
    state = FileDB.set(key: 'foo', value: 'bar', wait: true)
    FileDB.set(key: 'foo', value: 'bar', wait: true)
    assert_raises(FileDB::CompareAndSwap) do
      FileDB.set(key: 'foo', value: 'bar', prev_node: state.node, wait: true)
    end
  end

  it 'should delete a key' do
    FileDB.set(key: 'foo', value: 'bar', wait: true)
    state = FileDB.del(key: 'foo', wait: true)
    refute(state.node)
  end

  it 'should del a key value in namespace' do
    FileDB.set(key: 'foo', value: 'bar', namespace: 'fubar')
    assert_raises(FileDB::NotFound) { FileDB.del(key: 'foo', wait: true) }
    state = FileDB.del(key: 'foo', namespace: 'fubar', wait: true)
    refute(state.node)
  end

  it 'should raise version error' do
    state = FileDB.set(key: 'foo', value: 'bar', wait: true)
    FileDB.set(key: 'foo', value: 'bar', wait: true)
    assert_raises(FileDB::CompareAndDelete) do
      FileDB.del(key: 'foo', prev_node: state.node, wait: true)
    end
  end
end

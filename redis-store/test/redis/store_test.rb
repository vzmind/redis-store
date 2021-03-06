require 'test_helper'

describe Redis::Store do
  before do
    @store  = Redis::Store.new
    @client = @store.instance_variable_get(:@client)
  end

  it "returns useful informations about the server" do
    @store.to_s.must_equal("Redis Client connected to #{@client.host}:#{@client.port} against DB #{@client.db}")
  end

  it "must force reconnection" do
    @client.expects(:reconnect)
    @store.reconnect
  end
end
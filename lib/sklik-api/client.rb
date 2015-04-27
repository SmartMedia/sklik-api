# -*- encoding : utf-8 -*-
class SklikApi
  class Client

    NAME = "client"

    include Object

    def initialize args = {}
      super args
    end

    def self.find args = {}
      out = connection.call("client.getAttributes") { |param|
        accounts = param[:user] ? [param[:user]] : []
        accounts += param[:foreignAccounts]
        accounts.collect{|u|
          u.symbolize_keys!
          SklikApi::Client.new(
            :customer_id => u[:userId],
            :email => u[:username]
          )
        }
      }
      out.select!{|c| c.args[:customer_id] == args[:customer_id]} if args[:customer_id]
      out.select!{|c| c.args[:email] == args[:email]} if args[:email]
      return out
    end

    def stats(args)
      super(@args[:customer_id], args)
    end
  end
end

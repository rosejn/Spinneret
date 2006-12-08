module Spinneret
module Search
  class SearchBase < Struct
    attr_accessor :uid

    @@uuid = 0

    def initialize(uid, *args)
      super(*args)
      @uid = uid
    end

    def SearchBase::get_new_uid
      uid = @@uuid
      @@uuid += 1
      return uid
    end
  end
end
end

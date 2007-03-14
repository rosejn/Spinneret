module Spinneret
module Search
  class SearchBase < Struct
    attr_accessor :uid, :immed_src

    @@uuid = 0

    def initialize(uid, immed_src, *args)
      super(*args)
      @uid = uid
      @immed_src = immed_src
    end

    def SearchBase::get_new_uid
      uid = @@uuid
      @@uuid += 1
      return uid
    end
  end
end
end

module Fundler
  # We're doing this because we might write tests that deal
  # with other versions of fundler and we are unsure how to
  # handle this better.
  VERSION = "1.0.7" unless defined?(::Fundler::VERSION)
end

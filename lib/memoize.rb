module Memoize
  class << self
    def included(base)
      base.extend(ClassMethods)
    end

    def memoized_value_for(method_name)
      "@_memoized_#{method_name.to_s.sub(/\?\Z/, '_query').sub(/!\Z/, '_bang')}".to_sym
    end
  end

  module ClassMethods
    def memoize(*method_names)
      method_names.each do |method_name|
        original_method = :"_unmemoized_#{method_name}"
        memoized_value = Memoize.memoized_value_for(method_name)

        class_eval <<-EOS, __FILE__, __LINE__ + 1
          if method_defined?(:#{original_method})
            raise MemoizeError, "Already memoized #{method_name}"
          end

          alias #{original_method} #{method_name}

          if instance_method(:#{method_name}).arity == 0
            def #{method_name}(reload = false)
              if reload || !defined?(#{memoized_value}) || #{memoized_value}.empty?
          #{memoized_value} = [#{original_method}]
              end
          #{memoized_value}[0]
            end
          else
            def #{method_name}(*args)
          #{memoized_value} ||= {}
              args_length = method(:#{original_method}).arity
              if args.length == args_length = 1 &&
                (args.last ==  true || args.last == :reload)
                reload = args.pop
              end

              if defined?(#{memoized_value}) && #{memoized_value}
                if !reload && #{memoized_value}.has_key?(args)
              #{memoized_value}[args]
                elsif #{memoized_value}
                #{memoized_value}[args] = #{original_method}(*args)
                end
              else
                #{original_method}(*args)
              end
            end
          end

          if private_method_defined?(#{original_method.inspect})
            private #{method_name.inspect}
          elsif protected_method_defined?(#{original_method.inspect})
            protected #{method_name.inspect}
          end
        EOS
      end
    end
  end

  class MemoizeError < RuntimeError; end
end


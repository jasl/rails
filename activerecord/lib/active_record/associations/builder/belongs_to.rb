module ActiveRecord::Associations::Builder
  class BelongsTo < SingularAssociation #:nodoc:
    def macro
      :belongs_to
    end

    def valid_options
      super + [:foreign_type, :polymorphic, :touch, :counter_cache]
    end

    def self.valid_dependent_options
      [:destroy, :delete]
    end

    def self.define_callbacks(model, reflection)
      super
      mark_counter_cache_readonly(model, reflection) if reflection.options[:counter_cache]
      add_touch_callbacks(model, reflection)         if reflection.options[:touch]
    end

    private

    def self.mark_counter_cache_readonly(model, reflection)
      cache_column = reflection.counter_cache_column
      klass = reflection.class_name.safe_constantize
      klass.attr_readonly cache_column if klass && klass.respond_to?(:attr_readonly)
    end

    def self.touch_record(o, foreign_key, name, touch) # :nodoc:
      old_foreign_id = o.changed_attributes[foreign_key]

      if old_foreign_id
        association = o.association(name)
        reflection = association.reflection
        if reflection.polymorphic?
          klass = o.public_send("#{reflection.foreign_type}_was").constantize
        else
          klass = association.klass
        end
        old_record = klass.find_by(klass.primary_key => old_foreign_id)

        if old_record
          if touch != true
            old_record.touch touch
          else
            old_record.touch
          end
        end
      end

      record = o.send name
      if record && record.persisted?
        if touch != true
          record.touch touch
        else
          record.touch
        end
      end
    end

    def self.add_touch_callbacks(model, reflection)
      foreign_key = reflection.foreign_key
      n           = reflection.name
      touch       = reflection.options[:touch]

      callback = lambda { |record|
        BelongsTo.touch_record(record, foreign_key, n, touch)
      }

      model.after_save    callback
      model.after_touch   callback
      model.after_destroy callback
    end
  end
end

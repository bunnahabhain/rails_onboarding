module RailsOnboarding
  # Whether a host model's columns can be read yet.
  #
  # Three concerns inspect columns the moment they are included -- to decide
  # whether to configure JSON serialization -- and `columns_hash` and
  # `column_names` both query the database. That runs when the host model is
  # loaded, which can be long before the table exists.
  #
  # A host that references its user model from an initializer hits this
  # immediately. The common OmniAuth `:identity` setup passes `model: User`, so
  # the model loads during boot and the process dies with
  # `Table 'users' doesn't exist`. That is circular and unrecoverable: loading
  # the schema requires booting the app, and booting the app requires the
  # schema. It stops `db:prepare` bootstrapping a genuinely new database, a
  # restore into an empty schema, and CI against a fresh database service.
  module SchemaGuard
    module_function

    # Only ever answers false when the table is positively known to be absent.
    #
    # These concerns are deliberately includable into plain classes that are not
    # ActiveRecord models -- hence the `respond_to?(:has_many)` and
    # `respond_to?(:validate)` guards in Onboardable -- and such a class answers
    # `columns_hash` while having no `table_exists?`. Vetoing those would
    # silently stop configuring them, so anything that cannot be asked is
    # treated as queryable and left to the callers' own guards, exactly as
    # before this check existed.
    def columns_queryable?(model)
      return true unless model.respond_to?(:table_exists?)

      model.table_exists?
    rescue ActiveRecord::NoDatabaseError,
           ActiveRecord::ConnectionNotEstablished,
           ActiveRecord::StatementInvalid
      false
    end
  end
end

module RailsOnboarding
  # Per-request/per-job isolated state.
  #
  # MultiTenant.with_tenant_configuration uses this to apply tenant-specific
  # configuration overrides for the duration of a block without mutating the
  # shared RailsOnboarding.configuration singleton - CurrentAttributes is
  # isolated per thread/fiber and is automatically reset by Rails around each
  # request and job, so concurrent requests on a threaded server can never
  # observe (or clobber) each other's tenant configuration.
  class Current < ActiveSupport::CurrentAttributes
    attribute :tenant_overrides
  end
end

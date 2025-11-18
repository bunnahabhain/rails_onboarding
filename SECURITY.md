# Security Guide

This document outlines security considerations and best practices for using the Rails Onboarding gem.

## Table of Contents

1. [CSRF Protection](#csrf-protection)
2. [API Authentication](#api-authentication)
3. [Rate Limiting](#rate-limiting)
4. [Input Sanitization](#input-sanitization)
5. [Authorization](#authorization)
6. [Webhook Security](#webhook-security)
7. [SQL Injection Prevention](#sql-injection-prevention)
8. [Secure Token Storage](#secure-token-storage)

## CSRF Protection

### Web Endpoints

All standard Rails web endpoints in the gem include CSRF protection by default through Rails' built-in `protect_from_forgery` mechanism.

**How it works:**
- Rails automatically includes a CSRF token in all forms and AJAX requests
- The token is validated on each POST, PUT, PATCH, and DELETE request
- Invalid tokens result in a `ActionController::InvalidAuthenticityToken` exception

**Best Practices:**
```ruby
# In your views, ensure CSRF tokens are included
<%= form_with model: @user do |f| %>
  <%= f.hidden_field :authenticity_token, value: form_authenticity_token %>
  <!-- form fields -->
<% end %>

# For AJAX requests with Turbo/Stimulus
// CSRF token is automatically included in request headers
fetch('/api/endpoint', {
  method: 'POST',
  headers: {
    'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
    'Content-Type': 'application/json'
  }
})
```

### API Endpoints

API endpoints (under `/api/`) skip CSRF verification because they use token-based authentication instead.

**Configuration:**
```ruby
# In API controllers
class MyApiController < ApplicationController
  include RailsOnboarding::ApiMode

  # CSRF is automatically skipped for API requests
  # Token authentication is used instead
end
```

**Why skip CSRF for APIs:**
- API requests come from mobile apps, SPAs, and other non-browser clients
- These clients cannot maintain session cookies or CSRF tokens
- Token-based authentication provides equivalent security

**Security Note:** Never disable CSRF protection for web endpoints that use session-based authentication.

## API Authentication

### Token-Based Authentication

The gem uses secure token-based authentication for all API endpoints.

**Setup:**

1. Add an `api_token` column to your User model:
```ruby
rails generate migration AddApiTokenToUsers api_token:string:index
rake db:migrate
```

2. Generate secure tokens for users:
```ruby
class User < ApplicationRecord
  before_create :generate_api_token

  private

  def generate_api_token
    self.api_token = SecureRandom.hex(32)
  end
end
```

3. Configure the gem:
```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.api_mode_enabled = true
  config.api_authentication_method = :token
end
```

**Custom Authentication:**

You can implement custom token authentication:
```ruby
class User < ApplicationRecord
  def self.find_by_api_token(token)
    # Constant-time comparison to prevent timing attacks
    users = where(active: true)
    users.find do |user|
      ActiveSupport::SecurityUtils.secure_compare(
        user.api_token.to_s,
        token.to_s
      )
    end
  end
end
```

**Security Best Practices:**
- Use cryptographically secure random tokens (SecureRandom.hex)
- Store tokens hashed in the database (like passwords)
- Implement token rotation/expiration
- Use HTTPS in production
- Never log or expose tokens in error messages

## Rate Limiting

The gem includes built-in rate limiting to prevent abuse.

### Configuration

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.rate_limiting_enabled = true
  config.rate_limit_per_period = 60    # 60 requests
  config.rate_limit_period = 60        # per 60 seconds (1 minute)
end
```

### How It Works

- Tracks requests per IP address (unauthenticated) or user ID (authenticated)
- Returns `429 Too Many Requests` when limit is exceeded
- Includes `Retry-After` header indicating when to retry
- Adds rate limit headers to all responses:
  - `X-RateLimit-Limit`: Maximum requests allowed
  - `X-RateLimit-Remaining`: Requests remaining in current period
  - `X-RateLimit-Reset`: Unix timestamp when the limit resets

### Custom Rate Limiting

Override rate limiting in your controllers:
```ruby
class MyController < ApplicationController
  include RailsOnboarding::RateLimitable

  private

  def rate_limit_per_period
    current_user&.premium? ? 1000 : 60
  end

  def rate_limit_period
    1.minute
  end
end
```

## Input Sanitization

### Step Data Sanitization

All user input through `step_data` params is automatically sanitized:

```ruby
# Dangerous keys are automatically removed:
# - authenticity_token
# - _method
# - controller
# - action

# Use permitted params in your custom processing
def process_step_data(step_name, data)
  case step_name
  when :profile
    # Only permit specific attributes
    current_user.update(data.permit(:name, :timezone, :notifications_enabled))
  end
end
```

### Strong Parameters

Always use strong parameters for user input:
```ruby
def user_params
  params.require(:user).permit(:name, :email, :timezone)
end
```

### XSS Prevention

The gem uses Rails' built-in XSS protection:
- All output is HTML-escaped by default
- Use `sanitize()` for user-generated HTML content
- Never use `html_safe` on user input

## Authorization

### Admin Access

Admin controllers require proper authorization:

```ruby
# Add admin? method to your User model
class User < ApplicationRecord
  def admin?
    role == 'admin'
  end
end

# Or implement custom authentication
class ApplicationController < ActionController::Base
  def authenticate_rails_onboarding_admin!
    redirect_to root_path unless current_user&.admin?
  end
end
```

### Access Control

The gem logs all unauthorized access attempts:
```ruby
# Check logs for security issues
Rails.logger.warn "Unauthorized admin access attempt by user #123"
```

## Webhook Security

### Signature Verification

All webhooks include cryptographic signatures for verification:

**Configuration:**
```ruby
RailsOnboarding.configure do |config|
  config.webhooks_enabled = true
  config.webhook_secret_key = ENV['WEBHOOK_SECRET_KEY']
  config.webhook_endpoints = [
    {
      url: 'https://your-app.com/webhooks/onboarding',
      events: [:onboarding_completed, :step_completed]
    }
  ]
end
```

**Signature Generation:**
```ruby
# The gem generates signatures using HMAC-SHA256
signature = OpenSSL::HMAC.hexdigest(
  'SHA256',
  secret_key,
  "#{event_name}:#{payload.to_json}:#{timestamp}"
)
```

**Verifying Webhooks:**
```ruby
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def onboarding
    # Verify signature
    signature = request.headers['X-Webhook-Signature']
    timestamp = request.headers['X-Webhook-Timestamp']

    unless verify_signature(signature, timestamp, request.raw_post)
      render json: { error: 'Invalid signature' }, status: :unauthorized
      return
    end

    # Process webhook
    # ...
  end

  private

  def verify_signature(signature, timestamp, body)
    # Prevent replay attacks - reject old signatures
    return false if Time.at(timestamp.to_i) < 5.minutes.ago

    expected_signature = OpenSSL::HMAC.hexdigest(
      'SHA256',
      ENV['WEBHOOK_SECRET_KEY'],
      body
    )

    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end
end
```

**Security Best Practices:**
- Always verify webhook signatures
- Use constant-time comparison to prevent timing attacks
- Implement replay protection with timestamps
- Use HTTPS for all webhook endpoints
- Store secret keys in environment variables

## SQL Injection Prevention

### Parameterized Queries

The gem uses ActiveRecord which automatically prevents SQL injection through parameterized queries:

```ruby
# Safe - uses parameterized query
User.where("email = ?", params[:email])
User.where(email: params[:email])

# Unsafe - vulnerable to SQL injection (NEVER DO THIS)
User.where("email = '#{params[:email]}'")
```

### Dynamic Queries

When building dynamic queries, always sanitize input:

```ruby
# Safe column sorting
ALLOWED_SORT_COLUMNS = %w[name created_at email].freeze

def sort_column
  ALLOWED_SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : 'created_at'
end

def sort_direction
  %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
end

users = User.order("#{sort_column} #{sort_direction}")
```

## Secure Token Storage

### Environment Variables

Store all sensitive credentials in environment variables:

```bash
# .env (DO NOT commit this file)
WEBHOOK_SECRET_KEY=your_secure_secret_key_here
API_TOKEN_SECRET=another_secure_secret_here
```

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.webhook_secret_key = ENV['WEBHOOK_SECRET_KEY']
end
```

### Encrypted Credentials

Use Rails encrypted credentials for production:

```bash
# Edit credentials
EDITOR=vim rails credentials:edit

# Add secrets
webhook_secret_key: <%= SecureRandom.hex(32) %>
```

```ruby
# Access in configuration
config.webhook_secret_key = Rails.application.credentials.webhook_secret_key
```

### Token Rotation

Implement token rotation for API tokens:

```ruby
class User < ApplicationRecord
  def rotate_api_token!
    update!(
      api_token: SecureRandom.hex(32),
      api_token_rotated_at: Time.current
    )
  end

  def api_token_expired?
    api_token_rotated_at.nil? || api_token_rotated_at < 90.days.ago
  end
end
```

## Security Checklist

- [ ] Enable CSRF protection for all web endpoints
- [ ] Use token authentication for API endpoints
- [ ] Configure rate limiting
- [ ] Implement proper authorization for admin access
- [ ] Verify webhook signatures
- [ ] Use parameterized queries for all database access
- [ ] Store secrets in environment variables or encrypted credentials
- [ ] Use HTTPS in production
- [ ] Implement token rotation
- [ ] Monitor logs for unauthorized access attempts
- [ ] Keep dependencies up to date
- [ ] Perform regular security audits

## Reporting Security Issues

If you discover a security vulnerability, please email security@example.com instead of using the issue tracker.

## Additional Resources

- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Rails API Documentation - Security](https://api.rubyonrails.org/)

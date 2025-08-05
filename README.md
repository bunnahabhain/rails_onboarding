# RailsOnboarding
Short description and motivation.

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "rails_onboarding"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install rails_onboarding
```

## Requirements

This gem requires that your application has:
1. An `ApplicationController` class
2. A `current_user` method available in your controllers
3. Authentication in place (Devise, Authlogic, or custom)

## How it Works

The onboarding controllers inherit from your app's `ApplicationController`,
which means they have access to all your authentication methods and helpers.


## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

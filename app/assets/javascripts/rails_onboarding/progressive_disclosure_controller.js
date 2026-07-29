import { Controller } from "@hotwired/stimulus"

// Progressive Disclosure Stimulus Controller
// Handles automatic checking and displaying of progressive features
//
// Usage:
//   <div data-controller="progressive-disclosure"
//        data-progressive-disclosure-check-interval-value="60000">
//   </div>
export default class extends Controller {
  static values = {
    checkInterval: { type: Number, default: 60000 }, // Check every minute
    autoReveal: { type: Boolean, default: true },
    notificationPosition: { type: String, default: 'top-right' }
  }

  static targets = ['notification', 'featureList']

  connect() {
    this.checkReadyFeatures()

    // Set up periodic checking if interval is > 0
    if (this.checkIntervalValue > 0) {
      this.intervalId = setInterval(() => {
        this.checkReadyFeatures()
      }, this.checkIntervalValue)
    }
  }

  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
    }
  }

  // Check for features that are ready to be revealed
  async checkReadyFeatures() {
    try {
      const response = await fetch('/rails_onboarding/progressive_features/ready', {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (!response.ok) return

      const features = await response.json()

      if (features && features.length > 0) {
        this.handleReadyFeatures(features)
      }
    } catch (error) {
      console.error('Error checking progressive features:', error)
    }
  }

  // Handle features that are ready
  handleReadyFeatures(features) {
    if (this.autoRevealValue) {
      // Automatically reveal all ready features
      this.revealAllReady()
    } else {
      // Show notifications for each ready feature
      features.forEach(feature => {
        this.showFeatureNotification(feature)
      })
    }
  }

  // Show a notification for a new feature
  showFeatureNotification(feature) {
    const notification = this.createNotificationElement(feature)
    document.body.appendChild(notification)

    // Animate in
    setTimeout(() => {
      notification.classList.add('onboarding-show')
    }, 100)

    // Auto-dismiss after 10 seconds if not interacted with
    setTimeout(() => {
      if (notification.parentElement) {
        this.dismissNotification(notification)
      }
    }, 10000)
  }

  // Create notification DOM element
  createNotificationElement(feature) {
    const notification = document.createElement('div')
    notification.className = `progressive-feature-notification ${this.notificationPositionValue}`
    notification.dataset.featureKey = feature.key

    notification.innerHTML = `
      <div class="notification-content">
        <div class="notification-header">
          <span class="notification-icon">✨</span>
          <h4>${feature.title || 'New Feature Available'}</h4>
          <button class="notification-close" data-action="click->progressive-disclosure#dismissNotification">×</button>
        </div>
        <p>${feature.description || 'A new feature is now available for you!'}</p>
        <div class="notification-actions">
          <button class="onboarding-btn onboarding-btn-primary" data-action="click->progressive-disclosure#revealFeature" data-feature-key="${feature.key}">
            Explore Now
          </button>
          <button class="onboarding-btn onboarding-btn-secondary" data-action="click->progressive-disclosure#dismissNotification">
            Later
          </button>
        </div>
      </div>
    `

    return notification
  }

  // Reveal a specific feature
  async revealFeature(event) {
    const featureKey = event.currentTarget.dataset.featureKey
    const notification = event.currentTarget.closest('.progressive-feature-notification')

    try {
      const response = await fetch(`/rails_onboarding/progressive_features/${featureKey}/reveal`, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (!response.ok) {
        throw new Error('Failed to reveal feature')
      }

      const data = await response.json()

      if (data.success) {
        this.dismissNotification(notification)

        // Trigger custom event for feature revealed
        this.dispatch('featureRevealed', {
          detail: { feature: data.feature }
        })

        // Navigate to feature if URL is provided
        if (data.feature && data.feature.url) {
          window.location.href = data.feature.url
        }
      }
    } catch (error) {
      console.error('Error revealing feature:', error)
    }
  }

  // Reveal all ready features
  async revealAllReady() {
    try {
      const response = await fetch('/rails_onboarding/progressive_features/reveal_all_ready', {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (!response.ok) return

      const data = await response.json()

      if (data.success && data.revealed && data.revealed.length > 0) {
        // Dispatch event for all revealed features
        this.dispatch('featuresRevealed', {
          detail: { features: data.revealed }
        })
      }
    } catch (error) {
      console.error('Error revealing features:', error)
    }
  }

  // Dismiss a notification
  dismissNotification(target) {
    const notification = target.target ? target.currentTarget.closest('.progressive-feature-notification') : target

    if (!notification) return

    notification.classList.remove('onboarding-show')
    notification.classList.add('onboarding-hide')

    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove()
      }
    }, 300)

    // Track dismissal
    const featureKey = notification.dataset.featureKey
    if (featureKey) {
      fetch(`/rails_onboarding/progressive_features/${featureKey}/dismiss`, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      }).catch(error => {
        console.error('Error tracking dismissal:', error)
      })
    }
  }

  // Get CSRF token
  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ''
  }
}

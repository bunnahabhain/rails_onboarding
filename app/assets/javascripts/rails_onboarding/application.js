/**
 * Rails Onboarding JavaScript Application
 *
 * This file provides flexible integration with different JavaScript bundling strategies:
 * - Stimulus (via importmap or bundler)
 * - Standalone (without Stimulus)
 * - ESBuild/Webpack/Vite
 *
 * The code automatically detects the environment and adapts accordingly.
 *
 * Compatibility:
 * - Works with Asset Pipeline (Sprockets)
 * - Works with Propshaft
 * - Works with importmap-rails
 * - Works with esbuild, webpack, vite, etc.
 */

(function() {
  'use strict';

  // Initialize Stimulus application if available
  function initializeStimulusIfAvailable() {
    // Check if Stimulus is already loaded
    if (window.Stimulus) {
      console.log('RailsOnboarding: Using existing Stimulus application');
      return window.Stimulus;
    }

    // Check if we can create a new Stimulus application
    if (typeof Application !== 'undefined') {
      const app = Application.start();
      app.debug = false;
      window.Stimulus = app;
      console.log('RailsOnboarding: Created new Stimulus application');
      return app;
    }

    console.debug('RailsOnboarding: Stimulus not available, using standalone mode');
    return null;
  }

  // Auto-initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      initializeStimulusIfAvailable();
    });
  } else {
    initializeStimulusIfAvailable();
  }
})();

// Global utilities for onboarding
window.RailsOnboarding = {
    // Show a global tooltip
    showTooltip: function(element, content, options = {}) {
        const tooltip = new TooltipController()
        tooltip.element = element
        tooltip.featureValue = options.feature || ''
        tooltip.positionValue = options.position || 'top'
        tooltip.delayValue = options.delay || 0
        tooltip.dismissibleValue = options.dismissible !== false

        // Override content method
        tooltip.getTooltipContent = () => content

        tooltip.connect()
        tooltip.forceShow()

        return tooltip
    },

    // Hide all tooltips
    hideAllTooltips: function() {
        document.querySelectorAll('.onboarding-tooltip').forEach(tooltip => {
            if (tooltip.parentNode) {
                tooltip.parentNode.removeChild(tooltip)
            }
        })
    },

    // Restart onboarding (if supported by backend)
    restartOnboarding: function() {
        if (confirm('Are you sure you want to restart the onboarding process?')) {
            if (typeof Rails !== 'undefined' && Rails.ajax) {
                Rails.ajax({
                    url: '/rails_onboarding/onboarding/restart',
                    type: 'POST',
                    headers: {
                        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
                    },
                    success: function() {
                        window.location.reload()
                    },
                    error: function() {
                        alert('Failed to restart onboarding. Please try again.')
                    }
                })
            }
        }
    },

    // Skip to end of onboarding
    skipToEnd: function() {
        if (confirm('Are you sure you want to skip the remaining onboarding steps?')) {
            const skipForm = document.createElement('form')
            skipForm.method = 'POST'
            skipForm.action = '/rails_onboarding/onboarding/complete'

            const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
            if (csrfToken) {
                const csrfInput = document.createElement('input')
                csrfInput.type = 'hidden'
                csrfInput.name = 'authenticity_token'
                csrfInput.value = csrfToken
                skipForm.appendChild(csrfInput)
            }

            document.body.appendChild(skipForm)
            skipForm.submit()
        }
    },

    // Get current onboarding progress
    getProgress: function() {
        const progressController = document.querySelector('[data-controller*="progress"]')
        if (progressController) {
            return {
                current: progressController.dataset.progressCurrentStepValue || 1,
                total: progressController.dataset.progressTotalStepsValue || 4,
                percentage: progressController.dataset.progressValue || 0
            }
        }
        return null
    },

    // Add custom step validation
    addStepValidation: function(stepName, validationFunction) {
        const onboardingController = document.querySelector('[data-controller*="onboarding"]')
        if (onboardingController && onboardingController.stimulus) {
            const controller = onboardingController.stimulus
            if (!controller.customValidations) {
                controller.customValidations = {}
            }
            controller.customValidations[stepName] = validationFunction
        }
    }
}

// Auto-initialize tooltips for elements with data-tooltip attribute
document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('[data-tooltip]').forEach(element => {
        const tooltipText = element.dataset.tooltip
        const feature = element.dataset.tooltipFeature
        const position = element.dataset.tooltipPosition || 'top'
        const delay = parseInt(element.dataset.tooltipDelay) || 0

        if (tooltipText && !element.dataset.controllerAdded) {
            element.dataset.controller = (element.dataset.controller || '') + ' tooltip'
            element.dataset.tooltipFeatureValue = feature || ''
            element.dataset.tooltipPositionValue = position
            element.dataset.tooltipDelayValue = delay
            element.dataset.tooltipText = tooltipText
            element.dataset.controllerAdded = 'true'

            // Re-initialize Stimulus for this element
            application.register("tooltip", TooltipController)
        }
    })
})

// Handle onboarding completion celebration
document.addEventListener('onboarding:completed', function(event) {
    // Show celebration animation or message
    const celebration = document.createElement('div')
    celebration.innerHTML = `
    <div style="
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: white;
      padding: 2rem;
      border-radius: 1rem;
      box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
      text-align: center;
      z-index: 9999;
    ">
      <div style="font-size: 3rem; margin-bottom: 1rem;">🎉</div>
      <h2 style="margin-bottom: 1rem; color: #1f2937;">Congratulations!</h2>
      <p style="color: #6b7280; margin-bottom: 1.5rem;">You've completed the onboarding process.</p>
      <button onclick="this.parentElement.parentElement.remove()" style="
        background: #6366f1;
        color: white;
        border: none;
        padding: 0.75rem 1.5rem;
        border-radius: 0.5rem;
        cursor: pointer;
        font-weight: 600;
      ">Get Started</button>
    </div>
  `

    document.body.appendChild(celebration)

    // Auto-remove after 5 seconds
    setTimeout(() => {
        if (celebration.parentNode) {
            celebration.remove()
        }
    }, 5000)
})

// Handle page transitions during onboarding
document.addEventListener('turbo:before-visit', function(event) {
    // Hide tooltips before navigation
    RailsOnboarding.hideAllTooltips()
})

// Re-initialize onboarding after Turbo navigation
document.addEventListener('turbo:load', function() {
    // Refresh any dynamic onboarding elements
    const onboardingContainer = document.querySelector('.onboarding-container')
    if (onboardingContainer) {
        onboardingContainer.setAttribute('data-step-changed', 'true')

        // Remove the attribute after animation
        setTimeout(() => {
            onboardingContainer.removeAttribute('data-step-changed')
        }, 300)
    }
})

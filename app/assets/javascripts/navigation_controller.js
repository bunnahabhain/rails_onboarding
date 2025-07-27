import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["helpTooltip"]
    static values = { currentStep: String }

    connect() {
        this.setupKeyboardShortcuts()
        this.setupClickOutsideHandler()
    }

    // Show help tooltip
    showHelp(event) {
        event.preventDefault()

        if (this.hasHelpTooltipTarget) {
            this.helpTooltipTarget.hidden = false
            this.positionTooltip()
            this.focusTooltip()
        }
    }

    // Hide help tooltip
    hideHelp(event) {
        if (event) event.preventDefault()

        if (this.hasHelpTooltipTarget) {
            this.helpTooltipTarget.hidden = true
        }
    }

    // Handle skip confirmation
    confirmSkip(event) {
        const confirmed = confirm(event.target.dataset.confirm || "Are you sure you want to skip this step?")

        if (!confirmed) {
            event.preventDefault()
            return false
        }

        // Track skip event for analytics
        this.trackSkipEvent()
        return true
    }

    // Position help tooltip relative to button
    positionTooltip() {
        if (!this.hasHelpTooltipTarget) return

        const tooltip = this.helpTooltipTarget
        const button = this.element.querySelector('.help-action')

        if (button) {
            const buttonRect = button.getBoundingClientRect()
            const tooltipRect = tooltip.getBoundingClientRect()

            // Position above the button by default
            let top = buttonRect.top - tooltipRect.height - 8
            let left = buttonRect.left + (buttonRect.width / 2) - (tooltipRect.width / 2)

            // Adjust if tooltip would be off-screen
            if (top < 8) {
                // Position below if no room above
                top = buttonRect.bottom + 8
            }

            if (left < 8) {
                left = 8
            } else if (left + tooltipRect.width > window.innerWidth - 8) {
                left = window.innerWidth - tooltipRect.width - 8
            }

            tooltip.style.position = 'fixed'
            tooltip.style.top = `${top}px`
            tooltip.style.left = `${left}px`
        }
    }

    // Focus the first focusable element in tooltip
    focusTooltip() {
        if (this.hasHelpTooltipTarget) {
            const focusableElement = this.helpTooltipTarget.querySelector('button, a, input, [tabindex]')
            if (focusableElement) {
                focusableElement.focus()
            }
        }
    }

    // Setup keyboard shortcuts
    setupKeyboardShortcuts() {
        document.addEventListener('keydown', this.handleKeyboard.bind(this))
    }

    // Handle keyboard events
    handleKeyboard(event) {
        // Close help on Escape
        if (event.key === 'Escape' && this.hasHelpTooltipTarget && !this.helpTooltipTarget.hidden) {
            this.hideHelp()
            return
        }

        // Show help on F1 or Ctrl+?
        if (event.key === 'F1' || (event.ctrlKey && event.key === '?')) {
            event.preventDefault()
            this.showHelp(event)
            return
        }

        // Skip with Ctrl+S (if skippable)
        if (event.ctrlKey && event.key === 's') {
            const skipButton = this.element.querySelector('.skip-action')
            if (skipButton) {
                event.preventDefault()
                skipButton.click()
            }
        }
    }

    // Setup click outside handler to close tooltip
    setupClickOutsideHandler() {
        document.addEventListener('click', (event) => {
            if (this.hasHelpTooltipTarget && !this.helpTooltipTarget.hidden) {
                // Check if click is outside tooltip and help button
                const tooltip = this.helpTooltipTarget
                const helpButton = this.element.querySelector('.help-action')

                if (!tooltip.contains(event.target) && !helpButton.contains(event.target)) {
                    this.hideHelp()
                }
            }
        })
    }

    // Track skip event for analytics
    trackSkipEvent() {
        // Send analytics event if analytics system is available
        if (typeof gtag !== 'undefined') {
            gtag('event', 'onboarding_step_skipped', {
                step: this.currentStepValue,
                timestamp: new Date().toISOString()
            })
        }

        // Send to Rails if needed
        if (typeof Rails !== 'undefined' && Rails.ajax) {
            Rails.ajax({
                url: '/rails_onboarding/analytics/skip',
                type: 'POST',
                data: `step=${encodeURIComponent(this.currentStepValue)}`,
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
                }
            })
        }
    }

    // Handle navigation button clicks
    navigateToStep(event) {
        const direction = event.params.direction
        const form = document.querySelector('.onboarding-form')

        if (direction === 'next' && form) {
            // Validate form before proceeding
            const isValid = this.validateCurrentStep()
            if (isValid) {
                form.submit()
            }
        } else if (direction === 'previous') {
            // Handle previous navigation (if implemented)
            this.goToPreviousStep()
        }
    }

    // Validate current step before proceeding
    validateCurrentStep() {
        const form = document.querySelector('.onboarding-form')
        if (!form) return true

        // Check required fields
        const requiredFields = form.querySelectorAll('input[required], select[required]')
        const radioGroups = this.getRadioGroups(form)

        // Validate radio button groups
        for (const groupName in radioGroups) {
            const group = radioGroups[groupName]
            const hasSelection = group.some(radio => radio.checked)

            if (!hasSelection && group.length > 0) {
                this.showValidationMessage('Please make a selection to continue.')
                group[0].focus()
                return false
            }
        }

        // Validate other required fields
        for (const field of requiredFields) {
            if (field.value.trim() === '') {
                this.showValidationMessage('Please fill in all required fields.')
                field.focus()
                return false
            }
        }

        return true
    }

    // Get radio button groups
    getRadioGroups(form) {
        const radioGroups = {}

        form.querySelectorAll('input[type="radio"]').forEach(radio => {
            if (!radioGroups[radio.name]) {
                radioGroups[radio.name] = []
            }
            radioGroups[radio.name].push(radio)
        })

        return radioGroups
    }

    // Show validation message
    showValidationMessage(message) {
        // Remove existing messages
        document.querySelectorAll('.navigation-validation-error').forEach(error => {
            error.remove()
        })

        // Create new message
        const errorDiv = document.createElement('div')
        errorDiv.className = 'navigation-validation-error'
        errorDiv.style.cssText = `
      background: #fef2f2;
      border: 1px solid #fecaca;
      color: #dc2626;
      padding: 0.75rem;
      border-radius: 0.5rem;
      margin: 1rem 0;
      text-align: center;
      font-size: 0.875rem;
    `
        errorDiv.textContent = message

        // Insert at top of navigation
        this.element.insertBefore(errorDiv, this.element.firstChild)

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (errorDiv.parentNode) {
                errorDiv.remove()
            }
        }, 5000)
    }

    // Go to previous step (if supported)
    goToPreviousStep() {
        // This would need to be implemented based on your routing
        console.log('Previous step navigation not yet implemented')
    }

    // Show progress summary
    showProgressSummary() {
        const progress = document.querySelector('[data-controller="progress"]')
        if (progress) {
            const currentStep = progress.dataset.progressCurrentStepValue || 1
            const totalSteps = progress.dataset.progressTotalStepsValue || 4

            alert(`Progress: Step ${currentStep} of ${totalSteps}`)
        }
    }

    // Cleanup on disconnect
    disconnect() {
        document.removeEventListener('keydown', this.handleKeyboard)
        document.removeEventListener('click', this.handleClickOutside)
    }
}

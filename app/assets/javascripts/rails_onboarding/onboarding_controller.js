import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["submitButton", "radioButton"]
    static values = { currentStep: String }

    connect() {
        this.updateSubmitButtonState()
        this.setupKeyboardNavigation()
        this.announceStepToScreenReader()
    }

    // Enable submit button when radio button is selected
    enableSubmit(event) {
        const submitButton = this.element.querySelector('.primary-action[disabled]')
        if (submitButton && event.target.checked) {
            submitButton.disabled = false
            submitButton.textContent = submitButton.textContent.replace('disabled', '')
        }
    }

    // Handle radio button changes
    radioChanged(event) {
        if (event.target.type === 'radio' && event.target.checked) {
            this.enableSubmitButton()
            this.updateSelectedChoice(event.target)
        }
    }

    // Show feature tooltip
    showFeatureTooltip(event) {
        const feature = event.target.dataset.featureTarget
        const tooltip = this.createTooltip(feature)
        this.showTooltip(tooltip, event.target)
    }

    // Update submit button state based on form validity
    updateSubmitButtonState() {
        const submitButton = this.element.querySelector('.primary-action')
        const radioButtons = this.element.querySelectorAll('input[type="radio"]')
        const requiredFields = this.element.querySelectorAll('input[required], select[required]')

        if (submitButton && (radioButtons.length > 0 || requiredFields.length > 0)) {
            const hasSelection = Array.from(radioButtons).some(radio => radio.checked)
            const allRequiredFilled = Array.from(requiredFields).every(field =>
                field.value.trim() !== ''
            )

            if (radioButtons.length > 0) {
                submitButton.disabled = !hasSelection
            } else if (requiredFields.length > 0) {
                submitButton.disabled = !allRequiredFilled
            }
        }
    }

    // Enable the submit button
    enableSubmitButton() {
        const submitButton = this.element.querySelector('.primary-action')
        if (submitButton) {
            submitButton.disabled = false
        }
    }

    // Update visual state of selected choice
    updateSelectedChoice(selectedRadio) {
        // Remove selection from all choices
        this.element.querySelectorAll('.action-choice').forEach(choice => {
            choice.classList.remove('selected')
        })

        // Add selection to current choice
        const selectedChoice = selectedRadio.closest('.action-choice')
        if (selectedChoice) {
            selectedChoice.classList.add('selected')
        }
    }

    // Create tooltip for feature explanation
    createTooltip(feature) {
        const tooltips = {
            organizing: {
                title: "Smart Organization",
                content: "Create hierarchical lists, set priorities, add due dates, and organize items exactly how you think. Use tags, categories, and custom sorting to keep everything in its place."
            },
            collaboration: {
                title: "Team Collaboration",
                content: "Invite team members, assign tasks, leave comments, and track progress together. Real-time updates keep everyone synchronized and productive."
            },
            automation: {
                title: "Smart Automation",
                content: "Set up recurring tasks, automated reminders, smart templates, and rule-based actions. Let the app handle routine work so you can focus on what matters."
            },
            insights: {
                title: "Progress Insights",
                content: "Track completion rates, identify patterns, see productivity trends, and get personalized suggestions to improve your workflow and achieve your goals."
            }
        }

        return tooltips[feature] || { title: "Feature", content: "Learn more about this feature." }
    }

    // Show tooltip near target element
    showTooltip(tooltipData, targetElement) {
        // Remove any existing tooltips
        this.hideTooltips()

        const tooltip = document.createElement('div')
        tooltip.className = 'feature-tooltip'
        tooltip.innerHTML = `
      <div class="tooltip-content">
        <h4>${tooltipData.title}</h4>
        <p>${tooltipData.content}</p>
        <button type="button" class="tooltip-close" data-action="click->onboarding#hideTooltips">
          Got it
        </button>
      </div>
    `

        // Position tooltip
        document.body.appendChild(tooltip)
        this.positionTooltip(tooltip, targetElement)

        // Auto-hide after 10 seconds
        setTimeout(() => this.hideTooltips(), 10000)
    }

    // Position tooltip relative to target
    positionTooltip(tooltip, target) {
        const rect = target.getBoundingClientRect()
        const tooltipRect = tooltip.getBoundingClientRect()

        let top = rect.bottom + 10
        let left = rect.left + (rect.width / 2) - (tooltipRect.width / 2)

        // Adjust if tooltip would be off-screen
        if (left < 10) left = 10
        if (left + tooltipRect.width > window.innerWidth - 10) {
            left = window.innerWidth - tooltipRect.width - 10
        }
        if (top + tooltipRect.height > window.innerHeight - 10) {
            top = rect.top - tooltipRect.height - 10
        }

        tooltip.style.position = 'fixed'
        tooltip.style.top = `${top}px`
        tooltip.style.left = `${left}px`
        tooltip.style.zIndex = '1000'
    }

    // Hide all tooltips
    hideTooltips() {
        document.querySelectorAll('.feature-tooltip').forEach(tooltip => {
            tooltip.remove()
        })
    }

    // Setup keyboard navigation
    setupKeyboardNavigation() {
        this.element.addEventListener('keydown', (event) => {
            if (event.key === 'Escape') {
                this.hideTooltips()
            }

            // Arrow key navigation for radio buttons
            if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
                const radioButtons = Array.from(this.element.querySelectorAll('input[type="radio"]'))
                const currentIndex = radioButtons.findIndex(radio => radio.checked)

                if (radioButtons.length > 0) {
                    event.preventDefault()
                    let nextIndex

                    if (event.key === 'ArrowDown') {
                        nextIndex = (currentIndex + 1) % radioButtons.length
                    } else {
                        nextIndex = currentIndex <= 0 ? radioButtons.length - 1 : currentIndex - 1
                    }

                    radioButtons[nextIndex].checked = true
                    radioButtons[nextIndex].focus()
                    this.updateSelectedChoice(radioButtons[nextIndex])
                    this.enableSubmitButton()
                }
            }
        })
    }

    // Announce step change to screen readers
    announceStepToScreenReader() {
        const announcement = document.createElement('div')
        announcement.setAttribute('aria-live', 'polite')
        announcement.setAttribute('aria-atomic', 'true')
        announcement.className = 'onboarding-sr-only'
        announcement.style.cssText = 'position: absolute; left: -10000px; width: 1px; height: 1px; overflow: hidden;'

        const stepTitle = this.element.querySelector('.step-title')
        if (stepTitle) {
            announcement.textContent = `Onboarding step: ${stepTitle.textContent}`
            document.body.appendChild(announcement)

            // Remove after announcement
            setTimeout(() => {
                if (announcement.parentNode) {
                    announcement.parentNode.removeChild(announcement)
                }
            }, 1000)
        }
    }

    // Handle form submission with validation
    submitForm(event) {
        const form = event.target.closest('form')
        if (form) {
            // Validate required fields
            const requiredFields = form.querySelectorAll('input[required], select[required]')
            const radioGroups = {}

            // Check radio button groups
            form.querySelectorAll('input[type="radio"]').forEach(radio => {
                if (!radioGroups[radio.name]) {
                    radioGroups[radio.name] = []
                }
                radioGroups[radio.name].push(radio)
            })

            // Validate radio groups
            for (const groupName in radioGroups) {
                const group = radioGroups[groupName]
                const hasSelection = group.some(radio => radio.checked)

                if (!hasSelection && group.length > 0) {
                    event.preventDefault()
                    this.showValidationError('Please make a selection to continue.')
                    return false
                }
            }

            // Validate other required fields
            for (const field of requiredFields) {
                if (field.value.trim() === '') {
                    event.preventDefault()
                    field.focus()
                    this.showValidationError('Please fill in all required fields.')
                    return false
                }
            }
        }

        return true
    }

    // Show validation error message
    showValidationError(message) {
        // Remove existing error messages
        this.element.querySelectorAll('.validation-error').forEach(error => {
            error.remove()
        })

        // Create error message
        const errorDiv = document.createElement('div')
        errorDiv.className = 'validation-error'
        errorDiv.style.cssText = `
      background: #fef2f2;
      border: 1px solid #fecaca;
      color: #dc2626;
      padding: 0.75rem 1rem;
      border-radius: 0.5rem;
      margin-top: 1rem;
      font-size: 0.875rem;
      text-align: center;
    `
        errorDiv.textContent = message

        // Insert before action buttons
        const actionButtons = this.element.querySelector('.action-buttons')
        if (actionButtons) {
            actionButtons.parentNode.insertBefore(errorDiv, actionButtons)
        } else {
            this.element.appendChild(errorDiv)
        }

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (errorDiv.parentNode) {
                errorDiv.remove()
            }
        }, 5000)
    }

    // Handle input changes for real-time validation
    inputChanged(event) {
        this.updateSubmitButtonState()

        // Clear validation errors when user starts typing
        const existingErrors = this.element.querySelectorAll('.validation-error')
        if (existingErrors.length > 0) {
            existingErrors.forEach(error => error.remove())
        }
    }

    // Disconnect cleanup
    disconnect() {
        this.hideTooltips()
    }
}

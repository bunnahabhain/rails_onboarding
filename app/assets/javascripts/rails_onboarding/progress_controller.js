import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        progress: Number,
        totalSteps: Number,
        currentStep: Number
    }

    connect() {
        this.updateProgressDisplay()
    }

    // Update progress when values change
    progressValueChanged() {
        this.updateProgressDisplay()
    }

    currentStepValueChanged() {
        this.updateStepStates()
    }

    // Update the visual progress display. The fill's width comes from
    // --onboarding-progress-width (consumed by .progress-fill in CSS), so
    // changing it here still animates via the stylesheet's `transition:
    // width` - no inline width/transition needed.
    updateProgressDisplay() {
        const progressFill = this.element.querySelector('.onboarding-progress-fill')
        const progressText = this.element.querySelector('.current-progress')

        if (progressFill) {
            progressFill.style.setProperty('--onboarding-progress-width', `${this.progressValue}%`)
        }

        if (progressText) {
            progressText.textContent = `Step ${this.currentStepValue || 1}`
        }
    }

    // Update step marker states
    updateStepStates() {
        const steps = this.element.querySelectorAll('.progress-step')
        const currentStep = this.currentStepValue || 1

        steps.forEach((step, index) => {
            const stepNumber = index + 1
            const marker = step.querySelector('.step-marker')
            const checkElement = step.querySelector('.step-check')
            const numberElement = step.querySelector('.step-number')

            // Remove all state classes
            step.classList.remove('onboarding-completed', 'current', 'upcoming')

            // Add appropriate class based on progress
            if (stepNumber < currentStep) {
                step.classList.add('onboarding-completed')

                // Show checkmark for completed steps
                if (numberElement && !checkElement) {
                    numberElement.textContent = '✓'
                    numberElement.className = 'step-check'
                }
            } else if (stepNumber === currentStep) {
                step.classList.add('onboarding-current')

                // Show number for current step
                if (numberElement) {
                    numberElement.textContent = stepNumber
                    numberElement.className = 'step-number'
                }
            } else {
                step.classList.add('onboarding-upcoming')

                // Show number for upcoming steps
                if (numberElement) {
                    numberElement.textContent = stepNumber
                    numberElement.className = 'step-number'
                }
            }
        })
    }

    // Calculate progress percentage
    calculateProgress(currentStep, totalSteps) {
        if (!totalSteps || totalSteps <= 0) return 0
        return Math.min(100, Math.max(0, (currentStep / totalSteps) * 100))
    }

    // Pulse animation for current step
    pulseCurrentStep() {
        const currentStepElement = this.element.querySelector('.progress-step.onboarding-current .step-marker')
        if (currentStepElement) {
            currentStepElement.classList.add('step-marker-pulse')

            setTimeout(() => {
                currentStepElement.classList.remove('step-marker-pulse')
            }, 1000)
        }
    }

    // Show step tooltip on hover
    showStepTooltip(event) {
        const step = event.currentTarget
        const stepIndex = Array.from(step.parentNode.children).indexOf(step)
        const stepData = this.getStepData(stepIndex)

        if (stepData) {
            this.createStepTooltip(stepData, step)
        }
    }

    // Hide step tooltip
    hideStepTooltip(event) {
        const tooltip = document.querySelector('.step-tooltip')
        if (tooltip) {
            tooltip.remove()
        }
    }

    // Get step data for tooltip
    getStepData(stepIndex) {
        const stepNames = ['welcome', 'profile', 'first_action', 'explore']
        const stepTitles = ['Welcome', 'Setup Profile', 'First Action', 'Explore Features']
        const stepDescriptions = [
            'Get introduced to the platform',
            'Personalize your experience',
            'Take your first meaningful action',
            'Discover key features'
        ]

        if (stepIndex < stepNames.length) {
            return {
                name: stepNames[stepIndex],
                title: stepTitles[stepIndex],
                description: stepDescriptions[stepIndex]
            }
        }
        return null
    }

    // Create tooltip for step
    createStepTooltip(stepData, targetElement) {
        const tooltip = document.createElement('div')
        tooltip.className = 'step-tooltip'
        tooltip.innerHTML = `
      <div class="tooltip-content">
        <h4>${stepData.title}</h4>
        <p>${stepData.description}</p>
      </div>
    `

        // Position tooltip (top/left are computed per call, so they stay inline;
        // everything else lives in .step-tooltip)
        document.body.appendChild(tooltip)
        this.positionTooltip(tooltip, targetElement)

        // Auto-remove after 3 seconds
        setTimeout(() => {
            if (tooltip.parentNode) {
                tooltip.remove()
            }
        }, 3000)
    }

    // Position tooltip relative to target
    positionTooltip(tooltip, target) {
        const rect = target.getBoundingClientRect()
        const tooltipRect = tooltip.getBoundingClientRect()

        let top = rect.bottom + 8
        let left = rect.left + (rect.width / 2) - (tooltipRect.width / 2)

        // Adjust if tooltip would be off-screen
        if (left < 8) left = 8
        if (left + tooltipRect.width > window.innerWidth - 8) {
            left = window.innerWidth - tooltipRect.width - 8
        }
        if (top + tooltipRect.height > window.innerHeight - 8) {
            top = rect.top - tooltipRect.height - 8
        }

        // The maths above is all in viewport space (getBoundingClientRect,
        // window.innerWidth/Height), but .step-tooltip is `position: absolute`
        // on document.body, so add the scroll offset when applying. See the same
        // conversion in tooltip_controller.js#positionTooltip.
        tooltip.style.top = `${top + window.scrollY}px`
        tooltip.style.left = `${left + window.scrollX}px`
    }

    // Advance to next step (for testing/demo purposes)
    advanceStep() {
        if (this.currentStepValue < this.totalStepsValue) {
            this.currentStepValue += 1
            this.progressValue = this.calculateProgress(this.currentStepValue, this.totalStepsValue)
            this.pulseCurrentStep()
        }
    }

    // Go back to previous step
    previousStep() {
        if (this.currentStepValue > 1) {
            this.currentStepValue -= 1
            this.progressValue = this.calculateProgress(this.currentStepValue, this.totalStepsValue)
            this.pulseCurrentStep()
        }
    }
}

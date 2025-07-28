import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        progress: Number,
        totalSteps: Number,
        currentStep: Number
    }

    connect() {
        this.updateProgressDisplay()
        this.animateProgressBar()
    }

    // Update progress when values change
    progressValueChanged() {
        this.updateProgressDisplay()
        this.animateProgressBar()
    }

    currentStepValueChanged() {
        this.updateStepStates()
    }

    // Update the visual progress display
    updateProgressDisplay() {
        const progressFill = this.element.querySelector('.progress-fill')
        const progressText = this.element.querySelector('.current-progress')

        if (progressFill) {
            progressFill.style.width = `${this.progressValue}%`
        }

        if (progressText) {
            progressText.textContent = `Step ${this.currentStepValue || 1}`
        }
    }

    // Animate progress bar changes
    animateProgressBar() {
        const progressFill = this.element.querySelector('.progress-fill')
        if (progressFill) {
            // Add transition if not already present
            if (!progressFill.style.transition) {
                progressFill.style.transition = 'width 0.6s cubic-bezier(0.4, 0, 0.2, 1)'
            }

            // Trigger animation
            requestAnimationFrame(() => {
                progressFill.style.width = `${this.progressValue}%`
            })
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
            step.classList.remove('completed', 'current', 'upcoming')

            // Add appropriate class based on progress
            if (stepNumber < currentStep) {
                step.classList.add('completed')

                // Show checkmark for completed steps
                if (numberElement && !checkElement) {
                    numberElement.textContent = '✓'
                    numberElement.className = 'step-check'
                }
            } else if (stepNumber === currentStep) {
                step.classList.add('current')

                // Show number for current step
                if (numberElement) {
                    numberElement.textContent = stepNumber
                    numberElement.className = 'step-number'
                }
            } else {
                step.classList.add('upcoming')

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
        const currentStepElement = this.element.querySelector('.progress-step.current .step-marker')
        if (currentStepElement) {
            currentStepElement.style.animation = 'pulse 1s ease-in-out'

            setTimeout(() => {
                currentStepElement.style.animation = ''
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

        // Style the tooltip
        tooltip.style.cssText = `
      position: absolute;
      background: white;
      border: 1px solid #e5e7eb;
      border-radius: 0.5rem;
      padding: 0.75rem;
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
      z-index: 1000;
      max-width: 12rem;
      font-size: 0.875rem;
      pointer-events: none;
    `

        // Position tooltip
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

        tooltip.style.top = `${top}px`
        tooltip.style.left = `${left}px`
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

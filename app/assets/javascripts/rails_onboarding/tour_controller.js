import { Controller } from "@hotwired/stimulus"

/**
 * Tour Controller - Interactive Guided Tours with Modal Overlays
 *
 * Provides step-by-step guided tours with spotlight/highlight effects
 * on specific elements, modal overlays, and navigation controls.
 *
 * Features:
 * - Modal overlay with customizable opacity
 * - Multiple highlight styles (spotlight, border, glow)
 * - Step-by-step navigation
 * - Progress indicators
 * - Keyboard navigation (ESC, arrows, Enter)
 * - Auto-scrolling to highlighted elements
 * - Responsive positioning
 * - Analytics tracking
 */
export default class extends Controller {
    static targets = ["overlay", "spotlight", "popup", "progress"]
    static values = {
        steps: String, // JSON array of tour steps
        autoStart: { type: Boolean, default: false },
        showProgress: { type: Boolean, default: true },
        allowSkip: { type: Boolean, default: true },
        overlayOpacity: { type: Number, default: 0.7 },
        highlightStyle: { type: String, default: "spotlight" }, // spotlight, border, glow, none
        scrollBehavior: { type: String, default: "smooth" }, // smooth, auto, none
        scrollOffset: { type: Number, default: 80 }, // px offset from top when scrolling
        persistProgress: { type: Boolean, default: true },
        tourId: String
    }

    connect() {
        this.currentStepIndex = 0
        this.isActive = false
        this.tourSteps = []
        this.completedTours = this.loadCompletedTours()

        this.parseSteps()
        this.setupKeyboardHandlers()
        this.setupViewportHandlers()

        // Auto-start if configured and not completed
        if (this.autoStartValue && !this.isTourCompleted()) {
            setTimeout(() => this.start(), 1000)
        }
    }

    /**
     * Parse and validate tour steps from configuration
     */
    parseSteps() {
        try {
            this.tourSteps = JSON.parse(this.stepsValue || '[]')
        } catch (error) {
            console.error('Invalid tour steps configuration:', error)
            this.tourSteps = []
            return
        }

        // Validate and enhance each step
        this.tourSteps = this.tourSteps.map((step, index) => ({
            id: step.id || `step_${index}`,
            selector: step.selector, // Element to highlight
            title: step.title || '',
            content: step.content || '',
            position: step.position || 'auto', // auto, top, bottom, left, right, center
            highlightStyle: step.highlightStyle || this.highlightStyleValue,
            highlightPadding: step.highlightPadding || 10, // px padding around highlighted element
            showNext: step.showNext !== false,
            showPrev: step.showPrev !== false,
            showSkip: step.showSkip !== false && this.allowSkipValue,
            nextLabel: step.nextLabel || 'Next',
            prevLabel: step.prevLabel || 'Previous',
            skipLabel: step.skipLabel || 'Skip Tour',
            completeLabel: step.completeLabel || 'Complete',
            beforeShow: step.beforeShow, // Callback function name
            afterShow: step.afterShow,
            beforeHide: step.beforeHide,
            onComplete: step.onComplete,
            width: step.width || 400, // Popup width in px
            ...step
        }))
    }

    /**
     * Start the tour from the beginning
     */
    start() {
        if (this.isActive || this.tourSteps.length === 0) return

        this.isActive = true
        this.currentStepIndex = 0

        this.createOverlay()
        this.showStep(this.currentStepIndex)
        this.trackEvent('tour_started')

        this.dispatch('start', { detail: { tourId: this.tourIdValue } })
    }

    /**
     * Resume tour from saved progress
     */
    resume() {
        const progress = this.loadProgress()
        if (progress && progress.stepIndex < this.tourSteps.length) {
            this.currentStepIndex = progress.stepIndex
            this.start()
        }
    }

    /**
     * Stop and clean up the tour
     */
    stop() {
        if (!this.isActive) return

        this.hideCurrentStep()
        this.removeOverlay()
        this.isActive = false

        this.trackEvent('tour_stopped')
        this.dispatch('stop')
    }

    /**
     * Complete the tour
     */
    complete() {
        if (!this.isActive) return

        this.markTourCompleted()
        this.clearProgress()

        this.trackEvent('tour_completed')
        this.dispatch('complete', {
            detail: {
                tourId: this.tourIdValue,
                stepsCompleted: this.currentStepIndex + 1,
                totalSteps: this.tourSteps.length
            }
        })

        // Execute onComplete callback of final step
        const currentStep = this.tourSteps[this.currentStepIndex]
        if (currentStep && currentStep.onComplete) {
            this.executeCallback(currentStep.onComplete, currentStep)
        }

        this.stop()
    }

    /**
     * Skip the tour
     */
    skip() {
        if (!this.isActive) return

        this.trackEvent('tour_skipped', {
            stepIndex: this.currentStepIndex,
            stepId: this.tourSteps[this.currentStepIndex]?.id
        })

        this.dispatch('skip')
        this.stop()
    }

    /**
     * Show a specific step
     */
    showStep(index) {
        if (index < 0 || index >= this.tourSteps.length) return

        // Hide current step first
        if (this.popup) {
            this.hideCurrentStep()
        }

        this.currentStepIndex = index
        const step = this.tourSteps[index]

        // Execute beforeShow callback
        if (step.beforeShow) {
            this.executeCallback(step.beforeShow, step)
        }

        // Find target element
        const targetElement = step.selector ? document.querySelector(step.selector) : null

        this.currentTargetElement = targetElement

        if (targetElement) {
            this.scrollToElement(targetElement, step)
            this.createHighlight(targetElement, step)
        }

        this.createPopup(step, targetElement)
        this.updateProgress()
        this.saveProgress()

        // Execute afterShow callback
        if (step.afterShow) {
            setTimeout(() => this.executeCallback(step.afterShow, step), 100)
        }

        this.trackEvent('step_shown', {
            stepIndex: index,
            stepId: step.id
        })

        this.dispatch('step-shown', { detail: { step, index } })
    }

    /**
     * Hide current step
     */
    hideCurrentStep() {
        const step = this.tourSteps[this.currentStepIndex]

        if (step && step.beforeHide) {
            this.executeCallback(step.beforeHide, step)
        }

        this.removeHighlight()
        this.removePopup()
    }

    /**
     * Navigate to next step
     */
    next() {
        if (this.currentStepIndex < this.tourSteps.length - 1) {
            this.showStep(this.currentStepIndex + 1)
            this.trackEvent('next_step')
        } else {
            this.complete()
        }
    }

    /**
     * Navigate to previous step
     */
    previous() {
        if (this.currentStepIndex > 0) {
            this.showStep(this.currentStepIndex - 1)
            this.trackEvent('previous_step')
        }
    }

    /**
     * Go to specific step by index
     */
    goToStep(index) {
        if (index >= 0 && index < this.tourSteps.length) {
            this.showStep(index)
        }
    }

    /**
     * Create modal overlay
     */
    createOverlay() {
        if (this.overlay) return

        this.overlay = document.createElement('div')
        this.overlay.className = 'tour-overlay'
        this.overlay.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, ${this.overlayOpacityValue});
            z-index: 9998;
            opacity: 0;
            transition: opacity 0.3s ease;
        `

        document.body.appendChild(this.overlay)

        // Deliberately no `document.body.style.overflow = 'hidden'` here. The overlay is
        // position:fixed and already covers the viewport, and locking the body made
        // scrollToElement()'s window.scrollTo a no-op - so a target below the fold was
        // spotlit off-screen, since the spotlight and popup are placed from
        // getBoundingClientRect(). Scrolling stays live and repositionCurrentStep()
        // keeps the highlight glued to its element instead.

        // Trigger fade in
        requestAnimationFrame(() => {
            this.overlay.style.opacity = '1'
        })
    }

    /**
     * Remove modal overlay
     */
    removeOverlay() {
        const overlay = this.overlay
        if (!overlay) return

        this.overlay = null
        overlay.style.opacity = '0'

        setTimeout(() => {
            if (overlay.parentNode) overlay.parentNode.removeChild(overlay)
        }, 300)
    }

    /**
     * Create highlight/spotlight on target element
     */
    createHighlight(element, step) {
        this.removeHighlight()

        const rect = element.getBoundingClientRect()
        const padding = step.highlightPadding
        const style = step.highlightStyle

        if (style === 'none') return

        this.spotlight = document.createElement('div')
        this.spotlight.className = `tour-spotlight tour-spotlight-${style}`

        const baseStyles = `
            position: fixed;
            pointer-events: none;
            z-index: 9999;
            transition: all 0.3s ease;
        `

        switch (style) {
            case 'spotlight':
                // Create a cutout effect in the overlay
                this.spotlight.style.cssText = `
                    ${baseStyles}
                    top: ${rect.top - padding}px;
                    left: ${rect.left - padding}px;
                    width: ${rect.width + (padding * 2)}px;
                    height: ${rect.height + (padding * 2)}px;
                    box-shadow: 0 0 0 9999px rgba(0, 0, 0, ${this.overlayOpacityValue});
                    border-radius: 8px;
                `
                break

            case 'border':
                this.spotlight.style.cssText = `
                    ${baseStyles}
                    top: ${rect.top - padding}px;
                    left: ${rect.left - padding}px;
                    width: ${rect.width + (padding * 2)}px;
                    height: ${rect.height + (padding * 2)}px;
                    border: 3px solid #3b82f6;
                    border-radius: 8px;
                    box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.2);
                `
                break

            case 'glow':
                this.spotlight.style.cssText = `
                    ${baseStyles}
                    top: ${rect.top - padding}px;
                    left: ${rect.left - padding}px;
                    width: ${rect.width + (padding * 2)}px;
                    height: ${rect.height + (padding * 2)}px;
                    border-radius: 8px;
                    box-shadow:
                        0 0 0 4px rgba(59, 130, 246, 0.3),
                        0 0 20px 8px rgba(59, 130, 246, 0.4),
                        inset 0 0 20px rgba(59, 130, 246, 0.2);
                `
                break
        }

        document.body.appendChild(this.spotlight)

        // Make highlighted element interactive, remembering what we overwrote so
        // removeHighlight() can put it back without searching the document.
        this.highlightedElement = element
        this.previousElementPosition = element.style.position
        this.previousElementZIndex = element.style.zIndex
        element.style.position = 'relative'
        element.style.zIndex = '10000'
    }

    /**
     * Remove highlight/spotlight
     */
    removeHighlight() {
        if (this.spotlight) {
            if (this.spotlight.parentNode) {
                this.spotlight.parentNode.removeChild(this.spotlight)
            }
            this.spotlight = null
        }

        // Restore only the element we actually touched. This used to sweep the whole
        // document for [style*="z-index: 10000"], which clears the inline z-index of
        // unrelated host-app elements that happen to carry that value.
        if (this.highlightedElement) {
            this.highlightedElement.style.position = this.previousElementPosition || ''
            this.highlightedElement.style.zIndex = this.previousElementZIndex || ''
            this.highlightedElement = null
        }
    }

    /**
     * Create tour popup with content and navigation
     */
    createPopup(step, targetElement) {
        this.removePopup()

        this.popup = document.createElement('div')
        this.popup.className = 'tour-popup'

        // Build popup HTML
        const isFirstStep = this.currentStepIndex === 0
        const isLastStep = this.currentStepIndex === this.tourSteps.length - 1

        this.popup.innerHTML = `
            <div class="tour-popup-content">
                ${step.title ? `<h3 class="tour-popup-title">${step.title}</h3>` : ''}
                <div class="tour-popup-body">${step.content}</div>

                ${this.showProgressValue ? `
                    <div class="tour-popup-progress">
                        <div class="tour-progress-bar">
                            <div class="tour-progress-fill" style="width: ${((this.currentStepIndex + 1) / this.tourSteps.length) * 100}%"></div>
                        </div>
                        <div class="tour-progress-text">
                            Step ${this.currentStepIndex + 1} of ${this.tourSteps.length}
                        </div>
                    </div>
                ` : ''}

                <div class="tour-popup-actions">
                    ${step.showSkip ? `
                        <button type="button" class="tour-btn tour-btn-skip" data-action="click->tour#skip">
                            ${step.skipLabel}
                        </button>
                    ` : '<div></div>'}

                    <div class="tour-popup-nav">
                        ${step.showPrev && !isFirstStep ? `
                            <button type="button" class="tour-btn tour-btn-prev" data-action="click->tour#previous">
                                ← ${step.prevLabel}
                            </button>
                        ` : ''}

                        ${step.showNext ? `
                            <button type="button" class="tour-btn tour-btn-next" data-action="click->tour#next">
                                ${isLastStep ? step.completeLabel : step.nextLabel} →
                            </button>
                        ` : ''}
                    </div>
                </div>
            </div>
        `

        // Style popup
        this.stylePopup(step)

        document.body.appendChild(this.popup)

        // Position popup relative to target
        this.positionPopup(step, targetElement)

        // Animate in
        requestAnimationFrame(() => {
            if (this.popup) this.popup.classList.add('onboarding-show')
        })
    }

    /**
     * Style the popup element
     */
    stylePopup(step) {
        // Only the per-step width is set inline. Everything else - including the
        // background - belongs to `.tour-popup` in tour.css, so that a host app
        // redefining the --onboarding-* tokens (and the dark-mode block that flips
        // them) actually reaches the popup. An inline background would win over both.
        this.popup.style.maxWidth = `${step.width}px`
    }

    /**
     * Position popup relative to target element
     */
    positionPopup(step, targetElement) {
        if (!this.popup) return

        const popupRect = this.popup.getBoundingClientRect()
        const margin = 20
        let top, left

        if (targetElement) {
            const targetRect = targetElement.getBoundingClientRect()
            const position = this.calculateBestPosition(step, targetRect, popupRect, margin)

            top = position.top
            left = position.left
        } else {
            // Center on screen if no target
            top = (window.innerHeight - popupRect.height) / 2
            left = (window.innerWidth - popupRect.width) / 2
        }

        // Ensure popup stays in viewport
        top = Math.max(margin, Math.min(top, window.innerHeight - popupRect.height - margin))
        left = Math.max(margin, Math.min(left, window.innerWidth - popupRect.width - margin))

        this.popup.style.top = `${top}px`
        this.popup.style.left = `${left}px`
    }

    /**
     * Calculate best position for popup
     */
    calculateBestPosition(step, targetRect, popupRect, margin) {
        const positions = {
            top: {
                top: targetRect.top - popupRect.height - margin,
                left: targetRect.left + (targetRect.width - popupRect.width) / 2
            },
            bottom: {
                top: targetRect.bottom + margin,
                left: targetRect.left + (targetRect.width - popupRect.width) / 2
            },
            left: {
                top: targetRect.top + (targetRect.height - popupRect.height) / 2,
                left: targetRect.left - popupRect.width - margin
            },
            right: {
                top: targetRect.top + (targetRect.height - popupRect.height) / 2,
                left: targetRect.right + margin
            },
            center: {
                top: (window.innerHeight - popupRect.height) / 2,
                left: (window.innerWidth - popupRect.width) / 2
            }
        }

        // If position is auto, find best fit
        if (step.position === 'auto') {
            const preferences = ['bottom', 'top', 'right', 'left']

            for (const pos of preferences) {
                const coords = positions[pos]
                if (this.isPositionValid(coords, popupRect, margin)) {
                    return coords
                }
            }

            // Fallback to center
            return positions.center
        }

        return positions[step.position] || positions.bottom
    }

    /**
     * Check if position is valid (within viewport)
     */
    isPositionValid(coords, popupRect, margin) {
        return coords.top >= margin &&
               coords.left >= margin &&
               coords.top + popupRect.height <= window.innerHeight - margin &&
               coords.left + popupRect.width <= window.innerWidth - margin
    }

    /**
     * Remove popup
     */
    removePopup() {
        const popup = this.popup
        if (!popup) return

        // Detach from the instance up front and let the timeout close over the local.
        // createPopup() calls removePopup() and then assigns a new this.popup straight
        // away, so a timeout reading the instance property would remove the popup that
        // replaced this one - every Next and Previous would blank the tour after 300ms.
        this.popup = null
        popup.classList.remove('onboarding-show')

        setTimeout(() => {
            if (popup.parentNode) popup.parentNode.removeChild(popup)
        }, 300)
    }

    /**
     * Update progress display
     */
    updateProgress() {
        if (!this.showProgressValue) return

        const progressBar = this.popup?.querySelector('.tour-progress-fill')
        const progressText = this.popup?.querySelector('.tour-progress-text')

        if (progressBar) {
            const percentage = ((this.currentStepIndex + 1) / this.tourSteps.length) * 100
            progressBar.style.width = `${percentage}%`
        }

        if (progressText) {
            progressText.textContent = `Step ${this.currentStepIndex + 1} of ${this.tourSteps.length}`
        }
    }

    /**
     * Scroll element into view
     */
    scrollToElement(element, step) {
        if (this.scrollBehaviorValue === 'none') return

        const rect = element.getBoundingClientRect()
        const offset = this.scrollOffsetValue

        // Check if element is already in view
        const isInView = rect.top >= offset && rect.bottom <= window.innerHeight - offset

        if (!isInView) {
            const scrollTop = window.pageYOffset + rect.top - offset

            window.scrollTo({
                top: scrollTop,
                behavior: this.scrollBehaviorValue
            })
        }
    }

    /**
     * Re-place the highlight and popup for the current step. The spotlight and popup
     * are position:fixed and derived from getBoundingClientRect(), so they have to be
     * recomputed whenever the viewport moves under them.
     */
    repositionCurrentStep() {
        if (!this.isActive) return

        const step = this.tourSteps[this.currentStepIndex]
        if (!step) return

        const element = this.currentTargetElement
        if (element && element.isConnected) {
            this.createHighlight(element, step)
        }
        this.positionPopup(step, element)
    }

    /**
     * Setup viewport handlers that keep the current step aligned
     */
    setupViewportHandlers() {
        this.viewportHandler = () => {
            if (!this.isActive) return
            if (this.viewportFrame) cancelAnimationFrame(this.viewportFrame)
            this.viewportFrame = requestAnimationFrame(() => this.repositionCurrentStep())
        }

        window.addEventListener('scroll', this.viewportHandler, { passive: true })
        window.addEventListener('resize', this.viewportHandler)
    }

    /**
     * Setup keyboard event handlers
     */
    setupKeyboardHandlers() {
        this.keyboardHandler = (event) => {
            if (!this.isActive) return

            switch (event.key) {
                case 'Escape':
                    event.preventDefault()
                    this.skip()
                    break

                case 'ArrowRight':
                case 'Enter':
                    event.preventDefault()
                    this.next()
                    break

                case 'ArrowLeft':
                    event.preventDefault()
                    this.previous()
                    break
            }
        }

        document.addEventListener('keydown', this.keyboardHandler)
    }

    /**
     * Execute callback function by name
     */
    executeCallback(functionName, step) {
        if (typeof window[functionName] === 'function') {
            try {
                window[functionName](step, this)
            } catch (error) {
                console.error(`Error executing callback ${functionName}:`, error)
            }
        }
    }

    /**
     * Save tour progress
     */
    saveProgress() {
        if (!this.persistProgressValue || !this.tourIdValue) return

        const progress = {
            tourId: this.tourIdValue,
            stepIndex: this.currentStepIndex,
            timestamp: Date.now()
        }

        localStorage.setItem(`tour_progress_${this.tourIdValue}`, JSON.stringify(progress))
    }

    /**
     * Load tour progress
     */
    loadProgress() {
        if (!this.tourIdValue) return null

        try {
            const data = localStorage.getItem(`tour_progress_${this.tourIdValue}`)
            return data ? JSON.parse(data) : null
        } catch (error) {
            return null
        }
    }

    /**
     * Clear tour progress
     */
    clearProgress() {
        if (!this.tourIdValue) return
        localStorage.removeItem(`tour_progress_${this.tourIdValue}`)
    }

    /**
     * Mark tour as completed
     */
    markTourCompleted() {
        if (!this.tourIdValue) return

        this.completedTours[this.tourIdValue] = Date.now()
        localStorage.setItem('completed_tours', JSON.stringify(this.completedTours))
    }

    /**
     * Check if tour is completed
     */
    isTourCompleted() {
        return this.tourIdValue && !!this.completedTours[this.tourIdValue]
    }

    /**
     * Load completed tours
     */
    loadCompletedTours() {
        try {
            const data = localStorage.getItem('completed_tours')
            return data ? JSON.parse(data) : {}
        } catch (error) {
            return {}
        }
    }

    /**
     * Track analytics event
     */
    trackEvent(action, metadata = {}) {
        // Track with Google Analytics if available
        if (typeof gtag !== 'undefined') {
            gtag('event', action, {
                event_category: 'tour',
                tour_id: this.tourIdValue,
                ...metadata
            })
        }

        // Dispatch custom event for other analytics systems
        this.dispatch('analytics', {
            detail: { action, tourId: this.tourIdValue, ...metadata }
        })
    }

    /**
     * Cleanup on disconnect
     */
    disconnect() {
        this.stop()

        if (this.keyboardHandler) {
            document.removeEventListener('keydown', this.keyboardHandler)
        }

        if (this.viewportHandler) {
            window.removeEventListener('scroll', this.viewportHandler)
            window.removeEventListener('resize', this.viewportHandler)
        }

        if (this.viewportFrame) cancelAnimationFrame(this.viewportFrame)
    }
}

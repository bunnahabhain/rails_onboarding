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
        // Whether the highlighted element stays clickable. It is lifted above the
        // overlay so that a tour can say "click here to continue", and that is the
        // default. An informational tour wants the opposite: a link inside the
        // spotlight is a trap, because following it navigates away and the tour is
        // either lost or restarted from step one. Overridable per step.
        allowInteraction: { type: Boolean, default: true },
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
            this.autoStartTimer = setTimeout(() => this.autoStart(), 1000)
        }
    }

    /**
     * Begin an auto-started tour, if the page it was configured on is still the
     * one on screen.
     *
     * Turbo renders a cached snapshot as a preview while the fresh response is
     * still in flight, and every controller on the page connects to that preview
     * as well as to the render that replaces it a few milliseconds later.
     * Starting on the preview builds the whole tour, tears it down again when the
     * preview is discarded, and rebuilds it - which a member sees as the popup
     * appearing, vanishing and appearing again. The real render starts it
     * properly, so the preview should simply stand aside.
     *
     * The element check covers the same ground from the other side: a controller
     * whose element has left the document must not build an overlay and a popup,
     * because it no longer has the handlers that would take them down again.
     */
    autoStart() {
        if (!this.element.isConnected) return
        if (document.documentElement.hasAttribute('data-turbo-preview')) return

        this.start()
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
            allowInteraction: step.allowInteraction ?? this.allowInteractionValue,
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

        const targetElement = this.resolveTarget(step)

        this.currentTargetElement = targetElement
        this.applyScrim(step, targetElement)

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
     * Find the element a step should point at.
     *
     * `selector` may be a list, which is how a step survives a responsive layout:
     * the same idea is often two elements, one of them display:none at the current
     * breakpoint - a row of tabs on a wide screen and a select on a narrow one. The
     * first candidate that is actually rendered wins.
     *
     * An element with no layout box is treated as absent rather than used anyway.
     * getBoundingClientRect() on a display:none element is all zeroes, so the
     * spotlight became a small square in the top-left corner and the popup was
     * placed against the origin - pointing confidently at nothing, on top of
     * whatever happened to be there.
     */
    resolveTarget(step) {
        const selectors = Array.isArray(step.selector) ? step.selector : [step.selector]

        for (const selector of selectors) {
            if (!selector) continue

            const element = document.querySelector(selector)
            if (element && this.hasLayoutBox(element)) return element
        }

        return null
    }

    hasLayoutBox(element) {
        return element.getClientRects().length > 0
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
     * Elements the controller injects into document.body. Turbo caches the whole body
     * when you navigate away, so without this a Back lands you on a snapshot with a
     * frozen overlay and popup baked in - which then sit underneath the live tour the
     * launcher starts, as duplicated and inert DOM. The attribute is ignored by hosts
     * that do not use Turbo.
     */
    excludeFromSnapshot(element) {
        element.setAttribute('data-turbo-cache', 'false')
        return element
    }

    /**
     * Create modal overlay
     */
    createOverlay() {
        if (this.overlay) return

        this.overlay = this.excludeFromSnapshot(document.createElement('div'))
        this.overlay.className = 'tour-overlay'
        this.overlay.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: transparent;
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

        document.documentElement.style.removeProperty('--onboarding-tour-scrim')
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

        this.spotlight = this.excludeFromSnapshot(document.createElement('div'))
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
        this.previousElementPointerEvents = element.style.pointerEvents
        element.style.position = 'relative'
        element.style.zIndex = '10000'

        // With interaction off, clicks fall through the highlighted element to the
        // overlay beneath, which swallows them like the rest of the page. The element
        // is still lifted above the overlay so it stays fully lit.
        if (step.allowInteraction === false) {
            element.style.pointerEvents = 'none'
        }
    }

    /**
     * Decide which layer paints the scrim for this step, and at what strength.
     *
     * A 'spotlight' highlight is already a full-viewport scrim - its box-shadow has a
     * 9999px spread and covers everything but the cutout - so painting the overlay on
     * top of it darkens every pixel twice. At the default 0.7 that composites to ~0.92,
     * which buries the surrounding page and leaves someone unfamiliar with the layout
     * with no idea what the highlight is being singled out *from*. Every other style
     * (border, glow, none) draws no scrim of its own, and nor does a step with no target
     * element, so those still need the overlay.
     */
    applyScrim(step, targetElement) {
        document.documentElement.style.setProperty(
            '--onboarding-tour-scrim', this.overlayOpacityValue
        )

        if (!this.overlay) return

        const spotlit = Boolean(targetElement) && step.highlightStyle === 'spotlight'
        this.overlay.style.background = spotlit
            ? 'transparent'
            : `rgba(0, 0, 0, ${this.overlayOpacityValue})`
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
            this.highlightedElement.style.pointerEvents = this.previousElementPointerEvents || ''
            this.highlightedElement = null
        }
    }

    /**
     * Create tour popup with content and navigation
     */
    createPopup(step, targetElement) {
        this.removePopup()

        this.popup = this.excludeFromSnapshot(document.createElement('div'))
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
                        <button type="button" class="tour-btn tour-btn-skip">
                            ${step.skipLabel}
                        </button>
                    ` : '<div></div>'}

                    <div class="tour-popup-nav">
                        ${step.showPrev && !isFirstStep ? `
                            <button type="button" class="tour-btn tour-btn-prev">
                                ← ${step.prevLabel}
                            </button>
                        ` : ''}

                        ${step.showNext ? `
                            <button type="button" class="tour-btn tour-btn-next">
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

        // The popup lives on document.body, so that host overflow and stacking
        // contexts cannot clip it - which also puts it outside every controller
        // scope, where Stimulus will not bind a data-action. These buttons are
        // wired directly for that reason; a data-action on them would be silently
        // inert, which is what left the tour unable to advance at all.
        this.bindPopupActions()

        // Position popup relative to target
        this.positionPopup(step, targetElement)

        // Animate in
        requestAnimationFrame(() => {
            if (this.popup) this.popup.classList.add('onboarding-show')
        })
    }

    /**
     * Wire the popup's own controls. See the note in createPopup().
     */
    bindPopupActions() {
        const actions = {
            '.tour-btn-next': () => this.next(),
            '.tour-btn-prev': () => this.previous(),
            '.tour-btn-skip': () => this.skip()
        }

        for (const [selector, handler] of Object.entries(actions)) {
            this.popup.querySelector(selector)?.addEventListener('click', (event) => {
                event.preventDefault()
                handler()
            })
        }
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
        const targetRect = targetElement ? targetElement.getBoundingClientRect() : null

        const coords = targetRect
            ? this.calculateBestPosition(step, targetRect, popupRect, margin)
            : {
                top: (window.innerHeight - popupRect.height) / 2,
                left: (window.innerWidth - popupRect.width) / 2
            }

        // The clamp keeps the popup reachable, which matters more than anything else -
        // its own buttons are the only way forward. calculateBestPosition is what keeps
        // it off the highlight; this is the last word on staying on screen.
        this.popup.style.top =
            `${this.clamp(coords.top, margin, window.innerHeight - popupRect.height - margin)}px`
        this.popup.style.left =
            `${this.clamp(coords.left, margin, window.innerWidth - popupRect.width - margin)}px`
    }

    clamp(value, min, max) {
        return Math.max(min, Math.min(value, max))
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

        // 'center' is a host saying "do not point at anything", so it is taken at its
        // word. Every other position is a *preference*: it used to be handed back
        // without being checked, and positionPopup then clamped it into the viewport -
        // which on a phone slides the popup straight over the element it is describing.
        // A tour that hides what it is explaining is worse than one placed on the wrong
        // side, so the asked-for side is tried first and the others are tried after it.
        if (step.position === 'center') return positions.center

        const fallbacks = ['bottom', 'top', 'right', 'left']
        const order = positions[step.position] && step.position !== 'auto'
            ? [step.position, ...fallbacks.filter((pos) => pos !== step.position)]
            : fallbacks

        for (const pos of order) {
            if (this.isPositionValid(positions[pos], popupRect, margin)) return positions[pos]
        }

        return this.positionBesideTarget(targetRect, popupRect, margin)
    }

    /**
     * Nothing fits cleanly on any side, which on a small viewport is the ordinary
     * case rather than the exceptional one. Put the popup in whichever band - above
     * the target or below it - has more room. Centring instead, which is what this
     * used to do, lands on the target more often than not.
     */
    positionBesideTarget(targetRect, popupRect, margin) {
        const roomAbove = targetRect.top - margin
        const roomBelow = window.innerHeight - targetRect.bottom - margin
        const left = targetRect.left + (targetRect.width - popupRect.width) / 2

        return roomBelow >= roomAbove
            ? { top: targetRect.bottom + margin, left }
            : { top: targetRect.top - popupRect.height - margin, left }
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

        if (this.autoStartTimer) clearTimeout(this.autoStartTimer)

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

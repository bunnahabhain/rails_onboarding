import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["content", "trigger"]
    static values = {
        position: { type: String, default: "top" },
        delay: { type: Number, default: 0 },
        feature: String,
        dismissUrl: { type: String, default: "" }, // rails_onboarding.dismiss_tooltip_path(tooltip_id: feature)
        dismissible: { type: Boolean, default: true },
        trigger: { type: String, default: "hover" }, // hover, click, focus, idle, scroll, contextual
        idleTime: { type: Number, default: 3000 }, // ms before showing on idle
        scrollThreshold: { type: Number, default: 0.5 }, // % of element visible before showing
        contextual: { type: Boolean, default: false }, // context-aware behavior
        priority: { type: Number, default: 5 }, // 1-10 priority for tooltip importance
        maxDaily: { type: Number, default: 3 }, // max times to show per day
        animation: { type: String, default: "fade" }, // fade, slide, bounce, scale, none
        duration: { type: Number, default: 200 } // animation duration in ms
    }

    connect() {
        this.tooltip = null
        this.showTimeout = null
        this.hideTimeout = null
        this.idleTimeout = null
        this.userInteractionCount = 0
        this.lastInteractionTime = Date.now()
        this.setupEventListeners()
        this.initializeContextualBehavior()
    }

    // Setup event listeners for showing/hiding tooltip
    setupEventListeners() {
        const target = this.hasTriggerTarget ? this.triggerTarget : this.element
        
        // Setup based on trigger type
        switch (this.triggerValue) {
            case 'hover':
                target.addEventListener('mouseenter', this.show.bind(this))
                target.addEventListener('mouseleave', this.hide.bind(this))
                target.addEventListener('focus', this.show.bind(this))
                target.addEventListener('blur', this.hide.bind(this))
                break
                
            case 'click':
                target.addEventListener('click', this.toggle.bind(this))
                // Close on outside click
                document.addEventListener('click', this.handleOutsideClick.bind(this))
                break
                
            case 'focus':
                target.addEventListener('focus', this.show.bind(this))
                target.addEventListener('blur', this.hide.bind(this))
                break
                
            case 'idle':
                this.setupIdleDetection()
                break
                
            case 'scroll':
                this.setupScrollDetection()
                break
                
            case 'contextual':
                this.setupContextualTriggers()
                break

            case 'auto':
                // Shown programmatically the instant it connects, with no user
                // interaction - this is what the tooltip scheduler relies on when
                // it appends a trigger:auto tooltip for a guided-tour step. Defer
                // one macrotask so the freshly-appended element has settled before
                // positionTooltip measures it; setTimeout (not requestAnimationFrame)
                // so it still fires in a backgrounded tab. Hiding is driven by the
                // scheduler via forceHide().
                setTimeout(() => this.show(), 0)
                break

            default: // hover
                target.addEventListener('mouseenter', this.show.bind(this))
                target.addEventListener('mouseleave', this.hide.bind(this))
                target.addEventListener('focus', this.show.bind(this))
                target.addEventListener('blur', this.hide.bind(this))
        }

        // Handle keyboard events
        document.addEventListener('keydown', this.handleKeyboard.bind(this))
        
        // Track user interactions for contextual behavior
        if (this.contextualValue) {
            this.setupInteractionTracking()
        }
    }
    
    // Initialize contextual behavior patterns
    initializeContextualBehavior() {
        if (!this.contextualValue) return
        
        // Load user behavior patterns from localStorage
        this.behaviorData = JSON.parse(localStorage.getItem('rails_onboarding_behavior') || '{}')
        this.todayKey = new Date().toISOString().split('T')[0]
        
        // Initialize today's data if needed
        if (!this.behaviorData[this.todayKey]) {
            this.behaviorData[this.todayKey] = {
                tooltipsShown: {},
                interactions: 0,
                strugglingAreas: [],
                timeOnPage: 0,
                pageViews: 0
            }
        }
        
        // Track page view
        this.behaviorData[this.todayKey].pageViews++
        this.saveBehaviorData()
        
        // Start page time tracking
        this.pageStartTime = Date.now()
    }
    
    // Setup idle detection for idle trigger type
    setupIdleDetection() {
        const target = this.hasTriggerTarget ? this.triggerTarget : this.element
        
        // Show tooltip after idle period
        const startIdleTimer = () => {
            if (this.idleTimeout) clearTimeout(this.idleTimeout)
            this.idleTimeout = setTimeout(() => {
                if (this.shouldShow()) {
                    this.show()
                }
            }, this.idleTimeValue)
        }
        
        // Reset timer on any interaction
        const resetIdleTimer = () => {
            if (this.idleTimeout) {
                clearTimeout(this.idleTimeout)
                this.idleTimeout = null
            }
        }
        
        // Track mouse/keyboard activity
        ['mouseenter', 'mousemove', 'keydown', 'scroll'].forEach(event => {
            target.addEventListener(event, () => {
                resetIdleTimer()
                startIdleTimer()
            })
        })
        
        // Start initial timer
        startIdleTimer()
    }
    
    // Setup scroll-based detection
    setupScrollDetection() {
        const target = this.hasTriggerTarget ? this.triggerTarget : this.element
        
        const checkVisibility = () => {
            const rect = target.getBoundingClientRect()
            const visibleHeight = Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0)
            const visibilityRatio = Math.max(0, visibleHeight) / rect.height
            
            if (visibilityRatio >= this.scrollThresholdValue && this.shouldShow()) {
                this.show()
                // Remove scroll listener once shown
                window.removeEventListener('scroll', checkVisibility)
            }
        }
        
        window.addEventListener('scroll', checkVisibility)
        // Check initial visibility
        checkVisibility()
    }
    
    // Setup contextual triggers based on user behavior
    setupContextualTriggers() {
        const behaviorData = this.behaviorData?.[this.todayKey]
        if (!behaviorData) return
        
        // Show tooltip if user seems to be struggling
        if (this.detectStruggling()) {
            setTimeout(() => {
                if (this.shouldShow()) this.show()
            }, 2000) // Show after 2 seconds of struggling
        }
        
        // Show high-priority tooltips for new users
        if (this.isNewUser() && this.priorityValue >= 8) {
            setTimeout(() => {
                if (this.shouldShow()) this.show()
            }, 1000)
        }
        
        // Show tooltips based on time spent on page
        if (behaviorData.timeOnPage > 30000 && this.priorityValue >= 6) { // 30+ seconds
            setTimeout(() => {
                if (this.shouldShow()) this.show()
            }, 500)
        }
    }
    
    // Setup interaction tracking for contextual behavior
    setupInteractionTracking() {
        const target = this.hasTriggerTarget ? this.triggerTarget : this.element
        
        // Track various interactions
        ['click', 'focus', 'mouseenter'].forEach(eventType => {
            target.addEventListener(eventType, () => {
                this.trackInteraction(eventType)
            })
        })
        
        // Track page visibility
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.updateTimeOnPage()
            }
        })
        
        // Track before page unload
        window.addEventListener('beforeunload', () => {
            this.updateTimeOnPage()
        })
    }
    
    // Handle outside clicks for click trigger
    handleOutsideClick(event) {
        if (this.tooltip && !this.tooltip.contains(event.target) && 
            !this.element.contains(event.target)) {
            this.hide()
        }
    }
    
    // Detect if user is struggling with current element/feature
    detectStruggling() {
        const behaviorData = this.behaviorData?.[this.todayKey]
        if (!behaviorData) return false
        
        const feature = this.featureValue || this.element.id || 'unknown'
        
        // Look for signs of struggling:
        // 1. Multiple clicks without progress
        // 2. Long hover times without action
        // 3. Repeated visits to same area
        // 4. Error patterns
        
        const strugglingIndicators = behaviorData.strugglingAreas || []
        return strugglingIndicators.includes(feature)
    }
    
    // Check if user is new (within first few days)
    isNewUser() {
        const allData = JSON.parse(localStorage.getItem('rails_onboarding_behavior') || '{}')
        const dayCount = Object.keys(allData).length
        return dayCount <= 3 // Consider new if less than 3 days of data
    }
    
    // Track user interactions
    trackInteraction(type) {
        this.lastInteractionTime = Date.now()
        this.userInteractionCount++
        
        if (this.behaviorData && this.behaviorData[this.todayKey]) {
            this.behaviorData[this.todayKey].interactions++
            this.saveBehaviorData()
        }
    }
    
    // Update time spent on current page
    updateTimeOnPage() {
        if (this.pageStartTime && this.behaviorData && this.behaviorData[this.todayKey]) {
            const timeSpent = Date.now() - this.pageStartTime
            this.behaviorData[this.todayKey].timeOnPage += timeSpent
            this.saveBehaviorData()
            this.pageStartTime = Date.now() // Reset for next session
        }
    }
    
    // Save behavior data to localStorage
    saveBehaviorData() {
        localStorage.setItem('rails_onboarding_behavior', JSON.stringify(this.behaviorData))
    }
    
    // Record that this tooltip was shown today
    recordTooltipShow() {
        if (!this.featureValue || !this.behaviorData || !this.behaviorData[this.todayKey]) return
        
        const feature = this.featureValue
        if (!this.behaviorData[this.todayKey].tooltipsShown) {
            this.behaviorData[this.todayKey].tooltipsShown = {}
        }
        
        this.behaviorData[this.todayKey].tooltipsShown[feature] = 
            (this.behaviorData[this.todayKey].tooltipsShown[feature] || 0) + 1
        
        this.saveBehaviorData()
    }

    // Show tooltip
    show(event) {
        if (event) event.preventDefault()

        // Clear any existing timeouts
        if (this.hideTimeout) {
            clearTimeout(this.hideTimeout)
            this.hideTimeout = null
        }

        // Set show timeout if delay is specified
        if (this.delayValue > 0) {
            this.showTimeout = setTimeout(() => {
                this.createTooltip()
            }, this.delayValue)
        } else {
            this.createTooltip()
        }
    }

    // Hide tooltip
    hide(event) {
        if (event) event.preventDefault()

        // Clear show timeout if it exists
        if (this.showTimeout) {
            clearTimeout(this.showTimeout)
            this.showTimeout = null
        }

        // Hide with small delay to allow for mouse movement
        this.hideTimeout = setTimeout(() => {
            this.removeTooltip()
        }, 100)
    }

    // Force show tooltip (for click events)
    forceShow(event) {
        if (event) event.preventDefault()
        this.createTooltip()
    }

    // Force hide tooltip
    forceHide(event) {
        if (event) event.preventDefault()
        this.removeTooltip()
    }

    // Create and display tooltip
    createTooltip() {
        // Remove existing tooltip
        this.removeTooltip()

        // Get content
        const content = this.getTooltipContent()
        if (!content) return

        // Create tooltip element
        this.tooltip = document.createElement('div')
        this.tooltip.className = 'onboarding-tooltip'
        this.tooltip.innerHTML = `
      <div class="tooltip-arrow"></div>
      <div class="tooltip-inner">
        ${content}
        ${this.dismissibleValue ? '<button type="button" class="tooltip-dismiss" aria-label="Dismiss">×</button>' : ''}
      </div>
    `

        // Style the tooltip
        this.styleTooltip()

        // Add to DOM
        document.body.appendChild(this.tooltip)

        // Position tooltip
        this.positionTooltip()

        // Setup dismiss handler
        if (this.dismissibleValue) {
            const dismissButton = this.tooltip.querySelector('.tooltip-dismiss')
            if (dismissButton) {
                dismissButton.addEventListener('click', this.dismiss.bind(this))
            }
        }

        // Track tooltip show event
        this.trackTooltipEvent('show')
        this.recordTooltipShow()

        // Auto-hide after 10 seconds for feature tooltips
        if (this.featureValue) {
            setTimeout(() => {
                this.removeTooltip()
            }, 10000)
        }
    }

    // Remove tooltip from DOM with animation
    removeTooltip() {
        if (this.tooltip) {
            this.animateTooltipOut(() => {
                if (this.tooltip && this.tooltip.parentNode) {
                    this.tooltip.parentNode.removeChild(this.tooltip)
                }
                this.tooltip = null
            })
        }
    }

    // Get tooltip content
    getTooltipContent() {
        if (this.hasContentTarget) {
            return this.contentTarget.innerHTML
        } else if (this.element.dataset.tooltipText) {
            return this.element.dataset.tooltipText
        } else if (this.featureValue) {
            return this.getFeatureTooltipContent()
        }
        return null
    }

    // Get feature-specific tooltip content
    //
    // There's no way for this static JS to read config.feature_tooltips
    // (that lives server-side in Ruby), so there's nothing meaningful to
    // fall back to here - the host app must supply the actual copy via a
    // data-tooltip-target="content" element or a data-tooltip-text
    // attribute (both checked before this method runs, in
    // getTooltipContent() above).
    getFeatureTooltipContent() {
        console.warn(
            `RailsOnboarding: tooltip for feature "${this.featureValue}" has no ` +
            `content. Add a data-tooltip-target="content" element, or a ` +
            `data-tooltip-text attribute, with the text configured in ` +
            `config.feature_tooltips["${this.featureValue}"].`
        )
        return `<p>Learn more about this feature.</p>`
    }
    
    // Animate tooltip entrance
    animateTooltipIn() {
        if (!this.tooltip) return
        
        // Set initial state based on animation type
        this.setInitialAnimationState()
        
        // Apply animation class for CSS transitions
        this.tooltip.classList.add('tooltip-animating-in')
        this.tooltip.style.animationDuration = `${this.durationValue}ms`
        
        // Trigger animation
        requestAnimationFrame(() => {
            if (this.tooltip) {
                this.setFinalAnimationState()
                
                // Remove animation class after completion
                setTimeout(() => {
                    if (this.tooltip) {
                        this.tooltip.classList.remove('tooltip-animating-in')
                    }
                }, this.durationValue)
            }
        })
    }
    
    // Animate tooltip exit
    animateTooltipOut(callback) {
        if (!this.tooltip) {
            if (callback) callback()
            return
        }
        
        // Add exit animation class
        this.tooltip.classList.add('tooltip-animating-out')
        this.tooltip.style.animationDuration = `${this.durationValue}ms`
        
        // Set exit state based on animation type
        this.setExitAnimationState()
        
        // Remove after animation completes
        setTimeout(() => {
            if (callback) callback()
        }, this.durationValue)
    }
    
    // Set initial animation state
    setInitialAnimationState() {
        if (!this.tooltip) return
        
        const baseStyles = {
            transition: `all ${this.durationValue}ms ease-out`,
            pointerEvents: 'none'
        }
        
        switch (this.animationValue) {
            case 'fade':
                Object.assign(this.tooltip.style, {
                    ...baseStyles,
                    opacity: '0'
                })
                break
                
            case 'slide':
                const slideDirection = this.getSlideDirection()
                Object.assign(this.tooltip.style, {
                    ...baseStyles,
                    opacity: '0',
                    transform: `translate${slideDirection.axis}(${slideDirection.distance}px)`
                })
                break
                
            case 'bounce':
                Object.assign(this.tooltip.style, {
                    ...baseStyles,
                    opacity: '0',
                    transform: 'scale(0.3)',
                    animationTimingFunction: 'cubic-bezier(0.68, -0.55, 0.265, 1.55)'
                })
                break
                
            case 'scale':
                Object.assign(this.tooltip.style, {
                    ...baseStyles,
                    opacity: '0',
                    transform: 'scale(0.8)',
                    transformOrigin: this.getTransformOrigin()
                })
                break
                
            case 'none':
                Object.assign(this.tooltip.style, {
                    opacity: '1',
                    pointerEvents: 'auto'
                })
                break
                
            default: // fade
                Object.assign(this.tooltip.style, {
                    ...baseStyles,
                    opacity: '0'
                })
        }
    }
    
    // Set final animation state
    setFinalAnimationState() {
        if (!this.tooltip) return
        
        switch (this.animationValue) {
            case 'fade':
                this.tooltip.style.opacity = '1'
                this.tooltip.style.pointerEvents = 'auto'
                break
                
            case 'slide':
                this.tooltip.style.opacity = '1'
                this.tooltip.style.transform = 'translate(0, 0)'
                this.tooltip.style.pointerEvents = 'auto'
                break
                
            case 'bounce':
            case 'scale':
                this.tooltip.style.opacity = '1'
                this.tooltip.style.transform = 'scale(1)'
                this.tooltip.style.pointerEvents = 'auto'
                break
                
            case 'none':
                // Already set in initial state
                break
                
            default: // fade
                this.tooltip.style.opacity = '1'
                this.tooltip.style.pointerEvents = 'auto'
        }
    }
    
    // Set exit animation state
    setExitAnimationState() {
        if (!this.tooltip) return
        
        switch (this.animationValue) {
            case 'fade':
                this.tooltip.style.opacity = '0'
                break
                
            case 'slide':
                const slideDirection = this.getSlideDirection()
                this.tooltip.style.opacity = '0'
                this.tooltip.style.transform = `translate${slideDirection.axis}(${slideDirection.distance}px)`
                break
                
            case 'bounce':
                this.tooltip.style.opacity = '0'
                this.tooltip.style.transform = 'scale(0.3)'
                break
                
            case 'scale':
                this.tooltip.style.opacity = '0'
                this.tooltip.style.transform = 'scale(0.8)'
                break
                
            case 'none':
                this.tooltip.style.opacity = '0'
                break
                
            default: // fade
                this.tooltip.style.opacity = '0'
        }
    }
    
    // Get slide direction based on tooltip position
    getSlideDirection() {
        const position = this.positionValue
        
        switch (position) {
            case 'top':
                return { axis: 'Y', distance: -20 }
            case 'bottom':
                return { axis: 'Y', distance: 20 }
            case 'left':
                return { axis: 'X', distance: -20 }
            case 'right':
                return { axis: 'X', distance: 20 }
            default:
                return { axis: 'Y', distance: -20 }
        }
    }
    
    // Get transform origin for scale animations
    getTransformOrigin() {
        const position = this.positionValue
        
        switch (position) {
            case 'top':
                return 'center bottom'
            case 'bottom':
                return 'center top'
            case 'left':
                return 'right center'
            case 'right':
                return 'left center'
            default:
                return 'center bottom'
        }
    }

    // Style the tooltip
    // Appearance (colours, radius, shadow, padding) lives in tooltips.css under
    // .onboarding-tooltip, so tooltips follow the --onboarding-* design tokens and
    // the dark-mode block like the rest of the gem. Only the animation state is set
    // here, because animateTooltipIn/Out drive opacity and transform imperatively;
    // position comes from positionTooltip(), which computes top/left in pixels.
    styleTooltip() {
        if (!this.tooltip) return

        this.tooltip.style.opacity = "0"
        this.tooltip.style.transform = "scale(0.95) translateY(-5px)"
        this.tooltip.style.transition = "opacity 0.15s ease, transform 0.15s ease"
    }

    // Position tooltip relative to trigger element with smart collision detection
    positionTooltip() {
        if (!this.tooltip) return

        const target = this.hasTriggerTarget ? this.triggerTarget : this.element
        const targetRect = target.getBoundingClientRect()
        const tooltipRect = this.tooltip.getBoundingClientRect()
        const arrow = this.tooltip.querySelector('.tooltip-arrow')
        
        // Get viewport info
        const viewport = {
            width: window.innerWidth,
            height: window.innerHeight,
            scrollX: window.scrollX,
            scrollY: window.scrollY
        }
        
        const margin = 16 // Minimum margin from viewport edges
        
        // Find the best position using smart collision detection
        const bestPosition = this.findBestPosition(targetRect, tooltipRect, viewport, margin)
        
        let { position, top, left, arrowPosition } = bestPosition

        // Apply position
        this.tooltip.style.top = `${top}px`
        this.tooltip.style.left = `${left}px`
        
        // Style arrow based on final position
        if (arrow) {
            this.styleArrowForPosition(arrow, position, arrowPosition, targetRect, tooltipRect)
        }

        // Add position class for CSS styling. The class names are namespaced
        // (onboarding-top, onboarding-left, ...), so strip by exact class rather
        // than with a \b word boundary - \b treats "-" as a boundary, so the old
        // /\b(top|bottom|left|right)\b/ would also match inside a namespaced name.
        this.tooltip.classList.remove(
            "onboarding-top", "onboarding-bottom", "onboarding-left", "onboarding-right"
        )
        this.tooltip.classList.add(`onboarding-${position}`)

        // Animate in with enhanced animations
        this.animateTooltipIn()
    }
    
    // Find the best position for tooltip using collision detection
    findBestPosition(targetRect, tooltipRect, viewport, margin) {
        const positions = [
            this.positionValue, // Preferred position first
            'top', 'bottom', 'left', 'right'
        ].filter((pos, index, arr) => arr.indexOf(pos) === index) // Remove duplicates
        
        let bestPosition = null
        let bestScore = -1
        
        for (const position of positions) {
            const result = this.calculatePosition(position, targetRect, tooltipRect, viewport, margin)
            const score = this.scorePosition(result, viewport, margin)
            
            if (score > bestScore) {
                bestScore = score
                bestPosition = result
                bestPosition.position = position
            }
            
            // If we found a perfect position, use it
            if (score >= 100) break
        }
        
        return bestPosition
    }
    
    // Calculate position coordinates for a given direction
    calculatePosition(position, targetRect, tooltipRect, viewport, margin) {
        const gap = 12 // Gap between target and tooltip
        let top, left, arrowPosition = { x: '50%', y: '50%' }
        
        switch (position) {
            case 'top':
                top = targetRect.top - tooltipRect.height - gap
                left = targetRect.left + (targetRect.width / 2) - (tooltipRect.width / 2)
                arrowPosition = { x: '50%', y: 'bottom' }
                break
                
            case 'bottom':
                top = targetRect.bottom + gap
                left = targetRect.left + (targetRect.width / 2) - (tooltipRect.width / 2)
                arrowPosition = { x: '50%', y: 'top' }
                break
                
            case 'left':
                top = targetRect.top + (targetRect.height / 2) - (tooltipRect.height / 2)
                left = targetRect.left - tooltipRect.width - gap
                arrowPosition = { x: 'right', y: '50%' }
                break
                
            case 'right':
                top = targetRect.top + (targetRect.height / 2) - (tooltipRect.height / 2)
                left = targetRect.right + gap
                arrowPosition = { x: 'left', y: '50%' }
                break
                
            default:
                top = targetRect.top - tooltipRect.height - gap
                left = targetRect.left + (targetRect.width / 2) - (tooltipRect.width / 2)
                arrowPosition = { x: '50%', y: 'bottom' }
        }
        
        // Adjust horizontal position to stay in viewport
        if (left < margin) {
            const adjustment = margin - left
            left = margin
            // Adjust arrow position for horizontal shifts
            if (position === 'top' || position === 'bottom') {
                const arrowLeft = Math.max(16, (targetRect.left + targetRect.width / 2) - left)
                arrowPosition.x = `${Math.min(arrowLeft, tooltipRect.width - 16)}px`
            }
        } else if (left + tooltipRect.width > viewport.width - margin) {
            const adjustment = (left + tooltipRect.width) - (viewport.width - margin)
            left = viewport.width - tooltipRect.width - margin
            // Adjust arrow position for horizontal shifts
            if (position === 'top' || position === 'bottom') {
                const arrowLeft = (targetRect.left + targetRect.width / 2) - left
                arrowPosition.x = `${Math.min(Math.max(16, arrowLeft), tooltipRect.width - 16)}px`
            }
        }
        
        // Adjust vertical position to stay in viewport
        if (top < margin) {
            const adjustment = margin - top
            top = margin
            // Adjust arrow position for vertical shifts
            if (position === 'left' || position === 'right') {
                const arrowTop = Math.max(16, (targetRect.top + targetRect.height / 2) - top)
                arrowPosition.y = `${Math.min(arrowTop, tooltipRect.height - 16)}px`
            }
        } else if (top + tooltipRect.height > viewport.height - margin) {
            const adjustment = (top + tooltipRect.height) - (viewport.height - margin)
            top = viewport.height - tooltipRect.height - margin
            // Adjust arrow position for vertical shifts
            if (position === 'left' || position === 'right') {
                const arrowTop = (targetRect.top + targetRect.height / 2) - top
                arrowPosition.y = `${Math.min(Math.max(16, arrowTop), tooltipRect.height - 16)}px`
            }
        }
        
        return { top, left, arrowPosition }
    }
    
    // Score a position based on how well it fits and avoids collisions
    scorePosition(result, viewport, margin) {
        const { top, left } = result
        const tooltipRect = this.tooltip.getBoundingClientRect()
        
        let score = 100 // Start with perfect score
        
        // Penalize if tooltip goes outside viewport
        if (left < margin) score -= Math.abs(left - margin)
        if (top < margin) score -= Math.abs(top - margin)
        if (left + tooltipRect.width > viewport.width - margin) {
            score -= Math.abs((left + tooltipRect.width) - (viewport.width - margin))
        }
        if (top + tooltipRect.height > viewport.height - margin) {
            score -= Math.abs((top + tooltipRect.height) - (viewport.height - margin))
        }
        
        // Check for collisions with other elements
        const collisionPenalty = this.checkCollisions(top, left, tooltipRect.width, tooltipRect.height)
        score -= collisionPenalty
        
        return Math.max(0, score)
    }
    
    // Check for collisions with fixed/sticky elements
    checkCollisions(top, left, width, height) {
        const tooltipArea = { top, left, right: left + width, bottom: top + height }
        const fixedElements = document.querySelectorAll('[style*="position: fixed"], [style*="position: sticky"], .navbar, .header, .sidebar')
        
        let penalty = 0
        
        fixedElements.forEach(element => {
            if (element === this.tooltip) return // Skip self
            
            const rect = element.getBoundingClientRect()
            const elementArea = { 
                top: rect.top, 
                left: rect.left, 
                right: rect.right, 
                bottom: rect.bottom 
            }
            
            // Check for overlap
            if (this.areasOverlap(tooltipArea, elementArea)) {
                const overlapArea = this.calculateOverlapArea(tooltipArea, elementArea)
                penalty += overlapArea * 0.5 // Penalty proportional to overlap
            }
        })
        
        return penalty
    }
    
    // Check if two rectangular areas overlap
    areasOverlap(area1, area2) {
        return !(area1.right < area2.left || 
                area2.right < area1.left || 
                area1.bottom < area2.top || 
                area2.bottom < area1.top)
    }
    
    // Calculate the area of overlap between two rectangles
    calculateOverlapArea(area1, area2) {
        const overlapLeft = Math.max(area1.left, area2.left)
        const overlapTop = Math.max(area1.top, area2.top)
        const overlapRight = Math.min(area1.right, area2.right)
        const overlapBottom = Math.min(area1.bottom, area2.bottom)
        
        if (overlapLeft < overlapRight && overlapTop < overlapBottom) {
            return (overlapRight - overlapLeft) * (overlapBottom - overlapTop)
        }
        
        return 0
    }
    
    // Style arrow based on final position and adjustments
    styleArrowForPosition(arrow, position, arrowPosition, targetRect, tooltipRect) {
        const arrowSize = 6
        
        // Reset arrow styles
        arrow.style.cssText = `
            position: absolute;
            width: 0;
            height: 0;
        `
        
        switch (position) {
            case 'top':
                arrow.style.bottom = `-${arrowSize}px`
                arrow.style.left = arrowPosition.x
                arrow.style.transform = arrowPosition.x === '50%' ? 'translateX(-50%)' : 'none'
                arrow.style.borderLeft = `${arrowSize}px solid transparent`
                arrow.style.borderRight = `${arrowSize}px solid transparent`
                arrow.style.borderTopWidth = `${arrowSize}px`
                arrow.style.borderTopStyle = 'solid'
                break
                
            case 'bottom':
                arrow.style.top = `-${arrowSize}px`
                arrow.style.left = arrowPosition.x
                arrow.style.transform = arrowPosition.x === '50%' ? 'translateX(-50%)' : 'none'
                arrow.style.borderLeft = `${arrowSize}px solid transparent`
                arrow.style.borderRight = `${arrowSize}px solid transparent`
                arrow.style.borderBottomWidth = `${arrowSize}px`
                arrow.style.borderBottomStyle = 'solid'
                break
                
            case 'left':
                arrow.style.right = `-${arrowSize}px`
                arrow.style.top = arrowPosition.y
                arrow.style.transform = arrowPosition.y === '50%' ? 'translateY(-50%)' : 'none'
                arrow.style.borderTop = `${arrowSize}px solid transparent`
                arrow.style.borderBottom = `${arrowSize}px solid transparent`
                arrow.style.borderLeftWidth = `${arrowSize}px`
                arrow.style.borderLeftStyle = 'solid'
                break
                
            case 'right':
                arrow.style.left = `-${arrowSize}px`
                arrow.style.top = arrowPosition.y
                arrow.style.transform = arrowPosition.y === '50%' ? 'translateY(-50%)' : 'none'
                arrow.style.borderTop = `${arrowSize}px solid transparent`
                arrow.style.borderBottom = `${arrowSize}px solid transparent`
                arrow.style.borderRightWidth = `${arrowSize}px`
                arrow.style.borderRightStyle = 'solid'
                break
        }
    }

    // Style arrow based on position
    styleArrow(arrow, side, position, transform) {
        const arrowSize = 6

        arrow.style[side] = `-${arrowSize}px`
        arrow.style[position === '50%' ? (side === 'top' || side === 'bottom' ? 'left' : 'top') : side] = position
        arrow.style.transform = transform

        // Create arrow using borders
        if (side === 'top' || side === 'bottom') {
            arrow.style.borderLeft = `${arrowSize}px solid transparent`
            arrow.style.borderRight = `${arrowSize}px solid transparent`
            arrow.style[side === 'top' ? 'borderBottomWidth' : 'borderTopWidth'] = `${arrowSize}px`
            arrow.style[side === 'top' ? 'borderBottomStyle' : 'borderTopStyle'] = 'solid'
        } else {
            arrow.style.borderTop = `${arrowSize}px solid transparent`
            arrow.style.borderBottom = `${arrowSize}px solid transparent`
            arrow.style[side === 'left' ? 'borderRightWidth' : 'borderLeftWidth'] = `${arrowSize}px`
            arrow.style[side === 'left' ? 'borderRightStyle' : 'borderLeftStyle'] = 'solid'
        }
    }

    // Dismiss tooltip and mark as seen
    dismiss(event) {
        if (event) event.preventDefault()

        this.removeTooltip()
        this.markTooltipSeen()
        this.trackTooltipEvent('dismiss')
    }

    // Mark tooltip as seen (for feature tooltips)
    markTooltipSeen() {
        if (this.featureValue) {
            // The engine's mount path isn't knowable from static JS, so this
            // relies on the host app supplying the real route via
            // data-tooltip-dismiss-url-value (e.g.
            // rails_onboarding.dismiss_tooltip_path(tooltip_id: "...")) -
            // there's no reliable path to guess here.
            if (this.hasDismissUrlValue && this.dismissUrlValue) {
                fetch(this.dismissUrlValue, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
                        'Accept': 'application/json'
                    },
                    body: `tooltip_id=${encodeURIComponent(this.featureValue)}`
                }).catch(() => {})
            } else {
                console.warn(
                    `RailsOnboarding: tooltip "${this.featureValue}" has no ` +
                    `data-tooltip-dismiss-url-value, so it was not marked as shown ` +
                    `server-side and may reappear on the next page load. Set it to ` +
                    `rails_onboarding.dismiss_tooltip_path(tooltip_id: "${this.featureValue}").`
                )
            }

            // Also store in localStorage as backup
            const seenTooltips = JSON.parse(localStorage.getItem('rails_onboarding_seen_tooltips') || '{}')
            seenTooltips[this.featureValue] = new Date().toISOString()
            localStorage.setItem('rails_onboarding_seen_tooltips', JSON.stringify(seenTooltips))
        }
    }

    // Track tooltip events for analytics
    trackTooltipEvent(action) {
        if (typeof gtag !== 'undefined') {
            gtag('event', `tooltip_${action}`, {
                feature: this.featureValue || 'unknown',
                position: this.positionValue,
                timestamp: new Date().toISOString()
            })
        }
    }

    // Handle keyboard events
    handleKeyboard(event) {
        if (event.key === 'Escape' && this.tooltip) {
            this.dismiss()
        }
    }

    // Check if tooltip should be shown (enhanced with contextual logic)
    shouldShow() {
        // Always show non-feature tooltips
        if (!this.featureValue) return true

        // Check if already seen and dismissed
        const seenTooltips = JSON.parse(localStorage.getItem('rails_onboarding_seen_tooltips') || '{}')
        if (seenTooltips[this.featureValue]) {
            return false
        }
        
        // Check daily limit
        if (this.maxDailyValue > 0) {
            const behaviorData = this.behaviorData?.[this.todayKey]
            if (behaviorData && behaviorData.tooltipsShown) {
                const todayCount = behaviorData.tooltipsShown[this.featureValue] || 0
                if (todayCount >= this.maxDailyValue) {
                    return false
                }
            }
        }
        
        // Apply contextual logic for better timing
        if (this.contextualValue) {
            return this.shouldShowContextually()
        }

        return true
    }
    
    // Determine if tooltip should show based on contextual factors
    shouldShowContextually() {
        const behaviorData = this.behaviorData?.[this.todayKey]
        if (!behaviorData) return true
        
        // Don't overwhelm users - limit concurrent tooltips
        const activeTooltips = document.querySelectorAll('.onboarding-tooltip')
        if (activeTooltips.length >= 2) return false
        
        // Respect user interaction patterns
        const timeSinceLastInteraction = Date.now() - this.lastInteractionTime
        
        // If user is actively interacting, wait for a pause
        if (timeSinceLastInteraction < 2000 && this.priorityValue < 9) {
            return false
        }
        
        // If user seems busy (many recent interactions), only show high priority
        if (behaviorData.interactions > 20 && this.priorityValue < 7) {
            return false
        }
        
        // If it's user's first day, be more helpful
        if (this.isNewUser()) {
            return this.priorityValue >= 5
        }
        
        // For returning users, be more selective
        return this.priorityValue >= 6
    }

    // Show tooltip if it should be shown
    conditionalShow(event) {
        if (this.shouldShow()) {
            this.show(event)
        }
    }

    // Toggle tooltip visibility
    toggle(event) {
        if (this.tooltip) {
            this.hide(event)
        } else {
            this.show(event)
        }
    }

    // Update tooltip content
    updateContent(newContent) {
        if (this.tooltip) {
            const inner = this.tooltip.querySelector('.tooltip-inner')
            if (inner) {
                inner.innerHTML = newContent + (this.dismissibleValue ? '<button type="button" class="tooltip-dismiss" aria-label="Dismiss">×</button>' : '')

                // Re-setup dismiss handler
                if (this.dismissibleValue) {
                    const dismissButton = this.tooltip.querySelector('.tooltip-dismiss')
                    if (dismissButton) {
                        dismissButton.addEventListener('click', this.dismiss.bind(this))
                    }
                }

                // Re-position tooltip
                this.positionTooltip()
            }
        }
    }

    // Cleanup on disconnect
    disconnect() {
        if (this.showTimeout) {
            clearTimeout(this.showTimeout)
        }
        if (this.hideTimeout) {
            clearTimeout(this.hideTimeout)
        }

        this.removeTooltip()
        document.removeEventListener('keydown', this.handleKeyboard)
    }
}

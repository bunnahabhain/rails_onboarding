import { Controller } from "@hotwired/stimulus"

// Tooltip Scheduler for Progressive Disclosure
// Manages sequences of tooltips, timing, and user flow
export default class extends Controller {
    static values = {
        sequence: String, // JSON array of tooltip configurations
        autoStart: { type: Boolean, default: false },
        delay: { type: Number, default: 1000 }, // Delay between tooltips
        pauseOnHover: { type: Boolean, default: true },
        pauseOnInteraction: { type: Boolean, default: true },
        maxConcurrent: { type: Number, default: 1 }, // Max tooltips shown at once
        priority: { type: String, default: "sequential" } // sequential, priority, adaptive
    }

    connect() {
        this.currentIndex = 0
        this.isRunning = false
        this.isPaused = false
        this.activeTooltips = []
        this.userInteracting = false
        this.lastInteractionTime = Date.now()
        this.behaviorData = this.loadBehaviorData()
        
        this.parseSequence()
        this.setupInteractionTracking()
        
        if (this.autoStartValue) {
            this.start()
        }
    }

    // Parse the sequence configuration
    parseSequence() {
        try {
            this.tooltipSequence = JSON.parse(this.sequenceValue || '[]')
        } catch (error) {
            console.warn('Invalid tooltip sequence configuration:', error)
            this.tooltipSequence = []
        }
        
        // Validate and enhance each tooltip config
        this.tooltipSequence = this.tooltipSequence.map((config, index) => ({
            id: config.id || `tooltip_${index}`,
            selector: config.selector,
            content: config.content,
            position: config.position || 'top',
            trigger: config.trigger || 'auto',
            priority: config.priority || 5,
            delay: config.delay || this.delayValue,
            duration: config.duration || 5000,
            conditions: config.conditions || {},
            onShow: config.onShow,
            onHide: config.onHide,
            dismissible: config.dismissible !== false,
            contextual: config.contextual || false,
            animation: config.animation || 'fade',
            maxDaily: config.maxDaily || 3,
            ...config
        }))
    }

    // Setup interaction tracking to pause tooltips during active use
    setupInteractionTracking() {
        // Track various user interactions
        const interactionEvents = ['click', 'keydown', 'scroll', 'mousemove', 'touchstart']
        
        interactionEvents.forEach(eventType => {
            document.addEventListener(eventType, () => {
                this.userInteracting = true
                this.lastInteractionTime = Date.now()
                
                if (this.pauseOnInteractionValue && this.isRunning) {
                    this.pause()
                    
                    // Resume after interaction stops
                    clearTimeout(this.resumeTimeout)
                    this.resumeTimeout = setTimeout(() => {
                        this.userInteracting = false
                        if (this.isPaused) {
                            this.resume()
                        }
                    }, 2000) // Resume 2 seconds after interaction stops
                }
            })
        })
        
        // Track hovering over tooltips
        if (this.pauseOnHoverValue) {
            document.addEventListener('mouseenter', (event) => {
                if (event.target.closest('.onboarding-tooltip')) {
                    this.pause()
                }
            }, true)
            
            document.addEventListener('mouseleave', (event) => {
                if (event.target.closest('.onboarding-tooltip')) {
                    if (this.isPaused && !this.userInteracting) {
                        this.resume()
                    }
                }
            }, true)
        }
    }

    // Start the tooltip sequence
    start() {
        if (this.isRunning) return
        
        this.isRunning = true
        this.isPaused = false
        this.currentIndex = 0
        
        this.scheduleNext()
    }

    // Pause the sequence
    pause() {
        this.isPaused = true
        if (this.nextTimeout) {
            clearTimeout(this.nextTimeout)
        }
    }

    // Resume the sequence
    resume() {
        if (!this.isRunning || !this.isPaused) return
        
        this.isPaused = false
        this.scheduleNext()
    }

    // Stop the sequence
    stop() {
        this.isRunning = false
        this.isPaused = false
        this.currentIndex = 0
        
        if (this.nextTimeout) {
            clearTimeout(this.nextTimeout)
        }
        
        // Hide all active tooltips
        this.hideAllTooltips()
    }

    // Schedule the next tooltip in the sequence
    scheduleNext() {
        if (!this.isRunning || this.isPaused) return
        
        // Clean up finished tooltips
        this.cleanupActiveTooltips()
        
        // Check if we have more tooltips to show
        const nextTooltip = this.getNextTooltip()
        if (!nextTooltip) {
            this.complete()
            return
        }
        
        // Check if we can show more tooltips (concurrent limit)
        if (this.activeTooltips.length >= this.maxConcurrentValue) {
            // Wait for some to finish
            setTimeout(() => this.scheduleNext(), 500)
            return
        }
        
        // Schedule the tooltip
        this.nextTimeout = setTimeout(() => {
            this.showTooltip(nextTooltip)
            this.scheduleNext()
        }, nextTooltip.delay)
    }

    // Get the next tooltip to show based on priority strategy
    getNextTooltip() {
        switch (this.priorityValue) {
            case 'sequential':
                return this.getNextSequential()
            case 'priority':
                return this.getNextByPriority()
            case 'adaptive':
                return this.getNextAdaptive()
            default:
                return this.getNextSequential()
        }
    }

    // Get next tooltip sequentially
    getNextSequential() {
        while (this.currentIndex < this.tooltipSequence.length) {
            const tooltip = this.tooltipSequence[this.currentIndex]
            this.currentIndex++
            
            if (this.shouldShowTooltip(tooltip)) {
                return tooltip
            }
        }
        return null
    }

    // Get next tooltip by priority (highest first)
    getNextByPriority() {
        const availableTooltips = this.tooltipSequence
            .filter(tooltip => this.shouldShowTooltip(tooltip))
            .sort((a, b) => b.priority - a.priority)
        
        if (availableTooltips.length > 0) {
            const tooltip = availableTooltips[0]
            // Remove from sequence so it's not shown again
            this.tooltipSequence = this.tooltipSequence.filter(t => t.id !== tooltip.id)
            return tooltip
        }
        
        return null
    }

    // Get next tooltip adaptively based on user behavior
    getNextAdaptive() {
        const behaviorData = this.behaviorData[this.getTodayKey()]
        if (!behaviorData) return this.getNextSequential()
        
        // Adapt based on user behavior patterns
        const availableTooltips = this.tooltipSequence.filter(tooltip => this.shouldShowTooltip(tooltip))
        
        if (availableTooltips.length === 0) return null
        
        // Score tooltips based on user context
        const scoredTooltips = availableTooltips.map(tooltip => ({
            ...tooltip,
            score: this.scoreTooltipRelevance(tooltip, behaviorData)
        }))
        
        // Sort by score and return highest
        scoredTooltips.sort((a, b) => b.score - a.score)
        const tooltip = scoredTooltips[0]
        
        // Remove from sequence
        this.tooltipSequence = this.tooltipSequence.filter(t => t.id !== tooltip.id)
        return tooltip
    }

    // Score tooltip relevance based on user behavior
    scoreTooltipRelevance(tooltip, behaviorData) {
        let score = tooltip.priority
        
        // Boost score for struggling areas
        if (behaviorData.strugglingAreas && behaviorData.strugglingAreas.includes(tooltip.selector)) {
            score += 3
        }
        
        // Reduce score if shown recently
        const recentlyShown = behaviorData.tooltipsShown && behaviorData.tooltipsShown[tooltip.id]
        if (recentlyShown && recentlyShown > Date.now() - 86400000) { // 24 hours
            score -= 2
        }
        
        // Boost score for high interaction areas
        if (behaviorData.interactions > 10) {
            score += 1
        }
        
        // Contextual adjustments
        if (tooltip.contextual) {
            // Check if user is on relevant page/section
            const relevantElement = document.querySelector(tooltip.selector)
            if (relevantElement && this.isElementVisible(relevantElement)) {
                score += 2
            }
        }
        
        return score
    }

    // Check if tooltip should be shown
    shouldShowTooltip(tooltip) {
        // Check if element exists
        const element = document.querySelector(tooltip.selector)
        if (!element) return false
        
        // Check visibility
        if (!this.isElementVisible(element)) return false
        
        // Check conditions
        if (tooltip.conditions && !this.checkConditions(tooltip.conditions)) {
            return false
        }
        
        // Check daily limits
        const behaviorData = this.behaviorData[this.getTodayKey()]
        if (behaviorData && behaviorData.tooltipsShown) {
            const todayCount = behaviorData.tooltipsShown[tooltip.id] || 0
            if (todayCount >= tooltip.maxDaily) {
                return false
            }
        }
        
        // Check if already dismissed
        const seenTooltips = JSON.parse(localStorage.getItem('rails_onboarding_seen_tooltips') || '{}')
        if (seenTooltips[tooltip.id]) {
            return false
        }
        
        return true
    }

    // Check custom conditions
    checkConditions(conditions) {
        for (const [condition, value] of Object.entries(conditions)) {
            switch (condition) {
                case 'url':
                    if (!window.location.href.includes(value)) return false
                    break
                case 'element_visible':
                    if (!this.isElementVisible(document.querySelector(value))) return false
                    break
                case 'time_on_page':
                    const timeOnPage = Date.now() - this.pageStartTime
                    if (timeOnPage < value) return false
                    break
                case 'user_type':
                    // Could check user attributes here
                    break
                case 'screen_size':
                    if (value === 'mobile' && window.innerWidth > 768) return false
                    if (value === 'desktop' && window.innerWidth <= 768) return false
                    break
            }
        }
        return true
    }

    // Show a tooltip
    showTooltip(tooltipConfig) {
        const element = document.querySelector(tooltipConfig.selector)
        if (!element) return
        
        // Create tooltip controller instance
        const tooltipElement = this.createTooltipElement(tooltipConfig)
        element.appendChild(tooltipElement)
        
        // Track as active
        const tooltipInstance = {
            config: tooltipConfig,
            element: tooltipElement,
            startTime: Date.now()
        }
        
        this.activeTooltips.push(tooltipInstance)
        this.recordTooltipShow(tooltipConfig.id)
        
        // Auto-hide after duration
        setTimeout(() => {
            this.hideTooltip(tooltipInstance)
        }, tooltipConfig.duration)
        
        // Execute onShow callback
        if (tooltipConfig.onShow && typeof window[tooltipConfig.onShow] === 'function') {
            window[tooltipConfig.onShow](tooltipConfig)
        }
    }

    // Create tooltip DOM element
    createTooltipElement(config) {
        const wrapper = document.createElement('div')
        wrapper.innerHTML = `
            <div data-controller="tooltip"
                 data-tooltip-position-value="${config.position}"
                 data-tooltip-feature-value="${config.id}"
                 data-tooltip-animation-value="${config.animation}"
                 data-tooltip-trigger-value="auto"
                 data-tooltip-dismissible-value="${config.dismissible}">
                <div data-tooltip-target="content">
                    ${config.content}
                </div>
            </div>
        `
        return wrapper.firstElementChild
    }

    // Hide a specific tooltip
    hideTooltip(tooltipInstance) {
        if (tooltipInstance.element && tooltipInstance.element.parentNode) {
            // Trigger hide through tooltip controller
            const tooltipController = this.application.getControllerForElementAndIdentifier(
                tooltipInstance.element, 'tooltip'
            )
            
            if (tooltipController) {
                tooltipController.forceHide()
            } else {
                tooltipInstance.element.remove()
            }
        }
        
        // Execute onHide callback
        if (tooltipInstance.config.onHide && typeof window[tooltipInstance.config.onHide] === 'function') {
            window[tooltipInstance.config.onHide](tooltipInstance.config)
        }
        
        // Remove from active tooltips
        this.activeTooltips = this.activeTooltips.filter(t => t !== tooltipInstance)
    }

    // Hide all active tooltips
    hideAllTooltips() {
        [...this.activeTooltips].forEach(tooltip => {
            this.hideTooltip(tooltip)
        })
    }

    // Clean up finished tooltips
    cleanupActiveTooltips() {
        this.activeTooltips = this.activeTooltips.filter(tooltip => {
            return tooltip.element && tooltip.element.parentNode
        })
    }

    // Check if element is visible
    isElementVisible(element) {
        if (!element) return false
        
        const rect = element.getBoundingClientRect()
        return rect.width > 0 && rect.height > 0 && 
               rect.top >= 0 && rect.left >= 0 &&
               rect.bottom <= window.innerHeight && 
               rect.right <= window.innerWidth
    }

    // Complete the sequence
    complete() {
        this.isRunning = false
        this.isPaused = false
        
        // Dispatch completion event
        this.dispatch('complete', {
            detail: {
                totalShown: this.activeTooltips.length,
                sequence: this.tooltipSequence
            }
        })
    }

    // Load behavior data
    loadBehaviorData() {
        return JSON.parse(localStorage.getItem('rails_onboarding_behavior') || '{}')
    }

    // Record tooltip show
    recordTooltipShow(tooltipId) {
        const todayKey = this.getTodayKey()
        
        if (!this.behaviorData[todayKey]) {
            this.behaviorData[todayKey] = { tooltipsShown: {} }
        }
        
        if (!this.behaviorData[todayKey].tooltipsShown) {
            this.behaviorData[todayKey].tooltipsShown = {}
        }
        
        // Store a running COUNT, not a timestamp: shouldShowTooltip compares this
        // against tooltip.maxDaily as a count, so storing Date.now() here made every
        // value astronomically larger than maxDaily and suppressed the tooltip after
        // a single show (breaking the guided tour on any subsequent load).
        const shownToday = this.behaviorData[todayKey].tooltipsShown
        shownToday[tooltipId] = (shownToday[tooltipId] || 0) + 1

        localStorage.setItem('rails_onboarding_behavior', JSON.stringify(this.behaviorData))
    }

    // Get today's key
    getTodayKey() {
        return new Date().toISOString().split('T')[0]
    }

    // Public API methods
    skipCurrent() {
        if (this.activeTooltips.length > 0) {
            this.hideTooltip(this.activeTooltips[0])
        }
        this.scheduleNext()
    }

    skipAll() {
        this.stop()
    }

    showTooltipById(id) {
        const tooltip = this.tooltipSequence.find(t => t.id === id)
        if (tooltip && this.shouldShowTooltip(tooltip)) {
            this.showTooltip(tooltip)
        }
    }

    // Cleanup on disconnect
    disconnect() {
        this.stop()
        
        if (this.nextTimeout) {
            clearTimeout(this.nextTimeout)
        }
        
        if (this.resumeTimeout) {
            clearTimeout(this.resumeTimeout)
        }
    }
}
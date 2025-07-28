import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["content", "trigger"]
    static values = {
        position: { type: String, default: "top" },
        delay: { type: Number, default: 0 },
        feature: String,
        dismissible: { type: Boolean, default: true }
    }

    connect() {
        this.tooltip = null
        this.showTimeout = null
        this.hideTimeout = null
        this.setupEventListeners()
    }

    // Setup event listeners for showing/hiding tooltip
    setupEventListeners() {
        if (this.hasTriggerTarget) {
            this.triggerTarget.addEventListener('mouseenter', this.show.bind(this))
            this.triggerTarget.addEventListener('mouseleave', this.hide.bind(this))
            this.triggerTarget.addEventListener('focus', this.show.bind(this))
            this.triggerTarget.addEventListener('blur', this.hide.bind(this))
        } else {
            this.element.addEventListener('mouseenter', this.show.bind(this))
            this.element.addEventListener('mouseleave', this.hide.bind(this))
            this.element.addEventListener('focus', this.show.bind(this))
            this.element.addEventListener('blur', this.hide.bind(this))
        }

        // Handle keyboard events
        document.addEventListener('keydown', this.handleKeyboard.bind(this))
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
        this.tooltip.className = 'rails-onboarding-tooltip'
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

        // Auto-hide after 10 seconds for feature tooltips
        if (this.featureValue) {
            setTimeout(() => {
                this.removeTooltip()
            }, 10000)
        }
    }

    // Remove tooltip from DOM
    removeTooltip() {
        if (this.tooltip) {
            // Animate out
            this.tooltip.style.opacity = '0'
            this.tooltip.style.transform = 'scale(0.95) translateY(5px)'

            setTimeout(() => {
                if (this.tooltip && this.tooltip.parentNode) {
                    this.tooltip.parentNode.removeChild(this.tooltip)
                }
                this.tooltip = null
            }, 150)
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
    getFeatureTooltipContent() {
        const featureTooltips = {
            'getting_started': {
                title: 'Getting Started',
                content: 'Click here to begin your journey and learn the basics of using this platform effectively.'
            },
            'dashboard': {
                title: 'Dashboard',
                content: 'Your central hub for viewing overview information and quick access to key features.'
            },
            'create_list': {
                title: 'Create List',
                content: 'Start organizing by creating your first list. You can add items, set priorities, and share with others.'
            },
            'invite_users': {
                title: 'Invite Team Members',
                content: 'Collaborate with others by inviting team members to your workspace.'
            },
            'settings': {
                title: 'Settings',
                content: 'Customize your experience by adjusting preferences, notifications, and account settings.'
            }
        }

        const tooltip = featureTooltips[this.featureValue]
        if (tooltip) {
            return `
        <h4 class="tooltip-title">${tooltip.title}</h4>
        <p class="tooltip-text">${tooltip.content}</p>
      `
        }

        return `<p>Learn more about this feature.</p>`
    }

    // Style the tooltip
    styleTooltip() {
        if (!this.tooltip) return

        this.tooltip.style.cssText = `
      position: absolute;
      z-index: 1050;
      background: #1f2937;
      color: white;
      border-radius: 0.5rem;
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
      font-size: 0.875rem;
      line-height: 1.4;
      max-width: 16rem;
      opacity: 0;
      transform: scale(0.95) translateY(-5px);
      transition: opacity 0.15s ease, transform 0.15s ease;
      pointer-events: auto;
    `

        // Style inner content
        const inner = this.tooltip.querySelector('.tooltip-inner')
        if (inner) {
            inner.style.cssText = `
        padding: 0.75rem;
        position: relative;
      `
        }

        // Style arrow
        const arrow = this.tooltip.querySelector('.tooltip-arrow')
        if (arrow) {
            arrow.style.cssText = `
        position: absolute;
        width: 0;
        height: 0;
      `
        }

        // Style dismiss button
        const dismiss = this.tooltip.querySelector('.tooltip-dismiss')
        if (dismiss) {
            dismiss.style.cssText = `
        position: absolute;
        top: 0.25rem;
        right: 0.25rem;
        background: none;
        border: none;
        color: #d1d5db;
        font-size: 1.25rem;
        line-height: 1;
        cursor: pointer;
        padding: 0.25rem;
        width: 1.5rem;
        height: 1.5rem;
        display: flex;
        align-items: center;
        justify-content: center;
      `
        }

        // Style title and text
        const title = this.tooltip.querySelector('.tooltip-title')
        if (title) {
            title.style.cssText = `
        margin: 0 0 0.5rem;
        font-weight: 600;
        font-size: 0.875rem;
        color: white;
      `
        }

        const text = this.tooltip.querySelector('.tooltip-text')
        if (text) {
            text.style.cssText = `
        margin: 0;
        color: #d1d5db;
        font-size: 0.8125rem;
      `
        }
    }

    // Position tooltip relative to trigger element
    positionTooltip() {
        if (!this.tooltip) return

        const target = this.hasTriggerTarget ? this.triggerTarget : this.element
        const targetRect = target.getBoundingClientRect()
        const tooltipRect = this.tooltip.getBoundingClientRect()
        const arrow = this.tooltip.querySelector('.tooltip-arrow')

        let top, left, arrowTop, arrowLeft

        // Calculate position based on preferred position
        switch (this.positionValue) {
            case 'top':
                top = targetRect.top - tooltipRect.height - 8
                left = targetRect.left + (targetRect.width / 2) - (tooltipRect.width / 2)
                if (arrow) {
                    this.styleArrow(arrow, 'bottom', '50%', 'translateX(-50%)')
                }
                break

            case 'bottom':
                top = targetRect.bottom + 8
                left = targetRect.left + (targetRect.width / 2) - (tooltipRect.width / 2)
                if (arrow) {
                    this.styleArrow(arrow, 'top', '50%', 'translateX(-50%)')
                }
                break

            case 'left':
                top = targetRect.top + (targetRect.height / 2) - (tooltipRect.height / 2)
                left = targetRect.left - tooltipRect.width - 8
                if (arrow) {
                    this.styleArrow(arrow, 'right', '50%', 'translateY(-50%)')
                }
                break

            case 'right':
                top = targetRect.top + (targetRect.height / 2) - (tooltipRect.height / 2)
                left = targetRect.right + 8
                if (arrow) {
                    this.styleArrow(arrow, 'left', '50%', 'translateY(-50%)')
                }
                break

            default:
                top = targetRect.top - tooltipRect.height - 8
                left = targetRect.left + (targetRect.width / 2) - (tooltipRect.width / 2)
        }

        // Adjust if tooltip would be off-screen
        if (left < 8) {
            left = 8
        } else if (left + tooltipRect.width > window.innerWidth - 8) {
            left = window.innerWidth - tooltipRect.width - 8
        }

        if (top < 8) {
            top = 8
        } else if (top + tooltipRect.height > window.innerHeight - 8) {
            top = window.innerHeight - tooltipRect.height - 8
        }

        // Apply position
        this.tooltip.style.top = `${top}px`
        this.tooltip.style.left = `${left}px`

        // Animate in
        requestAnimationFrame(() => {
            if (this.tooltip) {
                this.tooltip.style.opacity = '1'
                this.tooltip.style.transform = 'scale(1) translateY(0)'
            }
        })
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
            arrow.style[side === 'top' ? 'borderBottom' : 'borderTop'] = `${arrowSize}px solid #1f2937`
        } else {
            arrow.style.borderTop = `${arrowSize}px solid transparent`
            arrow.style.borderBottom = `${arrowSize}px solid transparent`
            arrow.style[side === 'left' ? 'borderRight' : 'borderLeft'] = `${arrowSize}px solid #1f2937`
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
            // Send to Rails backend to mark as seen
            if (typeof Rails !== 'undefined' && Rails.ajax) {
                Rails.ajax({
                    url: '/rails_onboarding/tooltips/mark_shown',
                    type: 'POST',
                    data: `feature=${encodeURIComponent(this.featureValue)}`,
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
                    }
                })
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

    // Check if tooltip should be shown (for feature tooltips)
    shouldShow() {
        if (!this.featureValue) return true

        // Check localStorage first (immediate feedback)
        const seenTooltips = JSON.parse(localStorage.getItem('rails_onboarding_seen_tooltips') || '{}')
        if (seenTooltips[this.featureValue]) {
            return false
        }

        // Could also check server-side state here if needed
        return true
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

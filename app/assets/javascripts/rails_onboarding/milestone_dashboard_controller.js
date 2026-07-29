import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["milestoneCard", "pointsValue", "countValue"]
  // Supplied by the view via milestones_path. The engine is mounted at a
  // host-chosen prefix, so this cannot be a literal path.
  static values = { milestonesPath: String }
  
  connect() {
    this.animateStats()
    this.setupCardHovers()
    this.checkForNewMilestones()
  }

  animateStats() {
    // Animate the point counter
    if (this.hasPointsValueTarget) {
      const finalValue = parseInt(this.pointsValueTarget.textContent)
      this.animateCounter(this.pointsValueTarget, finalValue, 1000)
    }
    
    // Animate the milestone counter
    if (this.hasCountValueTarget) {
      const finalValue = parseInt(this.countValueTarget.textContent)
      this.animateCounter(this.countValueTarget, finalValue, 800)
    }
  }

  animateCounter(element, finalValue, duration) {
    const startValue = 0
    const startTime = performance.now()
    
    const updateCounter = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      // Easing function for smooth animation
      const easeOut = 1 - Math.pow(1 - progress, 3)
      const currentValue = Math.floor(startValue + (finalValue - startValue) * easeOut)
      
      element.textContent = currentValue
      
      if (progress < 1) {
        requestAnimationFrame(updateCounter)
      } else {
        element.textContent = finalValue
      }
    }
    
    requestAnimationFrame(updateCounter)
  }

  setupCardHovers() {
    this.milestoneCardTargets.forEach(card => {
      card.addEventListener('mouseenter', this.handleCardHover.bind(this))
      card.addEventListener('mouseleave', this.handleCardLeave.bind(this))
    })
  }

  handleCardHover(event) {
    const card = event.currentTarget
    card.style.transform = 'translateY(-4px)'
    card.style.transition = 'transform 0.2s ease-in-out'
  }

  handleCardLeave(event) {
    const card = event.currentTarget
    card.style.transform = 'translateY(0)'
  }

  checkForNewMilestones() {
    // Check URL parameters for newly achieved milestones
    const urlParams = new URLSearchParams(window.location.search)
    const awardedMilestones = urlParams.get('awarded_milestones')
    
    if (awardedMilestones) {
      const milestoneKeys = awardedMilestones.split(',')
      
      // Fetch milestone details and show celebrations
      milestoneKeys.forEach(key => {
        this.fetchAndShowMilestone(key.trim())
      })
      
      // Clean up URL
      this.cleanUrl()
    }
  }

  async fetchAndShowMilestone(milestoneKey) {
    // Without the mounted path there is nothing safe to guess at - bail rather
    // than fire a request at the host app's root.
    if (!this.hasMilestonesPathValue || !this.milestonesPathValue) return

    const base = this.milestonesPathValue.replace(/\/+$/, "")
    try {
      const response = await fetch(`${base}/${encodeURIComponent(milestoneKey)}`, {
        headers: { 'Accept': 'application/json' }
      })
      
      if (response.ok) {
        const milestone = await response.json()
        this.showMilestoneCelebration(milestone)
      }
    } catch (error) {
      console.error('Failed to fetch milestone:', error)
    }
  }

  showMilestoneCelebration(milestone) {
    // An empty shell on purpose: milestone_celebration_controller builds the
    // same structure the server-rendered partial produces when it connects to
    // an overlay with no .celebration-modal. Attributes are set as properties
    // rather than interpolated into markup so milestone data cannot break out
    // of the attribute.
    const overlay = document.createElement("div")
    overlay.className = "milestone-celebration-overlay"
    overlay.dataset.controller = "milestone-celebration"
    overlay.dataset.milestoneCelebrationMilestoneValue = JSON.stringify(milestone)
    overlay.dataset.temporary = "true"
    if (this.hasMilestonesPathValue && this.milestonesPathValue) {
      overlay.dataset.milestoneCelebrationMilestonesPathValue = this.milestonesPathValue
    }

    document.body.appendChild(overlay)
  }

  cleanUrl() {
    const url = new URL(window.location)
    url.searchParams.delete('awarded_milestones')
    window.history.replaceState({}, '', url)
  }
}
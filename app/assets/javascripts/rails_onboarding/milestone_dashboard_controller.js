import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["milestoneCard", "pointsValue", "countValue"]
  
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
    try {
      const response = await fetch(`/milestones/${milestoneKey}`, {
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
    // Create temporary celebration element
    const celebrationHTML = `
      <div class="milestone-celebration-overlay" 
           data-controller="milestone-celebration" 
           data-milestone-celebration-milestone-value='${JSON.stringify(milestone)}'
           data-temporary="true">
        <!-- Celebration content will be rendered by the controller -->
      </div>
    `
    
    document.body.insertAdjacentHTML('beforeend', celebrationHTML)
  }

  cleanUrl() {
    const url = new URL(window.location)
    url.searchParams.delete('awarded_milestones')
    window.history.replaceState({}, '', url)
  }
}
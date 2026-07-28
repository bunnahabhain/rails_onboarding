import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.setupAnimations()
  }

  setupAnimations() {
    const iconLarge = this.element.querySelector('.milestone-icon-large')
    const hero = this.element.querySelector('.milestone-hero')
    
    if (iconLarge) {
      // Add bounce animation to the icon
      iconLarge.style.animation = 'onboarding-milestone-bounce 1s ease-in-out'
    }
    
    if (hero && hero.classList.contains('achieved')) {
      // Add celebration effect for achieved milestones
      this.addCelebrationGlow()
    }
  }

  addCelebrationGlow() {
    const hero = this.element.querySelector('.milestone-hero')
    if (hero) {
      hero.classList.add('celebration-glow')
      
      // Remove the glow effect after animation
      setTimeout(() => {
        hero.classList.remove('celebration-glow')
      }, 2000)
    }
  }
}
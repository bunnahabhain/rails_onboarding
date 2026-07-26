import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["confetti"]
  static values = { milestone: Object }

  connect() {
    this.showCelebration()
  }

  showCelebration() {
    // Show the modal with animation. .is-hidden/.is-fading (and the
    // opacity transition) live in milestones.css, so this only toggles
    // classes rather than writing display/opacity/transition inline.
    this.element.classList.remove("is-hidden")
    this.element.classList.add("is-fading")

    // Trigger animations
    requestAnimationFrame(() => {
      this.element.classList.remove("is-fading")

      // Start confetti animation
      this.startConfetti()

      // Auto-dismiss after 5 seconds if user doesn't interact
      this.autoDismissTimer = setTimeout(() => {
        this.dismiss()
      }, 8000)
    })
  }

  startConfetti() {
    if (!this.hasConfettiTarget) return
    
    const confettiContainer = this.confettiTarget
    const colors = ['#FFD700', '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7']
    
    // Create confetti pieces
    for (let i = 0; i < 50; i++) {
      setTimeout(() => this.createConfettiPiece(confettiContainer, colors), i * 50)
    }
  }

  createConfettiPiece(container, colors) {
    const confetti = document.createElement('div')
    confetti.className = 'confetti-piece'
    
    // Random properties
    const color = colors[Math.floor(Math.random() * colors.length)]
    const size = Math.random() * 8 + 4
    const left = Math.random() * 100
    const animationDuration = Math.random() * 2 + 2
    const rotation = Math.random() * 360
    
    confetti.style.cssText = `
      position: absolute;
      width: ${size}px;
      height: ${size}px;
      background-color: ${color};
      left: ${left}%;
      top: -10px;
      border-radius: 50%;
      animation: confetti-fall ${animationDuration}s linear forwards;
      transform: rotate(${rotation}deg);
      pointer-events: none;
    `
    
    container.appendChild(confetti)
    
    // Remove confetti piece after animation
    setTimeout(() => {
      if (confetti.parentNode) {
        confetti.parentNode.removeChild(confetti)
      }
    }, animationDuration * 1000)
  }

  dismiss() {
    if (this.autoDismissTimer) {
      clearTimeout(this.autoDismissTimer)
    }

    this.element.classList.add("is-fading")

    setTimeout(() => {
      this.element.classList.add("is-hidden")
      // Remove the element from DOM if it was dynamically added
      if (this.element.dataset.temporary === "true") {
        this.element.remove()
      }
    }, 300)
  }

  viewAllMilestones() {
    this.dismiss()
    // Navigate to milestones page
    window.location.href = "/milestones"
  }

  // Prevent dismissal when clicking inside the modal
  preventDismiss(event) {
    event.stopPropagation()
  }
}
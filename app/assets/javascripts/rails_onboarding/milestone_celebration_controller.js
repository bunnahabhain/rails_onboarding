import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["confetti"]
  // milestonesPath is supplied by the view. The engine is mounted at a
  // host-chosen prefix, so a literal "/milestones" is wrong in most apps.
  static values = { milestone: Object, milestonesPath: String }

  connect() {
    this.renderContentIfEmpty()
    this.showCelebration()
  }

  // The celebration is normally rendered server-side by
  // rails_onboarding/shared/_milestone_celebration. It can also be injected
  // at runtime by milestone_dashboard_controller, which knows only the
  // milestone's JSON - that injected element is an empty shell, and without
  // this it showed as a full-screen backdrop containing nothing, with no
  // dismiss control and no confetti container. Build the same structure the
  // partial produces so the existing CSS applies either way.
  renderContentIfEmpty() {
    if (this.element.querySelector(".celebration-modal")) return

    const milestone = this.hasMilestoneValue ? this.milestoneValue : {}
    const el = (tag, className, text) => {
      const node = document.createElement(tag)
      if (className) node.className = className
      if (text !== undefined && text !== null) node.textContent = text
      return node
    }

    const backdrop = el("div", "celebration-backdrop")
    backdrop.dataset.action = "click->milestone-celebration#dismiss"

    const iconContainer = el("div", "achievement-icon-container")
    iconContainer.append(el("div", "achievement-icon-glow"),
                         el("div", "achievement-icon", milestone.icon))

    const points = el("div", "points-earned")
    points.append(el("span", "points-label", "You earned"),
                  el("span", "points-value", `+${milestone.points ?? 0}`),
                  el("span", "points-label", "points!"))

    const announcement = el("div", "achievement-announcement")
    announcement.append(iconContainer,
                        el("h2", "achievement-title", "Milestone Achieved!"),
                        el("h3", "milestone-name", milestone.title),
                        el("p", "milestone-description", milestone.description),
                        points)

    const confetti = el("div", "confetti-container")
    confetti.dataset.milestoneCelebrationTarget = "confetti"

    const continueBtn = el("button", "onboarding-btn onboarding-btn-primary", "Continue")
    continueBtn.type = "button"
    continueBtn.dataset.action = "click->milestone-celebration#dismiss"

    const actions = el("div", "celebration-actions")
    actions.append(continueBtn)

    // Only offer "View All" when the view told us where that lives.
    if (this.hasMilestonesPathValue && this.milestonesPathValue) {
      const allBtn = el("button", "onboarding-btn onboarding-btn-secondary", "View All Achievements")
      allBtn.type = "button"
      allBtn.dataset.action = "click->milestone-celebration#viewAllMilestones"
      actions.append(allBtn)
    }

    const content = el("div", "celebration-content")
    content.append(confetti, announcement, actions)

    const modal = el("div", "celebration-modal")
    modal.append(content)

    this.element.append(backdrop, modal)
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
    // Fall back to a direct lookup: when renderContentIfEmpty() has just
    // inserted the container, Stimulus may not have registered the target yet.
    const confettiContainer = this.hasConfettiTarget
      ? this.confettiTarget
      : this.element.querySelector(".confetti-container")
    if (!confettiContainer) return
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
      animation: onboarding-confetti-fall ${animationDuration}s linear forwards;
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
    // Supplied by the view via the engine's route helper; a literal
    // "/milestones" only resolves when the engine is mounted at root.
    if (this.hasMilestonesPathValue && this.milestonesPathValue) {
      window.location.href = this.milestonesPathValue
    }
  }

  // Prevent dismissal when clicking inside the modal
  preventDismiss(event) {
    event.stopPropagation()
  }
}
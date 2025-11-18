import { Controller } from "@hotwired/stimulus"

// Chart controller
// Handles chart animations and interactions
export default class extends Controller {
  static targets = ["bar"]

  connect() {
    this.animateBars()
  }

  animateBars() {
    if (!this.hasBarTarget) return

    this.barTargets.forEach((bar, index) => {
      const finalHeight = bar.style.height
      bar.style.height = '0%'

      setTimeout(() => {
        bar.style.transition = 'height 0.5s ease-out'
        bar.style.height = finalHeight
      }, index * 100)
    })
  }
}

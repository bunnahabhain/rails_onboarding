import { Controller } from "@hotwired/stimulus"

// Flow editor controller
// Handles dynamic step management in flow editor
export default class extends Controller {
  static targets = ["stepsContainer"]

  connect() {
    this.stepIndex = this.getMaxStepIndex()
  }

  addStep(event) {
    event.preventDefault()

    this.stepIndex++
    const stepNumber = this.stepIndex + 1

    const template = document.getElementById('step-template')
    if (!template) return

    const stepHtml = template.innerHTML
      .replace(/__INDEX__/g, this.stepIndex)
      .replace(/__NUMBER__/g, stepNumber)

    const stepsList = document.getElementById('steps-list')
    if (!stepsList) return

    // Remove empty state message if it exists
    const emptyMessage = stepsList.querySelector('.admin-text-muted')
    if (emptyMessage) {
      emptyMessage.remove()
    }

    stepsList.insertAdjacentHTML('beforeend', stepHtml)
    this.updateStepNumbers()
  }

  removeStep(event) {
    event.preventDefault()

    if (!confirm('Are you sure you want to remove this step?')) {
      return
    }

    const stepItem = event.target.closest('.admin-step-item')
    if (!stepItem) return

    stepItem.remove()
    this.updateStepNumbers()

    // Show empty message if no steps remain
    const stepsList = document.getElementById('steps-list')
    if (stepsList && stepsList.children.length === 0) {
      stepsList.innerHTML = '<p class="admin-text-muted">No steps added yet. Click "Add Step" to get started.</p>'
    }
  }

  updateStepNumbers() {
    const stepItems = document.querySelectorAll('.admin-step-item')
    stepItems.forEach((item, index) => {
      const stepNumber = item.querySelector('.admin-step-number')
      if (stepNumber) {
        stepNumber.textContent = index + 1
      }

      const orderInput = item.querySelector('input[type="hidden"][name*="[order]"]')
      if (orderInput) {
        orderInput.value = index
      }
    })
  }

  getMaxStepIndex() {
    const stepItems = document.querySelectorAll('.admin-step-item')
    let maxIndex = -1

    stepItems.forEach(item => {
      const index = parseInt(item.dataset.stepIndex || '0')
      if (index > maxIndex) {
        maxIndex = index
      }
    })

    return maxIndex
  }
}

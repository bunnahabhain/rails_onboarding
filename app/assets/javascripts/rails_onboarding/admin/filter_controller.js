import { Controller } from "@hotwired/stimulus"

// Filter controller
// Handles filtering and search functionality
export default class extends Controller {
  static targets = ["searchInput", "statusSelect", "table", "row"]

  connect() {
    this.filterRows()
  }

  filter() {
    this.filterRows()
  }

  filterRows() {
    if (!this.hasRowTarget) return

    const searchTerm = this.hasSearchInputTarget ?
      this.searchInputTarget.value.toLowerCase() : ''

    const statusFilter = this.hasStatusSelectTarget ?
      this.statusSelectTarget.value : ''

    this.rowTargets.forEach(row => {
      const rowText = row.textContent.toLowerCase()
      const rowStatus = row.dataset.status || ''

      const matchesSearch = searchTerm === '' || rowText.includes(searchTerm)
      const matchesStatus = statusFilter === '' || rowStatus === statusFilter

      if (matchesSearch && matchesStatus) {
        row.style.display = ''
      } else {
        row.style.display = 'none'
      }
    })
  }

  reset() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
    }
    if (this.hasStatusSelectTarget) {
      this.statusSelectTarget.selectedIndex = 0
    }
    this.filterRows()
  }
}

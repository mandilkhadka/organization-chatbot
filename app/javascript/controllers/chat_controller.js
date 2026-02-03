import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "button", "icon", "spinner"];

  connect() {
    this.inputTarget.focus();
  }

  disable() {
    // Disable form during submission
    this.inputTarget.disabled = true;
    this.buttonTarget.disabled = true;

    // Show loading spinner
    if (this.hasIconTarget && this.hasSpinnerTarget) {
      this.iconTarget.classList.add("d-none");
      this.spinnerTarget.classList.remove("d-none");
    }
  }

  enable() {
    // Re-enable form after submission
    this.inputTarget.disabled = false;
    this.buttonTarget.disabled = false;
    this.inputTarget.value = "";
    this.inputTarget.focus();

    // Hide loading spinner
    if (this.hasIconTarget && this.hasSpinnerTarget) {
      this.iconTarget.classList.remove("d-none");
      this.spinnerTarget.classList.add("d-none");
    }
  }

  // Handle Enter key submission
  submitOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.element.requestSubmit();
    }
  }
}

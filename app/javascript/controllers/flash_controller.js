import { Controller } from "@hotwired/stimulus"

// Auto-dismisses flash toasts after `delayValue` ms. Manual close button
// uses data-action="click->flash#close". The fade-out is driven by a CSS
// class (`.is-leaving`) so designers can tune the transition without
// touching JS. Hovering the toast pauses the timer.
export default class extends Controller {
  static values = { delay: { type: Number, default: 4500 } }

  connect() {
    this.armDismiss()
    this.element.addEventListener("mouseenter", this.pause)
    this.element.addEventListener("mouseleave", this.armDismiss)
  }

  disconnect() {
    this.pause()
    this.element.removeEventListener("mouseenter", this.pause)
    this.element.removeEventListener("mouseleave", this.armDismiss)
  }

  armDismiss = () => {
    this.pause()
    this.timer = setTimeout(() => this.close(), this.delayValue)
  }

  pause = () => {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  close = () => {
    this.pause()
    this.element.classList.add("is-leaving")
    // Match the SCSS transition duration so the node leaves the DOM
    // exactly when the animation ends.
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    // Fallback in case transitionend never fires (display:none parent etc.)
    setTimeout(() => this.element.remove(), 600)
  }
}

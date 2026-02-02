import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input"];

  connect() {
    this.inputTarget.focus();
  }

  reset() {
    this.inputTarget.value = "";
    this.inputTarget.focus();
  }
}

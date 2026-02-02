import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  async submit(event) {
    const button = event.currentTarget;
    const messageId = button.dataset.messageId;
    const feedback = button.dataset.feedback;
    const conversationId = window.location.pathname.split("/")[2];

    try {
      const response = await fetch(
        `/conversations/${conversationId}/messages/${messageId}/feedback`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
              .content,
          },
          body: JSON.stringify({ feedback: feedback }),
        },
      );

      if (response.ok) {
        // Update button styles
        const buttons = this.element.querySelectorAll(".feedback-btn");
        buttons.forEach((btn) => {
          btn.classList.remove("active");
        });
        button.classList.add("active");
      }
    } catch (error) {
      console.error("Failed to submit feedback:", error);
    }
  }
}

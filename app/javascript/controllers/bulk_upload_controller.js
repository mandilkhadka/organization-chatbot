import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "files",
    "titlePrefix",
    "categoryId",
    "fileList",
    "fileListItems",
    "uploadBtn",
    "progress",
    "results",
    "successAlert",
    "successList",
    "errorAlert",
    "errorList",
  ];

  // Escape HTML to prevent XSS attacks
  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  filesSelected() {
    const files = this.filesTarget.files;

    if (files.length === 0) {
      this.fileListTarget.style.display = "none";
      this.uploadBtnTarget.disabled = true;
      return;
    }

    if (files.length > 20) {
      alert("Maximum 20 files allowed");
      this.filesTarget.value = "";
      return;
    }

    this.fileListItemsTarget.innerHTML = "";

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const li = document.createElement("li");
      li.className =
        "list-group-item d-flex justify-content-between align-items-center";

      const sizeInMB = (file.size / (1024 * 1024)).toFixed(2);
      const sizeClass =
        file.size > 10 * 1024 * 1024 ? "text-danger" : "text-muted";

      // Build DOM elements safely to prevent XSS
      const nameSpan = document.createElement("span");
      const icon = document.createElement("i");
      icon.className = "fas fa-file me-2";
      nameSpan.appendChild(icon);
      nameSpan.appendChild(document.createTextNode(file.name));

      const sizeSpan = document.createElement("span");
      sizeSpan.className = `badge ${sizeClass}`;
      sizeSpan.textContent = `${sizeInMB} MB`;

      li.appendChild(nameSpan);
      li.appendChild(sizeSpan);
      this.fileListItemsTarget.appendChild(li);
    }

    this.fileListTarget.style.display = "block";
    this.uploadBtnTarget.disabled = false;
    this.resultsTarget.style.display = "none";
  }

  async upload() {
    const files = this.filesTarget.files;

    if (files.length === 0) {
      alert("Please select files to upload");
      return;
    }

    const formData = new FormData();

    for (let i = 0; i < files.length; i++) {
      formData.append("files[]", files[i]);
    }

    if (this.hasTitlePrefixTarget && this.titlePrefixTarget.value) {
      formData.append("title_prefix", this.titlePrefixTarget.value);
    }

    if (this.hasCategoryIdTarget && this.categoryIdTarget.value) {
      formData.append("category_id", this.categoryIdTarget.value);
    }

    this.uploadBtnTarget.disabled = true;
    this.progressTarget.style.display = "block";
    this.resultsTarget.style.display = "none";

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]');
      if (!csrfToken) {
        throw new Error("CSRF token not found");
      }

      const response = await fetch("/admin/documents/bulk_create", {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken.content,
        },
        body: formData,
      });

      if (!response.ok) {
        throw new Error(`Server error: ${response.status}`);
      }

      const result = await response.json();

      this.progressTarget.style.display = "none";
      this.resultsTarget.style.display = "block";

      if (result.successful && result.successful.length > 0) {
        this.successAlertTarget.style.display = "block";
        this.successListTarget.innerHTML = "";
        result.successful.forEach((doc) => {
          const li = document.createElement("li");
          li.textContent = doc.title;
          this.successListTarget.appendChild(li);
        });
      } else {
        this.successAlertTarget.style.display = "none";
      }

      if (result.failed && result.failed.length > 0) {
        this.errorAlertTarget.style.display = "block";
        this.errorListTarget.innerHTML = "";
        result.failed.forEach((doc) => {
          const li = document.createElement("li");
          li.textContent = `${doc.filename}: ${doc.error}`;
          this.errorListTarget.appendChild(li);
        });
      } else {
        this.errorAlertTarget.style.display = "none";
      }

      if (result.successful && result.successful.length > 0) {
        // Reload page after 2 seconds to show new documents
        setTimeout(() => {
          window.location.reload();
        }, 2000);
      } else {
        this.uploadBtnTarget.disabled = false;
      }
    } catch (error) {
      this.progressTarget.style.display = "none";
      this.resultsTarget.style.display = "block";
      this.errorAlertTarget.style.display = "block";
      this.errorListTarget.innerHTML = "";
      const li = document.createElement("li");
      li.textContent = `Upload failed: ${error.message}`;
      this.errorListTarget.appendChild(li);
      this.uploadBtnTarget.disabled = false;
    }
  }
}

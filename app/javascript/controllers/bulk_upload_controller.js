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

      li.innerHTML = `
        <span><i class="fas fa-file me-2"></i>${file.name}</span>
        <span class="badge ${sizeClass}">${sizeInMB} MB</span>
      `;
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
      const response = await fetch("/admin/documents/bulk_create", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
        body: formData,
      });

      const result = await response.json();

      this.progressTarget.style.display = "none";
      this.resultsTarget.style.display = "block";

      if (result.successful && result.successful.length > 0) {
        this.successAlertTarget.style.display = "block";
        this.successListTarget.innerHTML = result.successful
          .map((doc) => `<li>${doc.title}</li>`)
          .join("");
      } else {
        this.successAlertTarget.style.display = "none";
      }

      if (result.failed && result.failed.length > 0) {
        this.errorAlertTarget.style.display = "block";
        this.errorListTarget.innerHTML = result.failed
          .map((doc) => `<li>${doc.filename}: ${doc.error}</li>`)
          .join("");
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
      this.errorListTarget.innerHTML = `<li>Upload failed: ${error.message}</li>`;
      this.uploadBtnTarget.disabled = false;
    }
  }
}

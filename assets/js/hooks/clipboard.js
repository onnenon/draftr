// Add clipboard functionality hook
const Hooks = {
  CopyToClipboard: {
    mounted() {
      this.el.addEventListener("click", () => {
        const targetId = this.el.getAttribute("data-copy-target");
        const targetEl = document.getElementById(targetId);
        if (!targetEl) return;

        // Get the text to copy
        const textToCopy = targetEl.textContent;

        // Copy to clipboard
        navigator.clipboard
          .writeText(textToCopy)
          .then(() => {
            // Add "Copied!" text
            const feedbackEl = this.el.querySelector("[data-feedback]");
            if (feedbackEl) {
              const originalText = feedbackEl.textContent;
              feedbackEl.textContent = "Copied!";

              // Restore original text after 2 seconds
              setTimeout(() => {
                feedbackEl.textContent = originalText;
              }, 2000);
            }
          })
          .catch((err) => {
            console.error("Could not copy text: ", err);
          });
      });
    },
  },
};

export default Hooks;

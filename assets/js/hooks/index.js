import AnimationHooks from "./animation";
import ClipboardHooks from "./clipboard";
import RevealHook from "./reveal";
import CardFlipHook from "./card_flip";

// Hook for managing draft creator in local storage
const DraftCreator = {
  mounted() {
    this.handleEvent("store-draft-creator", ({ session_id }) => {
      // Store the session ID as a draft this user created
      localStorage.setItem(`draft_creator_${session_id}`, "true");
      console.log("Stored draft creator for session:", session_id);
    });
  }
};

// Hook to check if user is draft creator
const DraftViewer = {
  mounted() {
    const session_id = this.el.dataset.sessionId;
    const isCreator = localStorage.getItem(`draft_creator_${session_id}`) === "true";
    
    console.log("Checking draft creator for session:", session_id, "Is creator:", isCreator);
    
    // Make the isCreator status available to LiveView
    this.pushEvent("set_is_creator", { is_creator: isCreator });
    
    // Toggle visibility of creator-only elements
    if (!isCreator) {
      document.querySelectorAll("[data-creator-only]").forEach(el => {
        el.style.display = "none";
      });
      document.querySelectorAll("[data-viewer-only]").forEach(el => {
        el.style.display = "block";
      });
    } else {
      document.querySelectorAll("[data-creator-only]").forEach(el => {
        el.style.display = "block";
      });
      document.querySelectorAll("[data-viewer-only]").forEach(el => {
        el.style.display = "none";
      });
    }
  }
};

export default {
  ...AnimationHooks,
  ...ClipboardHooks,
  Reveal: RevealHook,
  CardFlip: CardFlipHook,
  DraftCreator,
  DraftViewer
};

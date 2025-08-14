// Card flip animation hook
const CardFlipHook = {
  mounted() {
    // Store the cards that have been flipped to avoid duplicate animations
    this.flippedCards = new Set();

    this.handleEvent("reveal_card", ({ index }) => {
      // Prevent double-flipping cards that have already been flipped
      if (this.flippedCards.has(index)) return;

      const card = this.el.querySelector(`[data-card-index="${index}"]`);
      if (card) {
        // Add a small delay for a more dramatic effect
        setTimeout(() => {
          // Add the is-flipped class to trigger the flip animation
          card.classList.add("is-flipped");

          // Also add a recently-flipped class for additional effects
          card.classList.add("recently-flipped");

          // Add to set of flipped cards
          this.flippedCards.add(index);

          // Scroll the card into view with a smooth animation
          card.scrollIntoView({
            behavior: "smooth",
            block: "center",
          });

          // Remove the recently-flipped class after animation completes
          setTimeout(() => {
            card.classList.remove("recently-flipped");
          }, 1500);
        }, 300);
      }
    });
  },
};

export default CardFlipHook;

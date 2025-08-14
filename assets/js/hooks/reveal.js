// Simple reveal animation hook
const RevealHook = {
  mounted() {
    // Store the rows that have been revealed to avoid duplicate animations
    this.revealedRows = new Set();
    
    this.handleEvent("reveal_pick", ({ index }) => {
      // Prevent double-revealing rows that have already been revealed
      if (this.revealedRows.has(index)) return;
      
      const row = this.el.querySelector(`[data-row-index="${index}"]`);
      if (row) {
        // Add to set of revealed rows
        this.revealedRows.add(index);
        
        // Add the revealed class to trigger the animation
        row.classList.add("opacity-0");
        
        // Add a small delay for a more dramatic effect
        setTimeout(() => {
          row.classList.remove("opacity-0");
          row.classList.add("opacity-100");
          
          // Scroll the row into view with a smooth animation
          row.scrollIntoView({
            behavior: "smooth",
            block: "center"
          });
          
          // Add a highlight effect that transitions from primary to base-100
          row.classList.add("bg-primary", "text-primary-content");
          setTimeout(() => {
            row.classList.add("transition-all", "duration-1000");
            row.classList.remove("bg-primary", "text-primary-content");
            row.classList.add("bg-base-100", "text-primary");
          }, 800);
        }, 300);
      }
    });
  }
};

export default RevealHook;

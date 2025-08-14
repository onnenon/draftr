// Animation hooks for transitions
const AnimationHooks = {
  AnimatedList: {
    mounted() {
      this.handleEvent("item_added", ({ index }) => {
        const items = this.el.querySelectorAll("[data-member-item]");
        if (items[index]) {
          const item = items[index];
          item.classList.add("animate-fade-in");
          setTimeout(() => {
            item.classList.remove("animate-fade-in");
          }, 500);
        }
      });

      this.handleEvent("item_removed", ({ index }) => {
        const items = this.el.querySelectorAll("[data-member-item]");
        if (index < items.length) {
          const item = items[index];
          item.classList.add("animate-fade-out");
        }
      });

      this.handleEvent("highlight_empty", () => {
        const items = this.el.querySelectorAll("[data-member-item]");
        items.forEach((item) => {
          const input = item.querySelector("input");
          if (input && input.value === "") {
            item.classList.add("animate-shake");
            input.style.borderColor = "var(--color-info)";
            input.style.boxShadow = "0 0 0 1px var(--color-info)";
            setTimeout(() => {
              item.classList.remove("animate-shake");
              // Reset after animation
              setTimeout(() => {
                input.style.borderColor = "";
                input.style.boxShadow = "";
              }, 2000);
            }, 500);
          }
        });
      });
    },
  },
};

export default AnimationHooks;

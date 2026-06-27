const toast = document.querySelector("#toast");
const notifyButton = document.querySelector("#notifyButton");
const faqItems = document.querySelectorAll(".faq-item");

function showToast(message) {
  if (!toast) return;
  toast.textContent = message;
  toast.classList.add("show");
  window.setTimeout(() => {
    toast.classList.remove("show");
  }, 2600);
}

faqItems.forEach((item) => {
  item.addEventListener("click", () => {
    item.classList.toggle("open");
    const symbol = item.querySelector("strong");
    if (symbol) {
      symbol.textContent = item.classList.contains("open") ? "-" : "+";
    }
  });
});

if (notifyButton) {
  notifyButton.addEventListener("click", () => {
    showToast("Email capture is a placeholder in this prototype.");
  });
}

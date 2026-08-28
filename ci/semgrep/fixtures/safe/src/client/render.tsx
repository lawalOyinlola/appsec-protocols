// Control 17 — rendered as text; sanitized where HTML is genuinely required.
export function Bio({ text, html }) {
  const node = document.getElementById("x");
  node.textContent = text;
  return <div>{text}</div>;
}

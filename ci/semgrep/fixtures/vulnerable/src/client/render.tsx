// Control 17 — output escaping escape hatches.
export function Bio({ html }) {
  document.getElementById("x").innerHTML = html;
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
export const link = `<a href="javascript:alert(1)">x</a>`;
export const run = (src) => eval(src);

// Cosmetic cleanup of module-qualified bindings rendered by Documenter.
//
// Documenter renders every documented symbol with its full module-qualified
// binding path, e.g., `Enumlib.basis` or `Enumlib.Polya.polya_count`. For a
// single-package docs site the `Enumlib.` prefix is noise — readers already
// know they're on the Enumlib docs. The submodule prefix `Polya.` is kept
// because it usefully signals "this lives in a submodule"; `Base.*` entries
// (e.g. `Base.enumerate`) are left alone since the `Base.` prefix is
// informative — it tells the user this is a method extension of a Base
// function rather than a new Enumlib-only function.
//
// Applied in two places:
//   1. The auto-generated `@index` block on `reference/index.md`.
//   2. The docstring-binding headers above every documented symbol on the
//      per-page reference pages (e.g., `# Enumlib.basis — Function`).
//
// Only text content is edited; `href` and `id` attributes still carry the
// canonical-binding form so navigation and deep links continue to work.

document.addEventListener("DOMContentLoaded", function () {
    function stripPrefix(t) {
        if (t.startsWith("Enumlib.Polya.")) {
            return "Polya." + t.slice("Enumlib.Polya.".length);
        }
        if (t.startsWith("Enumlib.")) {
            return t.slice("Enumlib.".length);
        }
        return t; // Base.* and anything else: unchanged.
    }

    // (1) The @index block — only present on reference/index.html.
    const indexHeading = document.getElementById("Index");
    if (indexHeading) {
        // The @index block renders as `<h2 id="Index">` followed by a `<ul>`.
        let el = indexHeading.nextElementSibling;
        while (el && el.tagName !== "UL") el = el.nextElementSibling;
        if (el) {
            el.querySelectorAll("code").forEach(function (code) {
                code.textContent = stripPrefix(code.textContent);
            });
        }
    }

    // (2) Per-page docstring-binding headers across all reference pages.
    document.querySelectorAll("a.docstring-binding > code").forEach(function (code) {
        code.textContent = stripPrefix(code.textContent);
    });
});

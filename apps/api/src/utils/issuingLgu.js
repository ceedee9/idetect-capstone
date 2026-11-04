// src/utils/issuingLgu.js
// Detects Senior Citizen / PWD cards whose printed text names another city
// or municipality. Those cards cannot be checked against the Valenzuela
// registry, so the verification route sends them to MANUAL REVIEW.
//
// Only the top lines of the card are read, where the issuing city is printed.
// A card counts as "other" only when a government keyword (CITY OF, CITY
// GOVERNMENT OF, MUNICIPALITY OF, LUNGSOD NG, BAYAN NG) is followed by a
// known Philippine city or municipality name, allowing a small number of
// OCR misread letters in longer names. A Valenzuela mention always wins.
// A card with no readable city is "unknown" and keeps the normal registry lookup.

const phLguNames = require("../data/phLguNames.json");

const HEADER_LINE_COUNT = 8;

// Tolerates common OCR misreads of "VALENZUELA" (e.g. "VALENZUEIA").
const VALENZUELA_PATTERN = /VALENZ|ALENZU/;

// Government keyword that comes right before a city name on the card.
const KEYWORD_PATTERN =
  /\b(?:CITY|MUNICIPALITY|MUNICIPAL|LUNGSOD|BAYAN)\s+(?:GOVERNMENT\s+|GOVT\.?\s+)?(?:OF|NG)\s+/g;

// Names shorter than 6 letters must match exactly, so common short words
// are not matched by accident. Longer names tolerate 1 misread letter, and
// names of 12 letters or more tolerate 2.
function maxEditsFor(name) {
  if (name.length >= 12) return 2;
  if (name.length >= 6) return 1;
  return 0;
}

function editDistance(a, b) {
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[b.length];
}

// Names that the start of `tail` matches, allowing the name to end at a word boundary.
function namesAtTail(tail) {
  const found = [];
  for (const name of phLguNames) {
    const k = maxEditsFor(name);
    const to = Math.min(tail.length, name.length + k);
    for (let l = Math.max(1, name.length - k); l <= to; l++) {
      if (/[A-Z0-9]/.test(tail[l] ?? "")) continue;
      if (editDistance(tail.slice(0, l), name) <= k) {
        found.push(name);
        break;
      }
    }
  }
  return found;
}

// Every city or municipality name that follows a government keyword in the header.
function issuingCityNames(upperHeader) {
  const text = upperHeader.replace(/\s+/g, " ");
  const names = new Set();
  for (const match of text.matchAll(KEYWORD_PATTERN)) {
    for (const name of namesAtTail(text.slice(match.index + match[0].length))) {
      names.add(name);
    }
  }
  return names;
}

function headerLines(rawText) {
  if (typeof rawText !== "string") return "";
  return rawText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, HEADER_LINE_COUNT)
    .join("\n");
}

// Returns "valenzuela", "other", or "unknown".
function classifyIssuingCity(rawText) {
  const upper = headerLines(rawText).toUpperCase();
  if (!upper) return "unknown";
  if (VALENZUELA_PATTERN.test(upper)) return "valenzuela";
  const names = issuingCityNames(upper);
  if (names.has("VALENZUELA")) return "valenzuela";
  return names.size > 0 ? "other" : "unknown";
}

function detectOutsideValenzuela(rawText) {
  return classifyIssuingCity(rawText) === "other";
}

module.exports = { HEADER_LINE_COUNT, headerLines, classifyIssuingCity, detectOutsideValenzuela };

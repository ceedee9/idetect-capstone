// Canonical disability type options aligned with PWD ID parsing.
export const PDAO_DISABILITY_TYPES = [
  "Deaf or Hard of Hearing",
  "Intellectual Disability",
  "Learning Disability",
  "Mental Disability",
  "Psychosocial Disability",
  "Physical Disability",
  "Speech and Language Impairment",
  "Visual Disability",
  "Cancer",
  "Rare Disease",
  "Other",
];

export const PDAO_DISABILITY_OPTIONS = [
  { value: "", label: "Select disability type..." },
  ...PDAO_DISABILITY_TYPES.map((label) => ({
    value: label.toLowerCase(),
    label,
  })),
];

export const PDAO_DISABILITY_FILTER_OPTIONS = [
  { value: "", label: "All Types" },
  ...PDAO_DISABILITY_TYPES.map((label) => ({
    value: label.toLowerCase(),
    label,
  })),
];

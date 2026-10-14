const maskIdNumber = (value) => {
  if (value == null || value === "") return value;
  const normalized = String(value);
  const visible = normalized.slice(-2);
  return `${"*".repeat(Math.max(normalized.length - 2, 2))}${visible}`;
};

const getAgeBand = (birthdate, now = new Date()) => {
  if (!birthdate) return null;
  const date = new Date(birthdate);
  if (Number.isNaN(date.getTime()) || date > now) return null;

  let age = now.getUTCFullYear() - date.getUTCFullYear();
  const month = now.getUTCMonth() - date.getUTCMonth();
  if (month < 0 || (month === 0 && now.getUTCDate() < date.getUTCDate())) {
    age -= 1;
  }

  if (age < 18) return "under_18";
  if (age < 30) return "18_29";
  if (age < 45) return "30_44";
  if (age < 60) return "45_59";
  if (age < 70) return "60_69";
  if (age < 80) return "70_79";
  return "80_plus";
};

const maskBeneficiary = (record) => {
  if (!record) return record;
  const masked = { ...record };

  if (Object.prototype.hasOwnProperty.call(masked, "id_number")) {
    masked.id_number = maskIdNumber(masked.id_number);
  }
  if (Object.prototype.hasOwnProperty.call(masked, "id_number_flagged")) {
    masked.id_number_flagged = maskIdNumber(masked.id_number_flagged);
  }
  if (Object.prototype.hasOwnProperty.call(masked, "beneficiary_id_number")) {
    masked.beneficiary_id_number = maskIdNumber(masked.beneficiary_id_number);
  }

  if (Object.prototype.hasOwnProperty.call(masked, "birthdate")) {
    masked.age_band = getAgeBand(masked.birthdate);
    delete masked.birthdate;
  }
  if (Object.prototype.hasOwnProperty.call(masked, "date_of_birth")) {
    masked.age_band = getAgeBand(masked.date_of_birth);
    delete masked.date_of_birth;
  }

  return masked;
};

module.exports = { getAgeBand, maskBeneficiary, maskIdNumber };

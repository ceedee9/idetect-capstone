import { useState, useEffect, useCallback } from "react";
import { beneficiariesAPI } from "../services/api";

function splitFullName(fullName = "") {
  const raw = String(fullName).trim();
  if (!raw) return { first_name: "", middle_name: "", last_name: "" };

  // Supports: "Lastname, Firstname Middlename"
  if (raw.includes(",")) {
    const [last, rest = ""] = raw.split(",");
    const parts = rest.trim().split(/\s+/).filter(Boolean);
    return {
      first_name: parts[0] ?? "",
      middle_name: parts.slice(1).join(" "),
      last_name: last.trim(),
    };
  }

  // Supports: "Firstname Middlename Lastname"
  const parts = raw.split(/\s+/).filter(Boolean);
  if (parts.length === 1) {
    return { first_name: parts[0], middle_name: "", last_name: "" };
  }
  if (parts.length === 2) {
    return { first_name: parts[0], middle_name: "", last_name: parts[1] };
  }
  return {
    first_name: parts[0],
    middle_name: parts.slice(1, -1).join(" "),
    last_name: parts[parts.length - 1],
  };
}

function normalizeBeneficiary(raw = {}) {
  const b = { ...raw };

  if (!b.date_of_birth && b.birthdate) b.date_of_birth = b.birthdate;
  if (!b.contact_number && b.registered_mobile)
    b.contact_number = b.registered_mobile;
  if (!b.id_expiry_date && b.validity_end) b.id_expiry_date = b.validity_end;

  if (!b.first_name && !b.last_name && b.full_name) {
    const parsed = splitFullName(b.full_name);
    b.first_name = parsed.first_name;
    b.middle_name = parsed.middle_name;
    b.last_name = parsed.last_name;
  }

  if (!b.full_name && (b.first_name || b.last_name)) {
    b.full_name = [b.first_name, b.middle_name, b.last_name]
      .filter(Boolean)
      .join(" ")
      .replace(/\s+/g, " ")
      .trim();
  }

  return b;
}

function extractList(data) {
  if (!data) return [];
  if (Array.isArray(data)) return data;
  for (const key of ["beneficiaries", "data", "rows", "results", "items"]) {
    if (Array.isArray(data[key])) return data[key];
  }
  const first = Object.values(data).find((v) => Array.isArray(v));
  return first ?? [];
}

export function useBeneficiaries(params = {}) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetch = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await beneficiariesAPI.list(params);
      setData(extractList(res.data).map(normalizeBeneficiary));
    } catch (err) {
      setError(err.response?.data?.message || "Failed to load beneficiaries.");
    } finally {
      setLoading(false);
    }
  }, [JSON.stringify(params)]);

  useEffect(() => {
    fetch();
  }, [fetch]);
  return { data, loading, error, refetch: fetch };
}

export function useBeneficiary(id) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetch = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const res = await beneficiariesAPI.getById(id);
      // API may return { beneficiary: {...} } or just the object
      const raw = res.data?.beneficiary ?? res.data;
      setData(normalizeBeneficiary(raw));
    } catch (err) {
      // Fallback: scan from list
      try {
        const listRes = await beneficiariesAPI.list();
        const list = extractList(listRes.data).map(normalizeBeneficiary);
        const found = list.find((b) => String(b.id) === String(id));
        if (!found) throw new Error("Beneficiary not found.");
        setData(found);
      } catch (e2) {
        setError(e2.message || "Failed to load beneficiary.");
      }
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetch();
  }, [fetch]);
  return { data, loading, error, refetch: fetch };
}

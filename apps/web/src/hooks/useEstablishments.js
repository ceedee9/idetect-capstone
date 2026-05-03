import { useState, useEffect, useCallback } from "react";
import { establishmentsAPI } from "../services/api";

// Extracts array from any API response shape
function extractList(data) {
  if (!data) return [];
  if (Array.isArray(data)) return data;
  // Try common wrapper keys in order of likelihood
  for (const key of ["establishments", "data", "rows", "results", "items"]) {
    if (Array.isArray(data[key])) return data[key];
  }
  // Last resort: find the first array value in the object
  const firstArray = Object.values(data).find((v) => Array.isArray(v));
  if (firstArray) return firstArray;
  console.warn("[useEstablishments] Could not find array in response:", data);
  return [];
}

export function useEstablishments(params = {}) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetch = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await establishmentsAPI.list(params);
      const list = extractList(res.data);
      console.log("[useEstablishments] parsed list:", list);
      setData(list);
    } catch (err) {
      setError(err.response?.data?.message || "Failed to load establishments.");
    } finally {
      setLoading(false);
    }
  }, [JSON.stringify(params)]);

  useEffect(() => {
    fetch();
  }, [fetch]);

  return { data, loading, error, refetch: fetch };
}

export function useEstablishment(id) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetch = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const res = await establishmentsAPI.get(id);
      setData(res.data);
    } catch (err) {
      setError(
        err.response?.data?.message ||
          err.message ||
          "Failed to load establishment.",
      );
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    fetch();
  }, [fetch]);

  return { data, loading, error, refetch: fetch };
}

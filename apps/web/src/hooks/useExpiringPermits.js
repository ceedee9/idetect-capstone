import { useState, useEffect } from "react";
import { establishmentsAPI } from "../services/api";

export function useExpiringPermits(days = 30) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    establishmentsAPI
      .expiringPermits(days)
      .then((res) => {
        if (!cancelled) setData(res.data?.data || []);
      })
      .catch(() => {
        if (!cancelled) setData([]);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [days]);

  return { data, loading };
}
